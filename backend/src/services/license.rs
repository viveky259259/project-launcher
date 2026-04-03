use futures::TryStreamExt;
use serde::{Deserialize, Serialize};

use crate::db::Db;
use crate::models::{LicenseKey, Plan};

pub struct LicenseService;

impl LicenseService {
    /// Generate a new license key for an org.
    pub async fn generate_key(
        db: &Db,
        org_id: bson::oid::ObjectId,
        seats: u32,
        plan: Plan,
        expires_at: Option<bson::DateTime>,
    ) -> anyhow::Result<LicenseKey> {
        let key = format!(
            "plk_live_{}",
            uuid::Uuid::new_v4().to_string().replace('-', "")
        );
        let license = LicenseKey {
            id: None,
            key,
            org_id,
            seats,
            plan,
            created_at: bson::DateTime::now(),
            expires_at,
            last_validated_at: None,
            revoked: false,
        };
        db.license_keys().insert_one(&license).await?;
        Ok(license)
    }

    /// Validate a license key (called by self-hosted instances).
    pub async fn validate(
        db: &Db,
        key: &str,
        seat_count: u32,
    ) -> anyhow::Result<LicenseValidation> {
        let license = db
            .license_keys()
            .find_one(bson::doc! { "key": key })
            .await?
            .ok_or_else(|| anyhow::anyhow!("License key not found"))?;

        if license.revoked {
            return Ok(LicenseValidation::invalid("License key has been revoked"));
        }

        if let Some(expires) = license.expires_at {
            if expires < bson::DateTime::now() {
                return Ok(LicenseValidation::invalid("License key has expired"));
            }
        }

        if seat_count > license.seats {
            return Ok(LicenseValidation::invalid(&format!(
                "Seat count {} exceeds licensed seats {}",
                seat_count, license.seats
            )));
        }

        // Update last_validated_at
        db.license_keys()
            .update_one(
                bson::doc! { "key": key },
                bson::doc! { "$set": { "lastValidatedAt": bson::DateTime::now() } },
            )
            .await?;

        Ok(LicenseValidation::valid(
            license.plan,
            license.seats,
            license.expires_at,
        ))
    }

    /// Revoke a license key.
    pub async fn revoke(db: &Db, key: &str) -> anyhow::Result<bool> {
        let result = db
            .license_keys()
            .update_one(
                bson::doc! { "key": key },
                bson::doc! { "$set": { "revoked": true } },
            )
            .await?;
        Ok(result.modified_count > 0)
    }

    /// List all license keys (for super admin).
    pub async fn list_all(db: &Db) -> anyhow::Result<Vec<LicenseKey>> {
        let cursor = db.license_keys().find(bson::doc! {}).await?;
        let keys: Vec<LicenseKey> = cursor.try_collect().await?;
        Ok(keys)
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LicenseValidation {
    pub valid: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub plan: Option<Plan>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub seats: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub expires_at: Option<bson::DateTime>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
}

impl LicenseValidation {
    fn valid(plan: Plan, seats: u32, expires_at: Option<bson::DateTime>) -> Self {
        Self {
            valid: true,
            plan: Some(plan),
            seats: Some(seats),
            expires_at,
            reason: None,
        }
    }

    fn invalid(reason: &str) -> Self {
        Self {
            valid: false,
            plan: None,
            seats: None,
            expires_at: None,
            reason: Some(reason.to_string()),
        }
    }
}
