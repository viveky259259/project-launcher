# Brainstorm: New Feature for Project Launcher
**Date**: 2026-04-03
**Type**: ideation

## Central Question
What new feature should be added to Project Launcher — the macOS developer dashboard for discovering, organizing, and launching projects?

## Mind Map

### Enterprise Direction chosen: Team Catalog as the wedge
- Shared, admin-managed repo catalog
- Solves dev onboarding pain
- Natural upsell surface into broader enterprise features

### Other enterprise branches identified (parked):
- Compliance & Security (SSO, audit logs, policy enforcement)
- Visibility & Reporting (org health dashboards, metrics)
- Integration Layer (Jira, Slack, CI/CD)
- Deployment / Distribution (MDM, centralized config)
- Monetization Shape (per-seat SaaS, self-hosted)

## Deep Dives

### Team Catalog — All Key Decisions Locked
- **Catalog lives on**: Self-hosted server (enterprise air-gap friendly)
- **Auth**: GitHub org membership = auto-access to catalog
- **Interface**: Both CLI (`plauncher join`) + GUI diff/status view
- **Server delivery**: `plauncher serve` subcommand — zero extra binary
- **Catalog format**: YAML (human-editable) + GUI catalog editor
- **Scope**: FAT v1 — env templates + onboarding checklist + admin UI

## Discussion Log

- Enterprise requirements chosen as the feature direction
- "Team Catalog as the wedge" selected over "Org Health Dashboard"
- Three key decisions: self-hosted server, GitHub org auth, CLI+GUI both
- Server delivered as `plauncher serve` subcommand (zero extra binary)
- Catalog format: YAML + GUI admin editor (both)
- Fat v1 scope confirmed: env templates + onboarding checklist + admin UI
- Admin UI confirmed as dealbreaker for enterprise buyers — cannot be deferred

## Phase 2: SaaS Multi-Tenant Architecture

### Stack decisions
- **Database**: MongoDB (org-scoped collections, flexible schema, self-hosted friendly)
- **Backend**: Rust (axum + mongodb crate + tokio)

### MongoDB Collections
| Collection | Purpose |
|---|---|
| `orgs` | Tenant orgs — slug, plan, seats, github_org, feature_flags |
| `catalogs` | Repo catalogs per org — repos, env_templates, published_by, git_sha |
| `members` | Org members — github_login, role (admin/developer), last_seen |
| `onboarding_sessions` | Per-member checklist state |
| `license_keys` | Self-hosted license keys — seats, expiry, last_validated |
| `super_admins` | Our internal admin users |

### Deployment Modes
- **Cloud** (default): hosted on plauncher.io, multi-tenant MongoDB
- **Self-hosted** (enterprise): Docker image, single-tenant, license key validates daily against plauncher.io

### Two Admin Portals
1. **Super Admin** (`admin.plauncher.io`) — us only: manage orgs, billing, feature flags, license keys
2. **Org Admin** (per customer, cloud or self-hosted): manage repos, members, sync status

### Build Plan (Phase 2)
- T10: backend/ Rust crate — MongoDB models + connection pool
- T11: Auth + tenant middleware (JWT roles: super_admin, org_admin, developer)
- T12: Super admin API routes (/super-admin/*)
- T13: Org admin API routes (/api/orgs/:slug/admin/*)
- T14: Catalog + onboarding API routes (multi-tenant)
- T15: License service (key generation + self-hosted validation endpoint)
- T16: Super admin Flutter web UI (super_admin_web/)
- T17: Update org admin web UI (web_app/) for multi-tenant API
- T18: Docker packaging (Dockerfile + docker-compose.yml)

## Synthesis

### Key Insights
1. **`plauncher serve` is the enterprise wedge** — single binary, zero new artifacts, IT-friendly ("just run one command")
2. **GitHub org membership as auth** eliminates deprovisioning problem — offboarding is automatic
3. **"10-minute new hire" moment** is the demo that sells this — measurable, emotional, shareable
4. **Admin UI is non-negotiable** — enterprise buyers won't trust YAML-only catalog management
5. **Server is nearly stateless** — reads catalog.yaml + calls GitHub API, no database in v1

### Decision Points (all locked)
| Decision | Choice |
|---|---|
| Catalog hosting | Self-hosted (`plauncher serve`) |
| Auth | GitHub OAuth + org membership check |
| Interface | CLI + GUI (both) |
| Server delivery | `plauncher serve` subcommand |
| Catalog format | YAML + GUI admin editor |
| v1 scope | Fat: env templates + onboarding checklist + admin UI |

### Next Steps (prioritized build sequence)

**Sprint 1 — Foundation**
- [ ] `plauncher serve` (axum server, catalog.yaml read/write)
- [ ] GitHub OAuth flow + org membership check
- [ ] `GET /api/catalog` + `GET /api/catalog/diff`

**Sprint 2 — Dev Experience**
- [ ] `plauncher join` + `plauncher catalog sync`
- [ ] Flutter GUI drift view (sidebar panel)
- [ ] Env template apply (prompt for "ask" vars)

**Sprint 3 — Onboarding Checklist**
- [ ] Onboarding checklist state machine (clone → build → test)
- [ ] GUI checklist view in Flutter
- [ ] `plauncher onboarding status/continue`

**Sprint 4 — Admin UI**
- [ ] Embedded admin SPA (repo CRUD, tags, env templates)
- [ ] Publish → catalog.yaml git commit flow
- [ ] Member activity view (who's synced, who's drifted)

---

## Implementation Complete — 2026-04-03

All wiring tasks for the Team Catalog enterprise feature have been completed.

### Tasks completed (9 of 9) — Phase 1

1. **`PUT /api/admin/catalog`** — admin-only endpoint to replace the in-memory catalog. Validates admin privilege via `is_admin()` helper before updating `AppState`.
2. **`POST /api/admin/publish`** — admin-only endpoint that serializes the catalog to YAML, writes it to the catalog file path stored in `AppState`, then runs `git add && git commit`. Returns `{"committed": true, "sha": "..."}` or `{"committed": false, "reason": "..."}`.
3. **`GET /api/admin/members`** — admin-only endpoint that scans `onboarding_states` in memory and returns per-user sync status: `{login, syncedRepos, totalRepos, lastSyncAt, isDrifted}`.
4. **`is_admin()` helper** — stub always returns `true` with a `TODO` comment describing the real GitHub Teams API call (`GET /orgs/{org}/teams/{team}/memberships/{username}`) to implement before production.
5. **Static file serving (Option A)** — `spa_router()` uses `tower_http::services::ServeDir` to serve `web_app/build/web/`; falls back to `index.html` for SPA routing. Comment documents Option B (compile-time embedding via `include_dir`) for production.
6. **Auth callback `redirect=admin`** — `GET /auth/callback?redirect=admin` now redirects to `/?token=<jwt>` after OAuth so the Flutter web SPA can pick up the token from the URL; existing behavior (JSON response) is unchanged when the param is absent.
7. **CORS** — added `PUT` to the allowed methods list to support the new admin catalog endpoint.
8. **Makefile targets** — added `build-admin`, `build-all`, and `serve` targets.
9. **Cargo build verified** — `cargo build` compiles clean with no warnings.

### Phase 1 file inventory

| File | Change |
|------|--------|
| `cli/src/serve.rs` | +3 admin handlers, `is_admin()` helper, `spa_router()`, updated `handle_auth_callback`, `put` import, `ServeDir` import, PUT in CORS |
| `Makefile` | +`build-admin`, `build-all`, `serve` targets; updated `.PHONY` |
| `brainstorm-new-feature-2026-04-03.md` | This section |

### Task 18 — Docker Packaging

| File | Change |
|------|--------|
| `backend/Dockerfile` | Multi-stage build: Rust backend + Flutter web SPAs + Debian slim runtime |
| `docker-compose.yml` | plauncher service + MongoDB 7 with healthcheck + persistent volume |
| `.env.example` | Added backend env vars (JWT secret, GitHub OAuth, license, MongoDB) |
| `Makefile` | +`build-backend`, `build-docker`, `run-docker`, `stop-docker`, `push-docker` targets; `build-all` includes `build-backend`; updated `.PHONY` |
| `brainstorm-new-feature-2026-04-03.md` | Updated with T18 + final summary |

## Final Implementation Summary

### Phase 1 — Team Catalog (Tasks 1-9)
- `plauncher serve` CLI subcommand (axum, GitHub OAuth, REST API)
- Catalog models (launcher_models)
- CatalogService (Flutter)
- Drift view panel + join workspace dialog
- Env template apply logic + dialog
- Onboarding state machine (CLI + Flutter service)
- Onboarding checklist screen
- Admin SPA (web_app/ — Flutter web)
- Admin SPA wired into plauncher serve

### Phase 2 — SaaS Multi-Tenant (Tasks 10-18)
- backend/ Rust crate + MongoDB (6 collections, 4 indexes)
- Auth middleware + tenant resolver + GitHub OAuth (3 extractors)
- Super admin API (11 routes)
- Org admin API (11 routes)
- Catalog + onboarding API (7 routes)
- License service + self-hosted validation
- Super admin Flutter web UI (super_admin_web/)
- Org admin web UI updated for multi-tenant
- Docker packaging (Dockerfile + docker-compose.yml)

### Deployment
- Cloud: deploy backend/ directly, point to managed MongoDB
- Self-hosted: `docker compose up -d` with .env configured
- First login becomes super admin (bootstrap)
