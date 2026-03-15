use anyhow::{Context, Result};
use colored::*;
use serde::Deserialize;
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;

// ---------------------------------------------------------------------------
// Data models (matching Flutter's JSON format)
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
struct Project {
    name: String,
    path: String,
    #[serde(default)]
    tags: Vec<String>,
    #[serde(default)]
    is_pinned: bool,
    added_at: Option<String>,
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
    let projects: Vec<Project> = serde_json::from_str(&data).context("Failed to parse projects.json")?;
    Ok(projects)
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
    scores.get(path)
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
    // Check if there's a tracking branch
    let tracking = Command::new("git")
        .args(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"])
        .current_dir(path)
        .output()
        .ok();

    if tracking.as_ref().map(|o| !o.status.success()).unwrap_or(true) {
        return 0;
    }

    Command::new("git")
        .args(["rev-list", "--count", "@{upstream}..HEAD"])
        .current_dir(path)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .and_then(|o| String::from_utf8_lossy(&o.stdout).trim().parse::<i32>().ok())
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
// Commands
// ---------------------------------------------------------------------------

fn cmd_list(projects: &[Project], scores: &HashMap<String, serde_json::Value>) {
    if projects.is_empty() {
        println!("{}", "No projects found. Add projects using the Project Launcher app.".dimmed());
        return;
    }

    // Header
    println!(
        "  {:<30} {:<8} {:<15} {}",
        "PROJECT".dimmed(),
        "HEALTH".dimmed(),
        "BRANCH".dimmed(),
        "LAST COMMIT".dimmed(),
    );
    println!("  {}", "-".repeat(75).dimmed());

    for project in projects {
        let health = get_health_score(scores, &project.path);
        let health_str = match health {
            Some(s) => {
                let text = format!("{}/100", s);
                if s >= 80 { text.green().to_string() }
                else if s >= 50 { text.yellow().to_string() }
                else { text.red().to_string() }
            }
            None => "--".dimmed().to_string(),
        };

        let branch = if is_git_repo(&project.path) {
            git_branch(&project.path).unwrap_or_else(|| "-".to_string())
        } else {
            "no git".dimmed().to_string()
        };

        let last = if is_git_repo(&project.path) {
            last_commit_time(&project.path).unwrap_or_else(|| "-".to_string())
        } else {
            "-".to_string()
        };

        let pin = if project.is_pinned { "*" } else { " " };
        let name = if project.is_pinned {
            project.name.bold().to_string()
        } else {
            project.name.clone()
        };

        // Indicators
        let mut indicators = String::new();
        if is_git_repo(&project.path) {
            if git_has_uncommitted(&project.path) {
                indicators.push_str(&" M".yellow().to_string());
            }
            let unpushed = git_unpushed_count(&project.path);
            if unpushed > 0 {
                indicators.push_str(&format!(" {}{}",  "↑".yellow(), unpushed.to_string().yellow()));
            }
        }

        println!(
            " {}{:<30} {:<18} {:<15} {}{}",
            pin, name, health_str, branch, last.dimmed(), indicators
        );
    }

    println!();
    println!(
        "  {} projects total",
        projects.len().to_string().bold()
    );
}

fn cmd_health(projects: &[Project], scores: &HashMap<String, serde_json::Value>) {
    let mut healthy = 0;
    let mut attention = 0;
    let mut critical = 0;
    let mut unknown = 0;

    for project in projects {
        match get_health_score(scores, &project.path) {
            Some(s) if s >= 80 => healthy += 1,
            Some(s) if s >= 50 => attention += 1,
            Some(_) => critical += 1,
            None => unknown += 1,
        }
    }

    println!();
    println!("  {} Project Health Summary", "".bold());
    println!("  {}", "-".repeat(35).dimmed());
    println!("  {} {} healthy", "●".green(), healthy.to_string().bold());
    println!("  {} {} needs attention", "●".yellow(), attention.to_string().bold());
    println!("  {} {} critical", "●".red(), critical.to_string().bold());
    if unknown > 0 {
        println!("  {} {} not scored", "○".dimmed(), unknown.to_string().dimmed());
    }
    println!("  {}", "-".repeat(35).dimmed());
    println!("  {} total", projects.len().to_string().bold());
    println!();

    // Show critical projects
    if critical > 0 {
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

    // Show unpushed
    let mut unpushed_projects = vec![];
    for project in projects {
        if is_git_repo(&project.path) {
            let count = git_unpushed_count(&project.path);
            if count > 0 {
                unpushed_projects.push((&project.name, count));
            }
        }
    }
    if !unpushed_projects.is_empty() {
        println!("  {} Unpushed commits:", "↑".yellow().bold());
        for (name, count) in &unpushed_projects {
            println!("    {} {} ({} commits)", "●".yellow(), name, count);
        }
        println!();
    }
}

fn cmd_open(projects: &[Project], query: &str, target: &str) {
    // Fuzzy match: find project whose name contains the query (case-insensitive)
    let query_lower = query.to_lowercase();
    let matches: Vec<&Project> = projects
        .iter()
        .filter(|p| p.name.to_lowercase().contains(&query_lower))
        .collect();

    if matches.is_empty() {
        eprintln!("{} No project matching \"{}\"", "Error:".red().bold(), query);
        eprintln!("  Run {} to see all projects", "plauncher list".cyan());
        std::process::exit(1);
    }

    if matches.len() > 1 {
        eprintln!("{} Multiple matches for \"{}\":", "Ambiguous:".yellow().bold(), query);
        for m in &matches {
            eprintln!("  - {}", m.name);
        }
        eprintln!("  Be more specific.");
        std::process::exit(1);
    }

    let project = matches[0];

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
            // Default: VS Code
            println!("Opening {} in VS Code...", project.name.bold());
            Command::new("code").arg(&project.path).spawn().ok();
        }
    }
}

fn cmd_status(projects: &[Project]) {
    println!();
    println!("  {} Git Status Across Projects", "".bold());
    println!("  {}", "-".repeat(50).dimmed());

    let mut clean = 0;
    let mut dirty = 0;
    let mut unpushed_total = 0;
    let mut no_git = 0;

    for project in projects {
        if !is_git_repo(&project.path) {
            no_git += 1;
            continue;
        }

        let uncommitted = git_has_uncommitted(&project.path);
        let unpushed = git_unpushed_count(&project.path);

        if !uncommitted && unpushed == 0 {
            clean += 1;
        } else {
            dirty += 1;
            let mut flags = vec![];
            if uncommitted {
                flags.push("uncommitted".yellow().to_string());
            }
            if unpushed > 0 {
                flags.push(format!("{} unpushed", unpushed).yellow().to_string());
                unpushed_total += unpushed;
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

fn cmd_badge(projects: &[Project], scores: &HashMap<String, serde_json::Value>, query: &str, style: &str) {
    let query_lower = query.to_lowercase();
    let matches: Vec<&Project> = projects
        .iter()
        .filter(|p| p.name.to_lowercase().contains(&query_lower))
        .collect();

    if matches.is_empty() {
        eprintln!("{} No project matching \"{}\"", "Error:".red().bold(), query);
        std::process::exit(1);
    }

    if matches.len() > 1 {
        eprintln!("{} Multiple matches for \"{}\":", "Ambiguous:".yellow().bold(), query);
        for m in &matches {
            eprintln!("  - {}", m.name);
        }
        std::process::exit(1);
    }

    let project = matches[0];
    let score = get_health_score(scores, &project.path).unwrap_or(0);

    let (color, label) = if score >= 80 {
        ("brightgreen", "healthy")
    } else if score >= 50 {
        ("yellow", "needs%20attention")
    } else {
        ("red", "critical")
    };

    println!();
    println!("  {} Badge markdown for {}", "".bold(), project.name.bold());
    println!("  {}", "-".repeat(50).dimmed());
    println!();

    // shields.io badge (works everywhere, no custom server needed)
    let shields_health = format!(
        "![Health](https://img.shields.io/badge/health-{}/100-{}?style={}&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyMWwtMS40NS0xLjMyQzUuNCAxNS4zNiAyIDEyLjI4IDIgOC41IDIgNS40MiA0LjQyIDMgNy41IDNjMS43NCAwIDMuNDEuODEgNC41IDIuMDlDMTMuMDkgMy44MSAxNC43NiAzIDE2LjUgMyAxOS41OCAzIDIyIDUuNDIgMjIgOC41YzAgMy43OC0zLjQgNi44Ni04LjU1IDExLjE4TDEyIDIxeiIvPjwvc3ZnPg==)",
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

    // If badge service is deployed
    println!("  {}", "Self-hosted badge (after deploying badge-service):".dimmed());
    println!("  ![Health](https://badge.projectlauncher.dev/health?score={}&label={}&style={})",
        score, project.name.replace(' ', "+"), style);
    println!();
}

fn print_help() {
    println!();
    println!("  {} - CLI companion for Project Launcher", "plauncher".bold());
    println!();
    println!("  {}", "USAGE:".dimmed());
    println!("    plauncher <command> [args]");
    println!();
    println!("  {}", "COMMANDS:".dimmed());
    println!("    {}          List all projects with health & git info", "list".cyan());
    println!("    {}        Summary health report across all projects", "health".cyan());
    println!("    {}        Git status (uncommitted, unpushed) for all projects", "status".cyan());
    println!("    {} {}  Open project in VS Code (default)", "open".cyan(), "<name>".dimmed());
    println!("    {} {} {}  Open in specific target (code/terminal/finder)", "open".cyan(), "<name>".dimmed(), "--in <target>".dimmed());
    println!("    {} {}  Generate README badge markdown for a project", "badge".cyan(), "<name>".dimmed());
    println!();
    println!("  {}", "EXAMPLES:".dimmed());
    println!("    plauncher list");
    println!("    plauncher health");
    println!("    plauncher status");
    println!("    plauncher open my-project");
    println!("    plauncher open my-project --in terminal");
    println!("    plauncher badge my-project");
    println!("    plauncher badge my-project --style flat-square");
    println!();
    println!("  Full dashboard: {}", "open \"/Applications/Project Launcher.app\"".dimmed());
    println!();
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 2 {
        print_help();
        return Ok(());
    }

    let command = args[1].as_str();

    match command {
        "list" | "ls" => {
            let projects = load_projects()?;
            let scores = load_health_scores();
            cmd_list(&projects, &scores);
        }
        "health" | "h" => {
            let projects = load_projects()?;
            let scores = load_health_scores();
            cmd_health(&projects, &scores);
        }
        "status" | "st" => {
            let projects = load_projects()?;
            cmd_status(&projects);
        }
        "open" | "o" => {
            if args.len() < 3 {
                eprintln!("{} plauncher open <project-name> [--in code|terminal|finder]", "Usage:".yellow());
                std::process::exit(1);
            }
            let query = &args[2];
            let target = if args.len() >= 5 && args[3] == "--in" {
                args[4].as_str()
            } else {
                "code"
            };
            let projects = load_projects()?;
            cmd_open(&projects, query, target);
        }
        "badge" | "b" => {
            if args.len() < 3 {
                eprintln!("{} plauncher badge <project-name> [--style flat|flat-square|for-the-badge]", "Usage:".yellow());
                std::process::exit(1);
            }
            let query = &args[2];
            let style = if args.len() >= 5 && args[3] == "--style" {
                args[4].as_str()
            } else {
                "flat"
            };
            let projects = load_projects()?;
            let scores = load_health_scores();
            cmd_badge(&projects, &scores, query, style);
        }
        "help" | "--help" | "-h" => {
            print_help();
        }
        "version" | "--version" | "-V" => {
            println!("plauncher {}", env!("CARGO_PKG_VERSION"));
        }
        _ => {
            eprintln!("{} Unknown command: {}", "Error:".red().bold(), command);
            print_help();
            std::process::exit(1);
        }
    }

    Ok(())
}
