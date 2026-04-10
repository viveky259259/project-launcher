use mongodb::{Client, Collection, Database};
use mongodb::options::ClientOptions;

use crate::models;

pub struct Db {
    #[allow(dead_code)]
    pub client: Client,
    pub database: Database,
}

/// Maximum number of connection attempts before giving up.
const MAX_RETRIES: u32 = 3;
/// Delay between retries (doubles each attempt).
const INITIAL_RETRY_DELAY: std::time::Duration = std::time::Duration::from_secs(2);

impl Db {
    pub async fn connect(uri: &str, db_name: &str) -> anyhow::Result<Self> {
        let mut opts = ClientOptions::parse(uri).await?;

        // Sensible timeouts for cloud MongoDB (Atlas) — prevents hangs on
        // unreachable hosts and surfaces errors quickly during startup.
        opts.connect_timeout = Some(std::time::Duration::from_secs(10));
        opts.server_selection_timeout = Some(std::time::Duration::from_secs(15));

        let client = Client::with_options(opts)?;
        let database = client.database(db_name);

        // Retry the initial ping with exponential backoff so transient network
        // blips during cold-start don't immediately crash the server.
        let mut last_err = None;
        let mut delay = INITIAL_RETRY_DELAY;
        for attempt in 1..=MAX_RETRIES {
            match database.run_command(bson::doc! { "ping": 1 }).await {
                Ok(_) => {
                    tracing::info!("Connected to MongoDB: {db_name}");
                    return Ok(Self { client, database });
                }
                Err(e) => {
                    tracing::warn!(
                        "MongoDB ping attempt {attempt}/{MAX_RETRIES} failed: {e}"
                    );
                    last_err = Some(e);
                    if attempt < MAX_RETRIES {
                        tokio::time::sleep(delay).await;
                        delay *= 2;
                    }
                }
            }
        }

        Err(anyhow::anyhow!(
            "Failed to connect to MongoDB after {MAX_RETRIES} attempts: {}",
            last_err.map(|e| e.to_string()).unwrap_or_default()
        ))
    }

    pub fn orgs(&self) -> Collection<models::Org> {
        self.database.collection("orgs")
    }

    pub fn catalogs(&self) -> Collection<models::CatalogDoc> {
        self.database.collection("catalogs")
    }

    pub fn members(&self) -> Collection<models::Member> {
        self.database.collection("members")
    }

    pub fn onboarding_sessions(&self) -> Collection<models::OnboardingSession> {
        self.database.collection("onboarding_sessions")
    }

    pub fn license_keys(&self) -> Collection<models::LicenseKey> {
        self.database.collection("license_keys")
    }

    pub fn super_admins(&self) -> Collection<models::SuperAdmin> {
        self.database.collection("super_admins")
    }

    pub fn api_keys(&self) -> Collection<models::ApiKey> {
        self.database.collection("api_keys")
    }
}
