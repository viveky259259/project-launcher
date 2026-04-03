use std::sync::Arc;

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::{IntoResponse, Redirect, Response},
    routing::get,
    Json, Router,
};
use serde::Deserialize;

use crate::app_state::AppState;
use crate::middleware::auth::create_jwt;
use crate::models::Role;

type SharedState = Arc<AppState>;

/// Query parameters for the OAuth callback.
#[derive(Debug, Deserialize)]
pub struct CallbackParams {
    pub code: String,
    pub state: String,
    #[serde(default)]
    pub redirect: Option<String>,
}

/// GitHub access token response.
#[derive(Debug, Deserialize)]
struct GithubTokenResponse {
    access_token: String,
    #[allow(dead_code)]
    token_type: Option<String>,
}

/// GitHub user info response.
#[derive(Debug, Deserialize)]
struct GithubUser {
    login: String,
    #[allow(dead_code)]
    avatar_url: Option<String>,
}

/// Build the auth route group.
pub fn auth_routes() -> Router<SharedState> {
    Router::new()
        .route("/:slug/github", get(org_github_login))
        .route("/super-admin/github", get(super_admin_github_login))
        .route("/callback", get(auth_callback))
}

// ---------------------------------------------------------------------------
// GET /auth/:slug/github — Org-scoped GitHub OAuth initiation
// ---------------------------------------------------------------------------

/// Check if GitHub OAuth is configured (client_id is non-empty and not a placeholder).
pub fn is_oauth_configured(state: &AppState) -> bool {
    let id = &state.github_client_id;
    !id.is_empty() && id != "placeholder" && id != "PLACEHOLDER"
}

async fn org_github_login(
    State(state): State<SharedState>,
    Path(slug): Path<String>,
) -> Response {
    if !is_oauth_configured(&state) {
        let body = serde_json::json!({ "error": "GitHub OAuth not configured. Use API keys instead." });
        return (StatusCode::NOT_FOUND, Json(body)).into_response();
    }

    // Encode the slug into the state parameter: "slug:random"
    let random = uuid::Uuid::new_v4().to_string();
    let oauth_state = format!("{slug}:{random}");

    let redirect_uri = build_callback_uri();
    let url = format!(
        "https://github.com/login/oauth/authorize?client_id={}&redirect_uri={}&state={}&scope=read:org,user",
        state.github_client_id,
        urlencoding(&redirect_uri),
        urlencoding(&oauth_state),
    );

    Redirect::temporary(&url).into_response()
}

// ---------------------------------------------------------------------------
// GET /auth/super-admin/github — Super-admin GitHub OAuth initiation
// ---------------------------------------------------------------------------

async fn super_admin_github_login(State(state): State<SharedState>) -> Response {
    if !is_oauth_configured(&state) {
        let body = serde_json::json!({ "error": "GitHub OAuth not configured. Use API keys instead." });
        return (StatusCode::NOT_FOUND, Json(body)).into_response();
    }

    let random = uuid::Uuid::new_v4().to_string();
    let oauth_state = format!("super-admin:{random}");

    let redirect_uri = build_callback_uri();
    let url = format!(
        "https://github.com/login/oauth/authorize?client_id={}&redirect_uri={}&state={}&scope=read:org,user",
        state.github_client_id,
        urlencoding(&redirect_uri),
        urlencoding(&oauth_state),
    );

    Redirect::temporary(&url).into_response()
}

// ---------------------------------------------------------------------------
// GET /auth/callback — GitHub OAuth callback (handles both org and super-admin)
// ---------------------------------------------------------------------------

async fn auth_callback(
    State(state): State<SharedState>,
    Query(params): Query<CallbackParams>,
) -> Response {
    if !is_oauth_configured(&state) {
        let body = serde_json::json!({ "error": "GitHub OAuth not configured. Use API keys instead." });
        return (StatusCode::NOT_FOUND, Json(body)).into_response();
    }

    match handle_callback(&state, &params).await {
        Ok(resp) => resp,
        Err(e) => {
            tracing::error!("Auth callback error: {e:#}");
            let body = serde_json::json!({ "error": format!("{e}") });
            (StatusCode::INTERNAL_SERVER_ERROR, Json(body)).into_response()
        }
    }
}

async fn handle_callback(state: &AppState, params: &CallbackParams) -> anyhow::Result<Response> {
    // Decode state to determine context
    let state_parts: Vec<&str> = params.state.splitn(2, ':').collect();
    if state_parts.len() < 2 {
        let body = serde_json::json!({ "error": "Invalid state parameter" });
        return Ok((StatusCode::BAD_REQUEST, Json(body)).into_response());
    }

    let context = state_parts[0]; // slug or "super-admin"
    let is_super_admin_flow = context == "super-admin";

    // Exchange code for access token
    let access_token = exchange_code_for_token(state, &params.code).await?;

    // Get GitHub user info
    let github_user = get_github_user(&access_token).await?;

    if is_super_admin_flow {
        return handle_super_admin_callback(state, &github_user, params).await;
    }

    // Org-scoped flow
    let slug = context;
    handle_org_callback(state, slug, &github_user, &access_token, params).await
}

async fn handle_super_admin_callback(
    state: &AppState,
    github_user: &GithubUser,
    params: &CallbackParams,
) -> anyhow::Result<Response> {
    // Verify user exists in super_admins collection
    let sa = state
        .db
        .super_admins()
        .find_one(bson::doc! { "githubLogin": &github_user.login })
        .await?;

    if sa.is_none() {
        let body = serde_json::json!({ "error": "Not a super admin" });
        return Ok((StatusCode::FORBIDDEN, Json(body)).into_response());
    }

    // Issue JWT
    let token = create_jwt(
        &state.jwt_secret,
        &github_user.login,
        &Role::SuperAdmin,
        None,
        None,
    )?;

    // Handle redirect
    if params.redirect.as_deref() == Some("super-admin") {
        let redirect_url = format!("/?token={token}");
        return Ok(Redirect::temporary(&redirect_url).into_response());
    }

    let body = serde_json::json!({ "token": token });
    Ok(Json(body).into_response())
}

async fn handle_org_callback(
    state: &AppState,
    slug: &str,
    github_user: &GithubUser,
    access_token: &str,
    params: &CallbackParams,
) -> anyhow::Result<Response> {
    // Look up the org
    let org = state
        .db
        .orgs()
        .find_one(bson::doc! { "slug": slug })
        .await?;

    let org = match org {
        Some(o) => o,
        None => {
            let body = serde_json::json!({ "error": "Organization not found" });
            return Ok((StatusCode::NOT_FOUND, Json(body)).into_response());
        }
    };

    if org.suspended_at.is_some() {
        let body = serde_json::json!({ "error": "Organization is suspended" });
        return Ok((StatusCode::FORBIDDEN, Json(body)).into_response());
    }

    // Check GitHub org membership
    let is_member =
        check_github_org_membership(access_token, &org.github_org, &github_user.login).await?;

    if !is_member {
        let body = serde_json::json!({ "error": "Not a member of the GitHub organization" });
        return Ok((StatusCode::FORBIDDEN, Json(body)).into_response());
    }

    let org_id = org.id.expect("org should have an _id");

    // Determine role:
    // 1. Check super_admins collection
    // 2. Check existing member record
    // 3. Create new member as Developer
    let role = determine_role(state, &org_id, &github_user.login).await?;

    // Issue JWT
    let token = create_jwt(
        &state.jwt_secret,
        &github_user.login,
        &role,
        Some(&org_id),
        Some(slug),
    )?;

    // Handle redirect
    if let Some(redirect_target) = &params.redirect {
        match redirect_target.as_str() {
            "admin" | "super-admin" => {
                let redirect_url = format!("/?token={token}");
                return Ok(Redirect::temporary(&redirect_url).into_response());
            }
            _ => {}
        }
    }

    let body = serde_json::json!({ "token": token });
    Ok(Json(body).into_response())
}

/// Determine the role for a user in an org.
async fn determine_role(
    state: &AppState,
    org_id: &bson::oid::ObjectId,
    github_login: &str,
) -> anyhow::Result<Role> {
    // Check if user is a super admin
    let sa = state
        .db
        .super_admins()
        .find_one(bson::doc! { "githubLogin": github_login })
        .await?;

    if sa.is_some() {
        return Ok(Role::SuperAdmin);
    }

    // Check existing membership
    let member = state
        .db
        .members()
        .find_one(bson::doc! { "orgId": org_id, "githubLogin": github_login })
        .await?;

    if let Some(m) = member {
        return Ok(m.role);
    }

    // Create new member as Developer
    let new_member = crate::models::Member {
        id: None,
        org_id: *org_id,
        github_login: github_login.to_string(),
        github_avatar: None,
        role: Role::Developer,
        invited_by: None,
        joined_at: bson::DateTime::now(),
        last_seen_at: None,
    };

    state.db.members().insert_one(new_member).await?;

    Ok(Role::Developer)
}

// ---------------------------------------------------------------------------
// GitHub API helpers
// ---------------------------------------------------------------------------

async fn exchange_code_for_token(state: &AppState, code: &str) -> anyhow::Result<String> {
    let client = reqwest::Client::new();
    let resp = client
        .post("https://github.com/login/oauth/access_token")
        .header("Accept", "application/json")
        .json(&serde_json::json!({
            "client_id": state.github_client_id,
            "client_secret": state.github_client_secret,
            "code": code,
        }))
        .send()
        .await?;

    let status = resp.status();
    if !status.is_success() {
        let text = resp.text().await.unwrap_or_default();
        anyhow::bail!("GitHub token exchange failed ({status}): {text}");
    }

    let token_resp: GithubTokenResponse = resp.json().await?;
    Ok(token_resp.access_token)
}

async fn get_github_user(access_token: &str) -> anyhow::Result<GithubUser> {
    let client = reqwest::Client::new();
    let resp = client
        .get("https://api.github.com/user")
        .header("Authorization", format!("Bearer {access_token}"))
        .header("User-Agent", "plauncher-backend")
        .send()
        .await?;

    let status = resp.status();
    if !status.is_success() {
        let text = resp.text().await.unwrap_or_default();
        anyhow::bail!("GitHub user API failed ({status}): {text}");
    }

    let user: GithubUser = resp.json().await?;
    Ok(user)
}

async fn check_github_org_membership(
    access_token: &str,
    org: &str,
    username: &str,
) -> anyhow::Result<bool> {
    let client = reqwest::Client::new();
    let resp = client
        .get(format!(
            "https://api.github.com/orgs/{org}/members/{username}"
        ))
        .header("Authorization", format!("Bearer {access_token}"))
        .header("User-Agent", "plauncher-backend")
        .send()
        .await?;

    // 204 = member, 404 = not a member, 302 = requester is not an org member
    Ok(resp.status().as_u16() == 204)
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

fn build_callback_uri() -> String {
    std::env::var("PLAUNCHER_CALLBACK_URI")
        .unwrap_or_else(|_| "http://localhost:8743/auth/callback".to_string())
}

/// Simple percent-encoding for URL parameters.
fn urlencoding(s: &str) -> String {
    // Use a simple manual encoding for the characters that matter in URLs.
    s.replace('%', "%25")
        .replace(' ', "%20")
        .replace(':', "%3A")
        .replace('/', "%2F")
        .replace('?', "%3F")
        .replace('#', "%23")
        .replace('&', "%26")
        .replace('=', "%3D")
}
