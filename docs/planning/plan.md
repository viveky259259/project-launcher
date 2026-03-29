# Project Launcher — Adoption Plan

## Mission
Make Project Launcher the default dashboard for every developer's project workflow.

## Positioning
> "The dashboard for your entire dev life — every project, every language, every tool, one place."

---

## Phase 1: Quick Wins (This Week)

### 1. Brand the "Dev Wrapped" Card for Social Sharing
- Make Year in Review generate a beautiful, branded shareable card
- Add "Made with Project Launcher" watermark + URL
- Save as high-quality PNG optimized for Twitter/LinkedIn (1200x675 or 1080x1080)
- Include: total commits, top language, most active project, monthly chart, streak
- One-tap share flow: Save to Desktop + Copy text

### 2. GitHub README
- Write a compelling README.md for the GitHub repo
- Hero screenshot/GIF of the dashboard
- Feature list with screenshots
- Quick install instructions
- "Why Project Launcher?" section with positioning
- Comparison table vs alternatives

### 3. Landing Page (projectlauncher.dev)
- Single-page site with hero, features, screenshots, download CTA
- Can be a simple Flutter web build or static site
- Must have: download button, screenshots, feature highlights

### 4. Homebrew Cask Formula
- Create a Homebrew cask so devs can `brew install --cask project-launcher`
- Requires a DMG or ZIP hosted somewhere (GitHub Releases)

---

## Phase 2: Short Term (This Month) -- DONE

### 5. Open Source (Hybrid Model) -- DONE
- [x] MIT LICENSE already exists
- [x] Added CONTRIBUTING.md with dev setup, PR guidelines, code structure
- [x] Added CODE_OF_CONDUCT.md (Contributor Covenant)
- [ ] Actually push repo to GitHub (manual step)

### 6. CLI Companion Tool -- DONE
- [x] Built `plauncher` in Rust (cli/ directory)
- [x] `plauncher list` — all projects with health, branch, last commit, indicators
- [x] `plauncher open <name> --in code|terminal|finder` — fuzzy match + open
- [x] `plauncher health` — summary with healthy/attention/critical counts + unpushed
- [x] `plauncher status` — git status across all projects
- [x] Installed to ~/bin/plauncher

### 7. Launch Campaign -- DRAFTED
- [x] Drafted Show HN post (launch-content.md)
- [x] Drafted ProductHunt tagline, description, maker comment
- [x] Drafted dev.to article outline
- [x] Drafted Reddit posts (r/FlutterDev, r/macapps, r/programming)
- [x] Drafted Twitter/Bluesky launch thread
- [ ] Execute launch (manual step)

### 8. First-Run Onboarding -- DONE
- [x] Auto-scan triggers on first launch when projects list is empty
- [x] Existing onboarding screen shows when no projects (welcome + scan + manual add)
- [x] SharedPreferences flag `hasCompletedOnboarding` prevents re-triggering

---

## Phase 3: Medium Term (Next Quarter)

### 9. Windows + Linux Builds -- DONE
- [x] Created PlatformHelper service with cross-platform abstractions
- [x] Updated all services (launcher, storage, health, stats, referral, premium, scanner)
- [x] Updated all screens (home, health, year_review, project_card)
- [x] Updated native_lib.dart with Windows/Linux library paths

### 10. VS Code Extension (Sidebar Panel) -- DONE
- [x] Built TreeDataProvider-based extension with project list + health summary
- [x] Activity bar icon, context menus, file watcher for auto-refresh
- [x] Commands: open in VS Code, Terminal, Finder, copy path, refresh

### 11. Raycast / Alfred Extension -- DONE
- [x] Built Raycast extension with search-projects and health-summary commands
- [x] Searchable project list with actions (VS Code, Terminal, Finder, copy)

### 12. GitHub Health Badge Service -- DONE
- [x] Built badge-service/ with Vercel-deployable serverless function
- [x] Endpoints: /health, /category, /git, /breakdown with 3 badge styles
- [x] Landing page with live badge previews and usage instructions
- [x] Added `plauncher badge <name>` CLI command generating shields.io markdown
- [x] Generates both shields.io (works now) and self-hosted badge URLs

### 13. Referral System Enhancement -- DONE
- [x] Added 2 new reward tiers: Early Bird (1 referral), Custom Accent Color (7 referrals)
- [x] Added Share button with pre-written message + Twitter intent link
- [x] Added "Next reward" progress bar in referral code card
- [x] Gradient background on referral code card
- [x] Updated reward gradients for new tiers

---

## Phase 4: Long Term (6+ Months)

### 14. AI-Powered Project Insights — DONE
- InsightsService with heuristic analysis engine (unpushed, stale, no-tests, health trends, productivity patterns, tech stack diversity)
- Full insights UI with summary tiles, filter chips, priority-colored cards, action buttons
- Sidebar integration across all screens

### 15. Plugin Ecosystem — DONE
- PluginManifest + PluginAction models with JSON serialization
- PluginSystem: load/save/toggle/execute plugins, file-based detection, placeholder resolution
- 5 built-in plugins (Docker, GitHub, CI/CD, NPM, Flutter)
- User plugin support via ~/.project_launcher/plugins/*.json
- PluginsScreen UI with toggle switches, colored icons, action previews

### 16. Public API — DONE
- Local HTTP REST API server (ApiServer) on localhost:9847
- 7 endpoints: /api/projects, /api/projects/:name, /api/health, /api/stats, /api/status, /api/scan, /api
- CORS support, JSON pretty-printing, fuzzy project name matching
- Settings dialog in header with on/off toggle, port config, curl example
- Persists enabled state via SharedPreferences, starts on app launch

### 17. Team Dashboard — DONE
- TeamService: workspaces, members, shared projects, health summaries, activity feeds
- Import/export workspaces as JSON for team sharing
- TeamScreen: workspace list sidebar, health summary tiles, shared project cards, activity feed
- Create/delete workspaces, add/remove projects, export to clipboard
- Sidebar integration across all screens

---

## Target Persona
**Primary:** Freelancer/consultant with 10-30 projects across multiple clients and tech stacks.
**Secondary:** OSS maintainers with dozens of repos needing health visibility.

## Success Metrics
- Phase 1: Ship all quick wins, repo ready for public
- Phase 2: 1,000 GitHub stars, 500 active users
- Phase 3: 10,000 users, 3 platforms
- Phase 4: Revenue from team tier
