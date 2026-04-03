use std::sync::Arc;

use axum::{
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
    Json,
};

use crate::app_state::AppState;
use crate::models::Role;

use super::auth::AuthUser;

/// Error returned when a role check fails.
pub struct RoleError {
    status: StatusCode,
    message: String,
}

impl IntoResponse for RoleError {
    fn into_response(self) -> Response {
        let body = serde_json::json!({ "error": self.message });
        (self.status, Json(body)).into_response()
    }
}

/// Requires the caller to be a SuperAdmin.
pub struct RequireSuperAdmin(pub AuthUser);

impl FromRequestParts<Arc<AppState>> for RequireSuperAdmin {
    type Rejection = Response;

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
            let user = AuthUser::from_request_parts(parts, state)
                .await
                .map_err(IntoResponse::into_response)?;

            if user.role != Role::SuperAdmin {
                return Err(RoleError {
                    status: StatusCode::FORBIDDEN,
                    message: "Insufficient permissions".into(),
                }
                .into_response());
            }

            Ok(RequireSuperAdmin(user))
        })
    }
}

/// Requires the caller to be at least an OrgAdmin.
/// For org-scoped routes, also verifies the user's org_slug matches the `:slug`
/// path param (SuperAdmins bypass this check).
pub struct RequireOrgAdmin(pub AuthUser);

impl FromRequestParts<Arc<AppState>> for RequireOrgAdmin {
    type Rejection = Response;

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
            let user = AuthUser::from_request_parts(parts, state)
                .await
                .map_err(IntoResponse::into_response)?;

            // Must be OrgAdmin or SuperAdmin (Role derives Ord: Developer < OrgAdmin < SuperAdmin)
            if user.role < Role::OrgAdmin {
                return Err(RoleError {
                    status: StatusCode::FORBIDDEN,
                    message: "Insufficient permissions".into(),
                }
                .into_response());
            }

            // For non-SuperAdmin users, verify org_slug matches path :slug
            if user.role != Role::SuperAdmin {
                // Try to extract :slug from path params
                if let Ok(path_params) = axum::extract::Path::<
                    std::collections::HashMap<String, String>,
                >::from_request_parts(parts, state)
                .await
                {
                    if let Some(path_slug) = path_params.get("slug") {
                        if user.org_slug.as_deref() != Some(path_slug.as_str()) {
                            return Err(RoleError {
                                status: StatusCode::FORBIDDEN,
                                message: "Insufficient permissions".into(),
                            }
                            .into_response());
                        }
                    }
                }
            }

            Ok(RequireOrgAdmin(user))
        })
    }
}

/// Requires the caller to be at least a Developer (i.e., any authenticated user).
pub struct RequireDeveloper(pub AuthUser);

impl FromRequestParts<Arc<AppState>> for RequireDeveloper {
    type Rejection = Response;

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
            let user = AuthUser::from_request_parts(parts, state)
                .await
                .map_err(IntoResponse::into_response)?;

            // All roles (Developer, OrgAdmin, SuperAdmin) pass this check.
            Ok(RequireDeveloper(user))
        })
    }
}
