# Brainstorm: Multi-Technology Project Detection & Display
**Date**: 2026-03-12
**Type**: problem-solving + ideation

## Central Question
How do we detect and elegantly display projects that use multiple technologies (Flutter+Rust, React+Python backend, monorepos) without cluttering the UI for simple single-tech projects?

## Mind Map

```
                         ┌─── Detection Strategy
                         │    ├── Root-level marker files (current)
                         │    ├── 1-level subfolder scan
                         │    ├── Known patterns (flutter+rust/, frontend/+backend/)
                         │    └── Primary vs Secondary tech concept
                         │
                         ├─── Display Strategy
                         │    ├── Stacked/overlapping icons
                         │    ├── Primary icon + secondary dots
                         │    ├── Icon + tech badges
                         │    └── Expandable tech stack row
                         │
  [MULTI-TECH PROJECTS]  ├─── Data Model
                         │    ├── List<ProjectType> instead of single
                         │    ├── Primary type + Set<secondary>
                         │    ├── ProjectStack concept
                         │    └── Filter: match ANY vs ALL
                         │
                         ├─── Common Patterns
                         │    ├── Flutter + Rust FFI (rust/ subfolder)
                         │    ├── React/Next + Node/Python API
                         │    ├── Monorepo (packages/, apps/)
                         │    ├── Mobile + native (ios/, android/)
                         │    └── Full-stack frameworks (Rails, Next.js)
                         │
                         ├─── Constraints
                         │    ├── Performance (don't deep-scan on every load)
                         │    ├── UI clutter (single-tech = 90% of projects)
                         │    ├── Filter bar overflow with too many chips
                         │    └── Detection accuracy (false positives)
                         │
                         └─── Wild Cards
                              ├── Auto-detect workspace type (monorepo tool?)
                              ├── Read CI config for tech hints
                              └── Dockerfile/docker-compose as hints
```

## Deep Dive 1: Detection Strategy

### Current Approach (Single Type)
- Check root for marker files in priority order
- First match wins → misses secondary technologies

### Proposed: Multi-Type Detection

**Tier 1 — Root scan (what we do now, but collect ALL matches)**
```
pubspec.yaml         → Flutter/Dart
package.json         → Node/React/TS
Cargo.toml           → Rust
go.mod               → Go
requirements.txt     → Python
build.gradle(.kts)   → Kotlin/Java
*.xcodeproj          → iOS/Swift
Gemfile              → Ruby
composer.json        → PHP
CMakeLists.txt       → C/C++
Dockerfile           → (hint, not primary)
docker-compose.yml   → (hint, not primary)
```

**Tier 2 — 1-level subfolder scan for known patterns**
Only check specific well-known subfolder names:
```
rust/Cargo.toml      → +Rust (Flutter FFI pattern)
native/Cargo.toml    → +Rust
frontend/package.json → +React/Node
backend/             → check for Python/Go/Node markers
server/              → check for Python/Go/Node markers
api/                 → check for Python/Go/Node markers
web/                 → check for React/Node markers
ios/                 → +iOS (if not already Flutter)
android/             → +Android
packages/            → monorepo hint
apps/                → monorepo hint
```

**Key insight**: Only scan known subfolder names, NOT arbitrary depth. This keeps it fast and avoids false positives from `node_modules/` or `build/` artifacts.

### Primary vs Secondary

The **first detected type at root level** = primary (determines the main icon).
Additional types found = secondary (shown as small badges).

This means:
- `pubspec.yaml` at root + `rust/Cargo.toml` → Primary: Flutter, Secondary: [Rust]
- `package.json` at root + `server/requirements.txt` → Primary: React/Node, Secondary: [Python]
- Only `pubspec.yaml` → Primary: Flutter, Secondary: [] (clean, no clutter)

## Deep Dive 2: Display Strategy

### Single-tech project (90% case)
```
┌──────────────────────────────────────────┐
│ [Flutter]  my_app                        │
│   icon     ~/Projects/my_app             │
│            Flutter                       │
└──────────────────────────────────────────┘
```
No change from current. Clean, simple.

### Multi-tech project
**Option A: Stacked icons (RECOMMENDED)**
```
┌──────────────────────────────────────────┐
│ [Flutter]  project_launcher              │
│  [Rust]    ~/Projects/project_launcher   │
│  overlap   Flutter · Rust                │
└──────────────────────────────────────────┘
```
Primary icon full-size, secondary icon small + overlapping bottom-right corner.
Like how app badges work on iOS. Familiar pattern.

**Option B: Primary icon + colored dots**
```
┌──────────────────────────────────────────┐
│ [Flutter]  project_launcher              │
│   icon     ~/Projects/project_launcher   │
│   •••      Flutter  ●Rust  ●FFI         │
└──────────────────────────────────────────┘
```
Small colored dots below the primary icon, one per secondary tech.

**Option C: Tech badge row (on the tags line)**
```
┌──────────────────────────────────────────┐
│ [Flutter]  project_launcher              │
│   icon     ~/Projects/project_launcher   │
│            [Flutter] [Rust] [FFI]        │
└──────────────────────────────────────────┘
```
Use the existing language tag style but show multiple. Already partially works.

### Recommendation: Option A (stacked) + Option C (badge row)
- Icon area: primary icon with small secondary overlay
- Tags row: show all detected technologies as colored badges
- Filter bar: clicking any tech type in filter shows projects that contain it

## Deep Dive 3: Filter Behavior

### Current: Single type filter
Click "Flutter" → show only Flutter projects

### Multi-tech filter behavior
Click "Flutter" → show projects where Flutter is primary OR secondary
Click "Rust" → show projects where Rust is primary OR secondary

This means a Flutter+Rust project appears in BOTH filters. This is correct UX.

### Filter bar overflow
With multi-tech, more types will appear in the filter bar.
Solution: Show top 6-8 most common types, then a "..." overflow menu for the rest.
Sort by frequency (most projects first).

## Data Model Change

```dart
// Before
Map<String, ProjectType> _projectTypes;

// After
Map<String, ProjectStack> _projectTypes;

class ProjectStack {
  final ProjectType primary;
  final List<ProjectType> secondary;

  List<ProjectType> get all => [primary, ...secondary];
  bool contains(ProjectType type) => primary == type || secondary.contains(type);
}
```

## Synthesis

### Key Insights
1. **Don't deep-scan** — only check known subfolder names (rust/, frontend/, backend/, server/, api/, web/) for secondary tech
2. **Primary + secondary model** preserves clean single-tech display while supporting multi-tech
3. **Stacked icon overlay** is the most space-efficient display for multi-tech
4. **Filter should match ANY** — a Flutter+Rust project appears under both Flutter and Rust filters
5. **Cache aggressively** — project types rarely change, detect once and cache

### Decision Points
- Max number of secondary technologies to show? (suggest: 3)
- Should Docker/CI files count as technologies? (suggest: no, they're tooling)
- Filter bar: show all types or top N with overflow? (suggest: top 8 by frequency)

### Next Steps
1. Change `ProjectType.detect()` → return `ProjectStack` (primary + secondaries)
2. Add subfolder scanning for known patterns
3. Update `ProjectCard` icon to support overlay
4. Update filter to work with `contains()` instead of `==`
5. Sort filter chips by project count
