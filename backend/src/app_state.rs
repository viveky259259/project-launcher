use crate::db::Db;

#[derive(Debug, Clone, PartialEq)]
pub enum ServerMode {
    Cloud,
    SelfHosted,
}

impl ServerMode {
    pub fn from_env(val: &str) -> Self {
        match val.to_lowercase().as_str() {
            "selfhosted" | "self-hosted" | "self_hosted" => Self::SelfHosted,
            _ => Self::Cloud,
        }
    }
}

#[allow(dead_code)]
pub struct AppState {
    pub db: Db,
    pub jwt_secret: String,
    pub github_client_id: String,
    pub github_client_secret: String,
    pub mode: ServerMode,
    /// Shared HTTP client — reuses the connection pool across all requests.
    pub http_client: reqwest::Client,
    /// Short-lived nonce store for OAuth CSRF protection.
    /// Maps nonce → context ("super-admin" or org slug).
    /// Entries are inserted at OAuth initiation and removed (consumed) at callback.
    pub oauth_states: dashmap::DashMap<String, String>,
    /// Revoked JWT IDs. Tokens whose `jti` appears here are rejected immediately,
    /// regardless of their expiry. Populated by POST /auth/logout.
    /// Note: in-memory only — clears on restart. For multi-instance deployments,
    /// back this with Redis.
    pub revoked_jwts: dashmap::DashMap<String, ()>,
}
