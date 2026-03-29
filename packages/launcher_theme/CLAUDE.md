# launcher_theme

Design system package — colors, typography, spacing, and switchable skins.

## Commands

| Command | What it does |
|---------|-------------|
| `flutter test` | Run tests (skin tests in root `test/skin/`) |
| `dart analyze --fatal-infos` | Static analysis |
| `flutter pub get` | Resolve dependencies |

## Key Exports

- `AppTheme` enum — light, dark, midnight, ocean base themes
- `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius` — design tokens
- `AppSkin` abstract class — 5 implementations: Default, Minimal, Corporate, Gaming, Terminal
- `SkinProvider` — InheritedWidget for providing skin context to widget tree
- `SkinColors`, `SkinTypography`, `SkinSpacing`, `SkinRadius` — per-skin customization
- `SkinCardStyle`, `SkinToolbarStyle`, `SkinAnimations` — component-specific styling
- `SkinMetadata` — unlock requirements and reward IDs
- `TextStyleExtensions` — `.bold`, `.semiBold`, `.withColor()`, `.withSize()`
- `MediaQueryBreakpoints` — responsive breakpoint helpers on BuildContext

## Patterns

- Enum-based theme selection with computed properties via extensions
- InheritedWidget pattern for skin propagation (`SkinProvider.of(context)`)
- Immutable value objects for all design tokens
- Skins can be locked/unlocked via reward IDs in `SkinMetadata`

## Dependencies

- `google_fonts: ^6.1.0` (Inter for UI, JetBrains Mono for code)
