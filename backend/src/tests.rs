//! Integration tests for the plauncher-backend HTTP API.
//!
//! These tests spin up a real `Router` (via `build_app`) with a MongoDB
//! connection and drive requests through `tower::ServiceExt::oneshot`.
//!
//! **Prerequisite:** MongoDB must be reachable at the URI given by
//! `TEST_MONGODB_URI` (defaults to `mongodb://localhost:27017`).
//! Tests that require DB connectivity will fail if Mongo is not running — this
//! is acceptable; run `docker compose up mongo` first.

#[cfg(test)]
mod integration {
    use std::sync::Arc;

    use axum::{
        body::Body,
        http::{Request, StatusCode},
    };
    use tower::ServiceExt; // for `oneshot`

    use crate::app_state::{AppState, ServerMode};
    use crate::db::Db;
    use crate::middleware::auth::create_jwt;
    use crate::models::Role;
    use crate::SharedState;

    // ── helpers ──────────────────────────────────────────────────────────────

    /// Build an `AppState` backed by a test MongoDB database.
    ///
    /// Uses a unique database name per test invocation so parallel tests don't
    /// interfere.  The database is **not** cleaned up automatically; for CI you
    /// can drop all databases matching `plauncher_test_*` after the test run.
    async fn make_test_state(db_suffix: &str) -> SharedState {
        let mongo_uri = std::env::var("TEST_MONGODB_URI")
            .unwrap_or_else(|_| "mongodb://localhost:27017".to_string());
        let db_name = format!("plauncher_test_{db_suffix}");

        let db = Db::connect(&mongo_uri, &db_name)
            .await
            .expect("connect to test MongoDB");

        Arc::new(AppState {
            db,
            jwt_secret: "test-secret".to_string(),
            github_client_id: String::new(),
            github_client_secret: String::new(),
            mode: ServerMode::Cloud,
            http_client: reqwest::Client::new(),
            oauth_states: dashmap::DashMap::new(),
            revoked_jwts: dashmap::DashMap::new(),
        })
    }

    // ── Test 1: Health check ─────────────────────────────────────────────────

    /// GET /health should return 200 with `{"status":"ok", ...}`.
    #[tokio::test]
    async fn health_check_returns_200() {
        let state = make_test_state("health").await;
        let app = crate::build_app(state);

        let req = Request::builder()
            .method("GET")
            .uri("/health")
            .body(Body::empty())
            .unwrap();

        let resp = app.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::OK);

        let body_bytes = axum::body::to_bytes(resp.into_body(), 1024)
            .await
            .unwrap();
        let body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();
        assert_eq!(body["status"], "ok");
    }

    // ── Test 2: Auth required ────────────────────────────────────────────────

    /// GET /super-admin/orgs without an Authorization header should return 401.
    #[tokio::test]
    async fn no_auth_header_returns_401() {
        let state = make_test_state("no_auth").await;
        let app = crate::build_app(state);

        let req = Request::builder()
            .method("GET")
            .uri("/super-admin/orgs")
            .body(Body::empty())
            .unwrap();

        let resp = app.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    }

    // ── Test 3: Invalid API key ──────────────────────────────────────────────

    /// GET /super-admin/orgs with a well-formed but non-existent API key should
    /// return 401 (not a 500 DB error).
    #[tokio::test]
    async fn invalid_api_key_returns_401() {
        let state = make_test_state("invalid_key").await;
        let app = crate::build_app(state);

        let req = Request::builder()
            .method("GET")
            .uri("/super-admin/orgs")
            .header("Authorization", "Bearer plk_invalid_key_that_does_not_exist")
            .body(Body::empty())
            .unwrap();

        let resp = app.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);

        let body_bytes = axum::body::to_bytes(resp.into_body(), 1024)
            .await
            .unwrap();
        let body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();
        // Must surface an auth error, not an internal server error
        assert!(body.get("error").is_some(), "expected 'error' field in body");
    }

    // ── Test 4: License key prefix not treated as API key ───────────────────

    /// A token starting with `lic_` should not be forwarded to the API-key
    /// lookup path.  It is not a JWT either, so the middleware rejects it with
    /// 401 and a message that does NOT say "DB error".
    #[tokio::test]
    async fn lic_prefix_not_treated_as_api_key() {
        let state = make_test_state("lic_prefix").await;
        let app = crate::build_app(state);

        let req = Request::builder()
            .method("GET")
            .uri("/super-admin/orgs")
            .header("Authorization", "Bearer lic_some_license_key_value")
            .body(Body::empty())
            .unwrap();

        let resp = app.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);

        let body_bytes = axum::body::to_bytes(resp.into_body(), 1024)
            .await
            .unwrap();
        let body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();
        let error_msg = body["error"].as_str().unwrap_or("");
        // The JWT path will reject this because it's not a valid JWT — that is
        // the correct behavior.  We just confirm it is NOT an "Internal server
        // error" (which would indicate the key was sent to the DB lookup).
        assert_ne!(error_msg, "Internal server error",
            "lic_ token must not reach the API-key DB lookup");
    }

    // ── Test 5: JWT revocation via POST /auth/logout ─────────────────────────

    /// Create a JWT, log out with it, then verify the same token is rejected.
    #[tokio::test]
    async fn jwt_revocation_via_logout() {
        let state = make_test_state("jwt_revoke").await;

        // Mint a JWT directly (bypasses GitHub OAuth)
        let token = create_jwt(
            "test-secret",
            "testuser",
            &Role::SuperAdmin,
            None,
            None,
        )
        .expect("create test JWT");

        // --- Step 1: call POST /auth/logout with the JWT ---
        {
            let app = crate::build_app(Arc::clone(&state));
            let req = Request::builder()
                .method("POST")
                .uri("/auth/logout")
                .header("Authorization", format!("Bearer {token}"))
                .header("Content-Length", "0")
                .body(Body::empty())
                .unwrap();

            let resp = app.oneshot(req).await.unwrap();
            assert_eq!(resp.status(), StatusCode::OK,
                "logout should succeed");
        }

        // --- Step 2: the same JWT must now be rejected ---
        {
            let app = crate::build_app(Arc::clone(&state));
            let req = Request::builder()
                .method("GET")
                .uri("/super-admin/orgs")
                .header("Authorization", format!("Bearer {token}"))
                .body(Body::empty())
                .unwrap();

            let resp = app.oneshot(req).await.unwrap();
            assert_eq!(resp.status(), StatusCode::UNAUTHORIZED,
                "revoked JWT must be rejected with 401");

            let body_bytes = axum::body::to_bytes(resp.into_body(), 1024)
                .await
                .unwrap();
            let body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();
            let error_msg = body["error"].as_str().unwrap_or("");
            assert!(
                error_msg.contains("revoked"),
                "error message should mention revocation, got: {error_msg}"
            );
        }
    }
}
