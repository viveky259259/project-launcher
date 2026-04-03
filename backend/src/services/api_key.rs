use futures::TryStreamExt;
use sha2::{Digest, Sha256};

use crate::db::Db;
use crate::models::{ApiKey, Role};

pub struct ApiKeyService;

/// Return value from `generate` — carries the one-time plaintext alongside the stored record.
/// The `plaintext` field must be returned to the caller immediately; it is never persisted.
pub struct GeneratedApiKey {
    /// The raw `plk_…` key to hand back to the user once. Never store this.
    pub plaintext: String,
    /// The record as written to the database (contains hash + prefix, not the plaintext).
    pub record: ApiKey,
}

/// Compute SHA-256 hex digest of a key string.
fn hash_key(key: &str) -> String {
    let digest = Sha256::digest(key.as_bytes());
    format!("{digest:x}")
}

impl ApiKeyService {
    /// Generate a new API key for a member.
    /// Returns a `GeneratedApiKey` whose `plaintext` must be sent to the user
    /// exactly once — it is not stored and cannot be recovered afterwards.
    pub async fn generate(
        db: &Db,
        org_id: bson::oid::ObjectId,
        member_login: &str,
        role: Role,
    ) -> anyhow::Result<GeneratedApiKey> {
        let plaintext = format!("plk_{}", uuid::Uuid::new_v4().to_string().replace('-', ""));
        let key_hash = hash_key(&plaintext);
        // Keep first 12 chars (e.g. "plk_a1b2c3d4") for safe display
        let key_prefix = plaintext.chars().take(12).collect::<String>();

        let record = ApiKey {
            id: None,
            key_hash,
            key_prefix,
            org_id,
            member_login: member_login.to_string(),
            role,
            created_at: bson::DateTime::now(),
            last_used_at: None,
            revoked: false,
        };
        db.api_keys().insert_one(&record).await?;
        Ok(GeneratedApiKey { plaintext, record })
    }

    /// Validate an API key: hash the plaintext, look up by hash, check not revoked,
    /// and update `last_used_at`.
    pub async fn validate(db: &Db, key: &str) -> anyhow::Result<Option<ApiKey>> {
        let key_hash = hash_key(key);
        let api_key = db
            .api_keys()
            .find_one(bson::doc! { "keyHash": &key_hash })
            .await?;

        let api_key = match api_key {
            Some(k) if !k.revoked => k,
            _ => return Ok(None),
        };

        db.api_keys()
            .update_one(
                bson::doc! { "keyHash": &key_hash },
                bson::doc! { "$set": { "lastUsedAt": bson::DateTime::now() } },
            )
            .await?;

        Ok(Some(api_key))
    }

    /// Revoke an API key by its plaintext value.
    pub async fn revoke(db: &Db, key: &str) -> anyhow::Result<bool> {
        let key_hash = hash_key(key);
        let result = db
            .api_keys()
            .update_one(
                bson::doc! { "keyHash": &key_hash },
                bson::doc! { "$set": { "revoked": true } },
            )
            .await?;
        Ok(result.modified_count > 0)
    }

    /// List all API keys for a member in an org (returns stored records — no plaintext).
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
