use serde::{Deserialize, Serialize};

use super::Role;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApiKey {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<bson::oid::ObjectId>,
    pub key: String,
    pub org_id: bson::oid::ObjectId,
    pub member_login: String,
    pub role: Role,
    pub created_at: bson::DateTime,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_used_at: Option<bson::DateTime>,
    pub revoked: bool,
}
