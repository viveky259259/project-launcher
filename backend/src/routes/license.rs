use std::sync::Arc;

use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use serde::Deserialize;

use crate::app_state::AppState;
use crate::services::license::LicenseService;

/// POST /api/license/validate
///
/// Body: `{ "key": "plk_live_xxx", "seatCount": 87, "instanceId": "xxx" }`
///
/// Response on success: `{ "valid": true, "plan": "enterprise", "seats": 100, "expiresAt": "..." }`
/// Response on failure: `{ "valid": false, "reason": "License key has been revoked" }`
///
/// No auth required -- self-hosted instances call this with just the license key.
pub async fn validate_license(
    State(state): State<Arc<AppState>>,
    Json(body): Json<ValidateRequest>,
) -> impl IntoResponse {
    match LicenseService::validate(&state.db, &body.key, body.seat_count).await {
        Ok(validation) => (StatusCode::OK, Json(serde_json::json!(validation))).into_response(),
        Err(e) => (
            StatusCode::NOT_FOUND,
            Json(serde_json::json!({"valid": false, "reason": e.to_string()})),
        )
            .into_response(),
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ValidateRequest {
    pub key: String,
    pub seat_count: u32,
    #[serde(default)]
    pub instance_id: Option<String>,
}
