//! Year-in-review statistics aggregation

use crate::git;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Aggregated stats for year-in-review
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct YearStats {
    pub total_projects: i32,
    pub total_commits: i32,
    pub active_projects_count: i32,
    pub most_active_project: Option<String>,
    pub most_active_project_commits: i32,
    pub monthly_activity: HashMap<String, i32>,
    pub generated_at: i64,
}

/// Calculate year-in-review stats for multiple projects
pub fn calculate_year_stats(project_paths: &[String]) -> YearStats {
    let mut stats = YearStats {
        total_projects: project_paths.len() as i32,
        total_commits: 0,
        active_projects_count: 0,
        most_active_project: None,
        most_active_project_commits: 0,
        monthly_activity: HashMap::new(),
        generated_at: Utc::now().timestamp(),
    };

    for path in project_paths {
        if !git::is_git_repository(path) {
            continue;
        }

        // Get yearly commit count
        let yearly_commits = git::get_yearly_commit_count(path).unwrap_or(0) as i32;
        stats.total_commits += yearly_commits;

        if yearly_commits > 0 {
            stats.active_projects_count += 1;
        }

        // Track most active project
        if yearly_commits > stats.most_active_project_commits {
            stats.most_active_project_commits = yearly_commits;
            // Extract project name from path
            let project_name = path
                .rsplit('/')
                .next()
                .unwrap_or(path)
                .to_string();
            stats.most_active_project = Some(project_name);
        }

        // Get monthly breakdown
        if let Ok(monthly) = git::get_monthly_commit_counts(path) {
            for (month, count) in monthly {
                *stats.monthly_activity.entry(month).or_insert(0) += count;
            }
        }
    }

    stats
}

/// Calculate stats for a single project
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectStats {
    pub path: String,
    pub name: String,
    pub total_commits: i32,
    pub yearly_commits: i32,
    pub monthly_commits: HashMap<String, i32>,
    pub last_commit_timestamp: Option<i64>,
    pub current_branch: Option<String>,
}

pub fn calculate_project_stats(path: &str) -> ProjectStats {
    let name = path.rsplit('/').next().unwrap_or(path).to_string();

    let mut stats = ProjectStats {
        path: path.to_string(),
        name,
        total_commits: 0,
        yearly_commits: 0,
        monthly_commits: HashMap::new(),
        last_commit_timestamp: None,
        current_branch: None,
    };

    if !git::is_git_repository(path) {
        return stats;
    }

    stats.total_commits = git::get_commit_count(path, None).unwrap_or(0) as i32;
    stats.yearly_commits = git::get_yearly_commit_count(path).unwrap_or(0) as i32;
    stats.monthly_commits = git::get_monthly_commit_counts(path).unwrap_or_default();
    stats.last_commit_timestamp = git::get_last_commit_timestamp(path).ok();
    stats.current_branch = git::get_current_branch(path).ok();

    stats
}
