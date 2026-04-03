use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OnboardingSession {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<bson::oid::ObjectId>,
    pub org_id: bson::oid::ObjectId,
    pub github_login: String,
    pub steps: Vec<OnboardingStep>,
    pub started_at: bson::DateTime,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completed_at: Option<bson::DateTime>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OnboardingStep {
    pub id: String,
    pub label: String,
    pub status: StepStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub repo_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum StepStatus {
    Pending,
    InProgress,
    Done,
    Failed,
}
