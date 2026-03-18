# Brainstorm: Universal Developer Adoption for Project Launcher
**Date**: 2026-03-13
**Type**: ideation + exploration

## Central Question
How can we make Project Launcher a tool that every developer wants to use — regardless of their tech stack, OS, or workflow?

## Mind Map

```
                          ┌─── What? (What does "adopted by every developer" mean?)
                          │    ├── Cross-platform (macOS → Windows → Linux)
                          │    ├── Language/framework agnostic (not just Flutter devs)
                          │    ├── Workflow-agnostic (IDE, terminal, GUI users)
                          │    ├── Scale: solo devs → enterprise teams
                          │    └── "Default tool" status (like VS Code, iTerm, Homebrew)
                          │
                          ├─── Why? (Why would devs switch to this?)
                          │    ├── Pain point: too many projects, no central dashboard
                          │    ├── Pain point: "which project was I working on?"
                          │    ├── Pain point: health/staleness goes unnoticed
                          │    ├── Pain point: context switching friction
                          │    └── Delight: beautiful UI that devs actually enjoy
                          │
                          ├─── How? (Growth & distribution strategies)
                          │    ├── Open source it (GitHub stars, community PRs)
                          │    ├── CLI companion tool (brew install project-launcher)
                          │    ├── Plugin ecosystem (IDE extensions, shell integrations)
                          │    ├── Viral loops (share stats, team features)
                          │    └── Content marketing (dev blogs, YouTube, ProductHunt)
                          │
[EVERY DEV ADOPTS THIS]──├─── Who? (Target personas & early adopters)
                          │    ├── Polyglot devs (5+ projects, multiple languages)
                          │    ├── Freelancers / consultants (many client projects)
                          │    ├── OSS maintainers (dozens of repos)
                          │    ├── Team leads (need project health visibility)
                          │    └── Students (learning multiple stacks)
                          │
                          ├─── Constraints (What's blocking adoption?)
                          │    ├── macOS only (biggest blocker)
                          │    ├── Flutter desktop maturity
                          │    ├── Discovery problem (how do devs find it?)
                          │    ├── Switching cost (devs have existing workflows)
                          │    └── Trust barrier (new tool from unknown dev)
                          │
                          └─── Wild Cards (Unconventional angles)
                               ├── AI-powered project insights ("you haven't touched X in 2 weeks")
                               ├── "Spotify Wrapped for Code" as viral marketing
                               ├── Team/org dashboard (enterprise play)
                               ├── CLI-first with optional GUI (attract terminal purists)
                               └── Integration as VS Code / JetBrains sidebar panel
```

## Deep Dives

### Deep Dive 1: Who? — Early Adopter Persona

**Winner: Freelancers/Consultants with 10-30 projects**
- Daily pain: "which project was I working on for Client X?"
- Opinionated tool adopters who blog, tweet, share
- Cross-platform polyglot (React, Flutter, Python, etc.)
- Pay for tools that save time
- Social proof influencers

**Second tier: OSS maintainers**
- Tons of repos, need health tracking
- Extremely visible — if they use it publicly, thousands see it

**Pain intensity ranking:**
1. Freelancers/Consultants (10+)
2. OSS Maintainers (10)
3. Polyglot Devs (9)
4. Tech Leads / Eng Managers (8)
5. Full-stack Solo Founders (8)
6. Agency Devs (7)
7. Students (4)
8. Single-stack Corp Devs (3)

### Deep Dive 2: How? — Three-Phase Growth Strategy

**Phase 1: "Earn the Right" (0 → 1K users)**
- Open source on GitHub
- Homebrew install: `brew install --cask project-launcher`
- ProductHunt + Hacker News launch
- Dev blog posts showing real workflows
- "Code Wrapped" as viral shareable content
- Reddit (r/programming, r/macapps), dev Twitter/Bluesky

**Phase 2: "Become Essential" (1K → 50K users)**
- CLI companion (`plauncher open/status/list/health`)
- VS Code extension (sidebar panel)
- Plugin/extension system
- GitHub Action: auto-add repos
- Alfred/Raycast integration
- Windows + Linux support

**Phase 3: "Platform Play" (50K+ users)**
- Team dashboards
- AI insights
- Marketplace for plugins/themes
- Enterprise tier (SSO, org-wide registry)
- API for third-party integrations

**Viral loops identified:**
- Code Wrapped shareable images (already built!)
- GitHub health badges for READMEs
- CLI output branding
- Referral codes (promo system exists)
- OSS project showcase page

**Open Source Strategy: Hybrid model recommended**
- Open-source core + premium features (team dashboard, AI insights)
- Follows Raycast/GitKraken/Linear model

### Key Strategic Questions Raised
1. Open source — yes/no? (5x adoption ceiling if yes)
2. CLI companion tool — trojan horse for terminal-first devs?
3. Code Wrapped → social media shareable cards = free marketing
4. Windows/Linux timeline? Flutter supports all three

## Discussion Log
- User wants to explore How (Growth) and Who (Target personas)
- Mapped pain intensity across 8 developer personas
- Identified freelancers/consultants as killer early adopter
- Laid out 3-phase growth strategy with viral loops
- Raised open source as single biggest strategic decision

## Deep Dive 3: Constraints — Current Blockers

| Blocker | Severity | Fix Difficulty |
|---------|----------|---------------|
| macOS only | CRITICAL | Medium (Flutter supports all 3) |
| No web presence / landing page | CRITICAL | Low (1-2 days) |
| Not open source | CRITICAL | Low (just publish) |
| No Homebrew/package manager | HIGH | Low |
| No CLI tool | HIGH | Medium |
| Discovery (nobody knows it) | HIGH | Ongoing |
| "Why not just use X?" positioning | HIGH | Messaging |
| No onboarding flow | MEDIUM | Medium |
| No cloud sync | MEDIUM | High |
| No plugin system | LOW (now) | High |

### Positioning Statement
"Project Launcher is the dashboard for your entire dev life — every project, every language, every tool, one place. Health scores, git status, instant launch. Think Raycast meets GitHub dashboard, but local-first."

### Competitor Counter-Arguments
- VS Code workspaces → No health scores, no cross-editor, no dashboard
- Terminal aliases → No visibility, no staleness tracking
- Raycast/Alfred → Can find files, but no project intelligence
- GitHub dashboard → Only git repos, no local-first
- JetBrains → Locked to JetBrains ecosystem
- "I just remember" → Works with 3 projects, not 15

## Deep Dive 4: Wild Card Ideas

### 1. "Dev Wrapped" — Viral Marketing Feature
- Beautiful shareable card with yearly coding stats
- Spotify Wrapped generates 60M+ social shares/year
- Already have the stats engine — just need card template + branding
- Every share = free marketing

### 2. CLI as Trojan Horse
- `brew install plauncher` → instant entry point for terminal devs
- Commands: list, open, health, status, wrapped
- CLI feeds users into the GUI ("Want the full dashboard? Run `plauncher gui`")

### 3. GitHub Health Badges
- `![Health](projectlauncher.dev/badge/user/repo)` in READMEs
- Every badge view = brand impression, click = landing page visit
- Spreads organically across thousands of repos

### 4. "Project Launcher for Teams" (Revenue Play)
- Solo: Free/freemium (local dashboard, health, CLI)
- Team: $8/dev/month (shared registry, team health, Slack, onboarding)
- One champion → entire team adopts

### 5. Raycast/Alfred Extension
- Integrate into existing launchers instead of competing
- `⌘Space → "pl client-api"` → open, health, copy path
- Zero friction, meets devs where they are

## Adoption Flywheel
Discovery → Try (CLI/GUI) → "Wow" moment (<30s) → Daily habit → Share Code Wrapped → Recommend to team → (loops back)

## Synthesis

### Key Insights
1. **Freelancers/consultants with 10-30 projects are the killer early adopter** — highest pain, most influential, willing to pay
2. **Open sourcing is the single highest-leverage decision** — dev tools that aren't OSS face a massive trust barrier
3. **CLI companion is the trojan horse** — terminal devs won't download a GUI first, but will `brew install` in 5 seconds
4. **"Dev Wrapped" is your viral marketing engine** — already 80% built, just needs beautiful shareable cards with branding
5. **The flywheel is: discover → try → wow → habit → share → recommend** — every feature should serve one of these stages
6. **Positioning must be clear: "dashboard for your entire dev life"** — not another launcher, not another IDE, it's the meta-layer

### Decision Points
1. **Open source: yes or hybrid?** (Recommended: hybrid — OSS core + premium features)
2. **CLI: build in Rust or Dart?** (Rust = fast + cross-platform + credibility with systems devs)
3. **Windows/Linux: when?** (Before or after initial growth push?)
4. **Landing page / web presence: what domain?** (projectlauncher.dev?)
5. **Free vs freemium vs paid?** (Recommended: generous free tier + team paid tier)
6. **Launch venue: ProductHunt, HN, or both?** (Both, staggered by 1 week)

### Next Steps (Prioritized)

**Quick Wins (This Week)**
- [ ] Create a landing page (even a single-page site on projectlauncher.dev)
- [ ] Make "Dev Wrapped" card shareable with branding watermark
- [ ] Write positioning copy and README for GitHub
- [ ] Set up Homebrew cask formula

**Short Term (This Month)**
- [ ] Open source the repo (or prepare hybrid OSS structure)
- [ ] Build CLI companion (`plauncher list/open/health/status`)
- [ ] Launch on ProductHunt + write HN "Show HN" post
- [ ] Create 2-3 blog posts / dev.to articles showing real workflows
- [ ] Add first-run onboarding flow (scan → wow moment in <30 seconds)

**Medium Term (Next Quarter)**
- [ ] Windows + Linux builds
- [ ] VS Code extension (sidebar panel)
- [ ] Raycast/Alfred extension
- [ ] GitHub health badge service
- [ ] Referral system (give a month, get a month)

**Long Term (6+ Months)**
- [ ] Team dashboard / enterprise features
- [ ] AI-powered project insights
- [ ] Plugin/extension ecosystem
- [ ] API for third-party integrations
