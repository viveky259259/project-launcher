// ---------------------------------------------------------------------------
// plauncher serve — start the Enterprise Catalog backend (self-hosted mode)
// ---------------------------------------------------------------------------

use anyhow::Result;
use colored::*;
use std::path::PathBuf;
use std::process::Command;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Load a .env-style file and return a list of (key, value) pairs.
/// Lines beginning with '#' and blank lines are ignored.
fn parse_env_file(path: &str) -> Result<Vec<(String, String)>> {
    let contents = std::fs::read_to_string(path)
        .map_err(|e| anyhow::anyhow!("Cannot read env file '{}': {}", path, e))?;
    let mut pairs = Vec::new();
    for line in contents.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((k, v)) = line.split_once('=') {
            pairs.push((k.trim().to_string(), v.trim().trim_matches('"').to_string()));
        }
    }
    Ok(pairs)
}

/// Determine whether `docker compose` (v2 plugin) or `docker-compose` (v1
/// standalone) is available on the current PATH.  Returns the program name
/// and whether the `compose` argument should be passed separately.
fn detect_docker_compose() -> Option<(&'static str, bool)> {
    // Try Docker Compose v2 plugin first
    let v2_ok = Command::new("docker")
        .args(["compose", "version"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    if v2_ok {
        return Some(("docker", true));
    }

    // Fall back to docker-compose v1
    let v1_ok = Command::new("docker-compose")
        .arg("version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    if v1_ok {
        return Some(("docker-compose", false));
    }

    None
}

/// Search for the backend binary in the standard locations and return its path
/// if one is found.
fn find_backend_binary() -> Option<PathBuf> {
    // 1. Explicit env override
    if let Ok(p) = std::env::var("PLAUNCHER_BACKEND") {
        let path = PathBuf::from(&p);
        if path.exists() {
            return Some(path);
        }
    }

    // 2. Adjacent to the currently running plauncher binary
    if let Ok(exe) = std::env::current_exe() {
        let sibling = exe.parent().map(|d| d.join("plauncher-backend"));
        if let Some(ref p) = sibling {
            if p.exists() {
                return sibling;
            }
        }
    }

    // 3. ~/.project_launcher/bin/plauncher-backend
    if let Ok(home) = std::env::var("HOME") {
        let well_known = PathBuf::from(home)
            .join(".project_launcher")
            .join("bin")
            .join("plauncher-backend");
        if well_known.exists() {
            return Some(well_known);
        }
    }

    None
}

// ---------------------------------------------------------------------------
// Public entry-point
// ---------------------------------------------------------------------------

pub fn cmd_serve(port: u16, env_file: Option<&str>, docker: bool, detach: bool) -> Result<()> {
    // Determine mode: docker explicitly requested, or docker-compose.yml found
    // in the current directory acts as an implicit signal.
    let compose_yml_present = PathBuf::from("docker-compose.yml").exists();
    let use_docker = docker || compose_yml_present;

    if use_docker {
        run_docker_mode(port, env_file, detach, compose_yml_present)
    } else {
        run_native_mode(port, env_file)
    }
}

// ---------------------------------------------------------------------------
// Docker Compose mode
// ---------------------------------------------------------------------------

fn run_docker_mode(
    port: u16,
    env_file: Option<&str>,
    detach: bool,
    compose_yml_found: bool,
) -> Result<()> {
    // Ensure docker-compose.yml is present
    if !compose_yml_found {
        print_compose_missing_hint();
        std::process::exit(1);
    }

    // Detect docker compose executable
    let compose_cmd = detect_docker_compose();
    if compose_cmd.is_none() {
        eprintln!(
            "\n  {} Docker is not installed or not running.",
            "Error:".red().bold()
        );
        eprintln!(
            "  Install Docker Desktop from {} or use the native binary mode (omit {}).",
            "https://docs.docker.com/get-docker/".cyan(),
            "--docker".bold()
        );
        std::process::exit(1);
    }
    let (program, compose_subcommand) = compose_cmd.unwrap();

    println!(
        "\n  {} Starting Enterprise Catalog backend",
        "".bold()
    );
    println!("  {}", "-".repeat(48).dimmed());
    println!("  Mode    : {}", "Docker Compose".cyan().bold());
    println!("  Port    : {}", port.to_string().cyan());
    println!(
        "  Detach  : {}",
        if detach { "yes".green() } else { "no".yellow() }
    );
    if let Some(f) = env_file {
        println!("  Env file: {}", f.cyan());
    }
    println!("  {}", "-".repeat(48).dimmed());
    println!();

    // Build the command
    let mut cmd = Command::new(program);

    if compose_subcommand {
        cmd.arg("compose");
    }

    // Pass --env-file if provided
    if let Some(f) = env_file {
        cmd.args(["--env-file", f]);
    }

    // Sub-command: up
    cmd.arg("up");

    if detach {
        cmd.arg("--detach");
    }

    // Forward PORT so docker-compose.yml can reference $PORT
    cmd.env("PORT", port.to_string());

    println!(
        "  {} Running: {} compose up{}",
        "▶".green().bold(),
        program,
        if detach { " --detach" } else { "" }
    );
    println!(
        "  {} Backend will be available at {}",
        "i".cyan().bold(),
        format!("http://localhost:{}", port).cyan()
    );
    println!();

    let status = cmd
        .status()
        .map_err(|e| anyhow::anyhow!("Failed to run docker compose: {}", e))?;

    if !status.success() {
        eprintln!(
            "\n  {} docker compose exited with status {}",
            "Error:".red().bold(),
            status
        );
        std::process::exit(status.code().unwrap_or(1));
    }

    Ok(())
}

fn print_compose_missing_hint() {
    eprintln!(
        "\n  {} No {} found in the current directory.",
        "Error:".red().bold(),
        "docker-compose.yml".bold()
    );
    eprintln!();
    eprintln!("  To get started, copy the bundled compose file:");
    eprintln!(
        "    {}",
        "curl -fsSL https://raw.githubusercontent.com/viveky259259/project-launcher/main/docker-compose.yml -o docker-compose.yml".dimmed()
    );
    eprintln!();
    eprintln!("  Or install the backend binary and run without {}:", "--docker".bold());
    eprintln!(
        "    {}",
        "plauncher serve --port 8743".dimmed()
    );
    eprintln!();
    eprintln!(
        "  See {} for full self-hosting documentation.",
        "https://github.com/viveky259259/project-launcher/blob/main/docs/self-hosting.md".cyan()
    );
}

// ---------------------------------------------------------------------------
// Native binary mode
// ---------------------------------------------------------------------------

fn run_native_mode(port: u16, env_file: Option<&str>) -> Result<()> {
    let binary = find_backend_binary();

    if binary.is_none() {
        print_backend_not_found_hint(port);
        std::process::exit(1);
    }

    let binary_path = binary.unwrap();

    // Load env file vars if provided
    let env_pairs: Vec<(String, String)> = if let Some(f) = env_file {
        parse_env_file(f)?
    } else {
        vec![]
    };

    println!(
        "\n  {} Starting Enterprise Catalog backend",
        "".bold()
    );
    println!("  {}", "-".repeat(48).dimmed());
    println!("  Mode    : {}", "Native binary".cyan().bold());
    println!("  Binary  : {}", binary_path.display().to_string().dimmed());
    println!("  Port    : {}", port.to_string().cyan());
    if let Some(f) = env_file {
        println!("  Env file: {}", f.cyan());
    }
    println!("  {}", "-".repeat(48).dimmed());
    println!();
    println!(
        "  {} Running: plauncher-backend",
        "▶".green().bold()
    );
    println!(
        "  {} Backend will be available at {}",
        "i".cyan().bold(),
        format!("http://localhost:{}", port).cyan()
    );
    println!();

    let mut cmd = Command::new(&binary_path);
    cmd.env("PORT", port.to_string());

    // Inject any env-file variables
    for (k, v) in &env_pairs {
        cmd.env(k, v);
    }

    let status = cmd
        .status()
        .map_err(|e| anyhow::anyhow!("Failed to run plauncher-backend at {}: {}", binary_path.display(), e))?;

    if !status.success() {
        eprintln!(
            "\n  {} plauncher-backend exited with status {}",
            "Error:".red().bold(),
            status
        );
        std::process::exit(status.code().unwrap_or(1));
    }

    Ok(())
}

fn print_backend_not_found_hint(port: u16) {
    eprintln!(
        "\n  {} Backend binary {} not found.",
        "Error:".red().bold(),
        "plauncher-backend".bold()
    );
    eprintln!();
    eprintln!("  The CLI looked in these locations (in order):");
    eprintln!(
        "    1. {} environment variable",
        "$PLAUNCHER_BACKEND".yellow()
    );
    eprintln!("    2. Same directory as the {} binary", "plauncher".bold());
    eprintln!(
        "    3. {}",
        "~/.project_launcher/bin/plauncher-backend".dimmed()
    );
    eprintln!();
    eprintln!("  Options:");
    eprintln!(
        "    a) Install the backend binary via the Project Launcher installer and re-run:"
    );
    eprintln!("         {}", format!("plauncher serve --port {}", port).dimmed());
    eprintln!();
    eprintln!("    b) Use Docker Compose mode (recommended for production):");
    eprintln!("         {}", format!("plauncher serve --docker --port {}", port).dimmed());
    eprintln!();
    eprintln!(
        "  See {} for full self-hosting documentation.",
        "https://github.com/viveky259259/project-launcher/blob/main/docs/self-hosting.md".cyan()
    );
}
