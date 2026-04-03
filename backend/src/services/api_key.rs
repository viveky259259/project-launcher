use futures::TryStreamExt;

use crate::db::Db;
use crate::models::{ApiKey, Role};

pub struct ApiKeyService;

impl ApiKeyService {
    /// Generate a new API key for a member.
    pub async fn generate(
        db: &Db,
        org_id: bson::oid::ObjectId,
        member_login: &str,
        role: Role,
    ) -> anyhow::Result<ApiKey> {
        let key = format!("plk_{}", uuid::Uuid::new_v4().to_string().replace('-', ""));
        let api_key = ApiKey {
            id: None,
            key,
            org_id,
            member_login: member_login.to_string(),
            role,
            created_at: bson::DateTime::now(),
            last_used_at: None,
            revoked: false,
        };
        db.api_keys().insert_one(&api_key).await?;
        Ok(api_key)
    }

    /// Validate an API key: find it, check it is not revoked, and update last_used_at.
    pub async fn validate(db: &Db, key: &str) -> anyhow::Result<Option<ApiKey>> {
        let api_key = db
            .api_keys()
            .find_one(bson::doc! { "key": key })
            .await?;

        let api_key = match api_key {
            Some(k) if !k.revoked => k,
            _ => return Ok(None),
        };

        // Update last_used_at
        db.api_keys()
            .update_one(
                bson::doc! { "key": key },
                bson::doc! { "$set": { "lastUsedAt": bson::DateTime::now() } },
            )
            .await?;

        Ok(Some(api_key))
    }

    /// Revoke an API key.
    pub async fn revoke(db: &Db, key: &str) -> anyhow::Result<bool> {
        let result = db
            .api_keys()
            .update_one(
                bson::doc! { "key": key },
                bson::doc! { "$set": { "revoked": true } },
            )
            .await?;
        Ok(result.modified_count > 0)
    }

    /// List all API keys for a member in an org.
    pub async fn list_by_member(
        db: &Db,
        org_id: bson::oid::ObjectId,
        login: &str,
    ) -> anyhow::Result<Vec<ApiKey>> {
        let cursor = db
            .api_keys()
            .find(bson::doc! { "orgId": org_id, "memberLogin": login })
            .await?;
        let keys: Vec<ApiKey> = cursor.try_collect().await?;
        Ok(keys)
    }
}
