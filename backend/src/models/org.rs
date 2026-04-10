use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Org {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<bson::oid::ObjectId>,
    pub slug: String,
    pub name: String,
    pub plan: Plan,
    pub seats: u32,
    pub github_org: String,
    pub allowed_teams: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub suspended_at: Option<bson::DateTime>,
    pub self_hosted: bool,
    pub feature_flags: FeatureFlags,
    pub created_at: bson::DateTime,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Plan {
    Starter,
    Pro,
    Enterprise,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FeatureFlags {
    pub advanced_reporting: bool,
    pub sso: bool,
    pub self_hosted_allowed: bool,
}
