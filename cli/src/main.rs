mod serve;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;

// ---------------------------------------------------------------------------
// CLI argument parsing (clap)
// ---------------------------------------------------------------------------

#[derive(Parser)]
#[command(name = "plauncher", version, about = "CLI companion for Project Launcher")]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Output as JSON
    #[arg(long, global = true)]
    json: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// List all projects with health & git info
    #[command(alias = "ls")]
    List {
        /// Filter by tag
        #[arg(long)]
        tag: Option<String>,
        /// Filter by health: healthy, attention, critical
        #[arg(long)]
        filter: Option<String>,
    },
    /// Summary health report across all projects
    #[command(alias = "h")]
    Health,
    /// Git status (uncommitted, unpushed) for all projects
    #[command(alias = "st")]
    Status,
    /// Open a project in VS Code, Terminal, or Finder
    #[command(alias = "o")]
    Open {
        /// Project name (fuzzy match)
        name: String,
        /// Target: code, terminal, finder
        #[arg(long, short, default_value = "code")]
        r#in: String,
    },
    /// Add a project (defaults to current directory)
    Add {
        /// Path to the project (defaults to ".")
        #[arg(default_value = ".")]
        path: String,
    },
    /// Print project path (use with: cd $(plauncher cd my-project))
    Cd {
        /// Project name (fuzzy match)
        name: String,
    },
    /// Search projects by name, tag, or path
    Search {
        /// Search query
        query: String,
    },
    /// List all tags across projects
    Tags,
    /// Pin or unpin a project
    Pin {
        /// Project name (fuzzy match)
        name: String,
    },
    /// Unpin a project
    Unpin {
        /// Project name (fuzzy match)
        name: String,
    },
    /// Generate README badge markdown for a project
    #[command(alias = "b")]
    Badge {
        /// Project name (fuzzy match)
        name: String,
        /// Badge style: flat, flat-square, for-the-badge
        #[arg(long, default_value = "flat")]
        style: String,
    },
    /// Start the Enterprise Catalog backend server (self-hosted mode)
    Serve {
        /// Port to listen on (default: 8743)
        #[arg(long, default_value = "8743")]
        port: u16,
        /// Path to .env file for backend config (default: .env in current dir)
        #[arg(long)]
        env_file: Option<String>,
        /// Use Docker Compose instead of the native binary (recommended for production)
        #[arg(long)]
        docker: bool,
        /// Detach — run the server in the background (Docker mode only)
        #[arg(long, short)]
        detach: bool,
    },
}

// ---------------------------------------------------------------------------
// Data models (matching Flutter's JSON format)
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct Project {
    name: String,
    path: String,
    added_at: String,
    #[serde(default)]
    last_opened_at: Option<String>,
    #[serde(default)]
    tags: Vec<String>,
    #[serde(default)]
    is_pinned: bool,
    #[serde(default)]
    notes: Option<String>,
}

// ---------------------------------------------------------------------------
// File IO
// ---------------------------------------------------------------------------

fn data_dir() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home).join(".project_launcher")
}

fn load_projects() -> Result<Vec<Project>> {
    let path = data_dir().join("projects.json");
    if !path.exists() {
        return Ok(vec![]);
    }
    let data = std::fs::read_to_string(&path).context("Failed to read projects.json")?;
    let projects: Vec<Project> =
        serde_json::from_str(&data).context("Failed to parse projects.json")?;
    Ok(projects)
}

fn save_projects(projects: &[Project]) -> Result<()> {
    let path = data_dir().join("projects.json");
    std::fs::create_dir_all(data_dir())?;
    let data = serde_json::to_string_pretty(projects)?;
    std::fs::write(&path, data).context("Failed to write projects.json")?;
    Ok(())
}

fn load_health_scores() -> HashMap<String, serde_json::Value> {
    let path = data_dir().join("health_cache.json");
    if !path.exists() {
        return HashMap::new();
    }
    let data = match std::fs::read_to_string(&path) {
        Ok(d) => d,
        Err(_) => return HashMap::new(),
    };
    serde_json::from_str(&data).unwrap_or_default()
}

fn get_health_score(scores: &HashMap<String, serde_json::Value>, path: &str) -> Option<i32> {
    scores
        .get(path)
        .and_then(|v| v.get("details"))
        .and_then(|d| d.get("totalScore"))
        .and_then(|s| s.as_i64())
        .map(|s| s as i32)
}

// ---------------------------------------------------------------------------
// Git helpers
// ---------------------------------------------------------------------------

fn git_branch(path: &str) -> Option<String> {
    Command::new("git")
        .args(["rev-parse", "--abbrev-ref", "HEAD"])
        .current_dir(path)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
}

fn git_has_uncommitted(path: &str) -> bool {
    Command::new("git")
        .args(["status", "--porcelain"])
        .current_dir(path)
        .output()
        .ok()
        .map(|o| !String::from_utf8_lossy(&o.stdout).trim().is_empty())
        .unwrap_or(false)
}

fn git_unpushed_count(path: &str) -> i32 {
    let tracking = Command::new("git")
        .args([
            "rev-parse",
            "--abbrev-ref",
            "--symbolic-full-name",
            "@{upstream}",
        ])
        .current_dir(path)
        .output()
        .ok();

    if tracking
        .as_ref()
        .map(|o| !o.status.success())
        .unwrap_or(true)
    {
        return 0;
    }

    Command::new("git")
        .args(["rev-list", "--count", "@{upstream}..HEAD"])
        .current_dir(path)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .and_then(|o| {
            String::from_utf8_lossy(&o.stdout)
                .trim()
                .parse::<i32>()
                .ok()
        })
        .unwrap_or(0)
}

fn is_git_repo(path: &str) -> bool {
    PathBuf::from(path).join(".git").exists()
}

fn last_commit_time(path: &str) -> Option<String> {
    Command::new("git")
        .args(["log", "-1", "--format=%cr"])
        .current_dir(path)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
}

// ---------------------------------------------------------------------------
// Fuzzy match helper
// ---------------------------------------------------------------------------

fn fuzzy_match<'a>(projects: &'a [Project], query: &str) -> Vec<&'a Project> {
    let query_lower = query.to_lowercase();
    projects
        .iter()
        .filter(|p| p.name.to_lowercase().contains(&query_lower))
        .collect()
}

fn resolve_one<'a>(projects: &'a [Project], query: &str) -> Result<&'a Project> {
    let matches = fuzzy_match(projects, query);
    if matches.is_empty() {
        eprintln!(
            "{} No project matching \"{}\"",
            "Error:".red().bold(),
            query
        );
        eprintln!("  Run {} to see all projects", "plauncher list".cyan());
        std::process::exit(1);
    }
    if matches.len() > 1 {
        // Try exact match first
        if let Some(exact) = matches.iter().find(|p| p.name.to_lowercase() == query.to_lowercase()) {
            return Ok(exact);
        }
        eprintln!(
            "{} Multiple matches for \"{}\":",
            "Ambiguous:".yellow().bold(),
            query
        );
        for m in &matches {
            eprintln!("  - {}", m.name);
        }
        std::process::exit(1);
    }
    Ok(matches[0])
}

// ---------------------------------------------------------------------------
// Project info (collected in parallel)
// ---------------------------------------------------------------------------

struct ProjectInfo {
    branch: String,
    last_commit: String,
    uncommitted: bool,
    unpushed: i32,
    has_git: bool,
}

fn collect_git_info(projects: &[Project]) -> Vec<ProjectInfo> {
    projects
        .par_iter()
        .map(|p| {
            let has_git = is_git_repo(&p.path);
            if !has_git {
                return ProjectInfo {
                    branch: String::new(),
                    last_commit: String::new(),
                    uncommitted: false,
                    unpushed: 0,
                    has_git: false,
                };
            }
            ProjectInfo {
                branch: git_branch(&p.path).unwrap_or_default(),
                last_commit: last_commit_time(&p.path).unwrap_or_default(),
                uncommitted: git_has_uncommitted(&p.path),
                unpushed: git_unpushed_count(&p.path),
                has_git: true,
            }
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

fn filter_projects<'a>(
    projects: &'a [Project],
    scores: &HashMap<String, serde_json::Value>,
    tag: &Option<String>,
    filter: &Option<String>,
) -> Vec<&'a Project> {
    projects
        .iter()
        .filter(|p| {
            if let Some(t) = tag {
                if !p.tags.iter().any(|pt| pt.to_lowercase() == t.to_lowercase()) {
                    return false;
                }
            }
            if let Some(f) = filter {
                let score = get_health_score(scores, &p.path);
                match f.as_str() {
                    "healthy" => return score.map(|s| s >= 80).unwrap_or(false),
                    "attention" => return score.map(|s| s >= 50 && s < 80).unwrap_or(false),
                    "critical" => return score.map(|s| s < 50).unwrap_or(false),
                    _ => {}
                }
            }
            true
        })
        .collect()
}

fn format_health_score(score: Option<i32>) -> String {
    match score {
        Some(s) => {
            let text = format!("{}/100", s);
            if s >= 80 {
                text.green().to_string()
            } else if s >= 50 {
                text.yellow().to_string()
            } else {
                text.red().to_string()
            }
        }
        None => "--".dimmed().to_string(),
    }
}

fn format_git_indicators(info: &ProjectInfo) -> String {
    let mut indicators = String::new();
    if info.has_git {
        if info.uncommitted {
            indicators.push_str(&" M".yellow().to_string());
        }
        if info.unpushed > 0 {
            indicators.push_str(&format!(
                " {}{}",
                "↑".yellow(),
                info.unpushed.to_string().yellow()
            ));
        }
    }
    indicators
}

fn print_project_row(project: &Project, health_str: &str, info: &ProjectInfo) {
    let branch = if info.has_git {
        if info.branch.is_empty() { "-".to_string() } else { info.branch.clone() }
    } else {
        "no git".dimmed().to_string()
    };

    let last = if info.has_git && !info.last_commit.is_empty() {
        info.last_commit.clone()
    } else {
        "-".to_string()
    };

    let pin = if project.is_pinned { "*" } else { " " };
    let name = if project.is_pinned {
        project.name.bold().to_string()
    } else {
        project.name.clone()
    };

    let indicators = format_git_indicators(info);

    println!(
        " {}{:<30} {:<18} {:<15} {}{}",
        pin, name, health_str, branch,
        last.dimmed(),
        indicators
    );
}

fn cmd_list(
    projects: &[Project],
    scores: &HashMap<String, serde_json::Value>,
    tag: &Option<String>,
    filter: &Option<String>,
    json_output: bool,
) {
    let filtered = filter_projects(projects, scores, tag, filter);

    if json_output {
        let output: Vec<serde_json::Value> = filtered
            .iter()
            .map(|p| {
                serde_json::json!({
                    "name": p.name,
                    "path": p.path,
                    "pinned": p.is_pinned,
                    "tags": p.tags,
                    "health": get_health_score(scores, &p.path),
                })
            })
            .collect();
        println!("{}", serde_json::to_string_pretty(&output).unwrap());
        return;
    }

    if filtered.is_empty() {
        println!(
            "{}",
            "No projects found. Add projects using the Project Launcher app or `plauncher add .`"
                .dimmed()
        );
        return;
    }

    let owned: Vec<Project> = filtered.iter().map(|p| (*p).clone()).collect();
    let git_info = collect_git_info(&owned);

    println!(
        "  {:<30} {:<8} {:<15} {}",
        "PROJECT".dimmed(),
        "HEALTH".dimmed(),
        "BRANCH".dimmed(),
        "LAST COMMIT".dimmed(),
    );
    println!("  {}", "-".repeat(75).dimmed());

    for (i, project) in filtered.iter().enumerate() {
        let health_str = format_health_score(get_health_score(scores, &project.path));
        print_project_row(project, &health_str, &git_info[i]);
    }

    println!();
    println!("  {} projects", filtered.len().to_string().bold());
}

struct HealthCounts {
    healthy: usize,
    attention: usize,
    critical: usize,
    unknown: usize,
}

fn tally_health(projects: &[Project], scores: &HashMap<String, serde_json::Value>) -> HealthCounts {
    let mut counts = HealthCounts { healthy: 0, attention: 0, critical: 0, unknown: 0 };
    for project in projects {
        match get_health_score(scores, &project.path) {
            Some(s) if s >= 80 => counts.healthy += 1,
            Some(s) if s >= 50 => counts.attention += 1,
            Some(_) => counts.critical += 1,
            None => counts.unknown += 1,
        }
    }
    counts
}

fn print_health_summary(counts: &HealthCounts, total: usize) {
    println!();
    println!("  {} Project Health Summary", "".bold());
    println!("  {}", "-".repeat(35).dimmed());
    println!("  {} {} healthy", "●".green(), counts.healthy.to_string().bold());
    println!("  {} {} needs attention", "●".yellow(), counts.attention.to_string().bold());
    println!("  {} {} critical", "●".red(), counts.critical.to_string().bold());
    if counts.unknown > 0 {
        println!("  {} {} not scored", "○".dimmed(), counts.unknown.to_string().dimmed());
    }
    println!("  {}", "-".repeat(35).dimmed());
    println!("  {} total", total.to_string().bold());
    println!();
}

fn find_unpushed_projects(projects: &[Project]) -> Vec<(&String, i32)> {
    projects
        .par_iter()
        .filter_map(|p| {
            if is_git_repo(&p.path) {
                let count = git_unpushed_count(&p.path);
                if count > 0 {
                    return Some((&p.name, count));
                }
            }
            None
        })
        .collect()
}

fn cmd_health(projects: &[Project], scores: &HashMap<String, serde_json::Value>, json_output: bool) {
    let counts = tally_health(projects, scores);

    if json_output {
        println!(
            "{}",
            serde_json::to_string_pretty(&serde_json::json!({
                "healthy": counts.healthy,
                "needsAttention": counts.attention,
                "critical": counts.critical,
                "unknown": counts.unknown,
                "total": projects.len(),
            }))
            .unwrap()
        );
        return;
    }

    print_health_summary(&counts, projects.len());

    if counts.critical > 0 {
        println!("  {} Critical projects:", "!".red().bold());
        for project in projects {
            if let Some(s) = get_health_score(scores, &project.path) {
                if s < 50 {
                    println!("    {} {} ({}/100)", "●".red(), project.name, s);
                }
            }
        }
        println!();
    }

    let unpushed_projects = find_unpushed_projects(projects);
    if !unpushed_projects.is_empty() {
        println!("  {} Unpushed commits:", "↑".yellow().bold());
        for (name, count) in &unpushed_projects {
            println!("    {} {} ({} commits)", "●".yellow(), name, count);
        }
        println!();
    }
}

fn cmd_status(projects: &[Project], json_output: bool) {
    let git_info = collect_git_info(projects);

    if json_output {
        let output: Vec<serde_json::Value> = projects
            .iter()
            .zip(git_info.iter())
            .filter(|(_, info)| info.has_git)
            .map(|(p, info)| {
                serde_json::json!({
                    "name": p.name,
                    "branch": info.branch,
                    "uncommitted": info.uncommitted,
                    "unpushed": info.unpushed,
                })
            })
            .collect();
        println!("{}", serde_json::to_string_pretty(&output).unwrap());
        return;
    }

    println!();
    println!("  {} Git Status Across Projects", "".bold());
    println!("  {}", "-".repeat(50).dimmed());

    let mut clean = 0;
    let mut dirty = 0;
    let mut unpushed_total = 0;
    let mut no_git = 0;

    for (project, info) in projects.iter().zip(git_info.iter()) {
        if !info.has_git {
            no_git += 1;
            continue;
        }

        if !info.uncommitted && info.unpushed == 0 {
            clean += 1;
        } else {
            dirty += 1;
            let mut flags = vec![];
            if info.uncommitted {
                flags.push("uncommitted".yellow().to_string());
            }
            if info.unpushed > 0 {
                flags.push(format!("{} unpushed", info.unpushed).yellow().to_string());
                unpushed_total += info.unpushed;
            }
            println!(
                "  {} {:<25} {}",
                "●".yellow(),
                project.name,
                flags.join(", ")
            );
        }
    }

    println!("  {}", "-".repeat(50).dimmed());
    println!(
        "  {} clean  {} dirty  {} unpushed commits  {} no git",
        clean.to_string().green().bold(),
        dirty.to_string().yellow().bold(),
        unpushed_total.to_string().yellow(),
        no_git.to_string().dimmed(),
    );
    println!();
}

fn cmd_open(projects: &[Project], query: &str, target: &str) {
    let project = resolve_one(projects, query).unwrap();

    match target {
        "code" | "vscode" => {
            println!("Opening {} in VS Code...", project.name.bold());
            Command::new("code").arg(&project.path).spawn().ok();
        }
        "terminal" | "term" => {
            println!("Opening {} in Terminal...", project.name.bold());
            Command::new("open")
                .args(["-a", "Terminal", &project.path])
                .spawn()
                .ok();
        }
        "finder" => {
            println!("Opening {} in Finder...", project.name.bold());
            Command::new("open").arg(&project.path).spawn().ok();
        }
        _ => {
            println!("Opening {} in VS Code...", project.name.bold());
            Command::new("code").arg(&project.path).spawn().ok();
        }
    }
}

fn cmd_add(projects: &mut Vec<Project>, path_str: &str) -> Result<()> {
    let path = std::fs::canonicalize(path_str)
        .with_context(|| format!("Path not found: {}", path_str))?;
    let path_string = path.to_string_lossy().to_string();

    // Check for duplicates
    if projects.iter().any(|p| p.path == path_string) {
        println!(
            "{} {} is already tracked",
            "Already added:".yellow(),
            path_string
        );
        return Ok(());
    }

    // Derive name from directory
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| path_string.clone());

    let now = chrono::Utc::now().to_rfc3339();

    projects.push(Project {
        name: name.clone(),
        path: path_string.clone(),
        added_at: now,
        last_opened_at: None,
        tags: vec![],
        is_pinned: false,
        notes: None,
    });

    save_projects(projects)?;
    println!("  {} Added {}", "✓".green(), name.bold());
    println!("  {}", path_string.dimmed());
    Ok(())
}

fn cmd_cd(projects: &[Project], query: &str) {
    let project = resolve_one(projects, query).unwrap();
    // Print raw path — designed for: cd $(plauncher cd my-project)
    print!("{}", project.path);
}

fn cmd_search(projects: &[Project], query: &str, json_output: bool) {
    let query_lower = query.to_lowercase();
    let matches: Vec<&Project> = projects
        .iter()
        .filter(|p| {
            p.name.to_lowercase().contains(&query_lower)
                || p.path.to_lowercase().contains(&query_lower)
                || p.tags
                    .iter()
                    .any(|t| t.to_lowercase().contains(&query_lower))
        })
        .collect();

    if json_output {
        let output: Vec<serde_json::Value> = matches
            .iter()
            .map(|p| {
                serde_json::json!({
                    "name": p.name,
                    "path": p.path,
                    "tags": p.tags,
                    "pinned": p.is_pinned,
                })
            })
            .collect();
        println!("{}", serde_json::to_string_pretty(&output).unwrap());
        return;
    }

    if matches.is_empty() {
        println!("  No results for \"{}\"", query);
        return;
    }

    println!();
    for p in &matches {
        let pin = if p.is_pinned {
            " *".yellow().to_string()
        } else {
            String::new()
        };
        println!("  {}{}", p.name.bold(), pin);
        println!("    {}", p.path.dimmed());
        if !p.tags.is_empty() {
            println!("    tags: {}", p.tags.join(", ").cyan());
        }
    }
    println!();
    println!("  {} results", matches.len().to_string().bold());
}

fn cmd_tags(projects: &[Project], json_output: bool) {
    let mut tag_counts: HashMap<String, usize> = HashMap::new();
    for p in projects {
        for tag in &p.tags {
            *tag_counts.entry(tag.clone()).or_insert(0) += 1;
        }
    }

    if json_output {
        println!("{}", serde_json::to_string_pretty(&tag_counts).unwrap());
        return;
    }

    if tag_counts.is_empty() {
        println!("  {}", "No tags found.".dimmed());
        return;
    }

    let mut sorted: Vec<(String, usize)> = tag_counts.into_iter().collect();
    sorted.sort_by(|a, b| b.1.cmp(&a.1));

    println!();
    for (tag, count) in &sorted {
        println!("  {} {} ({})", "●".cyan(), tag.bold(), count);
    }
    println!();
}

fn cmd_pin(projects: &mut Vec<Project>, query: &str, pin: bool) -> Result<()> {
    let query_lower = query.to_lowercase();
    let idx = projects
        .iter()
        .position(|p| p.name.to_lowercase().contains(&query_lower));

    match idx {
        Some(i) => {
            projects[i].is_pinned = pin;
            save_projects(projects)?;
            let action = if pin { "Pinned" } else { "Unpinned" };
            println!("  {} {} {}", "✓".green(), action, projects[i].name.bold());
        }
        None => {
            eprintln!("{} No project matching \"{}\"", "Error:".red().bold(), query);
            std::process::exit(1);
        }
    }
    Ok(())
}

fn cmd_badge(
    projects: &[Project],
    scores: &HashMap<String, serde_json::Value>,
    query: &str,
    style: &str,
) {
    let project = resolve_one(projects, query).unwrap();
    let score = get_health_score(scores, &project.path).unwrap_or(0);

    let (color, label) = if score >= 80 {
        ("brightgreen", "healthy")
    } else if score >= 50 {
        ("yellow", "needs%20attention")
    } else {
        ("red", "critical")
    };

    println!();
    println!(
        "  {} Badge markdown for {}",
        "".bold(),
        project.name.bold()
    );
    println!("  {}", "-".repeat(50).dimmed());
    println!();

    let shields_health = format!(
        "![Health](https://img.shields.io/badge/health-{}/100-{}?style={})",
        score, color, style
    );
    let shields_category = format!(
        "![Status](https://img.shields.io/badge/status-{}-{}?style={})",
        label, color, style
    );

    println!("  {}", "Health score badge:".dimmed());
    println!("  {}", shields_health);
    println!();
    println!("  {}", "Status badge:".dimmed());
    println!("  {}", shields_category);
    println!();
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

fn main() -> Result<()> {
    let cli = Cli::parse();

    let command = match cli.command {
        Some(cmd) => cmd,
        None => {
            // No subcommand — show help via clap
            Cli::parse_from(["plauncher", "--help"]);
            return Ok(());
        }
    };

    match command {
        Commands::List { tag, filter } => {
            let projects = load_projects()?;
            let scores = load_health_scores();
            cmd_list(&projects, &scores, &tag, &filter, cli.json);
        }
        Commands::Health => {
            let projects = load_projects()?;
            let scores = load_health_scores();
            cmd_health(&projects, &scores, cli.json);
        }
        Commands::Status => {
            let projects = load_projects()?;
            cmd_status(&projects, cli.json);
        }
        Commands::Open { name, r#in } => {
            let projects = load_projects()?;
            cmd_open(&projects, &name, &r#in);
        }
        Commands::Add { path } => {
            let mut projects = load_projects()?;
            cmd_add(&mut projects, &path)?;
        }
        Commands::Cd { name } => {
            let projects = load_projects()?;
            cmd_cd(&projects, &name);
        }
        Commands::Search { query } => {
            let projects = load_projects()?;
            cmd_search(&projects, &query, cli.json);
        }
        Commands::Tags => {
            let projects = load_projects()?;
            cmd_tags(&projects, cli.json);
        }
        Commands::Pin { name } => {
            let mut projects = load_projects()?;
            cmd_pin(&mut projects, &name, true)?;
        }
        Commands::Unpin { name } => {
            let mut projects = load_projects()?;
            cmd_pin(&mut projects, &name, false)?;
        }
        Commands::Badge { name, style } => {
            let projects = load_projects()?;
            let scores = load_health_scores();
            cmd_badge(&projects, &scores, &name, &style);
        }
        Commands::Serve { port, env_file, docker, detach } => {
            serve::cmd_serve(port, env_file.as_deref(), docker, detach)?;
        }
    }

    Ok(())
}