# Project Launcher

**The dashboard for your entire dev life.**

Every project, every language, every tool — one place. Health scores, git status, instant launch.

<!-- TODO: Add hero screenshot here -->
<!-- ![Project Launcher Dashboard](screenshots/hero.png) -->

---

## Why Project Launcher?

You have 15+ projects scattered across your machine. Some in `~/Projects`, some in `~/Developer`, some you forgot about entirely. You `cd` around, open VS Code from terminal, and have no idea which repos have unpushed commits or stale dependencies.

**Project Launcher fixes this.** It's a fast, native macOS app that gives you a single dashboard for every project you work on — regardless of language, framework, or tooling.

| Problem | Solution |
|---------|----------|
| "Which project was I working on?" | Instant dashboard sorted by last activity |
| "Do I have unpushed commits?" | Git status badges on every project card |
| "Is this project healthy?" | 0-100 health scores (git + deps + tests) |
| "Let me open this in VS Code..." | One-click launch to Terminal, VS Code, Finder |
| "I forgot about that repo" | Staleness alerts: Fresh / Warning / Stale / Abandoned |

### How is this different from...

- **VS Code workspaces** — No health scores, no cross-editor support, no dashboard
- **Terminal aliases** — No visibility, no staleness tracking, no overview
- **Raycast / Alfred** — Can find files, but no project intelligence
- **GitHub dashboard** — Only git repos, no local-first, no health scoring
- **JetBrains project manager** — Locked to one IDE ecosystem

Project Launcher works with **every language and every editor**. It's the meta-layer above your dev tools.

---

## Features

### Core
- **Instant Launch** — Open any project in Terminal, VS Code, or Finder with one click
- **Smart Scanning** — Auto-discover git repositories across your dev folders
- **Search & Filter** — Find projects by name, language, tags, health, activity, or git status
- **Pin & Tag** — Organize projects with pins, custom tags, and notes
- **List & Grid Views** — Switch between compact list and visual grid layouts

### Project Intelligence
- **Health Scores** — 0-100 score based on git activity, dependencies, and test coverage
- **Git Status** — See branch, uncommitted changes, and unpushed commits at a glance
- **Tech Stack Detection** — Auto-detects 17+ languages/frameworks including multi-tech projects (Flutter + Rust FFI, monorepos with frontend + backend)
- **Platform Detection** — Shows which platforms a project targets (macOS, iOS, Android, Web, Linux, Windows)
- **Staleness Tracking** — Visual indicators for inactive projects with activity timeline filters

### Code Wrapped
- **Year in Review** — Beautiful stats dashboard: commits, projects, coding hours, streaks
- **Shareable Cards** — Branded "Code Wrapped" PNG optimized for social sharing
- **Custom Date Ranges** — Review any time period with preset buttons
- **Author Filtering** — See only your commits (filters by git user.email)

### Customization
- **Dark Mode** — Beautiful dark theme by default
- **Unlockable Themes** — Earn premium themes through referrals
- **Freemium Model** — Core features free, premium features via subscription

---

## Install

### Homebrew (Recommended)
```bash
brew install --cask project-launcher
```

### Manual Download
1. Download the latest `.dmg` from [Releases](https://github.com/nickvivek/project-launcher/releases)
2. Open the DMG and drag to Applications
3. Right-click the app and select Open (first launch only, to bypass Gatekeeper)

### Build from Source
Requires: Flutter 3.x, Rust 1.70+, macOS 11.0+

```bash
git clone https://github.com/nickvivek/project-launcher.git
cd project-launcher
make install    # Builds Rust FFI + Flutter app → installs to /Applications
```

---

## Quick Start

1. **Launch** Project Launcher
2. **Scan** — Click the radar icon to auto-discover projects in ~/Projects, ~/Developer, ~/Documents, etc.
3. **Browse** — Your projects appear with health scores, git status, and activity indicators
4. **Launch** — Click any project to open in Terminal, VS Code, or Finder
5. **Filter** — Use activity filters (This Week, Last Month), health filters, git status, or tags

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI | Flutter 3.x (Dart) |
| Native Core | Rust + FFI (libgit2, walkdir) |
| Git Operations | libgit2 (native) with git CLI fallback |
| Platform | macOS native (Windows & Linux coming soon) |

The Rust native library provides high-performance git operations, directory scanning, and health scoring without spawning shell processes. Falls back gracefully to Dart/shell if the native library is unavailable.

---

## Project Structure

```
project_launcher/
├── lib/                    # Flutter/Dart source
│   ├── main.dart           # App entry point
│   ├── models/             # Data models (Project, HealthScore, etc.)
│   ├── services/           # Business logic, FFI bridge, git, stats
│   ├── screens/            # Feature screens (Home, Review, Health, Settings)
│   ├── widgets/            # Reusable widget components
│   └── theme/              # App theming and typography
├── rust/                   # Native Rust library
│   └── src/
│       ├── lib.rs          # FFI exports
│       ├── git.rs          # libgit2 operations
│       ├── health.rs       # Health scoring engine
│       └── stats.rs        # Stats aggregation
├── macos/                  # macOS platform config
├── Makefile                # Build automation
└── plan.md                 # Roadmap
```

## Data Storage

All data stored locally in `~/.project_launcher/`:
- `projects.json` — Project list and metadata
- `health_cache.json` — Cached health scores (24h TTL)
- `stats_cache.json` — Cached year stats (1h TTL)
- `referrals.json` — Referral codes and rewards

**100% local-first.** No cloud accounts, no telemetry, no tracking.

---

## Building

```bash
make install    # Build Rust + Flutter → codesign → install to /Applications
make dev        # Development build (debug mode)
make build      # Release build (no install)
make clean      # Clean all build artifacts
```

## Requirements

- macOS 11.0 (Big Sur) or later
- VS Code (optional, for "Open in VS Code" feature)

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/awesome`)
3. Commit your changes
4. Push and open a Pull Request

---

## Roadmap

- [ ] Windows & Linux support
- [ ] CLI companion tool (`plauncher`)
- [ ] VS Code extension (sidebar panel)
- [ ] Raycast / Alfred integration
- [ ] GitHub health badges
- [ ] Team dashboards
- [ ] Plugin ecosystem

See [plan.md](plan.md) for the full roadmap.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

**Made by [Vivek Yadav](https://github.com/nickvivek)** — Built with Flutter, Rust, and a lot of coffee.
