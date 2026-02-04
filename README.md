# Project Launcher

A fast, native macOS app for developers to quickly access and launch projects in Terminal or VS Code.

## Features

### Core
- **Quick Launch** - Open any project in Terminal, VS Code, or Finder with one click
- **Smart Scanning** - Automatically discover git repositories in common dev folders
- **Search & Filter** - Find projects instantly by name, path, tags, or notes
- **Pin Favorites** - Keep important projects at the top
- **Tags & Notes** - Organize projects with custom labels and reminders

### Health & Analytics
- **Project Health Score** - 0-100 score based on git status, dependencies, and tests
- **Staleness Alerts** - Visual indicators for inactive projects (Fresh → Warning → Stale → Abandoned)
- **Year in Review** - Shareable stats cards showing your coding activity

### Themes & Rewards
- **Dark Mode** - Beautiful dark theme by default
- **Unlockable Themes** - Earn Midnight and Ocean themes through referrals

## Installation

### Homebrew (Recommended)
```bash
brew install --cask project-launcher
```

### Manual Download
1. Download the latest `.dmg` from [Releases](https://github.com/vivekyadav/project-launcher/releases)
2. Open the DMG and drag to Applications
3. Right-click the app → Open (first time only, to bypass Gatekeeper)

### Build from Source
Requires: Flutter 3.x, Rust 1.70+

```bash
git clone https://github.com/vivekyadav/project-launcher.git
cd project-launcher
make install
```

## Usage

### Adding Projects

**Scan for Projects:**
- Click the radar icon to auto-discover git repos in ~/Projects, ~/Developer, etc.

**Manual Add:**
- Click "Add" and enter the project path
- Or use the terminal: `addproject /path/to/project`

### Project Actions

| Button | Action |
|--------|--------|
| Terminal (orange) | Open in Terminal.app |
| Code (blue) | Open in VS Code |
| Folder (teal) | Open in Finder |
| Pin | Pin to top of list |
| More (...) | Tags, notes, remove |

### Views & Filters

- **List / Folder** - Flat list or grouped by parent directory
- **Recent / A-Z** - Sort by last opened or alphabetically
- **Health Filters** - Show Healthy, Needs Attention, or Critical projects
- **Stale Only** - Show only inactive projects

### Feature Screens

- **Year in Review** (chart icon) - See your coding stats and share
- **Health Dashboard** (heart icon) - Overview of all project health scores
- **Referrals** (gift icon) - Get your referral code and unlock themes

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | Flutter 3.x (Dart) |
| Native Core | Rust + FFI |
| Git Operations | libgit2 |
| File Scanning | walkdir |
| Platform | macOS native |

The Rust native library provides high-performance:
- Git operations without spawning shell processes
- Fast recursive directory scanning
- Efficient health score calculation

Falls back gracefully to Dart/shell if native library unavailable.

## Building

```bash
# Build Rust + Flutter and install
make install

# Development build
make dev

# Just build (no install)
make build

# Clean all artifacts
make clean
```

## Project Structure

```
project_launcher/
├── lib/                    # Flutter/Dart source
│   ├── main.dart          # App entry point
│   ├── models/            # Data models
│   ├── services/          # Business logic + FFI
│   ├── screens/           # Feature screens
│   └── kit/               # UI component library
├── rust/                   # Native Rust library
│   └── src/
│       ├── lib.rs         # FFI exports
│       ├── git.rs         # libgit2 operations
│       ├── health.rs      # Health scoring
│       └── stats.rs       # Stats aggregation
└── Makefile               # Build automation
```

## Data Storage

All data stored locally in `~/.project_launcher/`:
- `projects.json` - Project list and metadata
- `health_cache.json` - Cached health scores (24h TTL)
- `stats_cache.json` - Cached year stats
- `referrals.json` - Referral codes and rewards

## Requirements

- macOS 11.0 (Big Sur) or later
- VS Code (optional, for "Open in VS Code")

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/awesome`)
3. Commit your changes (`git commit -m 'Add awesome feature'`)
4. Push to the branch (`git push origin feature/awesome`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- [Flutter](https://flutter.dev) - Cross-platform UI
- [libgit2](https://libgit2.org) - Git implementation
- [Inter](https://rsms.me/inter/) - Typography
