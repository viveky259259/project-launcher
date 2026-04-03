use serde::{Deserialize, Serialize};

use super::Role;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApiKey {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<bson::oid::ObjectId>,
    /// SHA-256 hex digest of the plaintext key. Never contains the raw key.
    pub key_hash: String,
    /// First 12 characters of the plaintext key for safe display (e.g. "plk_a1b2c3d4").
    pub key_prefix: String,
    pub org_id: bson::oid::ObjectId,
    pub member_login: String,
    pub role: Role,
    pub created_at: bson::DateTime,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_used_at: Option<bson::DateTime>,
    pub revoked: bool,
}
