use std::sync::Arc;

use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{delete, get, patch, post, put},
    Json, Router,
};
use bson::doc;
use futures::TryStreamExt;
use serde::{Deserialize, Serialize};

use crate::app_state::AppState;
use crate::middleware::require_role::RequireOrgAdmin;
use crate::middleware::tenant::ResolvedOrg;
use crate::models::{CatalogDoc, EnvTemplate, Member, Role};
use crate::services::api_key::ApiKeyService;

type SharedState = Arc<AppState>;

/// Build the org-admin route group.
/// All routes require `RequireOrgAdmin` extractor.
pub fn org_admin_routes() -> Router<SharedState> {
    let p = "/api/orgs/:slug/admin";
    Router::new()
        .route(&format!("{p}/members"), get(list_members))
        .route(&format!("{p}/members/invite"), post(invite_member))
        .route(&format!("{p}/members/:login"), patch(update_member).delete(remove_member))
        .route(&format!("{p}/members/:login/keys"), get(list_member_keys).post(generate_member_key))
        .route(&format!("{p}/members/:login/keys/:key"), delete(revoke_member_key))
        .route(&format!("{p}/catalog"), get(get_catalog).put(update_catalog))
        .route(&format!("{p}/catalog/publish"), post(publish_catalog))
        .route(&format!("{p}/templates"), get(list_templates).post(create_template))
        .route(&format!("{p}/templates/:name"), put(update_template).delete(delete_template))
}

// ===========================================================================
// Request / response types
// ===========================================================================

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct MemberSyncInfo {
    github_login: String,
    avatar_url: Option<String>,
    role: Role,
    joined_at: bson::DateTime,
    last_seen_at: Option<bson::DateTime>,
    synced_repos: u32,
    total_repos: u32,
    is_drifted: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct InviteMemberRequest {
    github_login: String,
    role: Role,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct UpdateMemberRequest {
    role: Role,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct UpdateCatalogRequest {
    version: String,
    repos: Vec<crate::models::CatalogRepo>,
    env_templates: Vec<EnvTemplate>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateTemplateRequest {
    name: String,
    vars: std::collections::HashMap<String, crate::models::EnvVar>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct UpdateTemplateRequest {
    vars: std::collections::HashMap<String, crate::models::EnvVar>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct PublishResult {
    committed: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    sha: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<String>,
}

/// A masked view of an API key (never exposes the full key).
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct MaskedApiKey {
    key: String,
    role: Role,
    created_at: bson::DateTime,
    #[serde(skip_serializing_if = "Option::is_none")]
    last_used_at: Option<bson::DateTime>,
    revoked: bool,
}

// ===========================================================================
// Helper: JSON error response
// ===========================================================================

fn json_error(status: StatusCode, msg: &str) -> (StatusCode, Json<serde_json::Value>) {
    (status, Json(serde_json::json!({ "error": msg })))
}

/// Mask an API key: show first 8 chars + last 4 chars, e.g. "plk_abcd...wxyz"
fn mask_key(key: &str) -> String {
    if key.len() <= 12 {
        return key.to_string();
    }
    let prefix = &key[..8];
    let suffix = &key[key.len() - 4..];
    format!("{prefix}...{suffix}")
}

// ===========================================================================
// Helper: get the latest catalog for an org
// ===========================================================================

async fn get_latest_catalog(
    state: &AppState,
    org_id: bson::oid::ObjectId,
) -> Result<Option<CatalogDoc>, (StatusCode, Json<serde_json::Value>)> {
    use mongodb::options::FindOneOptions;

    state
        .db
        .catalogs()
        .find_one(doc! { "orgId": org_id })
        .with_options(
            FindOneOptions::builder()
                .sort(doc! { "publishedAt": -1 })
                .build(),
        )
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))
}

// ===========================================================================
// Member management
// ===========================================================================

/// GET /members — list members with sync status
async fn list_members(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
) -> Result<Json<Vec<MemberSyncInfo>>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    // Fetch all members for this org
    let members: Vec<Member> = state
        .db
        .members()
        .find(doc! { "orgId": org_id })
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?
        .try_collect()
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    // Fetch the latest catalog to know total repos
    let catalog = get_latest_catalog(&state, org_id).await?;
    let total_repos = catalog.as_ref().map(|c| c.repos.len() as u32).unwrap_or(0);

    // Fetch onboarding sessions for this org to compute sync status
    let sessions: Vec<crate::models::OnboardingSession> = state
        .db
        .onboarding_sessions()
        .find(doc! { "orgId": org_id })
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?
        .try_collect()
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    // Build a lookup: github_login -> latest session
    let mut session_map: std::collections::HashMap<String, &crate::models::OnboardingSession> =
        std::collections::HashMap::new();
    for sess in &sessions {
        let existing = session_map.get(sess.github_login.as_str());
        if existing.is_none() || sess.started_at > existing.unwrap().started_at {
            session_map.insert(sess.github_login.clone(), sess);
        }
    }

    let result: Vec<MemberSyncInfo> = members
        .into_iter()
        .map(|m| {
            let session = session_map.get(m.github_login.as_str());
            let synced_repos = session
                .map(|s| {
                    s.steps
                        .iter()
                        .filter(|step| {
                            step.repo_name.is_some()
                                && matches!(step.status, crate::models::StepStatus::Done)
                        })
                        .count() as u32
                })
                .unwrap_or(0);
            let is_drifted = synced_repos < total_repos;

            MemberSyncInfo {
                github_login: m.github_login,
                avatar_url: m.github_avatar,
                role: m.role,
                joined_at: m.joined_at,
                last_seen_at: m.last_seen_at,
                synced_repos,
                total_repos,
                is_drifted,
            }
        })
        .collect();

    Ok(Json(result))
}

/// POST /members/invite — invite a new member
async fn invite_member(
    admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Json(body): Json<InviteMemberRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    // Check if member already exists
    let existing = state
        .db
        .members()
        .find_one(doc! { "orgId": org_id, "githubLogin": &body.github_login })
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    if existing.is_some() {
        return Err(json_error(StatusCode::CONFLICT, "Member already exists"));
    }

    // Cannot invite as SuperAdmin via this endpoint
    if body.role == Role::SuperAdmin {
        return Err(json_error(
            StatusCode::BAD_REQUEST,
            "Cannot assign SuperAdmin role via this endpoint",
        ));
    }

    let new_member = Member {
        id: None,
        org_id,
        github_login: body.github_login.clone(),
        github_avatar: None,
        role: body.role.clone(),
        invited_by: Some(admin.0.github_login),
        joined_at: bson::DateTime::now(),
        last_seen_at: None,
    };

    state
        .db
        .members()
        .insert_one(new_member)
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    // Generate an API key for the new member
    let api_key = ApiKeyService::generate(&state.db, org_id, &body.github_login, body.role)
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Failed to generate API key: {e}")))?;

    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({
            "member": body.github_login,
            "apiKey": api_key.key,
        })),
    ))
}

/// PATCH /members/:login — update member role
async fn update_member(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Path((_slug, login)): Path<(String, String)>,
    Json(body): Json<UpdateMemberRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    // Cannot set SuperAdmin role via this endpoint
    if body.role == Role::SuperAdmin {
        return Err(json_error(
            StatusCode::BAD_REQUEST,
            "Cannot assign SuperAdmin role via this endpoint",
        ));
    }

    // Cannot change a SuperAdmin's role via this endpoint
    let existing = state
        .db
        .members()
        .find_one(doc! { "orgId": org_id, "githubLogin": &login })
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    match existing {
        None => return Err(json_error(StatusCode::NOT_FOUND, "Member not found")),
        Some(m) if m.role == Role::SuperAdmin => {
            return Err(json_error(
                StatusCode::FORBIDDEN,
                "Cannot change SuperAdmin role via this endpoint",
            ));
        }
        _ => {}
    }

    let role_bson = bson::to_bson(&body.role)
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Serialization error: {e}")))?;

    let result = state
        .db
        .members()
        .update_one(
            doc! { "orgId": org_id, "githubLogin": &login },
            doc! { "$set": { "role": role_bson } },
        )
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    if result.matched_count == 0 {
        return Err(json_error(StatusCode::NOT_FOUND, "Member not found"));
    }

    Ok(Json(serde_json::json!({ "updated": login })))
}

/// DELETE /members/:login — remove member
async fn remove_member(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Path((_slug, login)): Path<(String, String)>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    let result = state
        .db
        .members()
        .delete_one(doc! { "orgId": org_id, "githubLogin": &login })
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    if result.deleted_count == 0 {
        return Err(json_error(StatusCode::NOT_FOUND, "Member not found"));
    }

    Ok(Json(serde_json::json!({ "removed": login })))
}

// ===========================================================================
// API key management
// ===========================================================================

/// GET /members/:login/keys — list API keys for a member (masked)
async fn list_member_keys(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Path((_slug, login)): Path<(String, String)>,
) -> Result<Json<Vec<MaskedApiKey>>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    let keys = ApiKeyService::list_by_member(&state.db, org_id, &login)
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    let masked: Vec<MaskedApiKey> = keys
        .into_iter()
        .map(|k| MaskedApiKey {
            key: mask_key(&k.key),
            role: k.role,
            created_at: k.created_at,
            last_used_at: k.last_used_at,
            revoked: k.revoked,
        })
        .collect();

    Ok(Json(masked))
}

/// POST /members/:login/keys — generate a new API key for a member
async fn generate_member_key(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Path((_slug, login)): Path<(String, String)>,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    // Verify the member exists
    let member = state
        .db
        .members()
        .find_one(doc! { "orgId": org_id, "githubLogin": &login })
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?
        .ok_or_else(|| json_error(StatusCode::NOT_FOUND, "Member not found"))?;

    let api_key = ApiKeyService::generate(&state.db, org_id, &login, member.role)
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Failed to generate API key: {e}")))?;

    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({ "apiKey": api_key.key })),
    ))
}

/// DELETE /members/:login/keys/:key — revoke an API key
async fn revoke_member_key(
    _admin: RequireOrgAdmin,
    ResolvedOrg(_org): ResolvedOrg,
    State(state): State<SharedState>,
    Path((_slug, _login, key)): Path<(String, String, String)>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let revoked = ApiKeyService::revoke(&state.db, &key)
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    if !revoked {
        return Err(json_error(StatusCode::NOT_FOUND, "API key not found"));
    }

    Ok(Json(serde_json::json!({ "revoked": key })))
}

// ===========================================================================
// Catalog management
// ===========================================================================

/// GET /catalog — get the latest catalog for the org
async fn get_catalog(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    let catalog = get_latest_catalog(&state, org_id).await?;

    match catalog {
        Some(c) => Ok(Json(serde_json::json!(c))),
        None => Err(json_error(StatusCode::NOT_FOUND, "No catalog found for this org")),
    }
}

/// PUT /catalog — replace the latest catalog
async fn update_catalog(
    admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Json(body): Json<UpdateCatalogRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    let catalog_doc = CatalogDoc {
        id: None,
        org_id,
        version: body.version,
        repos: body.repos,
        env_templates: body.env_templates,
        published_at: bson::DateTime::now(),
        published_by: admin.0.github_login,
        git_sha: None,
    };

    // Upsert: replace the latest doc for this org, or insert if none exists
    use mongodb::options::ReplaceOptions;

    state
        .db
        .catalogs()
        .replace_one(doc! { "orgId": org_id }, &catalog_doc)
        .with_options(ReplaceOptions::builder().upsert(true).build())
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    Ok(Json(serde_json::json!({ "published": true })))
}

/// POST /catalog/publish — replace catalog and attempt git commit
async fn publish_catalog(
    admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Json(body): Json<UpdateCatalogRequest>,
) -> Result<Json<PublishResult>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");
    let slug = org.slug.clone();

    let catalog_doc = CatalogDoc {
        id: None,
        org_id,
        version: body.version,
        repos: body.repos,
        env_templates: body.env_templates,
        published_at: bson::DateTime::now(),
        published_by: admin.0.github_login,
        git_sha: None,
    };

    // Upsert catalog into the database
    use mongodb::options::ReplaceOptions;

    state
        .db
        .catalogs()
        .replace_one(doc! { "orgId": org_id }, &catalog_doc)
        .with_options(ReplaceOptions::builder().upsert(true).build())
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    // Attempt to write YAML and git commit
    let publish_result = attempt_git_commit(&slug, &catalog_doc).await;

    Ok(Json(publish_result))
}

/// Write catalog to YAML file and run git add + commit.
async fn attempt_git_commit(slug: &str, catalog: &CatalogDoc) -> PublishResult {
    let catalog_dir = format!("catalogs/{slug}");
    let catalog_path = format!("{catalog_dir}/catalog.yaml");

    // Create directory
    if let Err(e) = std::fs::create_dir_all(&catalog_dir) {
        return PublishResult {
            committed: false,
            sha: None,
            reason: Some(format!("Failed to create directory: {e}")),
        };
    }

    // Serialize catalog to YAML
    let yaml = match serde_yaml::to_string(catalog) {
        Ok(y) => y,
        Err(e) => {
            return PublishResult {
                committed: false,
                sha: None,
                reason: Some(format!("Failed to serialize catalog to YAML: {e}")),
            };
        }
    };

    // Write YAML file
    if let Err(e) = std::fs::write(&catalog_path, &yaml) {
        return PublishResult {
            committed: false,
            sha: None,
            reason: Some(format!("Failed to write YAML file: {e}")),
        };
    }

    // git add
    let add_result = std::process::Command::new("git")
        .args(["add", &catalog_path])
        .output();

    match add_result {
        Ok(output) if !output.status.success() => {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return PublishResult {
                committed: false,
                sha: None,
                reason: Some(format!("git add failed: {stderr}")),
            };
        }
        Err(e) => {
            return PublishResult {
                committed: false,
                sha: None,
                reason: Some(format!("git not available: {e}")),
            };
        }
        _ => {}
    }

    // git commit
    let commit_msg = format!("chore: update catalog for {slug} [plauncher-admin]");
    let commit_result = std::process::Command::new("git")
        .args(["commit", "-m", &commit_msg])
        .output();

    match commit_result {
        Ok(output) if output.status.success() => {
            // Get the commit SHA
            let sha = std::process::Command::new("git")
                .args(["rev-parse", "HEAD"])
                .output()
                .ok()
                .and_then(|o| {
                    if o.status.success() {
                        Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
                    } else {
                        None
                    }
                });

            PublishResult {
                committed: true,
                sha,
                reason: None,
            }
        }
        Ok(output) => {
            let stderr = String::from_utf8_lossy(&output.stderr);
            PublishResult {
                committed: false,
                sha: None,
                reason: Some(format!("git commit failed: {stderr}")),
            }
        }
        Err(e) => PublishResult {
            committed: false,
            sha: None,
            reason: Some(format!("git not available: {e}")),
        },
    }
}

// ===========================================================================
// Env template management (convenience CRUD on catalog.envTemplates)
// ===========================================================================

/// GET /templates — return envTemplates from the latest catalog
async fn list_templates(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
) -> Result<Json<Vec<EnvTemplate>>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    let catalog = get_latest_catalog(&state, org_id).await?;

    match catalog {
        Some(c) => Ok(Json(c.env_templates)),
        None => Ok(Json(vec![])),
    }
}

/// POST /templates — add a template to the catalog
async fn create_template(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Json(body): Json<CreateTemplateRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    let mut catalog = get_latest_catalog(&state, org_id)
        .await?
        .ok_or_else(|| json_error(StatusCode::NOT_FOUND, "No catalog found for this org"))?;

    // Check for duplicate template name
    if catalog.env_templates.iter().any(|t| t.name == body.name) {
        return Err(json_error(StatusCode::CONFLICT, "Template with this name already exists"));
    }

    let new_template = EnvTemplate {
        name: body.name.clone(),
        vars: body.vars,
    };

    catalog.env_templates.push(new_template);

    // Write back
    let templates_bson = bson::to_bson(&catalog.env_templates)
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Serialization error: {e}")))?;

    state
        .db
        .catalogs()
        .update_one(
            doc! { "orgId": org_id },
            doc! { "$set": { "envTemplates": templates_bson } },
        )
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({ "created": body.name })),
    ))
}

/// PUT /templates/:name — update a template
async fn update_template(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Path((_slug, name)): Path<(String, String)>,
    Json(body): Json<UpdateTemplateRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    let mut catalog = get_latest_catalog(&state, org_id)
        .await?
        .ok_or_else(|| json_error(StatusCode::NOT_FOUND, "No catalog found for this org"))?;

    let template = catalog
        .env_templates
        .iter_mut()
        .find(|t| t.name == name);

    match template {
        None => return Err(json_error(StatusCode::NOT_FOUND, "Template not found")),
        Some(t) => {
            t.vars = body.vars;
        }
    }

    // Write back
    let templates_bson = bson::to_bson(&catalog.env_templates)
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Serialization error: {e}")))?;

    state
        .db
        .catalogs()
        .update_one(
            doc! { "orgId": org_id },
            doc! { "$set": { "envTemplates": templates_bson } },
        )
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    Ok(Json(serde_json::json!({ "updated": name })))
}

/// DELETE /templates/:name — remove a template
async fn delete_template(
    _admin: RequireOrgAdmin,
    ResolvedOrg(org): ResolvedOrg,
    State(state): State<SharedState>,
    Path((_slug, name)): Path<(String, String)>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let org_id = org.id.expect("org should have an _id");

    let mut catalog = get_latest_catalog(&state, org_id)
        .await?
        .ok_or_else(|| json_error(StatusCode::NOT_FOUND, "No catalog found for this org"))?;

    let original_len = catalog.env_templates.len();
    catalog.env_templates.retain(|t| t.name != name);

    if catalog.env_templates.len() == original_len {
        return Err(json_error(StatusCode::NOT_FOUND, "Template not found"));
    }

    // Write back
    let templates_bson = bson::to_bson(&catalog.env_templates)
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Serialization error: {e}")))?;

    state
        .db
        .catalogs()
        .update_one(
            doc! { "orgId": org_id },
            doc! { "$set": { "envTemplates": templates_bson } },
        )
        .await
        .map_err(|e| json_error(StatusCode::INTERNAL_SERVER_ERROR, &format!("Database error: {e}")))?;

    Ok(Json(serde_json::json!({ "removed": name })))
}
