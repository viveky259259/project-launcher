# Launch Content — Project Launcher

## 1. Show HN Post

**Title:** Show HN: Project Launcher – A dashboard for every project on your machine

**Text:**

Hi HN,

I built Project Launcher because I had 50+ repos scattered across my machine and no single place to see them all.

It's a native macOS app (Flutter + Rust FFI) that gives you a dashboard for every project on your machine — regardless of language or framework. It auto-detects 17+ tech stacks, calculates health scores (0-100 based on git activity, dependencies, and tests), tracks staleness, and lets you launch any project in VS Code/Terminal with one click.

Key features:
- Auto-scan: discovers git repos across your dev directories
- Health scores: 0-100 based on git activity, dependencies, tests
- Git status at a glance: branch, uncommitted changes, unpushed commits
- Tech stack detection: Flutter, Rust, Python, React, Go, Swift, and more
- Code Wrapped: beautiful year-in-review stats cards (like Spotify Wrapped for code)
- CLI companion: `plauncher list`, `plauncher health`, `plauncher open <project>`
- 100% local, no account required, no telemetry

The Rust FFI core uses libgit2 for fast git operations without spawning shell processes. Falls back to shell commands gracefully.

Install: `brew install --cask project-launcher`

GitHub: [link]
Website: projectlauncher.dev

Would love your feedback — especially on what you'd want from a project dashboard tool.

---

## 2. ProductHunt

**Tagline:** The dashboard for your entire dev life

**Description (short):**
Every project, every language, every tool — one place. Health scores, git status, instant launch. A native macOS app for developers who juggle multiple projects.

**Description (full):**
Project Launcher gives you a single dashboard for every project on your machine.

**The problem:** You have 15+ projects scattered across your filesystem. You `cd` around, can't remember which repos have unpushed commits, and have no idea which projects are healthy.

**The solution:** A fast, native macOS app that:
- Auto-discovers all your git repositories
- Shows health scores (0-100) based on git activity, dependencies, and tests
- Displays git status: branch, uncommitted changes, unpushed commits
- Detects your tech stack (17+ languages/frameworks)
- Launches any project in VS Code, Terminal, or Finder with one click
- Generates beautiful "Code Wrapped" year-in-review cards
- Includes a CLI companion (`plauncher`) for terminal lovers

Built with Flutter + Rust FFI for native performance. 100% local, no account required.

**Maker comment:**
I built this because I juggle 50+ projects across Flutter, Rust, Python, and React. I was tired of having no single place to see the health and status of all my repos. Project Launcher started as a simple project switcher and grew into a full project intelligence dashboard.

The Rust native core uses libgit2 for fast git operations, and the Flutter UI gives you a beautiful, responsive dashboard. Everything runs locally — no cloud, no telemetry.

**Topics:** Developer Tools, Productivity, macOS, Open Source

---

## 3. dev.to Article

**Title:** I built a dashboard for every project on my machine (and open-sourced it)

**Outline:**

### Hook
- "I have 107 projects on my machine. I know because Project Launcher told me."
- The problem: scattered repos, no visibility, context-switching friction

### What I Built
- Screenshot of the dashboard
- Key features walkthrough with screenshots:
  1. Auto-scan and discovery
  2. Health scores
  3. Git status at a glance
  4. Tech stack detection
  5. Code Wrapped

### The Tech Stack
- Why Flutter for a desktop app (cross-platform potential, fast iteration)
- Why Rust FFI (libgit2 for speed, no shell spawning)
- Architecture: how the Rust bridge works
- Performance comparison: Rust FFI vs shell git commands

### Code Wrapped: The Viral Feature
- Screenshot of the shareable card
- How stats are calculated (git rev-list, monthly aggregation)
- Why "Spotify Wrapped for code" resonates with developers

### The CLI Companion
- `plauncher list` / `plauncher health` / `plauncher status`
- Why CLI + GUI is better than either alone
- "Trojan horse" distribution strategy

### What I Learned
- Flutter desktop is production-ready (mostly)
- Rust FFI in Flutter is powerful but underdocumented
- Developer tools need to be fast AND beautiful
- The "wow moment" matters: first scan → full dashboard in 30 seconds

### Try It
- GitHub link
- `brew install --cask project-launcher`
- Would love feedback

**Tags:** flutter, rust, macos, devtools, opensource

---

## 4. Reddit Posts

### r/FlutterDev
**Title:** I built a macOS project dashboard with Flutter + Rust FFI — open source

Short description of the app, focus on Flutter desktop experience, Rust FFI integration, and what it was like building a real desktop app with Flutter. Include screenshots.

### r/macapps
**Title:** Project Launcher — a native project dashboard for developers (free, open source)

Focus on the macOS experience, app quality, design. Include screenshots.

### r/programming
**Title:** I open-sourced a developer dashboard that tracks 17+ tech stacks, health scores, and git status across all your local projects

Focus on the technical approach (Rust FFI, libgit2, health scoring algorithm). Brief, link to HN thread or GitHub.

---

## 5. Twitter/Bluesky Thread

```
1/ I built a dashboard for every project on my machine.

107 projects. 17 languages. One app.

It's called Project Launcher, and I just open-sourced it.

[screenshot]

2/ The problem: I have repos everywhere. ~/Projects, ~/Developer, random folders.

No single place to see:
- Which projects are healthy?
- Do I have unpushed commits?
- What was I working on last week?

3/ So I built a native macOS app that:

✅ Auto-discovers all your git repos
✅ Health scores (0-100)
✅ Git status at a glance
✅ Detects 17+ tech stacks
✅ One-click launch to VS Code/Terminal
✅ "Code Wrapped" — Spotify Wrapped for your code

4/ The tech stack:

🎯 Flutter for the UI (yes, desktop Flutter works great)
🦀 Rust FFI core using libgit2
⚡ No shell spawning — native git operations
📦 100% local, no cloud, no accounts

5/ My favorite feature: Code Wrapped

A shareable card showing your yearly coding stats.

Commits, streaks, top language, most active project.

Like Spotify Wrapped, but for code.

[code wrapped screenshot]

6/ There's also a CLI companion:

$ plauncher list
$ plauncher health
$ plauncher status

For those who live in the terminal.

7/ It's free and open source:

🔗 GitHub: [link]
🍺 brew install --cask project-launcher
🌐 projectlauncher.dev

Would love feedback. What features would make this your daily driver?
```
