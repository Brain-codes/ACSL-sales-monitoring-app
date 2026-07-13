# design.md — Design System (single source of visual truth)

All visual tokens live here and in `lib/core/constants/app_colors.dart`. A redesign = edit this file + the token file; screens reference tokens only, never raw values.

## Brand (migrating blue → green)

| Token | Value | Notes |
|---|---|---|
| `brandPrimary` | `#4A5D0F` | green — buttons, headers, active nav parent |
| `brandHeader` | `#6B8519` | green mid |
| `brandLight` | `#EEF3C4` | green tint — active child bg, light surfaces |
| ~~old blue~~ | `#07376A` / `#194977` / `#EFF6FF` | **commented out** in `app_colors.dart`, kept for rollback |

The brand circulates around green. Blue is not deleted — flip back by uncommenting the blue block and commenting the green block in `app_colors.dart`.

## Semantic colors

| Token | Value |
|---|---|
| `success` | `#22C55E` |
| `error` | `#EF4444` |
| `warning` | `#F59E0B` |
| `textPrimary` | `#0F172A` |
| `textMuted` | `#64748B` |
| `borderColor` | `#E2E8F0` |
| `cardBg` / surface | `#F8FAFC` |
| `white` | `#FFFFFF` |
| `offlineBanner` / text | `#FEF3C7` / `#92400E` |

## Navigation (mirrors web sidebar)

- Sidebar selected parent: bg `brandPrimary` (`#4A5D0F`), text white.
- Sidebar selected child: bg `brandLight` (`#EEF3C4`), text `brandPrimary`.
- Bottom nav: selected `brandPrimary`, unselected `textMuted`, fixed type, white bg.

## Spacing & radius

- Spacing scale (dp): 4, 8, 12, 16, 20, 24.
- Radius: inputs/buttons **8**, cards **12**, chips **20** (pill).
- Card padding 16; input padding 16 horizontal / 14 vertical.
- Buttons: height **50**, elevation **0**, label 15 / W600, full width by default.

## Typography

| Style | Size | Weight | Color |
|---|---|---|---|
| headlineLarge | 24 | W700 | textPrimary |
| headlineMedium | 20 | W700 | textPrimary |
| titleLarge | 18 | W600 | textPrimary |
| titleMedium | 16 | W600 | textPrimary |
| bodyLarge | 16 | W400 | textPrimary |
| bodyMedium | 14 | W400 | textPrimary |
| bodySmall | 12 | W400 | textMuted |
| labelMedium | 12 | W500 | textMuted |

Fonts via `google_fonts`. AppBar title 18 / W600 / white.

## Charts & gradients (decoupled from brand)

KPI gradient pairs and 6-color chart palette live in `app_colors.dart` (`gradient*`, `chartColors`). These are data-viz palettes, not brand — change independently.
