# Release v2.3.3 — Task List

**Date:** 2026-03-31
**Current version:** 2.3.2+9 → **2.3.3+10** (patch bump)
**Branch:** ocean/shell-73 → main

---

## Pre-Release (Quality)

- [ ] **Merge ocean/shell-73 into main** — 5 commits since v2.3.2, merge all changes into main for a clean release
- [ ] **Run static analysis** — `make analyze` across all packages to catch lint errors, unused imports, type issues
- [ ] **Run full test suite** — `make test` (Rust cargo test + Flutter flutter test), all must pass
- [ ] **Clean git working tree** — Remove/ignore untracked `.dart_tool` and `build` dirs; release script requires clean tree

## Pre-Release (Readiness)

- [ ] **Verify secrets are available** — APPLE_ID, TEAM_ID, APP_SPECIFIC_PASSWORD from viveky259259/secrets → project-launcher/.env
- [ ] **Verify required tools installed** — flutter, gh, codesign, xcrun, hdiutil + `gh auth status`
- [ ] **Verify Paddle checkout and premium gating** — Test checkout flow (checkout/index.html, checkout/portal.html), confirm premium features are gated correctly in release build
- [ ] **Test VS Code and Raycast extensions compatibility** — Ensure extensions work with the new app version, check for breaking CLI/app interface changes

## Release Execution

- [ ] **Dry run the release** — `make release-dry` to preview version bump, tag, DMG path, and release notes
- [ ] **Review and finalize release notes** — Review auto-generated changelog; key changes: Projekta skin, extracted widgets/dialogs, CI workflow, tests, docs
- [ ] **Execute release** — `make release-patch` runs the full 8-phase pipeline: version → Rust universal binary → Flutter build → codesign → verify → notarize → DMG → publish + Homebrew

## Post-Release (Distribution)

- [ ] **Post-release verification** — Verify GitHub Release page has DMG, test Homebrew install, download DMG and confirm launch, verify Gatekeeper passes (notarization stapled)
- [ ] **Verify Homebrew tap cask formula** — Check viveky259259/homebrew-project-launcher cask metadata (app name, homepage, description) after auto-update
- [ ] **Test fresh install experience** — Download DMG, drag to Applications, launch; verify onboarding, project scanning, CLI install prompt
- [ ] **Update badge-service for new version** — Ensure Vercel badge service reflects v2.3.3 after release

## Post-Release (Marketing)

- [ ] **Update website for v2.3.3** — New version number, latest screenshots, feature showcases (Projekta skin, extracted widgets), download links
- [ ] **Update README and app_details.md** — Reflect current feature set, up-to-date screenshots, new capabilities
- [ ] **Prepare release announcement** — Draft for social/community: new Projekta skin, improved project settings, AI insights, export/scan dialogs, grid card layout

## User Tracking

> Currently the project has **zero remote analytics** — all tracking is local-only.

- [ ] **Add website analytics** *(High)* — GA4, Plausible, Fathom, or Umami on docs/index.html and checkout pages; track page views, download clicks, checkout conversions, referral sources
- [ ] **Add opt-in in-app telemetry service** *(High)* — Track app launches, screen views, feature usage, session duration, app version; consider PostHog or Mixpanel; must include visible opt-out toggle in settings
- [ ] **Add crash and error reporting** *(High)* — Integrate Sentry or similar for macOS Flutter; capture unhandled exceptions, Rust FFI crashes, error logs
- [ ] **Add UTM parameter tracking** *(Medium)* — Capture utm_source/medium/campaign on website and checkout pages; store attribution alongside download/checkout events
- [ ] **Track Homebrew install metrics** *(Low)* — Monitor cask install counts via `brew info --json`; expose as live badge
- [ ] **Track GitHub Release download counts** *(Low)* — Monitor DMG download counts via GitHub API; expose via badge-service
- [ ] **Connect referral system to remote tracking** *(Medium)* — Current referral_service.dart is fully local (referrals.json); add remote tracking for real conversions
- [ ] **Add onboarding funnel tracking** *(Medium)* — Instrument first-run: app launch → project scan → first project opened → CLI installed → skin customized; track drop-off
- [ ] **Add retention and engagement tracking** *(Medium)* — DAU/WAU/MAU, session frequency, feature adoption over time, last-active timestamps; enables cohort analysis

## User Acquisition

- [ ] **Plan acquisition channels** *(High)* — Prioritize for developer audience:
  1. Hacker News / Reddit /r/macapps launch post
  2. Dev Twitter/X announcement
  3. Product Hunt launch
  4. Homebrew discoverability
  5. VS Code Marketplace listing for the extension
  6. Raycast Store submission
  7. Dev newsletter sponsorships
