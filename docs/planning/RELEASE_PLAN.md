# Project Launcher - Public Release Plan

## Overview
Release Project Launcher as a free, open-source macOS app for developers to manage and quickly access their projects.

---

## Phase 1: Repository Setup

### 1.1 GitHub Repository
- [ ] Create public repo: `github.com/vivekyadav/project-launcher`
- [ ] Add LICENSE (MIT recommended for max adoption)
- [ ] Add .github/FUNDING.yml for sponsorship
- [ ] Set up GitHub Actions for CI/CD

### 1.2 Documentation
- [ ] README.md with:
  - App screenshot/demo GIF
  - Feature list
  - Installation instructions (3 methods)
  - Build from source instructions
  - Tech stack overview
- [ ] CONTRIBUTING.md
- [ ] CHANGELOG.md

### 1.3 Issue Templates
- [ ] Bug report template
- [ ] Feature request template

---

## Phase 2: Release Build

### 2.1 App Signing (Optional but Recommended)
- [ ] Apple Developer account ($99/year) OR
- [ ] Distribute unsigned with Gatekeeper bypass instructions

### 2.2 Build Artifacts
- [ ] DMG installer with background image
- [ ] ZIP archive (alternative)
- [ ] Universal binary (Intel + Apple Silicon)

### 2.3 Versioning
- Current: v1.1.0
- Release: v1.2.0 (with Rust FFI)
- Follow semver: MAJOR.MINOR.PATCH

---

## Phase 3: Distribution Channels

### 3.1 GitHub Releases (Primary)
```
Releases/
├── Project-Launcher-1.2.0-arm64.dmg    # Apple Silicon
├── Project-Launcher-1.2.0-x86_64.dmg   # Intel
├── Project-Launcher-1.2.0-universal.dmg # Both
└── Source code (auto-generated)
```

### 3.2 Homebrew Cask (High Priority)
```ruby
cask "project-launcher" do
  version "1.2.0"
  sha256 "..."
  url "https://github.com/vivekyadav/project-launcher/releases/download/v#{version}/Project-Launcher-#{version}.dmg"
  name "Project Launcher"
  desc "Quick access to your development projects"
  homepage "https://github.com/vivekyadav/project-launcher"
  app "Project Launcher.app"
end
```
- Submit to homebrew/homebrew-cask

### 3.3 Other Channels (Future)
- [ ] MacUpdater integration
- [ ] Setapp (if app grows)

---

## Phase 4: Marketing & Visibility

### 4.1 Launch Announcements
- [ ] Twitter/X post with demo GIF
- [ ] Reddit: r/macapps, r/commandline, r/programming
- [ ] Hacker News (Show HN)
- [ ] Dev.to article
- [ ] Product Hunt launch

### 4.2 SEO & Discoverability
- [ ] GitHub topics: `macos`, `developer-tools`, `flutter`, `rust`, `productivity`
- [ ] GitHub description optimized for search
- [ ] Social preview image (1280x640)

### 4.3 Demo Content
- [ ] 30-second demo GIF for README
- [ ] 2-minute YouTube walkthrough (optional)
- [ ] Screenshots of key features

---

## Phase 5: Build Automation

### 5.1 GitHub Actions Workflow
```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - uses: dtolnay/rust-toolchain@stable
      - run: make build
      - run: create-dmg ...
      - uses: softprops/action-gh-release@v1
```

### 5.2 Automated Tasks
- [ ] Build on tag push
- [ ] Create DMG
- [ ] Upload to GitHub Releases
- [ ] Update Homebrew cask (via PR)

---

## Phase 6: Post-Launch

### 6.1 Monitoring
- [ ] GitHub star/fork tracking
- [ ] Issue response SLA (48h)
- [ ] Release download counts

### 6.2 Iteration
- [ ] Collect user feedback
- [ ] Prioritize feature requests
- [ ] Regular updates (monthly)

---

## Checklist Summary

### Before Release
- [ ] All features working
- [ ] No critical bugs
- [ ] README complete
- [ ] LICENSE added
- [ ] Demo GIF created
- [ ] DMG builds correctly

### Release Day
- [ ] Push v1.2.0 tag
- [ ] Verify GitHub Release
- [ ] Post to social media
- [ ] Submit to Homebrew

### After Release
- [ ] Monitor issues
- [ ] Respond to feedback
- [ ] Plan v1.3.0

---

## Tech Stack (for README)

| Component | Technology |
|-----------|------------|
| UI Framework | Flutter 3.x |
| Platform | macOS native |
| Native Core | Rust + FFI |
| Git Operations | libgit2 |
| File Scanning | walkdir |
| Fonts | Google Fonts (Inter) |

---

## Timeline Estimate

| Phase | Duration |
|-------|----------|
| Repository Setup | 1 day |
| Documentation | 1-2 days |
| Build Automation | 1 day |
| DMG Creation | 1 day |
| Marketing Prep | 1 day |
| **Total** | **~1 week** |
