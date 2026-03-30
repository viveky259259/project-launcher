# Project Launcher - App Summary & Design Prompts

## App Summary

**Project Launcher** is a native macOS developer productivity app built with Flutter and Rust. It helps developers quickly find, organize, and launch their coding projects in Terminal, VS Code, or Finder — while providing health analytics, engagement features, and a freemium monetization model.

### Core Value Proposition
A command center for developers who juggle multiple projects — scan your machine, see which repos need attention, track your coding activity, and launch into any project in one click.

### Key Features

| Category | Features |
|----------|----------|
| **Project Management** | Auto-scan git repos, manual add, pin favorites, custom tags, project notes |
| **Quick Launch** | Open in Terminal, VS Code, or Finder with one click |
| **Search & Filter** | Full-text search, tag filter, health filter, staleness filter, list/folder view, sort by recent or A-Z |
| **Health Scoring** | 0-100 score based on git activity (40pts), dependencies (30pts), tests (30pts); categories: Healthy / Needs Attention / Critical |
| **Staleness Detection** | Fresh (<30d), Getting Stale (30-90d), Stale (90-180d), Abandoned (180d+) |
| **Year in Review** | Total projects, total commits, most active project, monthly activity chart, shareable stats card |
| **Referral System** | Unique codes (PLR-XXXX-XXXX), unlock Midnight theme (3 refs) and Ocean theme (5 refs) |
| **Premium (Pro)** | RevenueCat integration, Monthly/Yearly/Lifetime tiers, unlocks Year in Review + theme bypass |
| **Themes** | Light, Dark (free), Midnight, Ocean (unlockable via referrals or Pro) |
| **Rust FFI** | Native performance for git operations, health scoring, directory scanning |

### Screens
1. **Home (Project List)** — Main hub with project cards, search, filters, quick-launch actions
2. **Health Dashboard** — Categorized health overview of all projects
3. **Year in Review** — Annual coding statistics with shareable card (Pro)
4. **Referrals & Rewards** — Referral code, progress, theme unlocks
5. **Pro / Subscription** — Feature showcase, pricing tiers, purchase flow

---

## Design Prompts

Use these prompts with an AI design agent (e.g., v0, Galileo AI, or a UI/UX Claude agent) to generate modern screen designs for Project Launcher.

---

### Prompt 1: Home Screen — Project List

> Design a modern macOS desktop app screen for "Project Launcher", a developer tool. This is the main Home screen showing a list of coding projects.
>
> **Layout:**
> - Top bar with app title "Project Launcher", a search field, and icon buttons for: scan projects, add project, theme switcher, settings gear
> - Below the top bar: a horizontal filter row with pill-shaped chips for: All, Healthy, Needs Attention, Critical, Stale — plus a tag dropdown and view toggle (list/folder) and sort toggle (recent/A-Z)
> - Main content: a scrollable list of project cards
>
> **Each project card shows:**
> - Project name (bold) with a colored health dot (green/yellow/red) beside it
> - File path in muted text below
> - Tags as small colored chips
> - A truncated note line if notes exist
> - Right side: quick-action icon buttons for Terminal, VS Code, Finder, Pin (star icon, filled if pinned)
> - Subtle staleness indicator if stale (e.g., "90d inactive" in orange text)
>
> **Pinned projects** appear at the top in a distinct "Pinned" section with a subtle divider.
>
> **Style:** Dark theme (blue-gray palette), glassmorphism-inspired card backgrounds, rounded corners (12px), subtle shadows, monospace font for paths, Inter font for UI text. macOS-native feel with a sidebar-less single-panel layout. Minimal, clean, developer-focused aesthetic. No unnecessary decoration.
>
> **Dimensions:** 900x650px macOS window with traffic light buttons.

---

### Prompt 2: Health Dashboard

> Design a modern macOS desktop app screen for "Project Launcher" — the Health Dashboard.
>
> **Layout:**
> - Top bar with back navigation arrow, title "Project Health", and a refresh button
> - Summary row with three stat cards side by side:
>   - "Healthy" — green accent, count of healthy projects, circular progress ring
>   - "Needs Attention" — amber/yellow accent, count, circular progress ring
>   - "Critical" — red accent, count, circular progress ring
> - Below: a segmented control to filter by category (All / Healthy / Needs Attention / Critical)
> - Scrollable list of project health cards
>
> **Each health card shows:**
> - Project name and overall score (e.g., "87/100") with a colored progress bar
> - Three sub-score rows: Git (x/40), Dependencies (x/30), Tests (x/30) — each with a mini horizontal bar
> - Staleness badge (Fresh / Getting Stale / Stale / Abandoned) color-coded
> - Last commit date in muted text
>
> **Style:** Dark theme, data-visualization aesthetic. Use subtle gradients on progress bars (green-to-emerald for healthy, amber gradient for warning, red gradient for critical). Cards have slight glassmorphism. Clean grid alignment. Inter font. macOS-native window chrome.
>
> **Dimensions:** 900x650px.

---

### Prompt 3: Year in Review

> Design a modern macOS desktop app screen for "Project Launcher" — the Year in Review analytics page. This is a Pro feature.
>
> **Layout:**
> - Top bar with back arrow, title "2026 Year in Review", a share button, and a refresh button
> - A prominent "Pro" badge near the title
> - Hero section: large stat cards in a 2x2 grid:
>   - Total Projects (number with a folder icon)
>   - Total Commits (number with a git-commit icon)
>   - Most Active Project (project name with a fire/trophy icon)
>   - Active Projects (number with a pulse/activity icon)
> - Below: a monthly activity bar chart showing commits per month (Jan-Dec), with the current month highlighted
> - Bottom: a shareable "stats card" preview — a dark, compact, beautifully designed card showing the key stats, styled for social sharing (like Spotify Wrapped or GitHub Skyline)
>
> **Style:** Dark theme with vibrant accent colors (electric blue, purple gradients) for the data visualizations. The bar chart uses a gradient fill. Stat numbers are large and bold. The shareable card has a distinct branded look with rounded corners and a subtle grid/code pattern background. Premium feel. Inter font. macOS window.
>
> **Dimensions:** 900x650px.

---

### Prompt 4: Referrals & Rewards

> Design a modern macOS desktop app screen for "Project Launcher" — the Referrals & Rewards page.
>
> **Layout:**
> - Top bar with back arrow and title "Referrals & Rewards"
> - Hero section: user's unique referral code displayed in a large, copy-friendly card (monospace font, e.g., "PLR-A3F2-X9K1") with a copy-to-clipboard button
> - Below: "Enter a Code" input field with a submit button
> - Progress section titled "Your Rewards":
>   - A visual progress tracker (stepped/milestone style, not just a bar) showing:
>     - Milestone 1: 3 referrals — Midnight Theme (dark purple preview swatch)
>     - Milestone 2: 5 referrals — Ocean Theme (blue preview swatch)
>   - Current referral count displayed prominently (e.g., "2 of 5 referrals")
>   - Unlocked rewards shown with a checkmark and "Unlocked" badge; locked ones are dimmed
> - Bottom: small text "Share your code with fellow developers to unlock exclusive themes"
>
> **Style:** Dark theme. The referral code card should feel special — subtle glow or border shimmer effect. Progress milestones use a connected node/dot-line pattern. Theme preview swatches are small rounded rectangles showing the actual theme colors. Celebratory but not cluttered. Inter font. macOS window.
>
> **Dimensions:** 900x650px.

---

### Prompt 5: Pro / Subscription Screen

> Design a modern macOS desktop app screen for "Project Launcher" — the Pro subscription page.
>
> **Layout:**
> - Top bar with back arrow and title "Project Launcher Pro"
> - Hero section: a bold headline "Unlock the Full Experience" with a short subtitle listing Pro benefits:
>   - Year in Review analytics
>   - All premium themes unlocked
>   - Priority support
>   - Future Pro features
> - Three pricing cards side by side:
>   - Monthly: price, "per month" label
>   - Yearly: price, "per year" label, a "Best Value" badge, slight visual emphasis (larger or highlighted border)
>   - Lifetime: price, "one-time" label, a "Forever" badge
> - Each card has a "Subscribe" / "Buy" CTA button
> - Below: "Restore Purchases" link and "Manage Subscription" link in muted text
> - If already Pro: show a "You're Pro!" status banner with subscription details instead of pricing cards
>
> **Style:** Dark theme with a premium, elevated feel. Pricing cards have subtle gradient borders or glassmorphism. The "Best Value" card has a slight golden/amber accent. CTA buttons are vibrant (electric blue or purple gradient). Clean hierarchy — the eye should flow from headline to pricing to CTA. Inter font. macOS window.
>
> **Dimensions:** 900x650px.

---

### Prompt 6: Scan Projects Dialog

> Design a modern macOS modal dialog for "Project Launcher" — the project scanning overlay.
>
> **Layout:**
> - Centered modal overlay (500x400px) with a semi-transparent backdrop
> - Title: "Scan for Projects"
> - Description: "Automatically discover git repositories on your machine"
> - A list of scan locations with checkboxes (~/Projects, ~/Developer, ~/Code, ~/GitHub, etc.) — user can toggle which folders to scan
> - A "Custom Folder..." button to add additional paths via file picker
> - Scan depth selector: "Scan depth: 2 levels" with a small stepper control
> - A prominent "Start Scan" button
> - During scan: replace content with a progress indicator, current directory being scanned, and count of projects found so far
> - After scan: show results — "Found 23 new projects" with an "Add All" button and a scrollable list with checkboxes to select which to add
>
> **Style:** Dark theme modal with frosted glass background. Clean form layout. Checkbox list is compact. Progress state uses a subtle animated spinner. Results list has small project name + path rows. Inter font. Rounded corners (16px).

---

### Prompt 7: Empty State & Onboarding

> Design a modern macOS desktop app screen for "Project Launcher" — the empty/first-launch state.
>
> **Layout:**
> - Centered content on a clean dark background
> - A minimal illustration or icon (folder with a rocket, or a terminal cursor blinking)
> - Headline: "Welcome to Project Launcher"
> - Subtitle: "Your developer command center. Find, organize, and launch projects instantly."
> - Two prominent action buttons stacked vertically:
>   - "Scan My Machine" (primary, filled) — auto-discover git repos
>   - "Add a Project" (secondary, outlined) — manual add
> - Below: small muted text "We'll look in common dev folders like ~/Projects, ~/Developer, ~/Code"
>
> **Style:** Dark theme, minimal and inviting. The illustration should be simple line art or a subtle icon, not a complex graphic. Plenty of whitespace. Feels like a premium developer tool's first impression. Inter font. macOS window with traffic lights.
>
> **Dimensions:** 900x650px.

---

### Prompt 8: Theme Switcher

> Design a modern macOS popover/dropdown for "Project Launcher" — the theme switcher.
>
> **Layout:**
> - Small floating panel (280x320px) anchored to a theme icon button in the top bar
> - Title: "Theme"
> - Four theme option rows, each showing:
>   - A color palette preview (3-4 small color circles or a mini app preview thumbnail)
>   - Theme name: Light, Dark, Midnight, Ocean
>   - Status: checkmark for active, lock icon for locked themes
>   - Locked themes show "3 referrals" or "5 referrals" or "Pro" as unlock hint
> - Active theme has a highlighted/selected border
> - Bottom link: "Earn more themes" linking to the Referral screen
>
> **Style:** Dark theme popover with subtle shadow and rounded corners (12px). Each theme row is a mini card. Color previews accurately represent each theme's palette (Dark: blue-gray, Midnight: deep purple, Ocean: blue-cyan, Light: soft gray-white). Clean and compact. Inter font.
