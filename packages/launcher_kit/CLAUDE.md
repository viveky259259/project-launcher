# launcher_kit

UIKit-inspired component library — layout, forms, and UI elements.

## Commands

| Command | What it does |
|---------|-------------|
| `dart analyze --fatal-infos` | Static analysis |
| `flutter pub get` | Resolve dependencies |

## Key Exports

- **Layout:** `UkContainer`, `UkGrid`, `UkCol`, `UkSection` (12-column responsive grid)
- **Elements:** `UkHeading`, `UkBadge`, `UkProgress`, `UkSpinner`, `UkTable`, `UkList`, `UkIcon`, `UkSkeleton`, `UkDivider`
- **Forms:** `UkInput`, `UkSelect`, `UkToggle`, `UkCheckbox`, `UkSwitch`, `UkSlider` + validators
- **Components:** `UkButton`, `UkCard`, `UkAlert`, `UkAccordion`, `UkTabs`, `UkModal`, `UkTooltip`, `UkDropdown`, `UkNotification`, `UkPagination`, `UkNavbar`, `UkCarousel`, `UkOverlay`, and more

## Patterns

- All components use `Uk` prefix (UIKit convention)
- `UkBreakpoint` enum: xs, sm, md, lg, xl
- `UkGrid` + `UkCol` for 12-column responsive layouts (16px default gap)
- `UkContainer` for max-width containers with responsive padding
- Zero external dependencies (Flutter SDK only)
