# Contributing to Project Launcher

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

### Prerequisites
- Flutter 3.x
- Rust 1.70+
- macOS 11.0+ (Big Sur or later)

### Getting Started

```bash
git clone https://github.com/nickvivek/project-launcher.git
cd project-launcher
make dev
```

This builds the Rust FFI library and runs the Flutter app in debug mode.

## How to Contribute

### Reporting Bugs
- Open an issue with a clear title and description
- Include steps to reproduce, expected vs actual behavior
- Include your macOS version and app version

### Suggesting Features
- Open an issue with the `feature` label
- Describe the problem it solves and who benefits
- Include mockups or examples if possible

### Pull Requests

1. Fork the repo and create your branch from `main`
2. Make your changes
3. Test on macOS (and other platforms if applicable)
4. Run `flutter analyze` and fix any warnings
5. Open a PR with a clear description of the changes

### PR Guidelines
- Keep PRs focused — one feature or fix per PR
- Follow existing code style and patterns
- Don't include unrelated formatting or refactoring changes
- Update the README if you change user-facing behavior

## Code Structure

```
lib/
├── models/        # Data models
├── services/      # Business logic, git operations, FFI bridge
├── screens/       # Full-page screens
├── widgets/       # Reusable UI components
└── theme/         # Colors, typography, spacing constants

rust/src/          # Native Rust library (libgit2, health scoring)
```

### Key Patterns
- **Services** are static classes with async methods
- **Screens** manage state; widgets are mostly stateless
- **Rust FFI** provides fast git operations; Dart is the fallback
- **Health scores** are cached in `~/.project_launcher/health_cache.json`

## Building

```bash
make build     # Release build
make dev       # Debug build
make install   # Build + codesign + install to /Applications
make clean     # Clean all artifacts
```

## Questions?

Open an issue or start a discussion. We're happy to help!
