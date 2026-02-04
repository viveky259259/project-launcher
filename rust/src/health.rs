//! Health score calculation for projects

use crate::git;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use walkdir::WalkDir;

/// Staleness level based on days since last activity
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum StalenessLevel {
    Fresh,     // < 30 days
    Warning,   // 30-90 days
    Stale,     // 90-180 days
    Abandoned, // 180+ days
}

impl StalenessLevel {
    pub fn from_days(days: i64) -> Self {
        if days < 30 {
            StalenessLevel::Fresh
        } else if days < 90 {
            StalenessLevel::Warning
        } else if days < 180 {
            StalenessLevel::Stale
        } else {
            StalenessLevel::Abandoned
        }
    }
}

/// Health category based on total score
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum HealthCategory {
    Healthy,        // 80-100
    NeedsAttention, // 50-79
    Critical,       // 0-49
}

impl HealthCategory {
    pub fn from_score(score: i32) -> Self {
        if score >= 80 {
            HealthCategory::Healthy
        } else if score >= 50 {
            HealthCategory::NeedsAttention
        } else {
            HealthCategory::Critical
        }
    }
}

/// Complete health score result
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HealthScoreResult {
    pub project_path: String,
    pub total_score: i32,
    pub git_score: i32,
    pub deps_score: i32,
    pub tests_score: i32,
    pub staleness: StalenessLevel,
    pub category: HealthCategory,
    // Git details
    pub has_recent_commits: bool,
    pub no_uncommitted_changes: bool,
    pub no_unpushed_commits: bool,
    pub last_commit_timestamp: Option<i64>,
    pub days_since_last_commit: Option<i64>,
    // Deps details
    pub has_dependency_file: bool,
    pub has_lock_file: bool,
    pub dependency_file_type: Option<String>,
    // Tests details
    pub has_test_folder: bool,
    pub has_test_files: bool,
}

/// Dependency file configuration
struct DepCheck {
    dep_file: &'static str,
    lock_file: Option<&'static str>,
    file_type: &'static str,
}

const DEP_CHECKS: &[DepCheck] = &[
    DepCheck {
        dep_file: "pubspec.yaml",
        lock_file: Some("pubspec.lock"),
        file_type: "Flutter/Dart",
    },
    DepCheck {
        dep_file: "package.json",
        lock_file: Some("package-lock.json"),
        file_type: "Node.js",
    },
    DepCheck {
        dep_file: "package.json",
        lock_file: Some("yarn.lock"),
        file_type: "Node.js (Yarn)",
    },
    DepCheck {
        dep_file: "requirements.txt",
        lock_file: None,
        file_type: "Python",
    },
    DepCheck {
        dep_file: "Pipfile",
        lock_file: Some("Pipfile.lock"),
        file_type: "Python (Pipenv)",
    },
    DepCheck {
        dep_file: "pyproject.toml",
        lock_file: Some("poetry.lock"),
        file_type: "Python (Poetry)",
    },
    DepCheck {
        dep_file: "Cargo.toml",
        lock_file: Some("Cargo.lock"),
        file_type: "Rust",
    },
    DepCheck {
        dep_file: "go.mod",
        lock_file: Some("go.sum"),
        file_type: "Go",
    },
    DepCheck {
        dep_file: "Gemfile",
        lock_file: Some("Gemfile.lock"),
        file_type: "Ruby",
    },
    DepCheck {
        dep_file: "composer.json",
        lock_file: Some("composer.lock"),
        file_type: "PHP",
    },
    DepCheck {
        dep_file: "pom.xml",
        lock_file: None,
        file_type: "Maven",
    },
];

const TEST_FOLDERS: &[&str] = &["test", "tests", "spec", "specs", "__tests__", "test_suite"];

/// Calculate health score for a project
pub fn calculate_health_score(project_path: &str) -> HealthScoreResult {
    let path = Path::new(project_path);
    let mut result = HealthScoreResult {
        project_path: project_path.to_string(),
        total_score: 0,
        git_score: 0,
        deps_score: 0,
        tests_score: 0,
        staleness: StalenessLevel::Abandoned,
        category: HealthCategory::Critical,
        has_recent_commits: false,
        no_uncommitted_changes: false,
        no_unpushed_commits: false,
        last_commit_timestamp: None,
        days_since_last_commit: None,
        has_dependency_file: false,
        has_lock_file: false,
        dependency_file_type: None,
        has_test_folder: false,
        has_test_files: false,
    };

    // Git scoring (40 points max)
    if git::is_git_repository(project_path) {
        // Last commit date (15 points)
        if let Ok(timestamp) = git::get_last_commit_timestamp(project_path) {
            result.last_commit_timestamp = Some(timestamp);
            let days_since = (Utc::now().timestamp() - timestamp) / 86400;
            result.days_since_last_commit = Some(days_since);
            result.staleness = StalenessLevel::from_days(days_since);

            if days_since < 30 {
                result.has_recent_commits = true;
                result.git_score += 15;
            } else if days_since < 90 {
                result.git_score += 10;
            } else if days_since < 180 {
                result.git_score += 5;
            }
        }

        // No uncommitted changes (15 points)
        if let Ok(has_changes) = git::has_uncommitted_changes(project_path) {
            if !has_changes {
                result.no_uncommitted_changes = true;
                result.git_score += 15;
            }
        }

        // No unpushed commits (10 points)
        if let Ok(unpushed) = git::get_unpushed_commit_count(project_path) {
            if unpushed == 0 {
                result.no_unpushed_commits = true;
                result.git_score += 10;
            }
        }
    }

    // Dependencies scoring (30 points max)
    for check in DEP_CHECKS {
        let dep_path = path.join(check.dep_file);
        if dep_path.exists() {
            result.has_dependency_file = true;
            result.dependency_file_type = Some(check.file_type.to_string());
            result.deps_score += 20;

            if let Some(lock_file) = check.lock_file {
                let lock_path = path.join(lock_file);
                if lock_path.exists() {
                    result.has_lock_file = true;
                    result.deps_score += 10;
                }
            } else {
                // No lock file expected, full points
                result.has_lock_file = true;
                result.deps_score += 10;
            }
            break;
        }
    }

    // Tests scoring (30 points max)
    for folder in TEST_FOLDERS {
        let test_path = path.join(folder);
        if test_path.exists() && test_path.is_dir() {
            result.has_test_folder = true;
            result.tests_score += 15;

            // Check for actual test files
            if has_test_files(&test_path) {
                result.has_test_files = true;
                result.tests_score += 15;
            }
            break;
        }
    }

    // Also check for test files in src/lib directories
    if !result.has_test_files {
        for src_dir in &["lib", "src", "app"] {
            let src_path = path.join(src_dir);
            if src_path.exists() && has_test_files_recursive(&src_path) {
                result.has_test_files = true;
                result.tests_score += 15;
                break;
            }
        }
    }

    // Calculate total
    result.total_score = result.git_score + result.deps_score + result.tests_score;
    result.category = HealthCategory::from_score(result.total_score);

    result
}

/// Check if a directory contains test files
fn has_test_files(dir: &Path) -> bool {
    WalkDir::new(dir)
        .max_depth(5)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
        .any(|e| {
            let name = e.file_name().to_string_lossy().to_lowercase();
            name.contains("test") || name.contains("spec")
        })
}

/// Check if a directory contains test files (for src directories)
fn has_test_files_recursive(dir: &Path) -> bool {
    WalkDir::new(dir)
        .max_depth(10)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
        .any(|e| {
            let name = e.file_name().to_string_lossy().to_lowercase();
            name.contains("_test.") || name.contains(".test.") || name.contains("_spec.")
        })
}

/// Scan a directory for git repositories
pub fn scan_for_git_repos(root_path: &str, max_depth: usize) -> Vec<String> {
    let mut repos = Vec::new();
    let root = Path::new(root_path);

    if !root.exists() {
        return repos;
    }

    scan_recursive(root, &mut repos, 0, max_depth);
    repos.sort();
    repos
}

fn scan_recursive(dir: &Path, repos: &mut Vec<String>, current_depth: usize, max_depth: usize) {
    if current_depth > max_depth {
        return;
    }

    // Check if this is a git repo
    let git_dir = dir.join(".git");
    if git_dir.exists() {
        if let Some(path_str) = dir.to_str() {
            repos.push(path_str.to_string());
        }
        return; // Don't scan inside git repos
    }

    // Scan subdirectories
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.filter_map(|e| e.ok()) {
            let path = entry.path();
            if path.is_dir() {
                let name = path.file_name().unwrap_or_default().to_string_lossy();

                // Skip hidden and common non-project directories
                if name.starts_with('.')
                    || name == "node_modules"
                    || name == "build"
                    || name == "dist"
                    || name == ".dart_tool"
                    || name == "Pods"
                    || name == "vendor"
                    || name == "__pycache__"
                    || name == "target"
                {
                    continue;
                }

                scan_recursive(&path, repos, current_depth + 1, max_depth);
            }
        }
    }
}
