use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LicenseKey {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<bson::oid::ObjectId>,
    pub key: String,
    pub org_id: bson::oid::ObjectId,
    pub seats: u32,
    pub plan: super::org::Plan,
    pub created_at: bson::DateTime,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub expires_at: Option<bson::DateTime>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_validated_at: Option<bson::DateTime>,
    pub revoked: bool,
}
