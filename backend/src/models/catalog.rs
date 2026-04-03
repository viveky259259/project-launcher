use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CatalogDoc {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<bson::oid::ObjectId>,
    pub org_id: bson::oid::ObjectId,
    pub version: String,
    pub repos: Vec<CatalogRepo>,
    pub env_templates: Vec<EnvTemplate>,
    pub published_at: bson::DateTime,
    pub published_by: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub git_sha: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CatalogRepo {
    pub name: String,
    pub url: String,
    pub required: bool,
    pub tags: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub env_template: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EnvTemplate {
    pub name: String,
    pub vars: HashMap<String, EnvVar>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum EnvVar {
    Default { value: String },
    Ask,
    Vault { path: String },
}
