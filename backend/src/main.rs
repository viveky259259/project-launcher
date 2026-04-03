mod app_state;
mod db;
mod middleware;
mod models;
mod routes;
mod services;

use std::sync::Arc;

use axum::{extract::State, routing::{get, post}, Json, Router};
use mongodb::IndexModel;
use tower_governor::{governor::GovernorConfigBuilder, GovernorLayer};
use tower_http::cors::CorsLayer;
use tracing_subscriber::EnvFilter;

use app_state::{AppState, ServerMode};
use db::Db;

type SharedState = Arc<AppState>;

async fn health_check(State(state): State<SharedState>) -> Json<serde_json::Value> {
    let oauth = routes::auth::is_oauth_configured(&state);
    Json(serde_json::json!({ "status": "ok", "oauth": oauth }))
}

/// Create required MongoDB indexes on startup.
async fn create_indexes(db: &Db) -> anyhow::Result<()> {
    // orgs: unique index on slug
    db.orgs()
        .create_index(
            IndexModel::builder()
                .keys(bson::doc! { "slug": 1 })
                .options(
                    mongodb::options::IndexOptions::builder()
                        .unique(true)
                        .build(),
                )
                .build(),
        )
        .await?;

    // members: compound unique index on (org_id, github_login)
    db.members()
        .create_index(
            IndexModel::builder()
                .keys(bson::doc! { "orgId": 1, "githubLogin": 1 })
                .options(
                    mongodb::options::IndexOptions::builder()
                        .unique(true)
                        .build(),
                )
                .build(),
        )
        .await?;

    // license_keys: unique index on key
    db.license_keys()
        .create_index(
            IndexModel::builder()
                .keys(bson::doc! { "key": 1 })
                .options(
                    mongodb::options::IndexOptions::builder()
                        .unique(true)
                        .build(),
                )
                .build(),
        )
        .await?;

    // api_keys: unique index on key
    db.api_keys()
        .create_index(
            IndexModel::builder()
                .keys(bson::doc! { "key": 1 })
                .options(
                    mongodb::options::IndexOptions::builder()
                        .unique(true)
                        .build(),
                )
                .build(),
        )
        .await?;

    // onboarding_sessions: compound index on (org_id, github_login)
    db.onboarding_sessions()
        .create_index(
            IndexModel::builder()
                .keys(bson::doc! { "orgId": 1, "githubLogin": 1 })
                .build(),
        )
        .await?;

    tracing::info!("MongoDB indexes created");
    Ok(())
}

/// Bootstrap a super admin via API key if PLAUNCHER_BOOTSTRAP_KEY is set
/// and no super admins exist yet.
async fn bootstrap_super_admin(db: &Db) {
    let bootstrap_key = match std::env::var("PLAUNCHER_BOOTSTRAP_KEY") {
        Ok(k) if !k.is_empty() => k,
        _ => return,
    };

    // Check if any super admins exist
    let count = match db
        .super_admins()
        .count_documents(bson::doc! {})
        .await
    {
        Ok(c) => c,
        Err(e) => {
            tracing::error!("Failed to count super_admins: {e}");
            return;
        }
    };

    if count > 0 {
        tracing::info!("Super admin(s) already exist — skipping bootstrap");
        return;
    }

    // Check if this bootstrap key already exists in api_keys
    let existing = db
        .api_keys()
        .find_one(bson::doc! { "key": &bootstrap_key })
        .await;

    match existing {
        Ok(Some(_)) => {
            tracing::info!("Bootstrap API key already exists in database");
            return;
        }
        Err(e) => {
            tracing::error!("Failed to check bootstrap key: {e}");
            return;
        }
        Ok(None) => {}
    }

    // Create a bootstrap super admin entry
    let bootstrap_login = "bootstrap-admin";
    let super_admin = models::SuperAdmin {
        id: None,
        github_login: bootstrap_login.to_string(),
        created_at: bson::DateTime::now(),
    };

    if let Err(e) = db.super_admins().insert_one(&super_admin).await {
        tracing::error!("Failed to create bootstrap super admin: {e}");
        return;
    }

    // We need an org_id for the API key. Use a sentinel ObjectId for bootstrap keys.
    // The bootstrap key is special — it has SuperAdmin role so it bypasses org checks.
    let sentinel_org_id = bson::oid::ObjectId::from_bytes([0u8; 12]);

    let api_key = models::ApiKey {
        id: None,
        key: bootstrap_key,
        org_id: sentinel_org_id,
        member_login: bootstrap_login.to_string(),
        role: models::Role::SuperAdmin,
        created_at: bson::DateTime::now(),
        last_used_at: None,
        revoked: false,
    };

    if let Err(e) = db.api_keys().insert_one(&api_key).await {
        tracing::error!("Failed to insert bootstrap API key: {e}");
        return;
    }

    tracing::info!(
        "Bootstrap super admin key active — use it to create your admin account, then revoke it"
    );
}

/// In self-hosted mode, validate the license key at startup.
/// Allows a 7-day grace period if the validation server is unreachable.
async fn validate_self_hosted_license() {
    let license_key = match std::env::var("PLAUNCHER_LICENSE_KEY") {
        Ok(k) if !k.is_empty() => k,
        _ => {
            tracing::warn!(
                "PLAUNCHER_LICENSE_KEY not set — running in self-hosted mode without a license key"
            );
            return;
        }
    };

    let validation_url = std::env::var("PLAUNCHER_LICENSE_URL")
        .unwrap_or_else(|_| "https://api.plauncher.dev/api/license/validate".to_string());

    tracing::info!("Validating license key against {validation_url}");

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .expect("failed to build reqwest client");

    let result = client
        .post(&validation_url)
        .json(&serde_json::json!({
            "key": license_key,
            "seatCount": 1,
            "instanceId": hostname(),
        }))
        .send()
        .await;

    match result {
        Ok(resp) if resp.status().is_success() => {
            match resp.json::<serde_json::Value>().await {
                Ok(body) => {
                    if body.get("valid").and_then(|v| v.as_bool()) == Some(true) {
                        let plan = body.get("plan").and_then(|v| v.as_str()).unwrap_or("unknown");
                        let seats = body.get("seats").and_then(|v| v.as_u64()).unwrap_or(0);
                        tracing::info!(
                            "License validated: plan={plan}, seats={seats}"
                        );
                    } else {
                        let reason = body
                            .get("reason")
                            .and_then(|v| v.as_str())
                            .unwrap_or("unknown");
                        tracing::warn!("License validation failed: {reason}");
                        tracing::warn!(
                            "Entering 7-day grace period — please resolve the license issue"
                        );
                    }
                }
                Err(e) => {
                    tracing::warn!("Failed to parse license validation response: {e}");
                    tracing::warn!(
                        "Entering 7-day grace period — please resolve the license issue"
                    );
                }
            }
        }
        Ok(resp) => {
            tracing::warn!(
                "License validation returned HTTP {}: entering 7-day grace period",
                resp.status()
            );
        }
        Err(e) => {
            tracing::warn!("License validation server unreachable: {e}");
            tracing::warn!("Entering 7-day grace period — please resolve connectivity");
        }
    }
}

/// Best-effort hostname for instance identification.
fn hostname() -> String {
    std::env::var("HOSTNAME")
        .or_else(|_| std::env::var("COMPUTERNAME"))
        .unwrap_or_else(|_| "unknown".to_string())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .init();

    // Read environment variables
    let mongodb_uri =
        std::env::var("MONGODB_URI").unwrap_or_else(|_| "mongodb://localhost:27017".to_string());
    let db_name =
        std::env::var("PLAUNCHER_DB_NAME").unwrap_or_else(|_| "plauncher".to_string());
    let jwt_secret = std::env::var("PLAUNCHER_JWT_SECRET")
        .unwrap_or_else(|_| "dev-secret-change-me".to_string());
    let github_client_id =
        std::env::var("GITHUB_CLIENT_ID").unwrap_or_default();
    let github_client_secret =
        std::env::var("GITHUB_CLIENT_SECRET").unwrap_or_default();
    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8743);
    let mode = ServerMode::from_env(
        &std::env::var("PLAUNCHER_MODE").unwrap_or_else(|_| "cloud".to_string()),
    );

    tracing::info!("Server mode: {:?}", mode);

    // Connect to MongoDB
    let db = Db::connect(&mongodb_uri, &db_name).await?;

    // Create indexes
    create_indexes(&db).await?;

    // Bootstrap super admin via API key if configured
    bootstrap_super_admin(&db).await;

    // Self-hosted mode: validate license key at startup
    if mode == ServerMode::SelfHosted {
        validate_self_hosted_license().await;
    }

    // Build shared application state
    let state: SharedState = Arc::new(AppState {
        db,
        jwt_secret,
        github_client_id,
        github_client_secret,
        mode,
        http_client: reqwest::Client::new(),
        oauth_states: dashmap::DashMap::new(),
        revoked_jwts: dashmap::DashMap::new(),
    });

    // Build router
    // Rate-limit auth endpoints: 5 requests/second sustained, burst of 10 per IP.
    // Protects the OAuth callback and token exchange from abuse.
    let auth_governor = Arc::new(
        GovernorConfigBuilder::default()
            .per_second(5)
            .burst_size(10)
            .finish()
            .unwrap(),
    );

    let app = Router::new()
        // Health check
        .route("/health", get(health_check))
        // Auth routes (GitHub OAuth) — rate-limited per IP
        .nest(
            "/auth",
            routes::auth::auth_routes().layer(GovernorLayer {
                config: Arc::clone(&auth_governor),
            }),
        )
        // License validation (called by self-hosted instances)
        .route("/api/license/validate", post(routes::license::validate_license))
        // Super admin routes
        .nest("/super-admin", routes::super_admin::super_admin_routes())
        // Org admin routes (full paths — nest() doesn't support path params)
        .merge(routes::org_admin::org_admin_routes())
        // Catalog routes
        .merge(routes::catalog::catalog_routes())
        // Onboarding routes
        .merge(routes::onboarding::onboarding_routes())
        .layer(CorsLayer::permissive())
        .with_state(state);

    // Start server
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}")).await?;
    tracing::info!("plauncher-backend listening on port {port}");
    axum::serve(listener, app).await?;

    Ok(())
}
