# Brainstorm: Making Users Think About Releases Daily
**Date**: 2026-03-16
**Type**: ideation + product strategy

## Central Question
How can Project Launcher become a daily-use app that makes developers naturally think about and work toward releases — not just a tool they open occasionally?

## Mind Map

```
                          ┌─── What triggers daily use?
                          │    ├── Habit loops (cue → routine → reward)
                          │    ├── Information you can't get elsewhere
                          │    ├── Actions that save time every day
                          │    └── Social/team accountability
                          │
                          ├─── Why don't devs think about releases?
                          │    ├── Releases feel like "extra work"
                          │    ├── No visibility into readiness
                          │    ├── Context switching cost
                          │    ├── "I'll do it later" syndrome
                          │    └── No urgency signal
                          │
  [DAILY RELEASE HABITS]  ├─── How to create daily pull?
                          │    ├── Morning dashboard (what needs attention)
                          │    ├── Streak/progress mechanics
                          │    ├── Notifications that matter
                          │    ├── One-click actions from menubar
                          │    └── AI nudges ("3 projects ready to ship")
                          │
                          ├─── Who benefits most?
                          │    ├── Solo devs shipping side projects
                          │    ├── Team leads tracking multiple repos
                          │    ├── Indie hackers with many products
                          │    └── Consultants managing client projects
                          │
                          ├─── Constraints
                          │    ├── Must not feel like busywork
                          │    ├── Desktop app (not always visible)
                          │    ├── Can't require account/login
                          │    └── Must work offline
                          │
                          └─── Wild Cards
                               ├── Menubar app (always visible)
                               ├── Git hook integration (passive tracking)
                               ├── "Release Friday" gamification
                               ├── Cross-project release calendar
                               └── AI release coach
```

## Deep Dives

### Deep Dive 1: The "Morning Dashboard" Pattern
The app opens to a view that answers: "What do I need to ship today?"

**Concept: Release Pulse**
- Projects sorted by "urgency to release" (unreleased commits × days since last release)
- Red/yellow/green status at a glance
- "3 projects have unreleased work" banner
- One-click: bump → tag → push → release in 10 seconds

**Why this works:**
- Developers already open tools in the morning
- Gives instant value (information they'd need 5 commands to get)
- Creates a "clear the board" motivation

### Deep Dive 2: Menubar Presence (Always Visible)
A menubar icon that shows release status passively.

**Concept: Release Tray**
- Menubar icon: green (all shipped) / yellow (unreleased work) / red (stale projects)
- Click to see: "5 projects with unreleased commits"
- Quick actions: bump, tag, open in terminal
- Weekly digest: "You shipped 3 releases this week"

**Why this works:**
- Zero-effort awareness (no need to open the app)
- Social proof with yourself (shipping streak)
- Reduces the "I forgot to release" problem

### Deep Dive 3: Passive Tracking via Git Hooks
Track release activity without the user doing anything special.

**Concept: Auto-Track**
- Install a global git post-commit hook that pings Project Launcher
- Track: commits since last tag, time since last release
- Build a "release debt" metric (like tech debt, but for shipping)
- Alert when a project has been worked on for 2 weeks without a release

### Deep Dive 4: Gamification — Ship Streak
Make releasing feel rewarding, not like a chore.

**Concept: Ship Score**
- Weekly shipping streak (like GitHub contribution graph but for releases)
- "Release Friday" challenge: ship something every Friday
- Badges: "First Release", "10 Releases", "Shipped Every Week for a Month"
- Year-in-review: "You shipped 47 releases across 12 projects in 2026"

### Deep Dive 5: AI Release Coach
Claude as your release accountability partner.

**Concept: Ship Advisor**
- Daily AI summary: "Here's what's ready to ship and what's blocking"
- Auto-generate release notes from commits
- "This project hasn't been released in 45 days — here's what changed"
- Pre-release checklist generated per project type
- Risk assessment: "This release has 847 changed lines — consider a beta first"

## Discussion Log

### Key Tension: Active vs. Passive
The app can't demand attention. The best daily-use apps work passively:
- **Passive**: Menubar icon, git hooks, background monitoring
- **Active**: Ship checklist, version bump buttons, release wizard

The ideal: passive awareness → active when ready → rewarding after shipping

### The "1% Better" Framework
Don't try to make users do releases. Make the release process so easy that
NOT releasing feels like more work than releasing:
- See unreleased commits → one click → version bumped + tagged + pushed + released
- Total time: 10 seconds (vs. 5 minutes of terminal commands)

## Synthesis

### Key Insights
1. **Daily use comes from passive awareness, not active features** — menubar presence + background tracking
2. **The "morning dashboard" pattern** drives daily engagement if it shows genuinely useful info
3. **Release debt is the killer metric** — unreleased commits × days = urgency score
4. **One-click release flow** removes the friction that causes procrastination
5. **Gamification works for solo devs** — shipping streaks, badges, year-in-review
6. **AI as release coach** can generate release notes, assess risk, and nudge

### Decision Points
- Menubar app: native macOS menubar extra or Flutter overlay?
- Git hooks: global install or per-project opt-in?
- Gamification: built into the main app or separate "ship score" view?

### Next Steps (Prioritized)
1. **Release Pulse dashboard** — morning view showing projects ranked by release urgency
2. **One-click release flow** — bump → tag → push → GH release in one button
3. **Menubar presence** — tray icon showing release status
4. **Ship streak tracking** — weekly shipping history with streak counter
5. **AI release notes** — auto-generate from commits via Claude CLI
6. **Release debt metric** — unreleased commits × days since last release
7. **Background monitoring** — detect when projects accumulate unreleased work
