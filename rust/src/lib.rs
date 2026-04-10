mod git;
mod health;
mod stats;
mod standalone_runner;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

// Re-export for internal use
pub use git::*;
pub use health::*;
pub use stats::*;
pub use standalone_runner::*;

/// Helper to convert C string to Rust string
fn c_str_to_string(s: *const c_char) -> Option<String> {
    if s.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(s).to_str().ok().map(|s| s.to_string()) }
}

/// Helper to convert Rust string to C string (caller must free)
fn string_to_c_str(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

/// Free a C string allocated by Rust
#[no_mangle]
pub extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}

// =============================================================================
// Git FFI Functions
// =============================================================================

/// Get the timestamp of the last commit (returns 0 if error/no commits)
#[no_mangle]
pub extern "C" fn git_last_commit_timestamp(repo_path: *const c_char) -> i64 {
    let path = match c_str_to_string(repo_path) {
        Some(p) => p,
        None => return 0,
    };
    git::get_last_commit_timestamp(&path).unwrap_or(0)
}

/// Get the number of commits (optionally since a timestamp)
#[no_mangle]
pub extern "C" fn git_commit_count(repo_path: *const c_char, since_timestamp: i64) -> i32 {
    let path = match c_str_to_string(repo_path) {
        Some(p) => p,
        None => return 0,
    };
    let since = if since_timestamp > 0 {
        Some(since_timestamp)
    } else {
        None
    };
    git::get_commit_count(&path, since).unwrap_or(0) as i32
}

/// Check if there are uncommitted changes (returns 1 if true, 0 if false)
#[no_mangle]
pub extern "C" fn git_has_uncommitted_changes(repo_path: *const c_char) -> i32 {
    let path = match c_str_to_string(repo_path) {
        Some(p) => p,
        None => return 0,
    };
    if git::has_uncommitted_changes(&path).unwrap_or(false) {
        1
    } else {
        0
    }
}

/// Get the number of unpushed commits
#[no_mangle]
pub extern "C" fn git_unpushed_commit_count(repo_path: *const c_char) -> i32 {
    let path = match c_str_to_string(repo_path) {
        Some(p) => p,
        None => return 0,
    };
    git::get_unpushed_commit_count(&path).unwrap_or(0) as i32
}

/// Check if path is a git repository (returns 1 if true)
#[no_mangle]
pub extern "C" fn git_is_repository(repo_path: *const c_char) -> i32 {
    let path = match c_str_to_string(repo_path) {
        Some(p) => p,
        None => return 0,
    };
    if git::is_git_repository(&path) {
        1
    } else {
        0
    }
}

/// Get monthly commit counts as JSON string (caller must free)
#[no_mangle]
pub extern "C" fn git_monthly_commits_json(repo_path: *const c_char) -> *mut c_char {
    let path = match c_str_to_string(repo_path) {
        Some(p) => p,
        None => return string_to_c_str("{}".to_string()),
    };
    let counts = git::get_monthly_commit_counts(&path).unwrap_or_default();
    let json = serde_json::to_string(&counts).unwrap_or_else(|_| "{}".to_string());
    string_to_c_str(json)
}

// =============================================================================
// Health Score FFI Functions
// =============================================================================

/// Calculate health score and return as JSON (caller must free)
#[no_mangle]
pub extern "C" fn calculate_health_score_json(project_path: *const c_char) -> *mut c_char {
    let path = match c_str_to_string(project_path) {
        Some(p) => p,
        None => return string_to_c_str("{}".to_string()),
    };
    let score = health::calculate_health_score(&path);
    let json = serde_json::to_string(&score).unwrap_or_else(|_| "{}".to_string());
    string_to_c_str(json)
}

/// Calculate health scores for multiple projects (JSON array input/output)
#[no_mangle]
pub extern "C" fn calculate_health_scores_batch_json(paths_json: *const c_char) -> *mut c_char {
    let json_str = match c_str_to_string(paths_json) {
        Some(s) => s,
        None => return string_to_c_str("[]".to_string()),
    };

    let paths: Vec<String> = serde_json::from_str(&json_str).unwrap_or_default();
    let scores: Vec<health::HealthScoreResult> = paths
        .iter()
        .map(|p| health::calculate_health_score(p))
        .collect();

    let json = serde_json::to_string(&scores).unwrap_or_else(|_| "[]".to_string());
    string_to_c_str(json)
}

// =============================================================================
// Stats FFI Functions
// =============================================================================

/// Calculate year-in-review stats for multiple projects (JSON input/output)
#[no_mangle]
pub extern "C" fn calculate_year_stats_json(paths_json: *const c_char) -> *mut c_char {
    let json_str = match c_str_to_string(paths_json) {
        Some(s) => s,
        None => return string_to_c_str("{}".to_string()),
    };

    let paths: Vec<String> = serde_json::from_str(&json_str).unwrap_or_default();
    let stats = stats::calculate_year_stats(&paths);
    let json = serde_json::to_string(&stats).unwrap_or_else(|_| "{}".to_string());
    string_to_c_str(json)
}

// =============================================================================
// File System FFI Functions
// =============================================================================

/// Scan directory for git repositories (returns JSON array of paths)
#[no_mangle]
pub extern "C" fn scan_for_repos_json(root_path: *const c_char, max_depth: i32) -> *mut c_char {
    let path = match c_str_to_string(root_path) {
        Some(p) => p,
        None => return string_to_c_str("[]".to_string()),
    };

    let repos = health::scan_for_git_repos(&path, max_depth as usize);
    let json = serde_json::to_string(&repos).unwrap_or_else(|_| "[]".to_string());
    string_to_c_str(json)
}
