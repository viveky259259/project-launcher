use mongodb::{Client, Collection, Database};

use crate::models;

pub struct Db {
    #[allow(dead_code)]
    pub client: Client,
    pub database: Database,
}

impl Db {
    pub async fn connect(uri: &str, db_name: &str) -> anyhow::Result<Self> {
        let client = Client::with_uri_str(uri).await?;
        let database = client.database(db_name);
        // Ping to verify connection
        database
            .run_command(bson::doc! { "ping": 1 })
            .await?;
        tracing::info!("Connected to MongoDB: {db_name}");
        Ok(Self { client, database })
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
