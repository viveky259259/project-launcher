use std::sync::Arc;

use axum::{
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};

use crate::app_state::AppState;
use crate::models::Role;
use crate::services::api_key::ApiKeyService;

/// JWT claims stored inside every token.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JwtClaims {
    /// github_login
    pub sub: String,
    /// "super_admin", "org_admin", "developer"
    pub role: String,
    /// ObjectId hex string, None for super admins
    #[serde(skip_serializing_if = "Option::is_none")]
    pub org_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub org_slug: Option<String>,
    /// Expiry (seconds since epoch)
    pub exp: usize,
}

/// The authenticated user extracted from a valid JWT or API key.
#[derive(Debug, Clone)]
pub struct AuthUser {
    pub github_login: String,
    pub role: Role,
    pub org_id: Option<bson::oid::ObjectId>,
    pub org_slug: Option<String>,
}

/// Errors returned by the auth extractor.
pub struct AuthError {
    pub status: StatusCode,
    pub message: String,
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let body = serde_json::json!({ "error": self.message });
        (self.status, Json(body)).into_response()
    }
}

impl FromRequestParts<Arc<AppState>> for AuthUser {
    type Rejection = AuthError;

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

            // Extract Authorization header
            let auth_header = parts
                .headers
                .get("authorization")
                .and_then(|v| v.to_str().ok())
                .ok_or_else(|| AuthError {
                    status: StatusCode::UNAUTHORIZED,
                    message: "Missing Authorization header".into(),
                })?;

            let token = auth_header.strip_prefix("Bearer ").ok_or_else(|| AuthError {
                status: StatusCode::UNAUTHORIZED,
                message: "Invalid Authorization header format, expected: Bearer <token>".into(),
            })?;

            // If token starts with "plk_", validate as API key
            if token.starts_with("plk_") {
                return validate_api_key(app_state, token).await;
            }

            // Otherwise, validate as JWT
            validate_jwt(app_state, token)
        })
    }
}

/// Validate a Bearer token as an API key (plk_xxx).
async fn validate_api_key(app_state: &AppState, token: &str) -> Result<AuthUser, AuthError> {
    let api_key = ApiKeyService::validate(&app_state.db, token)
        .await
        .map_err(|e| AuthError {
            status: StatusCode::INTERNAL_SERVER_ERROR,
            message: format!("API key validation error: {e}"),
        })?
        .ok_or_else(|| AuthError {
            status: StatusCode::UNAUTHORIZED,
            message: "Invalid or revoked API key".into(),
        })?;

    // Look up the org to get org_slug
    let org = app_state
        .db
        .orgs()
        .find_one(bson::doc! { "_id": api_key.org_id })
        .await
        .map_err(|e| AuthError {
            status: StatusCode::INTERNAL_SERVER_ERROR,
            message: format!("Database error: {e}"),
        })?;

    let org_slug = org.map(|o| o.slug);

    Ok(AuthUser {
        github_login: api_key.member_login,
        role: api_key.role,
        org_id: Some(api_key.org_id),
        org_slug,
    })
}

/// Validate a Bearer token as a JWT.
fn validate_jwt(app_state: &AppState, token: &str) -> Result<AuthUser, AuthError> {
    // Decode and validate JWT
    let token_data = decode::<JwtClaims>(
        token,
        &DecodingKey::from_secret(app_state.jwt_secret.as_bytes()),
        &Validation::new(jsonwebtoken::Algorithm::HS256),
    )
    .map_err(|e| AuthError {
        status: StatusCode::UNAUTHORIZED,
        message: format!("Invalid token: {e}"),
    })?;

    let claims = token_data.claims;

    // Map role string back to Role enum
    let role = match claims.role.as_str() {
        "super_admin" => Role::SuperAdmin,
        "org_admin" => Role::OrgAdmin,
        "developer" => Role::Developer,
        other => {
            return Err(AuthError {
                status: StatusCode::UNAUTHORIZED,
                message: format!("Unknown role in token: {other}"),
            });
        }
    };

    // Parse optional org_id
    let org_id = claims
        .org_id
        .as_deref()
        .map(|id| {
            id.parse::<bson::oid::ObjectId>().map_err(|_| AuthError {
                status: StatusCode::UNAUTHORIZED,
                message: "Invalid org_id in token".into(),
            })
        })
        .transpose()?;

    Ok(AuthUser {
        github_login: claims.sub,
        role,
        org_id,
        org_slug: claims.org_slug,
    })
}

/// Create a signed JWT for the given user.
pub fn create_jwt(
    secret: &str,
    github_login: &str,
    role: &Role,
    org_id: Option<&bson::oid::ObjectId>,
    org_slug: Option<&str>,
) -> anyhow::Result<String> {
    let role_str = match role {
        Role::SuperAdmin => "super_admin",
        Role::OrgAdmin => "org_admin",
        Role::Developer => "developer",
    };

    // 7 days from now
    let exp = chrono::Utc::now()
        .checked_add_signed(chrono::Duration::days(7))
        .expect("valid timestamp")
        .timestamp() as usize;

    let claims = JwtClaims {
        sub: github_login.to_string(),
        role: role_str.to_string(),
        org_id: org_id.map(|id| id.to_hex()),
        org_slug: org_slug.map(|s| s.to_string()),
        exp,
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )?;

    Ok(token)
}
