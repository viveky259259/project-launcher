// ---------------------------------------------------------------------------
// plauncher auth — token persistence for API key / JWT auth
// ---------------------------------------------------------------------------

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

#[derive(Debug, Serialize, Deserialize)]
pub struct SavedAuth {
    pub server_url: String,
    pub token: String,
    pub org: String,
}

fn auth_file() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home)
        .join(".project_launcher")
        .join("auth.json")
}

pub fn save_token(server_url: &str, token: &str, org: &str) -> anyhow::Result<()> {
    let auth = SavedAuth {
        server_url: server_url.to_string(),
        token: token.to_string(),
        org: org.to_string(),
    };
    let path = auth_file();
    let dir = path.parent().unwrap().to_path_buf();
    std::fs::create_dir_all(&dir)?;
    std::fs::write(&path, serde_json::to_string_pretty(&auth)?)?;
    // Restrict to owner read/write — prevents other users on the machine
    // from reading the stored token.
    #[cfg(unix)]
    {
        let mut perms = std::fs::metadata(&path)?.permissions();
        perms.set_mode(0o600);
        std::fs::set_permissions(&path, perms)?;
    }
    Ok(())
}

pub fn load_auth() -> Option<SavedAuth> {
    let data = std::fs::read_to_string(auth_file()).ok()?;
    serde_json::from_str(&data).ok()
}

pub fn load_token_for_server(server_url: &str) -> Option<(String, String)> {
    let auth = load_auth()?;
    if auth.server_url == server_url {
        Some((auth.token, auth.org))
    } else {
        None
    }
}
