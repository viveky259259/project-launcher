use std::sync::Arc;

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use futures::TryStreamExt;
use serde::Deserialize;

use crate::app_state::AppState;
use crate::middleware::require_role::{RequireDeveloper, RequireOrgAdmin};
use crate::middleware::tenant::ResolvedOrg;
use crate::models::{OnboardingSession, OnboardingStep, StepStatus};

type SharedState = Arc<AppState>;

/// Build the onboarding route group.
pub fn onboarding_routes() -> Router<SharedState> {
    let p = "/api/orgs/:slug/onboarding";
    Router::new()
        .route(p, get(get_session))
        .route(&format!("{p}/start"), post(start_session))
        .route(&format!("{p}/step"), post(update_step))
        .route(&format!("{p}/all"), get(list_all_sessions))
}

// ---------------------------------------------------------------------------
// GET /api/orgs/:slug/onboarding — Current user's onboarding session
// ---------------------------------------------------------------------------

async fn get_session(
    State(state): State<SharedState>,
    developer: RequireDeveloper,
    org: ResolvedOrg,
) -> Response {
    let org_id = org.0.id.expect("org must have _id");
    let github_login = &developer.0.github_login;

    match state
        .db
        .onboarding_sessions()
        .find_one(bson::doc! { "orgId": org_id, "githubLogin": github_login })
        .await
    {
        Ok(Some(session)) => (StatusCode::OK, Json(serde_json::json!(session))).into_response(),
        Ok(None) => (
            StatusCode::NOT_FOUND,
            Json(serde_json::json!({ "error": "No onboarding session found" })),
        )
            .into_response(),
        Err(e) => {
            tracing::error!("Failed to fetch onboarding session: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": "Database error" })),
            )
                .into_response()
        }
    }
}

// ---------------------------------------------------------------------------
// POST /api/orgs/:slug/onboarding/start — Create/replace onboarding session
// ---------------------------------------------------------------------------

async fn start_session(
    State(state): State<SharedState>,
    developer: RequireDeveloper,
    org: ResolvedOrg,
) -> Response {
    let org_id = org.0.id.expect("org must have _id");
    let github_login = developer.0.github_login.clone();

    // Fetch latest catalog to build steps
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

    // Build steps from catalog
    let mut steps: Vec<OnboardingStep> = Vec::new();

    for repo in &catalog.repos {
        if !repo.required {
            continue;
        }

        // Clone step
        steps.push(OnboardingStep {
            id: format!("clone_{}", repo.name),
            label: format!("Clone {}", repo.name),
            status: StepStatus::Pending,
            repo_name: Some(repo.name.clone()),
            error: None,
        });

        // Env setup step (if repo has env_template)
        if repo.env_template.is_some() {
            steps.push(OnboardingStep {
                id: format!("env_{}", repo.name),
                label: format!("Setup env: {}", repo.name),
                status: StepStatus::Pending,
                repo_name: Some(repo.name.clone()),
                error: None,
            });
        }
    }

    // Build verify step
    steps.push(OnboardingStep {
        id: "build_verify".to_string(),
        label: "Verify builds".to_string(),
        status: StepStatus::Pending,
        repo_name: None,
        error: None,
    });

    // Test verify step
    steps.push(OnboardingStep {
        id: "test_verify".to_string(),
        label: "Run tests".to_string(),
        status: StepStatus::Pending,
        repo_name: None,
        error: None,
    });

    let session = OnboardingSession {
        id: None,
        org_id,
        github_login: github_login.clone(),
        steps,
        started_at: bson::DateTime::now(),
        completed_at: None,
    };

    // Upsert: delete any existing session, then insert new one
    let filter = bson::doc! { "orgId": org_id, "githubLogin": &github_login };

    if let Err(e) = state
        .db
        .onboarding_sessions()
        .delete_one(filter.clone())
        .await
    {
        tracing::warn!("Failed to delete existing onboarding session: {e}");
    }

    match state.db.onboarding_sessions().insert_one(&session).await {
        Ok(result) => {
            // Return the session with the new _id
            let mut response_session = session;
            response_session.id = result.inserted_id.as_object_id();
            (
                StatusCode::CREATED,
                Json(serde_json::json!(response_session)),
            )
                .into_response()
        }
        Err(e) => {
            tracing::error!("Failed to create onboarding session: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": "Database error" })),
            )
                .into_response()
        }
    }
}

// ---------------------------------------------------------------------------
// POST /api/orgs/:slug/onboarding/step — Update a single step's status
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct UpdateStepRequest {
    step_id: String,
    status: StepStatus,
    #[serde(default)]
    error: Option<String>,
}

async fn update_step(
    State(state): State<SharedState>,
    developer: RequireDeveloper,
    org: ResolvedOrg,
    Json(body): Json<UpdateStepRequest>,
) -> Response {
    let org_id = org.0.id.expect("org must have _id");
    let github_login = &developer.0.github_login;

    let filter = bson::doc! { "orgId": org_id, "githubLogin": github_login };

    // Fetch the existing session
    let mut session = match state
        .db
        .onboarding_sessions()
        .find_one(filter.clone())
        .await
    {
        Ok(Some(s)) => s,
        Ok(None) => {
            return (
                StatusCode::NOT_FOUND,
                Json(serde_json::json!({ "error": "No onboarding session found" })),
            )
                .into_response();
        }
        Err(e) => {
            tracing::error!("Failed to fetch onboarding session: {e}");
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": "Database error" })),
            )
                .into_response();
        }
    };

    // Find and update the matching step
    let mut step_found = false;
    for step in &mut session.steps {
        if step.id == body.step_id {
            step.status = body.status.clone();
            step.error = body.error.clone();
            step_found = true;
            break;
        }
    }

    if !step_found {
        return (
            StatusCode::NOT_FOUND,
            Json(serde_json::json!({ "error": format!("Step '{}' not found", body.step_id) })),
        )
            .into_response();
    }

    // Check if all steps are done
    let all_done = session
        .steps
        .iter()
        .all(|s| matches!(s.status, StepStatus::Done));

    if all_done {
        session.completed_at = Some(bson::DateTime::now());
    }

    // Replace the entire document
    match state
        .db
        .onboarding_sessions()
        .replace_one(filter, &session)
        .await
    {
        Ok(_) => (StatusCode::OK, Json(serde_json::json!(session))).into_response(),
        Err(e) => {
            tracing::error!("Failed to update onboarding session: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": "Database error" })),
            )
                .into_response()
        }
    }
}

// ---------------------------------------------------------------------------
// GET /api/orgs/:slug/onboarding/all — All sessions for this org (admin only)
// ---------------------------------------------------------------------------

async fn list_all_sessions(
    State(state): State<SharedState>,
    _admin: RequireOrgAdmin,
    org: ResolvedOrg,
) -> Response {
    let org_id = org.0.id.expect("org must have _id");

    match state
        .db
        .onboarding_sessions()
        .find(bson::doc! { "orgId": org_id })
        .await
    {
        Ok(cursor) => match cursor.try_collect::<Vec<_>>().await {
            Ok(sessions) => (StatusCode::OK, Json(serde_json::json!(sessions))).into_response(),
            Err(e) => {
                tracing::error!("Failed to collect onboarding sessions: {e}");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    Json(serde_json::json!({ "error": "Database error" })),
                )
                    .into_response()
            }
        },
        Err(e) => {
            tracing::error!("Failed to query onboarding sessions: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": "Database error" })),
            )
                .into_response()
        }
    }
}
