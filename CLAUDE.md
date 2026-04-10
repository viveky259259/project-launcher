# Project Launcher

macOS developer dashboard — discover, organize, and launch projects. Flutter + Rust monorepo managed by Melos.

## Quick Reference

| Command | What it does |
|---------|-------------|
| `make dev` | Debug build + run |
| `make build` | Release build (Rust + Flutter) |
| `make test` | Run all tests (Rust + Flutter) |
| `make analyze` | Static analysis (all packages via Melos) |
| `make install` | Build + install to /Applications + codesign |
| `make bootstrap` | Install Melos + resolve all packages |
| `make clean` | Clean all build artifacts |
| `make serve` | Run backend catalog server (dev mode) |
| `make build-backend` | Build backend binary (release) |
| `make run-docker` | Start backend + MongoDB via Docker Compose |
| `make stop-docker` | Stop Docker Compose stack |
| `make setup-e2e` | Install Playwright E2E test dependencies |
| `make test-e2e` | Run Playwright E2E tests (backend must be running) |

## Architecture

- **lib/** — Flutter app (screens, services, widgets)
- **rust/** — Native Rust core (git ops, health scoring, stats) via FFI
- **cli/** — Rust CLI tool (`plauncher`)
- **backend/** — Rust Axum REST API (MongoDB, JWT auth, GitHub OAuth, multi-tenant)
- **packages/** — Extracted Dart packages (see per-package CLAUDE.md):
  - `launcher_theme` — Design system (colors, typography, spacing, skins)
  - `launcher_kit` — UI component library (layout, forms, elements)
  - `launcher_models` — Data models (pure Dart, no Flutter dependency)
  - `launcher_native` — FFI bindings to Rust core + logging
- **super_admin_web/** — Flutter web super admin portal
- **web_app/** — Flutter web org admin portal
- **e2e/** — Playwright E2E integration tests for backend API
- **vscode-extension/** — VS Code sidebar extension (TypeScript)
- **raycast-extension/** — Raycast commands (TypeScript)
- **badge-service/** — Vercel serverless badge generator (Node.js)

### Dependency Graph

```
launcher_theme → launcher_kit → project_launcher (root app)
launcher_models → project_launcher
launcher_native → project_launcher
rust/libproject_launcher_core.dylib → launcher_native (via FFI)
backend (Axum) → MongoDB
super_admin_web → backend API
web_app → backend API
cli → backend API
```

## Code Patterns

- State management: StatefulWidget + service singletons
- Theme: `launcher_theme` package with `SkinProvider` for switchable skins
- Native calls: Dart FFI via `launcher_native` package
- Screens: `lib/screens/<name>_screen.dart`
- Services: `lib/services/<name>_service.dart`
- Widgets by feature: `lib/widgets/<feature>/`

## Backend

- Framework: Axum (Rust async web framework)
- Database: MongoDB (cloud Atlas or local)
- Auth: JWT + API keys (`plk_` prefix) + GitHub OAuth
- Config: environment variables (see `.env.example`)
- Port: 8743 (default)
- Requires `MONGODB_URI` env var (falls back to `mongodb://localhost:27017`)

## Testing

| Scope | Command |
|-------|---------|
| Everything | `make test` |
| Flutter app only | `flutter test` |
| All packages (Melos) | `melos run test` |
| Rust core | `cd rust && cargo test` |
| Rust CLI | `cd cli && cargo test` |
| Backend | `cd backend && cargo test` |
| E2E (Playwright) | `make test-e2e` (backend must be running at localhost:8743) |
| Static analysis | `make analyze` |

## Release

- Full signed + notarized build: `./scripts/release_app.sh` (requires `.env` with Apple credentials)
- Patch: `make release-patch`
- Minor: `make release-minor`
- Major: `make release-major`
- Dry run: `make release-dry`
- Full script: `./scripts/release.sh <patch|minor|major> [--dry-run]`
- Crash diagnostics: `./scripts/launch-debug.sh [output-dir]`

## FFI Notes

- The Rust dylib must be in `macos/Frameworks/` before `flutter build macos`
- In release builds, `native_lib.dart` loads from `Contents/Frameworks/` (absolute path)
- In debug builds, falls back to `rust/target/release/` (relative path)
- Hardened runtime rejects relative paths — always ensure bundle path works first
- `AppDelegate.swift` ignores SIGPIPE to prevent crashes when launched from Finder/Dock
