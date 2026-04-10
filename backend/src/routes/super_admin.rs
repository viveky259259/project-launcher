use std::collections::HashMap;
use std::sync::Arc;

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{delete, get, post},
    Json, Router,
};
use futures::TryStreamExt;
use serde::Deserialize;

use crate::app_state::AppState;
use crate::middleware::require_role::RequireSuperAdmin;
use crate::models::{FeatureFlags, Org, Plan};
use crate::services::license::LicenseService;

type SharedState = Arc<AppState>;

/// Build the super-admin route group.
pub fn super_admin_routes() -> Router<SharedState> {
    Router::new()
        .route("/orgs", get(list_orgs).post(create_org))
        .route("/orgs/:slug", get(get_org).patch(update_org))
        .route("/orgs/:slug/suspend", post(suspend_org))
        .route("/orgs/:slug/unsuspend", post(unsuspend_org))
        .route("/orgs/:slug/members", get(list_org_members))
        .route(
            "/license-keys",
            get(list_license_keys).post(generate_license_key),
        )
        .route("/license-keys/:key", delete(revoke_license_key))
        .route("/metrics", get(get_metrics))
}

// ---------------------------------------------------------------------------
// Org management
// ---------------------------------------------------------------------------

/// GET /super-admin/orgs — List all orgs with member counts.
async fn list_orgs(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
) -> Response {
    let cursor = match state.db.orgs().find(bson::doc! {}).await {
        Ok(c) => c,
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": format!("Failed to list orgs: {e}")})),
            )
                .into_response();
        }
    };

    let orgs: Vec<Org> = match cursor.try_collect().await {
        Ok(v) => v,
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": format!("Failed to collect orgs: {e}")})),
            )
                .into_response();
        }
    };

    // Fetch all member counts in a single aggregation instead of N individual queries.
    let count_pipeline = vec![
        bson::doc! { "$group": { "_id": "$orgId", "count": { "$sum": 1 } } },
    ];
    let member_counts: HashMap<bson::oid::ObjectId, u64> = match state
        .db
        .members()
        .aggregate(count_pipeline)
        .await
    {
        Ok(cursor) => cursor
            .try_collect::<Vec<bson::Document>>()
            .await
            .unwrap_or_default()
            .into_iter()
            .filter_map(|doc| {
                let org_id = doc.get_object_id("_id").ok()?;
                let count = match doc.get("count") {
                    Some(bson::Bson::Int32(n)) => *n as u64,
                    Some(bson::Bson::Int64(n)) => *n as u64,
                    _ => 0,
                };
                Some((org_id, count))
            })
            .collect(),
        Err(_) => HashMap::new(),
    };

    let result: Vec<_> = orgs
        .iter()
        .map(|org| {
            let count = org
                .id
                .as_ref()
                .and_then(|id| member_counts.get(id))
                .copied()
                .unwrap_or(0);
            serde_json::json!({ "org": org, "memberCount": count })
        })
        .collect();

    (StatusCode::OK, Json(serde_json::json!(result))).into_response()
}

/// Request body for POST /super-admin/orgs.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateOrgRequest {
    slug: String,
    name: String,
    plan: Plan,
    seats: u32,
    github_org: String,
    #[serde(default)]
    allowed_teams: Option<Vec<String>>,
}

/// POST /super-admin/orgs — Create a new org.
async fn create_org(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
    Json(body): Json<CreateOrgRequest>,
) -> Response {
    // Check if slug already exists
    let existing = state
        .db
        .orgs()
        .find_one(bson::doc! { "slug": &body.slug })
        .await;

    match existing {
        Ok(Some(_)) => {
            return (
                StatusCode::CONFLICT,
                Json(serde_json::json!({"error": "An org with this slug already exists"})),
            )
                .into_response();
        }
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": format!("Database error: {e}")})),
            )
                .into_response();
        }
        Ok(None) => {} // slug is available
    }

    let org = Org {
        id: None,
        slug: body.slug,
        name: body.name,
        plan: body.plan,
        seats: body.seats,
        github_org: body.github_org,
        allowed_teams: body.allowed_teams.unwrap_or_default(),
        suspended_at: None,
        self_hosted: false,
        feature_flags: FeatureFlags {
            advanced_reporting: false,
            sso: false,
            self_hosted_allowed: false,
        },
        created_at: bson::DateTime::now(),
    };

    match state.db.orgs().insert_one(&org).await {
        Ok(_) => (StatusCode::CREATED, Json(serde_json::json!(org))).into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": format!("Failed to create org: {e}")})),
        )
            .into_response(),
    }
}

/// GET /super-admin/orgs/:slug — Get a single org with its member list.
async fn get_org(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
    Path(slug): Path<String>,
) -> Response {
    let org = match state
        .db
        .orgs()
        .find_one(bson::doc! { "slug": &slug })
        .await
    {
        Ok(Some(o)) => o,
        Ok(None) => {
            return (
                StatusCode::NOT_FOUND,
                Json(serde_json::json!({"error": "Org not found"})),
            )
                .into_response();
        }
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": format!("Database error: {e}")})),
            )
                .into_response();
        }
    };

    // Fetch members for this org
    let members = if let Some(org_id) = &org.id {
        match state
            .db
            .members()
            .find(bson::doc! { "orgId": org_id })
            .await
        {
            Ok(cursor) => cursor.try_collect().await.unwrap_or_default(),
            Err(_) => vec![],
        }
    } else {
        vec![]
    };

    (
        StatusCode::OK,
        Json(serde_json::json!({
            "org": org,
            "members": members,
        })),
    )
        .into_response()
}

/// Request body for PATCH /super-admin/orgs/:slug.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct UpdateOrgRequest {
    plan: Option<Plan>,
    seats: Option<u32>,
    feature_flags: Option<FeatureFlags>,
}

/// PATCH /super-admin/orgs/:slug — Partial update of org fields.
async fn update_org(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
    Path(slug): Path<String>,
    Json(body): Json<UpdateOrgRequest>,
) -> Response {
    let mut set_doc = bson::Document::new();

    if let Some(plan) = &body.plan {
        // Serialize the plan to its BSON representation
        let plan_bson = bson::to_bson(plan).unwrap_or(bson::Bson::Null);
        set_doc.insert("plan", plan_bson);
    }

    if let Some(seats) = body.seats {
        set_doc.insert("seats", seats as i64);
    }

    if let Some(flags) = &body.feature_flags {
        let flags_bson = bson::to_bson(flags).unwrap_or(bson::Bson::Null);
        set_doc.insert("featureFlags", flags_bson);
    }

    if set_doc.is_empty() {
        return (
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({"error": "No fields to update"})),
        )
            .into_response();
    }

    let result = state
        .db
        .orgs()
        .update_one(
            bson::doc! { "slug": &slug },
            bson::doc! { "$set": set_doc },
        )
        .await;

    match result {
        Ok(r) if r.matched_count == 0 => (
            StatusCode::NOT_FOUND,
            Json(serde_json::json!({"error": "Org not found"})),
        )
            .into_response(),
        Ok(_) => (
            StatusCode::OK,
            Json(serde_json::json!({"ok": true})),
        )
            .into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": format!("Failed to update org: {e}")})),
        )
            .into_response(),
    }
}

/// POST /super-admin/orgs/:slug/suspend — Suspend an org.
async fn suspend_org(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
    Path(slug): Path<String>,
) -> Response {
    let now = bson::DateTime::now();
    let result = state
        .db
        .orgs()
        .update_one(
            bson::doc! { "slug": &slug },
            bson::doc! { "$set": { "suspendedAt": now } },
        )
        .await;

    match result {
        Ok(r) if r.matched_count == 0 => (
            StatusCode::NOT_FOUND,
            Json(serde_json::json!({"error": "Org not found"})),
        )
            .into_response(),
        Ok(_) => (
            StatusCode::OK,
            Json(serde_json::json!({"ok": true})),
        )
            .into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": format!("Failed to suspend org: {e}")})),
        )
            .into_response(),
    }
}

/// POST /super-admin/orgs/:slug/unsuspend — Remove suspension from an org.
async fn unsuspend_org(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
    Path(slug): Path<String>,
) -> Response {
    let result = state
        .db
        .orgs()
        .update_one(
            bson::doc! { "slug": &slug },
            bson::doc! { "$set": { "suspendedAt": bson::Bson::Null } },
        )
        .await;

    match result {
        Ok(r) if r.matched_count == 0 => (
            StatusCode::NOT_FOUND,
            Json(serde_json::json!({"error": "Org not found"})),
        )
            .into_response(),
        Ok(_) => (
            StatusCode::OK,
            Json(serde_json::json!({"ok": true})),
        )
            .into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": format!("Failed to unsuspend org: {e}")})),
        )
            .into_response(),
    }
}

/// GET /super-admin/orgs/:slug/members — List members for a specific org.
async fn list_org_members(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
    Path(slug): Path<String>,
) -> Response {
    // Look up the org to get its _id
    let org = match state
        .db
        .orgs()
        .find_one(bson::doc! { "slug": &slug })
        .await
    {
        Ok(Some(o)) => o,
        Ok(None) => {
            return (
                StatusCode::NOT_FOUND,
                Json(serde_json::json!({"error": "Org not found"})),
            )
                .into_response();
        }
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": format!("Database error: {e}")})),
            )
                .into_response();
        }
    };

    let org_id = match org.id {
        Some(id) => id,
        None => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": "Org has no _id"})),
            )
                .into_response();
        }
    };

    let members: Vec<crate::models::Member> = match state
        .db
        .members()
        .find(bson::doc! { "orgId": org_id })
        .await
    {
        Ok(cursor) => cursor.try_collect().await.unwrap_or_default(),
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": format!("Failed to list members: {e}")})),
            )
                .into_response();
        }
    };

    (StatusCode::OK, Json(serde_json::json!(members))).into_response()
}

// ---------------------------------------------------------------------------
// License key management
// ---------------------------------------------------------------------------

/// Request body for POST /super-admin/license-keys.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GenerateLicenseKeyRequest {
    org_slug: String,
    seats: u32,
    plan: Option<Plan>,
    #[serde(default)]
    expires_at: Option<bson::DateTime>,
}

/// POST /super-admin/license-keys — Generate a new license key for an org.
async fn generate_license_key(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
    Json(body): Json<GenerateLicenseKeyRequest>,
) -> Response {
    // Look up the org by slug
    let org = match state
        .db
        .orgs()
        .find_one(bson::doc! { "slug": &body.org_slug })
        .await
    {
        Ok(Some(o)) => o,
        Ok(None) => {
            return (
                StatusCode::NOT_FOUND,
                Json(serde_json::json!({"error": "Org not found"})),
            )
                .into_response();
        }
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": format!("Database error: {e}")})),
            )
                .into_response();
        }
    };

    let org_id = match org.id {
        Some(id) => id,
        None => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": "Org has no _id"})),
            )
                .into_response();
        }
    };

    let plan = body.plan.unwrap_or(org.plan);

    match LicenseService::generate_key(&state.db, org_id, body.seats, plan, body.expires_at).await {
        Ok(license) => (StatusCode::CREATED, Json(serde_json::json!(license))).into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": format!("Failed to generate key: {e}")})),
        )
            .into_response(),
    }
}

/// GET /super-admin/license-keys — List all license keys with org slugs.
async fn list_license_keys(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
) -> Response {
    let keys = match LicenseService::list_all(&state.db).await {
        Ok(k) => k,
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": format!("Failed to list keys: {e}")})),
            )
                .into_response();
        }
    };

    // Join org slug for each key
    let mut result = Vec::with_capacity(keys.len());
    for key in &keys {
        let org_slug = state
            .db
            .orgs()
            .find_one(bson::doc! { "_id": key.org_id })
            .await
            .ok()
            .flatten()
            .map(|o| o.slug);

        result.push(serde_json::json!({
            "key": key,
            "orgSlug": org_slug,
        }));
    }

    (StatusCode::OK, Json(serde_json::json!(result))).into_response()
}

/// DELETE /super-admin/license-keys/:key — Revoke a license key.
async fn revoke_license_key(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
    Path(key): Path<String>,
) -> Response {
    match LicenseService::revoke(&state.db, &key).await {
        Ok(true) => (
            StatusCode::OK,
            Json(serde_json::json!({"ok": true})),
        )
            .into_response(),
        Ok(false) => (
            StatusCode::NOT_FOUND,
            Json(serde_json::json!({"error": "License key not found"})),
        )
            .into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"error": format!("Failed to revoke key: {e}")})),
        )
            .into_response(),
    }
}

// ---------------------------------------------------------------------------
// Metrics
// ---------------------------------------------------------------------------

/// GET /super-admin/metrics — Aggregate dashboard metrics.
async fn get_metrics(
    _admin: RequireSuperAdmin,
    State(state): State<SharedState>,
) -> Response {
    // Total orgs
    let total_orgs = state
        .db
        .orgs()
        .count_documents(bson::doc! {})
        .await
        .unwrap_or(0);

    // Active orgs (not suspended)
    let active_orgs = state
        .db
        .orgs()
        .count_documents(bson::doc! { "suspendedAt": bson::Bson::Null })
        .await
        .unwrap_or(0);

    // Total members
    let total_members = state
        .db
        .members()
        .count_documents(bson::doc! {})
        .await
        .unwrap_or(0);

    // Total repos (sum across all catalogs)
    // Use aggregation pipeline to sum the size of the repos array in each catalog
    let total_repos: u64 = match state
        .db
        .catalogs()
        .aggregate(vec![
            bson::doc! {
                "$group": {
                    "_id": bson::Bson::Null,
                    "totalRepos": { "$sum": { "$size": "$repos" } }
                }
            },
        ])
        .await
    {
        Ok(mut cursor) => {
            if let Ok(Some(doc)) = cursor.try_next().await {
                doc.get_i64("totalRepos").unwrap_or(0).max(0) as u64
            } else {
                0
            }
        }
        Err(_) => 0,
    };

    // Org breakdown by plan using aggregation
    let plan_breakdown: serde_json::Value = match state
        .db
        .orgs()
        .aggregate(vec![bson::doc! {
            "$group": {
                "_id": "$plan",
                "count": { "$sum": 1 }
            }
        }])
        .await
    {
        Ok(cursor) => {
            let docs: Vec<bson::Document> = cursor.try_collect().await.unwrap_or_default();
            let mut breakdown = serde_json::Map::new();
            for doc in docs {
                let plan = doc
                    .get_str("_id")
                    .unwrap_or("unknown");
                let count = doc.get_i32("count").unwrap_or(0);
                breakdown.insert(
                    plan.to_string(),
                    serde_json::Value::Number(serde_json::Number::from(count)),
                );
            }
            serde_json::Value::Object(breakdown)
        }
        Err(_) => serde_json::json!({}),
    };

    (
        StatusCode::OK,
        Json(serde_json::json!({
            "totalOrgs": total_orgs,
            "activeOrgs": active_orgs,
            "totalMembers": total_members,
            "totalRepos": total_repos,
            "planBreakdown": plan_breakdown,
        })),
    )
        .into_response()
}
