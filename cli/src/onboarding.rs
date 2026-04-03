// ---------------------------------------------------------------------------
// plauncher onboarding — CLI driver for the new-hire onboarding flow
// ---------------------------------------------------------------------------

use anyhow::{Context, Result};
use colored::*;
use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, Write};
use std::process::{Command, Stdio};

use crate::auth;

// ---------------------------------------------------------------------------
// API types (mirror serve::OnboardingState / OnboardingStepState)
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize, Serialize, Clone, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum StepStatus {
    Pending,
    InProgress,
    Done,
    Failed,
}

impl std::fmt::Display for StepStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match self {
                StepStatus::Pending => "pending",
                StepStatus::InProgress => "inProgress",
                StepStatus::Done => "done",
                StepStatus::Failed => "failed",
            }
        )
    }
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct Step {
    pub id: String,
    pub label: String,
    pub status: StepStatus,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OnboardingResponse {
    pub workspace_id: String,
    pub steps: Vec<Step>,
    pub started_at: String,
    pub completed_at: Option<String>,
    pub progress: f64,
}

/// Minimal catalog response for `plauncher join`
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
struct CatalogInfo {
    #[serde(rename = "name", alias = "orgName")]
    name: Option<String>,
    #[serde(rename = "githubOrg", alias = "github_org")]
    github_org: Option<String>,
    repos: Option<Vec<CatalogRepoInfo>>,
}

#[derive(Debug, Deserialize, Clone)]
struct CatalogRepoInfo {
    name: String,
    url: String,
    #[serde(default)]
    required: bool,
    #[serde(rename = "envTemplate", alias = "env_template")]
    env_template: Option<String>,
}

/// Response from GET /health
#[derive(Debug, Deserialize)]
struct HealthResponse {
    #[allow(dead_code)]
    status: String,
    #[serde(default)]
    oauth: bool,
    /// Org slug returned in self-hosted mode
    #[serde(default)]
    org: Option<String>,
}

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

fn auth_header(token: &str) -> reqwest::header::HeaderMap {
    let mut headers = reqwest::header::HeaderMap::new();
    headers.insert(
        reqwest::header::AUTHORIZATION,
        format!("Bearer {}", token).parse().unwrap(),
    );
    headers
}

/// Build the org-scoped API base: `{server}/api/orgs/{org}`
fn api_base(server: &str, org: &str) -> String {
    format!("{}/api/orgs/{}", server, org)
}

async fn fetch_health(server: &str) -> Result<HealthResponse> {
    let client = reqwest::Client::new();
    let resp = client
        .get(format!("{}/health", server))
        .send()
        .await
        .context("Failed to reach catalog server /health")?;

    if !resp.status().is_success() {
        anyhow::bail!("Server returned {} for GET /health", resp.status());
    }
    resp.json::<HealthResponse>()
        .await
        .context("Failed to parse /health response")
}

async fn fetch_onboarding(server: &str, org: &str, token: &str) -> Result<OnboardingResponse> {
    let client = reqwest::Client::new();
    let url = format!("{}/onboarding", api_base(server, org));
    let resp = client
        .get(&url)
        .headers(auth_header(token))
        .send()
        .await
        .context("Failed to reach catalog server")?;

    if !resp.status().is_success() {
        anyhow::bail!("Server returned {} for GET {}", resp.status(), url);
    }
    resp.json::<OnboardingResponse>()
        .await
        .context("Failed to parse onboarding response")
}

async fn post_step_update(
    server: &str,
    org: &str,
    token: &str,
    step_id: &str,
    status: &str,
) -> Result<()> {
    let client = reqwest::Client::new();
    let body = serde_json::json!({
        "stepId": step_id,
        "status": status,
    });
    let url = format!("{}/onboarding/step", api_base(server, org));
    let resp = client
        .post(&url)
        .headers(auth_header(token))
        .json(&body)
        .send()
        .await
        .context("Failed to POST step update")?;

    if !resp.status().is_success() {
        anyhow::bail!("Server returned {} for POST {}", resp.status(), url);
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Step display helpers
// ---------------------------------------------------------------------------

fn step_symbol(status: &StepStatus) -> ColoredString {
    match status {
        StepStatus::Done => "✓".green().bold(),
        StepStatus::Failed => "✗".red().bold(),
        StepStatus::InProgress => "⏳".yellow(),
        StepStatus::Pending => "○".dimmed(),
    }
}

fn print_step(step: &Step, annotation: Option<&str>) {
    let sym = step_symbol(&step.status);
    let label = match step.status {
        StepStatus::Done => step.label.green().to_string(),
        StepStatus::Failed => step.label.red().to_string(),
        StepStatus::InProgress => step.label.yellow().to_string(),
        StepStatus::Pending => step.label.dimmed().to_string(),
    };
    if let Some(note) = annotation {
        println!("  {} {}  {}", sym, label, note.yellow().dimmed());
    } else {
        println!("  {} {}", sym, label);
    }
}

// ---------------------------------------------------------------------------
// `plauncher join <url>`
// ---------------------------------------------------------------------------

pub async fn cmd_join(
    url: &str,
    base_path: &str,
    token_flag: Option<&str>,
    org_flag: Option<&str>,
) -> Result<()> {
    let server = url.trim_end_matches('/');

    // -----------------------------------------------------------------------
    // Resolve authentication token
    // -----------------------------------------------------------------------
    let token: String;

    if let Some(t) = token_flag {
        // Explicit --token provided
        token = t.to_string();
        println!(
            "\n  {} Using provided API key",
            "→".cyan().bold(),
        );
    } else if let Some((saved_token, _saved_org)) = auth::load_token_for_server(server) {
        // Saved token found for this server
        token = saved_token;
        println!(
            "\n  {} Using saved token for {}",
            "→".cyan().bold(),
            server.cyan()
        );
    } else {
        // No token — check if server supports OAuth
        print!(
            "\n  {} Checking server auth options... ",
            "→".cyan().bold(),
        );
        io::stdout().flush().ok();

        let health = fetch_health(server).await?;

        if health.oauth {
            // Server supports OAuth — do browser flow
            println!("{}", "OAuth available".green());
            println!(
                "\n  {} Authenticating via GitHub...",
                "→".cyan().bold()
            );
            let device_id = uuid::Uuid::new_v4().to_string();
            let auth_url = format!("{}/auth/github?device_id={}", server, device_id);
            println!(
                "  {} Open this URL in your browser to authenticate:",
                "→".yellow()
            );
            println!("    {}", auth_url.cyan().underline());

            token = poll_for_token(server, &device_id).await?;
            println!("  {} Authenticated", "✓".green().bold());
        } else {
            // No OAuth, no token — tell user what to do
            println!("{}", "no OAuth".yellow());
            println!();
            println!(
                "  {} No token provided and server does not support browser OAuth.",
                "!".red().bold()
            );
            println!("  Ask your org admin for an API key, then run:");
            println!();
            println!(
                "    {}",
                format!("plauncher join {} --token <your-api-key>", server).cyan()
            );
            println!();
            std::process::exit(1);
        }
    }

    // -----------------------------------------------------------------------
    // Resolve org slug
    // -----------------------------------------------------------------------
    let org: String;

    if let Some(o) = org_flag {
        org = o.to_string();
    } else if let Some((_saved_token, saved_org)) = auth::load_token_for_server(server) {
        if !saved_org.is_empty() {
            org = saved_org;
        } else {
            // Try /health for org slug
            let health = fetch_health(server).await?;
            org = health.org.unwrap_or_default();
        }
    } else {
        // Try /health for org slug
        let health = fetch_health(server).await?;
        org = health.org.unwrap_or_default();
    }

    if org.is_empty() {
        println!();
        println!(
            "  {} Could not determine org slug. Provide it with --org:",
            "!".red().bold()
        );
        println!(
            "    {}",
            format!("plauncher join {} --token <key> --org <slug>", server).cyan()
        );
        println!();
        std::process::exit(1);
    }

    // Save auth for future commands
    auth::save_token(server, &token, &org)?;
    println!(
        "  {} Auth saved for {}/{}",
        "✓".green().bold(),
        server.dimmed(),
        org.dimmed()
    );

    // -----------------------------------------------------------------------
    // Step 1: Fetch catalog info (authenticated, org-scoped)
    // -----------------------------------------------------------------------
    print!(
        "\n  {} Fetching catalog from {}... ",
        "→".cyan().bold(),
        server.cyan()
    );
    io::stdout().flush().ok();

    let client = reqwest::Client::new();
    let catalog_url = format!("{}/catalog", api_base(server, &org));
    let catalog_resp = client
        .get(&catalog_url)
        .headers(auth_header(&token))
        .send()
        .await
        .context("Failed to reach catalog server")?;

    if !catalog_resp.status().is_success() {
        println!("{}", "✗".red().bold());
        anyhow::bail!(
            "Server returned {} for GET {} — check your token and org slug.",
            catalog_resp.status(),
            catalog_url
        );
    }

    // Parse catalog (best-effort; server may return varied shapes)
    let catalog_body = catalog_resp
        .json::<serde_json::Value>()
        .await
        .context("Failed to parse catalog JSON")?;

    let org_name = catalog_body["name"]
        .as_str()
        .or_else(|| catalog_body["orgName"].as_str())
        .or_else(|| catalog_body["githubOrg"].as_str())
        .unwrap_or(&org);

    let repos: Vec<CatalogRepoInfo> = catalog_body["repos"]
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|v| serde_json::from_value::<CatalogRepoInfo>(v.clone()).ok())
                .collect()
        })
        .unwrap_or_default();

    let required_repos: Vec<&CatalogRepoInfo> = repos.iter().filter(|r| r.required).collect();

    println!("{}", "✓".green().bold());
    println!(
        "  {} Catalog: {} ({} repos, {} required)",
        " ".dimmed(),
        org_name.bold(),
        repos.len(),
        required_repos.len()
    );

    // -----------------------------------------------------------------------
    // Step 2: Clone required repos
    // -----------------------------------------------------------------------
    if required_repos.is_empty() {
        println!(
            "\n  {} No required repos to clone.",
            "i".cyan().bold()
        );
    } else {
        println!(
            "\n  {} Starting onboarding ({} required repos):",
            "→".cyan().bold(),
            required_repos.len()
        );

        std::fs::create_dir_all(base_path)
            .with_context(|| format!("Cannot create base directory: {}", base_path))?;

        for (i, repo) in required_repos.iter().enumerate() {
            let n = i + 1;
            let total = required_repos.len();
            print!(
                "  [{}/{}] Cloning {}... ",
                n,
                total,
                repo.name.bold()
            );
            io::stdout().flush().ok();

            let target = format!("{}/{}", base_path, repo.name);
            if std::path::Path::new(&target).exists() {
                println!("{} (already exists)", "⊙".yellow());
                post_step_update(server, &org, &token, &format!("clone_{}", repo.name), "done")
                    .await
                    .ok();
                continue;
            }

            let result = Command::new("git")
                .args(["clone", &repo.url, &target])
                .output();

            match result {
                Ok(out) if out.status.success() => {
                    println!("{}", "✓".green().bold());
                    post_step_update(server, &org, &token, &format!("clone_{}", repo.name), "done")
                        .await
                        .ok();
                }
                Ok(out) => {
                    println!("{}", "✗".red().bold());
                    eprintln!(
                        "    {}: {}",
                        "stderr".red(),
                        String::from_utf8_lossy(&out.stderr).trim()
                    );
                    post_step_update(server, &org, &token, &format!("clone_{}", repo.name), "failed")
                        .await
                        .ok();
                }
                Err(e) => {
                    println!("{}", "✗".red().bold());
                    eprintln!("    {}: {}", "error".red(), e);
                    post_step_update(server, &org, &token, &format!("clone_{}", repo.name), "failed")
                        .await
                        .ok();
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Step 3: Env setup — prompt for repos with env templates
    // -----------------------------------------------------------------------
    for repo in &required_repos {
        if repo.env_template.is_none() {
            continue;
        }
        let step_id = format!("env_{}", repo.name);
        post_step_update(server, &org, &token, &step_id, "inProgress")
            .await
            .ok();

        println!(
            "\n  {} Setup env for {} (has env template: {})",
            "→".yellow().bold(),
            repo.name.bold(),
            repo.env_template.as_deref().unwrap_or("").cyan()
        );

        let repo_path = format!("{}/{}", base_path, repo.name);
        let env_file = format!("{}/.env", repo_path);

        if std::path::Path::new(&env_file).exists() {
            println!(
                "  {} .env already exists, skipping.",
                "⊙".yellow()
            );
            post_step_update(server, &org, &token, &step_id, "done").await.ok();
            continue;
        }

        println!("  Enter environment variables (leave blank to skip):");
        let stdin = io::stdin();
        let mut lines = Vec::new();

        print!("  > ");
        io::stdout().flush().ok();
        for line in stdin.lock().lines() {
            let line = line.context("Failed to read stdin")?;
            if line.trim().is_empty() {
                break;
            }
            lines.push(line);
            print!("  > ");
            io::stdout().flush().ok();
        }

        if !lines.is_empty() {
            std::fs::create_dir_all(&repo_path).ok();
            std::fs::write(&env_file, lines.join("\n") + "\n")
                .with_context(|| format!("Failed to write {}", env_file))?;
            println!("  {} Wrote .env", "✓".green().bold());
        }

        post_step_update(server, &org, &token, &step_id, "done").await.ok();
    }

    // -----------------------------------------------------------------------
    // Step 4: Build verify
    // -----------------------------------------------------------------------
    println!("\n  {} Running build verification...", "→".cyan().bold());
    let build_ok = run_build_verify(base_path, &required_repos);
    post_step_update(
        server,
        &org,
        &token,
        "build_verify",
        if build_ok { "done" } else { "failed" },
    )
    .await
    .ok();
    if build_ok {
        println!("  {} Build verification passed", "✓".green().bold());
    } else {
        println!("  {} Build verification failed (check output above)", "✗".red().bold());
    }

    // -----------------------------------------------------------------------
    // Step 5: Test verify
    // -----------------------------------------------------------------------
    println!("\n  {} Running test verification...", "→".cyan().bold());
    let test_ok = run_test_verify(base_path, &required_repos);
    post_step_update(
        server,
        &org,
        &token,
        "test_verify",
        if test_ok { "done" } else { "failed" },
    )
    .await
    .ok();
    if test_ok {
        println!("  {} Test verification passed", "✓".green().bold());
    } else {
        println!("  {} Test verification failed (check output above)", "✗".red().bold());
    }

    // Done
    println!("\n  {} Onboarding complete! You're ready to code.", "★".green().bold());
    println!(
        "  {} Repos cloned to: {}\n",
        " ".dimmed(),
        base_path.dimmed()
    );

    Ok(())
}

// ---------------------------------------------------------------------------
// `plauncher onboarding status`
// ---------------------------------------------------------------------------

pub async fn cmd_status(server: &str, token: &str) -> Result<()> {
    let org = resolve_org(server)?;
    let state = fetch_onboarding(server, &org, token).await?;

    let pct = (state.progress * 100.0).round() as u32;
    println!(
        "\n  {} Onboarding: {} ({}% complete)",
        "→".cyan().bold(),
        state.workspace_id.bold(),
        pct
    );
    println!("  {}", "-".repeat(50).dimmed());

    for step in &state.steps {
        let note = if step.status == StepStatus::InProgress {
            Some("← needs input")
        } else {
            None
        };
        print_step(step, note);
    }

    println!("  {}", "-".repeat(50).dimmed());
    if let Some(completed) = &state.completed_at {
        println!("  {} Completed at: {}", "✓".green().bold(), completed.dimmed());
    } else {
        println!(
            "  {} {:.0}% complete  ({}/{} steps done)",
            "◐".cyan(),
            state.progress * 100.0,
            state.steps.iter().filter(|s| s.status == StepStatus::Done).count(),
            state.steps.len()
        );
    }
    println!();

    Ok(())
}

// ---------------------------------------------------------------------------
// `plauncher onboarding continue`
// ---------------------------------------------------------------------------

pub async fn cmd_continue(server: &str, token: &str, base_path: &str) -> Result<()> {
    let org = resolve_org(server)?;
    let state = fetch_onboarding(server, &org, token).await?;

    let first_pending = state
        .steps
        .iter()
        .find(|s| s.status != StepStatus::Done);

    match first_pending {
        None => {
            println!("\n  {} All onboarding steps are already complete!", "✓".green().bold());
            return Ok(());
        }
        Some(step) => {
            println!(
                "\n  {} Resuming from: {}",
                "→".cyan().bold(),
                step.label.bold()
            );
        }
    }

    // Drive remaining steps
    for step in state.steps.iter().filter(|s| s.status != StepStatus::Done) {
        match step.id.as_str() {
            id if id.starts_with("clone_") => {
                let repo_name = id.trim_start_matches("clone_");
                print!(
                    "  {} Cloning {}... ",
                    "→".cyan(),
                    repo_name.bold()
                );
                io::stdout().flush().ok();

                let target = format!("{}/{}", base_path, repo_name);
                if std::path::Path::new(&target).exists() {
                    println!("{} (already exists)", "⊙".yellow());
                    post_step_update(server, &org, token, &step.id, "done").await.ok();
                } else {
                    // We don't have the URL here; mark as needs-manual
                    println!(
                        "{}",
                        "⚠ repo URL not available in status — run `plauncher join <url>` instead"
                            .yellow()
                    );
                }
            }
            id if id.starts_with("env_") => {
                let repo_name = id.trim_start_matches("env_");
                println!(
                    "  {} Env setup for {} — open {}/{repo_name}/.env and fill in required vars,",
                    "⏳".yellow(),
                    repo_name.bold(),
                    base_path
                );
                println!("      then run this command again.");
            }
            "build_verify" => {
                println!("  {} Running build verification...", "→".cyan());
                let ok = try_build_in_dir(base_path);
                post_step_update(server, &org, token, "build_verify", if ok { "done" } else { "failed" })
                    .await
                    .ok();
                if ok {
                    println!("  {} Build verify done", "✓".green().bold());
                } else {
                    println!("  {} Build verify failed", "✗".red().bold());
                }
            }
            "test_verify" => {
                println!("  {} Running test verification...", "→".cyan());
                let ok = try_test_in_dir(base_path);
                post_step_update(server, &org, token, "test_verify", if ok { "done" } else { "failed" })
                    .await
                    .ok();
                if ok {
                    println!("  {} Test verify done", "✓".green().bold());
                } else {
                    println!("  {} Test verify failed", "✗".red().bold());
                }
            }
            _ => {
                println!("  {} Unknown step: {}", "?".dimmed(), step.id);
            }
        }
    }

    println!("\n  {} Done. Run `plauncher onboarding status` to check progress.\n", "✓".green().bold());
    Ok(())
}

/// Resolve the org slug from saved auth
fn resolve_org(server: &str) -> Result<String> {
    if let Some((_token, org)) = auth::load_token_for_server(server) {
        if !org.is_empty() {
            return Ok(org);
        }
    }
    // Fallback: check if any saved auth has the org
    if let Some(saved) = auth::load_auth() {
        if !saved.org.is_empty() {
            return Ok(saved.org);
        }
    }
    anyhow::bail!(
        "No org slug found. Run `plauncher join <url> --token <key> --org <slug>` first."
    )
}

// ---------------------------------------------------------------------------
// Build / test helpers
// ---------------------------------------------------------------------------

fn run_build_verify(base_path: &str, repos: &[&CatalogRepoInfo]) -> bool {
    let mut all_ok = true;
    for repo in repos {
        let repo_path = format!("{}/{}", base_path, repo.name);
        if !std::path::Path::new(&repo_path).exists() {
            continue;
        }
        let ok = if std::path::Path::new(&format!("{}/pubspec.yaml", repo_path)).exists() {
            run_streaming(
                "flutter",
                &["pub", "get"],
                &repo_path,
                &format!("flutter pub get ({})", repo.name),
            )
        } else if std::path::Path::new(&format!("{}/Cargo.toml", repo_path)).exists() {
            run_streaming(
                "cargo",
                &["build"],
                &repo_path,
                &format!("cargo build ({})", repo.name),
            )
        } else {
            true // no known build system — skip
        };
        if !ok {
            all_ok = false;
        }
    }
    all_ok
}

fn run_test_verify(base_path: &str, repos: &[&CatalogRepoInfo]) -> bool {
    let mut all_ok = true;
    for repo in repos {
        let repo_path = format!("{}/{}", base_path, repo.name);
        if !std::path::Path::new(&repo_path).exists() {
            continue;
        }
        let ok = if std::path::Path::new(&format!("{}/pubspec.yaml", repo_path)).exists() {
            run_streaming(
                "flutter",
                &["test"],
                &repo_path,
                &format!("flutter test ({})", repo.name),
            )
        } else if std::path::Path::new(&format!("{}/Cargo.toml", repo_path)).exists() {
            run_streaming(
                "cargo",
                &["test"],
                &repo_path,
                &format!("cargo test ({})", repo.name),
            )
        } else {
            true
        };
        if !ok {
            all_ok = false;
        }
    }
    all_ok
}

fn try_build_in_dir(dir: &str) -> bool {
    if std::path::Path::new(&format!("{}/pubspec.yaml", dir)).exists() {
        run_streaming("flutter", &["pub", "get"], dir, "flutter pub get")
    } else if std::path::Path::new(&format!("{}/Cargo.toml", dir)).exists() {
        run_streaming("cargo", &["build"], dir, "cargo build")
    } else {
        true
    }
}

fn try_test_in_dir(dir: &str) -> bool {
    if std::path::Path::new(&format!("{}/pubspec.yaml", dir)).exists() {
        run_streaming("flutter", &["test"], dir, "flutter test")
    } else if std::path::Path::new(&format!("{}/Cargo.toml", dir)).exists() {
        run_streaming("cargo", &["test"], dir, "cargo test")
    } else {
        true
    }
}

/// Run a command, streaming its stdout/stderr to the terminal.
fn run_streaming(program: &str, args: &[&str], dir: &str, label: &str) -> bool {
    println!("  {} {}", "  →".dimmed(), label.dimmed());
    let result = Command::new(program)
        .args(args)
        .current_dir(dir)
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status();

    match result {
        Ok(status) => status.success(),
        Err(e) => {
            eprintln!("  {} Failed to run {}: {}", "✗".red(), program, e);
            false
        }
    }
}

// ---------------------------------------------------------------------------
// Token polling for GitHub OAuth device flow
// ---------------------------------------------------------------------------

async fn poll_for_token(server: &str, device_id: &str) -> Result<String> {
    let client = reqwest::Client::new();
    let url = format!("{}/auth/status?device_id={}", server, device_id);
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(300);

    while std::time::Instant::now() < deadline {
        tokio::time::sleep(std::time::Duration::from_secs(3)).await;
        if let Ok(resp) = client.get(&url).send().await {
            if resp.status().is_success() {
                if let Ok(body) = resp.json::<serde_json::Value>().await {
                    if let Some(token) = body["token"].as_str() {
                        if !token.is_empty() {
                            return Ok(token.to_string());
                        }
                    }
                }
            }
        }
    }
    anyhow::bail!("GitHub authentication timed out. Please try again.")
}
