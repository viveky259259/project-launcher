//! Git operations using libgit2

use anyhow::Result;
use chrono::{Datelike, Utc};
use git2::{Repository, StatusOptions};
use std::collections::HashMap;

/// Check if a path is a git repository
pub fn is_git_repository(path: &str) -> bool {
    Repository::open(path).is_ok()
}

/// Get the timestamp of the last commit (Unix timestamp in seconds)
pub fn get_last_commit_timestamp(repo_path: &str) -> Result<i64> {
    let repo = Repository::open(repo_path)?;
    let head = repo.head()?;
    let commit = head.peel_to_commit()?;
    Ok(commit.time().seconds())
}

/// Get the number of commits, optionally since a specific timestamp
pub fn get_commit_count(repo_path: &str, since_timestamp: Option<i64>) -> Result<usize> {
    let repo = Repository::open(repo_path)?;
    let head = repo.head()?;
    let head_commit = head.peel_to_commit()?;

    let mut revwalk = repo.revwalk()?;
    revwalk.push(head_commit.id())?;

    let count = if let Some(since) = since_timestamp {
        revwalk
            .filter_map(|oid| oid.ok())
            .filter_map(|oid| repo.find_commit(oid).ok())
            .filter(|commit| commit.time().seconds() >= since)
            .count()
    } else {
        revwalk.count()
    };

    Ok(count)
}

/// Check if there are uncommitted changes (modified, staged, or untracked)
pub fn has_uncommitted_changes(repo_path: &str) -> Result<bool> {
    let repo = Repository::open(repo_path)?;
    let mut opts = StatusOptions::new();
    opts.include_untracked(true)
        .include_ignored(false)
        .recurse_untracked_dirs(true);

    let statuses = repo.statuses(Some(&mut opts))?;
    Ok(!statuses.is_empty())
}

/// Get the number of commits that haven't been pushed to the upstream
pub fn get_unpushed_commit_count(repo_path: &str) -> Result<usize> {
    let repo = Repository::open(repo_path)?;
    let head = repo.head()?;

    // Get the tracking branch
    let local_branch = repo.find_branch(
        head.shorthand().unwrap_or("HEAD"),
        git2::BranchType::Local,
    )?;

    let upstream = match local_branch.upstream() {
        Ok(b) => b,
        Err(_) => return Ok(0), // No tracking branch
    };

    let local_oid = head.target().ok_or_else(|| anyhow::anyhow!("No HEAD target"))?;
    let upstream_oid = upstream
        .get()
        .target()
        .ok_or_else(|| anyhow::anyhow!("No upstream target"))?;

    // Count commits between upstream and local
    let mut revwalk = repo.revwalk()?;
    revwalk.push(local_oid)?;
    revwalk.hide(upstream_oid)?;

    Ok(revwalk.count())
}

/// Get the current branch name
pub fn get_current_branch(repo_path: &str) -> Result<String> {
    let repo = Repository::open(repo_path)?;
    let head = repo.head()?;
    Ok(head.shorthand().unwrap_or("HEAD").to_string())
}

/// Get monthly commit counts for the past year
pub fn get_monthly_commit_counts(repo_path: &str) -> Result<HashMap<String, i32>> {
    let repo = Repository::open(repo_path)?;
    let head = repo.head()?;
    let head_commit = head.peel_to_commit()?;

    let mut counts: HashMap<String, i32> = HashMap::new();
    let now = Utc::now();

    // Initialize all months in the past year
    for i in 0..12 {
        let month = now.month() as i32 - i;
        let year = if month <= 0 {
            now.year() - 1
        } else {
            now.year()
        };
        let month = if month <= 0 { month + 12 } else { month };
        let key = format!("{}-{:02}", year, month);
        counts.insert(key, 0);
    }

    // Calculate timestamp for one year ago
    let one_year_ago = now
        .checked_sub_signed(chrono::Duration::days(365))
        .map(|d| d.timestamp())
        .unwrap_or(0);

    let mut revwalk = repo.revwalk()?;
    revwalk.push(head_commit.id())?;

    for oid in revwalk.filter_map(|r| r.ok()) {
        if let Ok(commit) = repo.find_commit(oid) {
            let timestamp = commit.time().seconds();
            if timestamp < one_year_ago {
                break; // Stop when we go beyond one year
            }

            // Convert timestamp to month key
            if let Some(dt) = chrono::DateTime::from_timestamp(timestamp, 0) {
                let key = format!("{}-{:02}", dt.year(), dt.month());
                if let Some(count) = counts.get_mut(&key) {
                    *count += 1;
                }
            }
        }
    }

    Ok(counts)
}

/// Get total commits in the past year
pub fn get_yearly_commit_count(repo_path: &str) -> Result<usize> {
    let one_year_ago = Utc::now()
        .checked_sub_signed(chrono::Duration::days(365))
        .map(|d| d.timestamp())
        .unwrap_or(0);

    get_commit_count(repo_path, Some(one_year_ago))
}
