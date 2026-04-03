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
}
