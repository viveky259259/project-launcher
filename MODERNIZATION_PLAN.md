# Project Launcher - Modernization Plan

## Overview

Redesign the Project Launcher app to match the new FlutterFlow Designer mockups. This plan covers the visual overhaul, navigation restructuring, new screens, and architectural improvements — while preserving all existing business logic and services.

---

## Design System Changes

### New Color Palette (from FlutterFlow theme JSON)

| Token | Dark | Light |
|-------|------|-------|
| **Primary** | `#F9FAFB` | `#1A1A1A` |
| **Accent** | `#22D3EE` (cyan) | `#0891B2` (teal) |
| **Background** | `#000000` (true black) | `#F9FAFB` |
| **Surface** | `#111111` | `#FFFFFF` |
| **Secondary Text** | `#9CA3AF` | `#6B7280` |
| **Divider** | `#262626` | `#E5E7EB` |
| **Error** | `#F87171` | `#EF4444` |
| **Success** | `#4ADE80` | `#10B981` |

**Key shift:** Move from blue-gray dark theme to **true black (#000000) background** with **cyan (#22D3EE) accent**. This matches all 9 design mockups.

### Typography

| Style | Font | Size | Weight |
|-------|------|------|--------|
| headline_large | Inter | 32 | 700 |
| headline_medium | Inter | 26 | 600 |
| title_large | Inter | 20 | 600 |
| title_medium | Inter | 16 | 600 |
| body_large | JetBrains Mono | 14 | 400 |
| body_medium | JetBrains Mono | 13 | 400 |
| body_small | JetBrains Mono | 12 | 400 |
| label_large | Inter | 13 | 600 |
| label_medium | Inter | 11 | 600 |
| label_small | Inter | 10 | 600 |

**Key shift:** Add **JetBrains Mono** as secondary font for code paths, stats, and monospace content. Currently only Inter is used.

### Spacing & Radii

| Token | Value |
|-------|-------|
| xs | 4px |
| sm | 8px |
| md | 16px |
| lg | 24px |
| xl | 32px |
| radius.sm | 4px |
| radius.md | 4px |
| radius.lg | 8px |
| radius.full | 9999px |

**Key shift:** Tighter border radii (4-8px vs current 8-24px). More squared-off, developer-tool aesthetic.

---

## Navigation Overhaul

### Current: Flat push navigation
```
ProjectListScreen (home)
  -> push YearReviewScreen
  -> push HealthScreen
  -> push ReferralScreen
  -> push ProScreen
```

### New: Sidebar navigation (from designs)

The Year in Review and Referrals screens now show a **persistent left sidebar**. The Home and Health screens use a **top-bar-only** pattern. The new structure:

```
App Shell
+-- Sidebar (visible on Year Review, Referrals, Settings screens)
|   +-- Dashboard / Projects
|   +-- Favorites
|   +-- Health Dashboard
|   +-- Year in Review
|   +-- Referrals
+-- Content Area
    +-- Home (Project List) — no sidebar, top bar with filters
    +-- Health Dashboard — no sidebar, back arrow + top bar
    +-- Year in Review — sidebar + content
    +-- Referrals & Rewards — sidebar + content
    +-- Pro Subscription — no sidebar, back arrow + full page
    +-- Project Settings — sidebar (settings sub-nav) + content [NEW SCREEN]
    +-- Onboarding — no sidebar, centered content
    +-- Scan Dialog — modal overlay
    +-- Theme Switcher — popover/panel overlay
```

### Implementation approach
- Create an `AppShell` widget that conditionally shows the sidebar
- Use a route-based approach to determine sidebar visibility
- Home + Health + Pro = top-bar only (back arrow navigation)
- Year Review + Referrals + Settings = sidebar layout

---

## Screen-by-Screen Changes

### Screen 1: Home (Project List)

**Current file:** `lib/main.dart` (1819 lines — needs splitting)

**Design changes from mockup:**
- True black background (#000000)
- Top bar: macOS traffic lights (red/yellow/green dots) + "Project Launcher" title + search bar (Cmd+K hint) + icon row (scan, terminal, vscode, add, settings)
- Filter pills row: All, Healthy, Needs Attention, Stale + Sort dropdown ("Recent") + view toggle (list/grid icons)
- **Pinned section** with label "PINNED" and star-filled icons on pinned projects
- **Recent Projects** section with label "RECENT PROJECTS"
- Each project card: name + pin icon, path (monospace), language tag (colored: Rust=orange, Flutter=cyan, NodeJS=green, Python=yellow, React=blue, Go=cyan, Markdown=gray, Bash=gray), action icons (terminal, code, folder, pin), staleness text ("94d Inactive", "180d+ Inactive" in muted/warning color)
- **Right sidebar panel** with:
  - "System Health" summary: Total Projects count, Healthy count (green), Needs Attention count (amber)
  - "Activity (7d)" mini bar chart (7 bars for M-T-W-T-F-S-S)
  - "Year in Review" promo card with gradient background, "Upgrade Now" CTA
- Status bar at bottom: "Rust FFI Connected" indicator, "Last scan: 2 mins ago"

**Implementation tasks:**
1. Extract `ProjectListScreen` from main.dart into `lib/screens/home_screen.dart`
2. Create `lib/widgets/home/` directory with:
   - `project_card.dart` — individual project row
   - `pinned_section.dart` — pinned projects group
   - `filter_bar.dart` — filter pills + sort + view toggle
   - `side_panel.dart` — right sidebar with health summary + activity chart + promo
   - `status_bar.dart` — bottom status bar
3. Add language/tech detection to project cards (based on dependency files already detected by health service)
4. Add 7-day activity mini chart (use existing git_service monthly data, add weekly)
5. Add bottom status bar with FFI connection status and last scan time

---

### Screen 2: Project Health

**Current file:** `lib/screens/health_screen.dart`

**Design changes from mockup:**
- Top bar: back arrow + "Project Health" title + "Refresh Analytics" button + settings gear
- Three summary cards: Healthy (12, green ring), Needs Attention (5, amber ring), Critical (2, red ring) — with circular progress rings
- Tab bar: "All Projects (19)" | Healthy | Needs Attention | Critical
- Health cards redesigned:
  - Project name + health badge ("Healthy" green, "Needs Attention" amber, "Critical" red) + score "92/100" right-aligned
  - Path in monospace
  - Three progress bars: Git Activity (x/40), Dependencies (x/30), Tests (x/30) — color-coded with gradient fills
  - Score values right-aligned to bars
  - "Last commit: 2h ago" text
  - Staleness badge: "Fresh" (green outline), "Getting Stale" (amber), "Abandoned" (red)

**Implementation tasks:**
1. Redesign summary cards with circular progress rings (use `CustomPainter` or `CircularProgressIndicator`)
2. Update tab bar to show total count "All Projects (N)"
3. Redesign health cards with the new layout (horizontal progress bars with labels + scores)
4. Add colored health badges inline with project name
5. Add gradient fills to progress bars (green-emerald, amber, red)

---

### Screen 3: Year in Review

**Current file:** `lib/screens/year_review_screen.dart`

**Design changes from mockup — MAJOR REDESIGN:**
- **Sidebar navigation** on the left: Project Launcher logo + nav items (Dashboard, All Projects, Health Check, Year in Review active)
- Top: "2024 Year in Review" title + PRO badge + "Export PDF" + "Share Stats" buttons
- Subtitle: "A deep dive into your coding journey over the last 12 months."
- **4 stat cards** in a row (not 2x2):
  - Total Commits: 2,842 (with "+12% vs 2023" delta, cyan icon)
  - Projects Launched: 48 (with "+4 new" delta, magenta icon)
  - Coding Hours: 1,240 (purple icon) **[NEW STAT]**
  - Longest Streak: 22 Days (amber icon) **[NEW STAT]**
- **Commit Activity** bar chart (full width, Jan-Dec, dark bars)
- **Top Languages** donut/pie chart (Python, Rust, TypeScript, Go, etc.) **[NEW]**
- **Most Active Projects** list: ranked by commits (Project Launcher 842, Oxide Engine 612, etc.)
- **Shareable "Wrapped" card** (bottom-right): GitHub-style branded card with key stats

**Implementation tasks:**
1. Add sidebar layout wrapper for this screen
2. Redesign stat cards to horizontal 4-card row with delta indicators
3. Add new stats: Coding Hours (estimate from commits), Longest Streak
4. Replace current bar chart with cleaner implementation
5. Add Top Languages donut chart (detect from project dependency files)
6. Add Most Active Projects ranked list
7. Redesign shareable card to match "2024 WRAPPED" style
8. Add "Export PDF" functionality

---

### Screen 4: Referrals & Rewards

**Current file:** `lib/screens/referral_screen.dart`

**Design changes from mockup:**
- **Sidebar navigation** on the left (same as Year in Review, with "Referrals" active)
- "REFERRAL CODE" label above the code
- Large referral code card with cyan border glow: "PLR-A3F2-X9K1" + copy button
- Helper text: "Share this code. When 3 friends join, you unlock the Midnight theme."
- Right-side stat cards: "TOTAL REFERRALS: 2" and "REWARDS EARNED: 0"
- **Milestone Progress** section: progress bar "2/5 to next reward"
- Three reward rows:
  - Midnight Theme (3 Referrals) — purple gradient swatch + lock icon
  - Oceanic Theme (5 Referrals) — blue gradient swatch + lock icon
  - **Founder Badge** (10 Referrals) — new reward! "Exclusive profile badge and priority support access" **[NEW REWARD]**
- Bottom: "Been referred by a friend?" section with code input + "Redeem" button
- User avatar/name in bottom-left sidebar: "John Dev, Pro Member"

**Implementation tasks:**
1. Add sidebar layout wrapper
2. Redesign referral code card with cyan border glow effect
3. Add stat cards (Total Referrals, Rewards Earned)
4. Redesign milestone progress as stepped tracker with progress bar
5. Add Founder Badge as third reward tier (10 referrals)
6. Move "enter code" section to bottom with "Been referred by a friend?" framing
7. Add user profile display in sidebar

---

### Screen 5: Pro Subscription

**Current file:** `lib/screens/pro_screen.dart`

**Design changes from mockup:**
- Back arrow + "Project Launcher Pro" + "Restore Purchases" + "Support" links in top bar
- **"POWER USER FEATURES"** badge (cyan)
- Headline: "Unlock the Full Potential of Your Workflow"
- Subtitle: "Advanced analytics, custom themes, and native performance optimizations for serious developers."
- **Feature list with icons** (4 items):
  - Year in Review — analytics description
  - Premium Themes — theme unlock description
  - **Priority Indexing** — faster scanning for monorepos **[NEW FEATURE DESCRIPTION]**
  - **Cloud Backup** — sync across machines **[NEW FEATURE DESCRIPTION]**
- **Activity preview chart** on the right (mini bar chart showing "2024 ACTIVITY")
- **Pricing section:** "Simple, Transparent Pricing" heading + "Choose the plan that fits your development scale"
  - Monthly: $4.99/mo — All Themes, Year in Review, Priority Support
  - Annual: $39.99/yr — 2 Months Free, Cloud Sync, Beta Feature Access + **"BEST VALUE"** ribbon
  - Lifetime: $99.00 — One-time Payment, Forever Updates, Founder Badge
- CTA buttons: "Start Monthly" (outline), "Get Yearly Pro" (cyan filled, prominent), "Go Lifetime" (outline)
- Footer: Privacy Policy | Terms of Service | Manage Subscription + "Secured by RevenueCat. Cancel anytime."

**Implementation tasks:**
1. Redesign hero section with feature list + activity preview
2. Redesign pricing cards with new layout and pricing
3. Add "BEST VALUE" ribbon to annual card
4. Differentiate CTA styles (outline vs filled for annual)
5. Add footer with legal links
6. Add activity preview mini chart

---

### Screen 6: Scan Projects Dialog (Modal)

**Current:** Inline scanning in ProjectListScreen

**Design changes from mockup:**
- Centered modal overlay with dark semi-transparent backdrop
- Title: "Scan for Projects" + close (X) button
- Subtitle: "Automatically discover git repositories on your machine"
- "SELECT DIRECTORIES" label
- Checkbox list with cyan checkboxes:
  - ~/Projects — "Main development folder" (checked, cyan border)
  - ~/Developer — "Apple SDKs and workspace" (checked, cyan border)
  - ~/Documents/Code — "Miscellaneous scripts" (unchecked)
  - /Volumes/External/Archive — "Custom external drive" (unchecked)
- Each row has a delete (trash) icon to remove custom paths
- "+ Add Custom Folder..." button
- **Scan Depth** control: minus/plus stepper with "2 Levels" display
- **Scanning state:** animated magnifier icon + "Scanning Filesystem..." text + current path being scanned (cyan text) + stats: "DIRECTORIES: 1,248 | REPOS FOUND: 42 | ELAPSED: 0:14s"
- Bottom: "Press ESC to dismiss" hint + action buttons (cyan + magenta)

**Implementation tasks:**
1. Create `lib/widgets/scan_dialog.dart` as a proper modal
2. Add directory list with descriptions and delete capability
3. Add custom folder picker with trash icon
4. Add scan depth stepper control
5. Redesign scanning progress state with animated icon + live stats
6. Add ESC-to-dismiss hint
7. Show elapsed time during scan

---

### Screen 7: Onboarding & Empty State

**Current:** Simple `_EmptyState` widget in main.dart

**Design changes from mockup — MAJOR UPGRADE:**
- **Sidebar navigation** visible (Projects active, Favorites, Health Dashboard, Year in Review)
- Terminal/code icon centered
- "Welcome to your command center" headline
- Subtitle: "Project Launcher organizes your local repositories and gives you instant access to your code. Let's get started by indexing your machine."
- **Two action cards** side by side:
  - "Auto-Scan Machine" — magnifier icon, description, "Start Deep Scan" button (cyan)
  - "Add Manually" — plus icon, description, "Browse Files..." button (magenta/pink)
- **Bottom feature highlights:** "Built for modern workflows" with three items:
  - Instant Launch — "Open in VS Code or Terminal"
  - Health Scoring — "Git activity & dependency audits"
  - Smart Tags — "Auto-categorize by language"
- Status bar: "Rust Engine Active" indicator (green)
- Bottom text: "Default scan paths: ~/Projects, ~/Developer, ~/Code"

**Implementation tasks:**
1. Create `lib/screens/onboarding_screen.dart`
2. Two-card layout for scan/manual add
3. Feature highlights row at bottom
4. Show sidebar with nav items (even in empty state)
5. Rust FFI status indicator

---

### Screen 8: Theme Switcher (Popover)

**Current:** Theme switching in settings/preferences

**Design changes from mockup:**
- Popover panel anchored to settings gear, right-aligned
- "Appearance" title + close (X) button
- Four theme rows:
  - Dark — "Default system theme" — three color dots (red/green/blue?) + active checkmark, cyan border
  - Light — "High contrast workspace" — gray dots + info icon
  - Midnight — "Unlock with 3 referrals" (amber text) — purple dots + lock icon
  - Ocean — "Unlock with 5 referrals" (amber text) — cyan dots + lock icon
- Active theme has cyan highlight border
- **"Earn Premium Themes"** card at bottom — "Share your referral code" with arrow, teal background
- **"Unlock All with Pro"** button (magenta/pink gradient, full width)

**Implementation tasks:**
1. Create `lib/widgets/theme_switcher.dart` as an overlay/popover
2. Theme rows with color dot previews and status icons
3. Active state with cyan border highlight
4. Lock state with referral requirement text
5. "Earn Premium Themes" link card
6. "Unlock All with Pro" CTA button

---

### Screen 9: Project Settings [NEW SCREEN]

**Current:** No dedicated settings screen (tags/notes edited via dialogs)

**Design from mockup:**
- **Left sidebar** with settings sub-navigation:
  - General Settings (active)
  - Health Rules
  - Environment
  - Git Configuration
- Project avatar (initials "PL") + project name + health badge + score
- **"Project Identity"** section:
  - Display Name field
  - Project Path field with "Move" button
- **"Quick Launch"** section:
  - Primary Terminal: iTerm2 (Default) with "Change" button
  - Editor: VS Code Insiders with "Change" button
- **"Tags & Categorization"** section:
  - Tag chips (Rust, Flutter, macOS, Desktop) with checkmarks, colored
  - "+ Add Tag" button
  - Project Notes textarea
- **"Health Overrides"** section:
  - Toggle: Ignore Dependency Alerts
  - Toggle: Strict Git History
  - Slider: Custom Health Threshold (80%)
- **"Danger Zone"** section (red accent):
  - "Removing the project from Launcher will not delete the local files."
  - "Remove Project" button (red)
- Top-right: "Discard" + "Save Changes" buttons
- Bottom-left: "Back to Dashboard" link

**Implementation tasks:**
1. Create `lib/screens/project_settings_screen.dart`
2. Create settings sub-navigation sidebar
3. Build form sections: Identity, Quick Launch, Tags, Health Overrides, Danger Zone
4. Add terminal/editor selection (detect installed terminals/editors)
5. Add health override toggles and threshold slider
6. Add project removal with confirmation
7. Wire up Save/Discard actions

---

## Architecture Changes

### File Restructuring

```
lib/
+-- main.dart                    # App entry, simplified (theme + routing only)
+-- app_shell.dart               # Shell with conditional sidebar
+-- router.dart                  # Route definitions
+-- theme/
|   +-- app_theme.dart           # New theme system (true black + cyan accent)
|   +-- app_colors.dart          # Color constants per theme
|   +-- app_typography.dart      # Typography with Inter + JetBrains Mono
|   +-- app_spacing.dart         # Spacing & radii constants
+-- models/                      # (unchanged)
|   +-- project.dart
|   +-- health_score.dart
|   +-- referral.dart
+-- services/                    # (unchanged, add minor extensions)
|   +-- project_storage.dart
|   +-- health_service.dart
|   +-- stats_service.dart
|   +-- referral_service.dart
|   +-- premium_service.dart
|   +-- git_service.dart
|   +-- native_lib.dart
|   +-- project_scanner.dart
|   +-- launcher_service.dart
+-- screens/
|   +-- home_screen.dart         # Extracted from main.dart
|   +-- health_screen.dart       # Redesigned
|   +-- year_review_screen.dart  # Redesigned with sidebar
|   +-- referral_screen.dart     # Redesigned with sidebar
|   +-- pro_screen.dart          # Redesigned
|   +-- project_settings_screen.dart  # NEW
|   +-- onboarding_screen.dart   # NEW
+-- widgets/
|   +-- sidebar.dart             # Reusable sidebar navigation
|   +-- home/
|   |   +-- project_card.dart
|   |   +-- pinned_section.dart
|   |   +-- filter_bar.dart
|   |   +-- side_panel.dart
|   |   +-- status_bar.dart
|   +-- health/
|   |   +-- summary_card.dart
|   |   +-- health_project_card.dart
|   |   +-- progress_bar.dart
|   +-- charts/
|   |   +-- activity_bar_chart.dart
|   |   +-- donut_chart.dart
|   |   +-- mini_activity_chart.dart
|   +-- scan_dialog.dart
|   +-- theme_switcher.dart
|   +-- status_bar.dart
+-- kit/                         # (keep existing, update theme tokens)
```

### Phase Plan

**Phase 1: Foundation** (theme + structure)
1. Create new theme system (`theme/` directory) matching design colors
2. Add `google_fonts` dependency for JetBrains Mono (already have Inter)
3. Create `app_shell.dart` with conditional sidebar
4. Extract `ProjectListScreen` from main.dart into `home_screen.dart`
5. Simplify `main.dart` to just app setup + routing

**Phase 2: Home Screen** (highest-impact screen)
1. Build new home screen layout with right sidebar panel
2. Create project card widgets matching new design
3. Add language/tech tag detection and colored badges
4. Add system health summary panel
5. Add 7-day activity mini chart
6. Add bottom status bar

**Phase 3: Health Dashboard**
1. Redesign summary cards with circular progress rings
2. Redesign health project cards with new progress bar layout
3. Update color scheme to match new theme

**Phase 4: Year in Review**
1. Add sidebar layout
2. Build 4 horizontal stat cards with deltas
3. Build commit activity bar chart
4. Add top languages donut chart
5. Add most active projects list
6. Redesign shareable wrapped card

**Phase 5: Supporting Screens**
1. Redesign Referrals screen with sidebar + new layout
2. Redesign Pro screen with new pricing layout
3. Build Onboarding screen
4. Build Scan Dialog modal
5. Build Theme Switcher popover

**Phase 6: New Features**
1. Build Project Settings screen
2. Add terminal/editor detection for Quick Launch config
3. Add health overrides (ignore alerts, strict git, threshold slider)
4. Add Founder Badge reward tier

---

## Dependencies to Add

```yaml
# pubspec.yaml additions
google_fonts: ^6.1.0  # already present, ensure JetBrains Mono works
```

No new package dependencies needed — the existing kit/ components + Flutter's built-in widgets cover everything. Charts will be built with `CustomPainter` (already used for the current bar chart).

---

## What NOT to Change

- **Services layer** — all business logic stays as-is
- **Models** — data models stay as-is (minor additions for new stats)
- **Rust FFI** — no changes needed
- **RevenueCat integration** — keep existing, just update UI
- **kit/ components** — keep and continue using, update theme tokens
- **Data persistence** — same JSON files + SharedPreferences
