# launcher_models

Pure Dart data models — no Flutter dependency.

## Commands

| Command | What it does |
|---------|-------------|
| `dart analyze --fatal-infos` | Static analysis |
| `dart pub get` | Resolve dependencies |

## Key Exports

- `Project` — Core project model with metadata, paths, tags
- `HealthScoreDetails`, `StalenessLevel`, `CachedHealthScore` — health metrics
- `AIInsight`, `ClaudeSkill` — AI-generated insights and skill definitions
- `ReleaseInfo`, `ReadinessScore`, `ReadinessItem` — release readiness
- `ComplianceReport`, `ComplianceItem` — compliance audit data
- `SBOMEntry`, `SecretFinding` — supply chain security models
- `DeploymentConfig`, `ReleaseProcess`, `ReleaseStep` — deployment config
- `ShipReadiness`, `ShipCategory`, `ShipCheckItem` — ship checklist

## Patterns

- JSON serialization: `factory Model.fromJson(Map)` + `.toJson()`
- Immutable updates: `.copyWith()` on all models
- Enum-based states: `HealthCategory`, `CheckMode`, `CheckStatus`
- Scoring: weighted categories (health = git 40 + deps 30 + tests 30)
- Staleness rings: 30/90/180/365 day thresholds
- Zero external dependencies (Dart SDK only)
