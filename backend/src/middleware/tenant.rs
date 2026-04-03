use std::sync::Arc;

use axum::{
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
    Json,
};

use crate::app_state::AppState;
use crate::models::Org;

/// A resolved org extracted from the `:slug` path parameter.
#[derive(Debug, Clone)]
pub struct ResolvedOrg(pub Org);

/// Errors returned by the tenant extractor.
pub struct TenantError {
    status: StatusCode,
    message: String,
}

impl IntoResponse for TenantError {
    fn into_response(self) -> Response {
        let body = serde_json::json!({ "error": self.message });
        (self.status, Json(body)).into_response()
    }
}

impl FromRequestParts<Arc<AppState>> for ResolvedOrg {
    type Rejection = TenantError;

    fn from_request_parts<'life0, 'life1, 'async_trait>(
        parts: &'life0 mut Parts,
        state: &'life1 Arc<AppState>,
    ) -> core::pin::Pin<
        Box<dyn core::future::Future<Output = Result<Self, Self::Rejection>> + Send + 'async_trait>,
    >
    where
        'life0: 'async_trait,
        'life1: 'async_trait,
        Self: 'async_trait,
    {
        Box::pin(async move {
            let app_state: &AppState = state.as_ref();

            // Extract :slug from the path parameters.
            let path_params: axum::extract::Path<std::collections::HashMap<String, String>> =
                axum::extract::Path::from_request_parts(parts, state)
                    .await
                    .map_err(|_| TenantError {
                        status: StatusCode::BAD_REQUEST,
                        message: "Missing slug path parameter".into(),
                    })?;

            let slug = path_params
                .get("slug")
                .ok_or_else(|| TenantError {
                    status: StatusCode::BAD_REQUEST,
                    message: "Missing slug path parameter".into(),
                })?
                .clone();

            // Look up org in MongoDB
            let org = app_state
                .db
                .orgs()
                .find_one(bson::doc! { "slug": &slug })
                .await
                .map_err(|e| TenantError {
                    status: StatusCode::INTERNAL_SERVER_ERROR,
                    message: format!("Database error: {e}"),
                })?
                .ok_or_else(|| TenantError {
                    status: StatusCode::NOT_FOUND,
                    message: "Organization not found".into(),
                })?;

            // Check if org is suspended
            if org.suspended_at.is_some() {
                return Err(TenantError {
                    status: StatusCode::FORBIDDEN,
                    message: "Organization is suspended".into(),
                });
            }

            Ok(ResolvedOrg(org))
        })
    }
}
