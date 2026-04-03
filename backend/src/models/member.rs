use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Member {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<bson::oid::ObjectId>,
    pub org_id: bson::oid::ObjectId,
    pub github_login: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub github_avatar: Option<String>,
    pub role: Role,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub invited_by: Option<String>,
    pub joined_at: bson::DateTime,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_seen_at: Option<bson::DateTime>,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    Developer,
    OrgAdmin,
    SuperAdmin,
}
