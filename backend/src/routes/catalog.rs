use std::sync::Arc;

use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;

use crate::app_state::AppState;
use crate::middleware::require_role::RequireDeveloper;
use crate::middleware::tenant::ResolvedOrg;

type SharedState = Arc<AppState>;

/// Build the catalog route group.
pub fn catalog_routes() -> Router<SharedState> {
    let p = "/api/orgs/:slug/catalog";
    Router::new()
        .route(p, get(get_catalog))
        .route(&format!("{p}/diff"), get(get_diff))
        .route(&format!("{p}/sync"), post(sync_repos))
}

// ---------------------------------------------------------------------------
// GET /api/orgs/:slug/catalog — Latest published catalog for this org
// ---------------------------------------------------------------------------

async fn get_catalog(
    State(state): State<SharedState>,
    _developer: RequireDeveloper,
    org: ResolvedOrg,
) -> Response {
    let org_id = org.0.id.expect("org must have _id");

    let options = mongodb::options::FindOneOptions::builder()
        .sort(bson::doc! { "publishedAt": -1 })
        .build();

    match state
        .db
        .catalogs()
        .find_one(bson::doc! { "orgId": org_id })
        .with_options(options)
        .await
    {
        Ok(Some(catalog)) => (StatusCode::OK, Json(serde_json::json!(catalog))).into_response(),
        Ok(None) => (
            StatusCode::NOT_FOUND,
            Json(serde_json::json!({ "error": "No published catalog found" })),
        )
            .into_response(),
        Err(e) => {
            tracing::error!("Failed to fetch catalog: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": "Database error" })),
            )
                .into_response()
        }
    }
}

// ---------------------------------------------------------------------------
// GET /api/orgs/:slug/catalog/diff?repos=name1,name2,name3
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
struct DiffQuery {
    #[serde(default)]
    repos: Option<String>,
}

async fn get_diff(
    State(state): State<SharedState>,
    _developer: RequireDeveloper,
    org: ResolvedOrg,
    Query(query): Query<DiffQuery>,
) -> Response {
    let org_id = org.0.id.expect("org must have _id");

    // Fetch latest catalog
    let options = mongodb::options::FindOneOptions::builder()
        .sort(bson::doc! { "publishedAt": -1 })
        .build();

    let catalog = match state
        .db
        .catalogs()
        .find_one(bson::doc! { "orgId": org_id })
        .with_options(options)
        .await
    {
        Ok(Some(c)) => c,
        Ok(None) => {
            return (
                StatusCode::NOT_FOUND,
                Json(serde_json::json!({ "error": "No published catalog found" })),
            )
                .into_response();
        }
        Err(e) => {
            tracing::error!("Failed to fetch catalog: {e}");
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": "Database error" })),
            )
                .into_response();
        }
    };

    // Parse local repo names from query
    let local_names: Vec<String> = query
        .repos
        .unwrap_or_default()
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();

    let local_set: std::collections::HashSet<&str> =
        local_names.iter().map(|s| s.as_str()).collect();

    let catalog_set: std::collections::HashSet<&str> =
        catalog.repos.iter().map(|r| r.name.as_str()).collect();

    let missing_repos: Vec<_> = catalog
        .repos
        .iter()
        .filter(|r| !local_set.contains(r.name.as_str()))
        .collect();

    let extra_repos: Vec<&str> = local_names
        .iter()
        .filter(|n| !catalog_set.contains(n.as_str()))
        .map(|n| n.as_str())
        .collect();

    let synced_repos: Vec<_> = catalog
        .repos
        .iter()
        .filter(|r| local_set.contains(r.name.as_str()))
        .collect();

    let body = serde_json::json!({
        "missingRepos": missing_repos,
        "extraRepos": extra_repos,
        "syncedRepos": synced_repos,
        "computedAt": chrono::Utc::now().to_rfc3339(),
    });

    (StatusCode::OK, Json(body)).into_response()
}

// ---------------------------------------------------------------------------
// POST /api/orgs/:slug/catalog/sync
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
struct SyncRequest {
    repos: Vec<String>,
}

async fn sync_repos(
    State(state): State<SharedState>,
    developer: RequireDeveloper,
    org: ResolvedOrg,
    Json(body): Json<SyncRequest>,
) -> Response {
    let org_id = org.0.id.expect("org must have _id");
    let github_login = &developer.0.github_login;

    // Fetch latest catalog
    let options = mongodb::options::FindOneOptions::builder()
        .sort(bson::doc! { "publishedAt": -1 })
        .build();

    let catalog = match state
        .db
        .catalogs()
        .find_one(bson::doc! { "orgId": org_id })
        .with_options(options)
        .await
    {
        Ok(Some(c)) => c,
        Ok(None) => {
            return (
                StatusCode::NOT_FOUND,
                Json(serde_json::json!({ "error": "No published catalog found" })),
            )
                .into_response();
        }
        Err(e) => {
            tracing::error!("Failed to fetch catalog: {e}");
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": "Database error" })),
            )
                .into_response();
        }
    };

    // Build clone instructions for requested repos
    let requested_set: std::collections::HashSet<&str> =
        body.repos.iter().map(|s| s.as_str()).collect();

    let instructions: Vec<serde_json::Value> = catalog
        .repos
        .iter()
        .filter(|r| requested_set.contains(r.name.as_str()))
        .map(|r| {
            serde_json::json!({
                "name": r.name,
                "url": r.url,
                "envTemplate": r.env_template,
            })
        })
        .collect();

    // Update member's last_seen_at
    if let Err(e) = state
        .db
        .members()
        .update_one(
            bson::doc! { "orgId": org_id, "githubLogin": github_login },
            bson::doc! { "$set": { "lastSeenAt": bson::DateTime::now() } },
        )
        .await
    {
        tracing::warn!("Failed to update member last_seen_at: {e}");
    }

    (
        StatusCode::OK,
        Json(serde_json::json!({ "instructions": instructions })),
    )
        .into_response()
}
