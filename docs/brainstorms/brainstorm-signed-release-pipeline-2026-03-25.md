# Brainstorm: Signed Release Pipeline with Auto-Versioning
**Date**: 2026-03-25
**Type**: problem-solving / decision-making

## Central Question
How should we build an end-to-end pipeline for Project Launcher that:
1. Automatically increments the version
2. Builds the Flutter + Rust macOS app
3. Code signs with Developer ID
4. Notarizes with Apple
5. Creates signed DMG
6. Publishes to GitHub Releases
7. Updates Homebrew cask

## Current State
- **Version**: 2.2.1+6 (pubspec.yaml)
- **Local script** (`release_app.sh`): Full pipeline — build, sign, notarize, staple, DMG, sign DMG
- **GitHub Actions** (`release.yml`): Builds + creates DMG/ZIP + publishes GitHub Release — **NO signing/notarization**
- **Homebrew**: Manual SHA256 calculation and PR submission
- **Env vars**: PADDLE_API_KEY, PADDLE_IS_SANDBOX, APPLE_ID, TEAM_ID, APP_SPECIFIC_PASSWORD
- **Gap**: No bridge between local signing capabilities and CI automation

## Mind Map

```
                              ┌─── Version Strategy
                              │     ├── Semver bumping (major/minor/patch)
                              │     ├── Build number auto-increment
                              │     ├── pubspec.yaml as source of truth
                              │     ├── Git tags as triggers
                              │     └── Changelog generation
                              │
                              ├─── Signing & Notarization
                              │     ├── Local-first (current approach) ✅ CHOSEN
                              │     ├── CI-based (certificates in GitHub Secrets)
                              │     ├── Hybrid (CI builds, local signs)
                              │     ├── Apple certificate management
                              │     └── Keychain provisioning in CI
                              │
  [SIGNED RELEASE PIPELINE] ──├─── CI/CD Architecture
                              │     ├── LOCAL-ONLY via single script ✅ CHOSEN
                              │     ├── gh CLI for GitHub Releases ✅ CHOSEN
                              │     ├── CLI args for Claude-friendliness ✅ CHOSEN
                              │     └── Universal binary (both arches) ✅ CHOSEN
                              │
                              ├─── Distribution
                              │     ├── GitHub Releases via gh CLI ✅ CHOSEN
                              │     ├── Own Homebrew tap (auto-update) ✅ CHOSEN
                              │     ├── Auto-changelog from commits ✅ CHOSEN
                              │     └── Manual changelog override option ✅ CHOSEN
                              │
                              ├─── Constraints
                              │     ├── Requires Apple Developer cert on local machine
                              │     ├── Requires gh CLI authenticated
                              │     ├── Rust must cross-compile for both arches
                              │     ├── Notarization wait ~30-90s per submission
                              │     └── .env must have all signing credentials
                              │
                              └─── Wild Cards (future)
                                    ├── Sparkle in-app auto-updater
                                    ├── TestFlight for macOS beta channel
                                    └── Nix/Flake distribution
```

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Version bump | CLI arg (`patch`/`minor`/`major`) | Claude-friendly, scriptable |
| Build target | Universal binary (x86_64 + arm64) | Cover all Macs |
| Signing | Local laptop only | Certificates already configured, no CI cert headaches |
| GitHub Release | `gh` CLI from local | Single pipeline, no split with CI |
| Homebrew | Own tap repo (`homebrew-project-launcher`) | Full control, instant updates |
| Changelog | Auto from commits, manual override | Fast default, flexibility when needed |

## Deep Dives

### Deep Dive 1: Version Increment Strategy

**Source of truth**: `pubspec.yaml` → `version: 2.2.1+6`

Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`

**CLI interface**:
```bash
# Invoked by human or Claude:
./release.sh patch              # 2.2.1+6 → 2.2.2+7
./release.sh minor              # 2.2.1+6 → 2.3.0+7
./release.sh major              # 2.2.1+6 → 3.0.0+7
./release.sh patch --dry-run    # Preview without executing
./release.sh patch --notes "Fixed crash on startup"  # Manual changelog
```

**Version bump logic**:
1. Read current version from `pubspec.yaml`
2. Parse into MAJOR.MINOR.PATCH+BUILD
3. Apply bump type, always increment BUILD
4. Write back to `pubspec.yaml`
5. Git commit: `release: v2.2.2`
6. Git tag: `v2.2.2`

**Build number**: Always increments by 1 regardless of bump type. This gives a monotonically increasing number for macOS bundle versioning (CFBundleVersion).

### Deep Dive 2: Changelog Auto-Generation

**Default (auto)**: Uses `git log` between the last tag and HEAD.

```bash
# Get commits since last tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline --no-merges
```

**Formatting**: Group by conventional commit prefix:
```markdown
## What's New in v2.2.2

### Features
- feat: Add project search by technology (#42)

### Bug Fixes
- fix: Crash when scanning empty directories (#38)
- fix: Homebrew formula path resolution

### Other
- chore: Update Flutter to 3.24.0
- docs: Add contributing guide
```

**Manual override**: `--notes "your notes"` replaces auto-generated notes entirely.

**Fallback**: If no conventional commit prefixes found, list commits as bullet points.

### Deep Dive 3: End-to-End Pipeline Architecture

**Single script: `release.sh`**

```
Phase 1: PREPARE
  ├── Validate .env exists and has required vars
  ├── Validate gh CLI is authenticated
  ├── Validate codesigning identity exists
  ├── Validate clean git working tree (no uncommitted changes)
  ├── Read current version from pubspec.yaml
  ├── Calculate new version from bump type
  └── Show preview, confirm (unless --yes flag)

Phase 2: VERSION
  ├── Update pubspec.yaml with new version
  ├── Git commit: "release: vX.Y.Z"
  └── Git tag: vX.Y.Z

Phase 3: BUILD
  ├── flutter clean
  ├── flutter pub get
  ├── Rust build x86_64-apple-darwin
  ├── Rust build aarch64-apple-darwin
  ├── lipo create universal binary
  ├── flutter build macos --release (with dart-defines)
  └── Copy dylib to app bundle Frameworks/

Phase 4: SIGN
  ├── Sign nested frameworks/dylibs
  ├── Sign main app bundle (--options runtime)
  ├── Verify signature (codesign --verify)
  └── Gatekeeper assessment (spctl --assess)

Phase 5: NOTARIZE
  ├── Create ZIP for notarization
  ├── Submit to Apple (notarytool submit --wait)
  └── Staple ticket to app

Phase 6: PACKAGE
  ├── Create DMG (hdiutil)
  ├── Sign DMG
  ├── Notarize DMG (submit --wait)
  └── Staple DMG

Phase 7: PUBLISH
  ├── Push git commit + tag to origin
  ├── Generate changelog (auto or manual)
  ├── gh release create with DMG + ZIP artifacts
  └── Print release URL

Phase 8: HOMEBREW
  ├── Calculate SHA256 of DMG
  ├── Update cask file in homebrew-project-launcher repo
  ├── Git commit + push to tap repo
  └── Print tap update confirmation
```

### Deep Dive 4: Homebrew Tap Structure

**Repo**: `github.com/viveky259259/homebrew-project-launcher`

```
homebrew-project-launcher/
├── Casks/
│   └── project-launcher.rb
└── README.md
```

**Cask file** (auto-updated by release script):
```ruby
cask "project-launcher" do
  version "2.2.2"
  sha256 "abc123..."

  url "https://github.com/viveky259259/project-launcher/releases/download/v#{version}/ProjectLauncher-#{version}.dmg"
  name "Project Launcher"
  desc "Quick access to your development projects"
  homepage "https://github.com/viveky259259/project-launcher"

  app "Project Launcher.app"
end
```

**User installs via**:
```bash
brew tap viveky259259/project-launcher
brew install --cask project-launcher
```

**Release script updates tap by**:
1. Clone/pull the tap repo to a temp dir
2. Sed-replace version and sha256 in the cask file
3. Commit and push

### Deep Dive 5: Error Handling & Recovery

Each phase should be **resumable**. If notarization fails:

```bash
./release.sh patch --resume-from=notarize
```

Key failure scenarios:
| Failure | Recovery |
|---------|----------|
| Notarization rejected | Fix issue, `--resume-from=sign` |
| `gh` upload fails | `--resume-from=publish` |
| Dirty git tree | Abort with message, user cleans up |
| Missing .env var | Abort immediately with which var is missing |
| Rust build fails | Abort, fix, re-run from scratch |

### Deep Dive 6: Makefile Integration

```makefile
# Release targets
release-patch:
	./release.sh patch

release-minor:
	./release.sh minor

release-major:
	./release.sh major

release-dry:
	./release.sh patch --dry-run
```

## Discussion Log

1. **Decision**: Releases run from local laptop only — no CI signing needed
2. **Decision**: CLI args for version bump type — Claude-friendly
3. **Decision**: `gh` CLI for GitHub Releases — single local pipeline
4. **Decision**: Own Homebrew tap — full control, auto-updated by script
5. **Decision**: Universal binary — always build both architectures
6. **Decision**: Auto-changelog from git commits, with `--notes` override

## Synthesis

### Key Insights

1. **The existing `release_app.sh` is 80% of the solution** — it already handles build, sign, notarize, DMG. We need to wrap it with version bumping (before) and publishing (after).

2. **Local-only is the right call** — Apple code signing in CI is a pain (export certificates, provisioning profiles, keychain setup). Your laptop already has everything configured.

3. **The `gh` CLI eliminates the CI/local split** — no need for GitHub Actions to create releases. One script does everything.

4. **Own Homebrew tap is low-friction** — no waiting for homebrew-cask PR reviews. Users get updates immediately.

5. **Resumability is important** — notarization can fail for Apple-side reasons. Don't force a full re-build when only the publish step needs retrying.

### Decision Points (Resolved)

| # | Decision | Status |
|---|----------|--------|
| 1 | Version bump via CLI arg | ✅ Decided |
| 2 | All local, no CI for releases | ✅ Decided |
| 3 | `gh` CLI for GitHub Releases | ✅ Decided |
| 4 | Own Homebrew tap | ✅ Decided |
| 5 | Universal binary always | ✅ Decided |
| 6 | Auto-changelog + manual override | ✅ Decided |

### Remaining Questions
- Should the GitHub Actions `release.yml` be kept for CI build validation (no signing), or removed entirely?
- Should the tap repo be created first, or as part of the first release run?
- Do we want `--resume-from` in v1, or add it later?

### Next Steps (Prioritized)

#### Quick Wins
1. **Create the Homebrew tap repo** (`homebrew-project-launcher`) with initial cask file
2. **Add `release` targets to Makefile** for ergonomics

#### Core Work
3. **Write `release.sh` v2** — unified script that wraps existing `release_app.sh` logic with:
   - Version bump (parse pubspec, apply semver, write back)
   - Git commit + tag
   - Auto-changelog generation
   - `gh release create` with artifacts
   - Homebrew tap auto-update
4. **Add `--dry-run` flag** — preview everything without executing
5. **Add `--yes` flag** — skip confirmation prompt (for Claude usage)

#### Nice-to-Haves (Later)
6. **`--resume-from` support** — skip completed phases
7. **Deprecate old `release_app.sh`** — once new script is validated
8. **Sparkle integration** — in-app auto-update checks
