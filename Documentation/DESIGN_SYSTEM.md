# Design System

Location: `NativeBusinessApp/Core/DesignSystem` and `Resources/Assets.xcassets`.

## Color tokens (`AppColors`)

Every token is an asset color with **light and dark** variants, accessed through Xcode-generated
`ColorResource` symbols, so a missing asset is a compile error.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `brandPrimary` | `#0D2232` | `#DCE7F1` | Headings, brand text |
| `brandSurface` | `#0D2232` | `#1B3B55` | Logo tile, avatar background (white content) |
| `actionFill` | `#0E67AA` | `#1A73B8` | Primary button fill (white text ≥ 5:1) |
| `actionText` / AccentColor | `#0E67AA` | `#6FB3EA` | Links, tinted icons, tab tint |
| `onAction` | `#FFFFFF` | `#FFFFFF` | Content on `actionFill` |
| `backgroundPrimary` | `#F4F6F9` | `#070F16` | Screen background |
| `surfaceCard` | `#FFFFFF` | `#122130` | Cards, list rows |
| `surfaceMuted` | `#EEF1F5` | `#1A2B3B` | Text fields, icon tiles, skeletons |
| `separator` (asset `DividerLine`) | `#DDE3EA` | `#243647` | Hairlines, card borders |
| `textPrimary` | `#0D2232` | `#EEF3F7` | Body text |
| `textSecondary` | `#4B5B6A` | `#A7B4C1` | Supporting text (≥ 6.5:1 on light surfaces) |
| `success` / `successBackground` | `#1B7A43` / `#E6F4EC` | `#5BCB8A` / `#12301F` | Positive trends, completed |
| `warning` / `warningBackground` | `#8A5300` / `#FDF1DE` | `#F0B44C` / `#33270F` | Pending, stale-data banners |
| `error` / `errorBackground` | `#B42318` / `#FDECEA` | `#FF8A80` / `#3A1714` | Validation, failures, destructive actions |

Contrast was checked against WCAG AA (4.5:1 for text). Status colors are never the only signal:
trends also use arrow symbols, and statuses carry text labels.

## Typography (`AppTypography`)

Built on system text styles (San Francisco), so everything scales with **Dynamic Type**.

| Token | Style |
| --- | --- |
| `largeTitle` | `.largeTitle` bold |
| `title` | `.title2` semibold |
| `sectionTitle` | `.headline` |
| `body` / `bodyEmphasized` | `.body` / semibold |
| `subheadline` / `subheadlineEmphasized` | `.subheadline` / medium |
| `caption` / `captionEmphasized` | `.caption` / semibold |
| `button` | `.body` semibold |
| `metricValue` | `.title2` semibold, monospaced digits |
| `amount` | `.subheadline` semibold, monospaced digits |

## Spacing and layout

`AppSpacing`: `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`.
`AppRadius`: `small 8 · medium 12 · large 20` (continuous corners).
`AppLayout`: `minTouchTarget 44`, `maxReadableWidth 680` (content on iPad/landscape), `maxFormWidth 440`.

Surface helpers (`AppTheme.swift`): `.appScreenBackground()`, `.cardSurface()` (hairline border and a
4% shadow instead of heavy elevation) and `.readableWidth()`.

## Components (`DesignSystem/Components`)

| Component | Notes |
| --- | --- |
| `PrimaryButton` | Full-width capsule, `isLoading` swaps the label for a spinner and adds "In progress" to the accessibility value |
| `SecondaryButton` | Outlined capsule. `role: .destructive` switches to the error color |
| `AppTextField` | Label, icon, focus/error border, inline error. Focus is driven by the parent's `FocusState` |
| `SecureTextField` | Same chrome plus a show/hide toggle (44 pt target, labelled). Never alters input |
| `AppCard` | Padded card container |
| `SectionHeader` | Header trait plus an optional trailing action ("See All") |
| `MetricCard` | KPI value, formatted change with trend arrow, one combined VoiceOver label |
| `ActivityRow` | Icon, title, subtitle, timestamp, optional amount and status. Stacks vertically at accessibility sizes |
| `StatusBadge` | Success, warning, error and neutral pills |
| `LoadingView` | Centered spinner and message |
| `SkeletonView`, `MetricCardSkeleton`, `ActivityRowSkeleton` | Placeholders that pulse, and stay static with Reduce Motion |
| `EmptyStateView` | `ContentUnavailableView` with an optional action |
| `ErrorStateView` | `ContentUnavailableView` from `UserFacingError`, with Try Again only when retryable |
| `InlineBanner` | Non-blocking info/warning/error notice with an optional action |
| `NotificationBadge` | Unread count capsule (99+), hidden at 0 |
| `ConfirmationDialog` | `.appConfirmationDialog(...)` on the native `confirmationDialog` |
| `AvatarView` | HTTPS image, or initials fallback |
| `BrandLogo` | Placeholder logo. Replace with the product mark |
| `QuickActionTile` | Square icon and label tile for the Home grid |

## Liquid Glass behaviour

- The four-tab shell uses the native `TabView` with `Tab(_:systemImage:value:)`. Built with the
  iOS 26 SDK, the tab bar renders in **Liquid Glass automatically**. No custom tab bar, no
  `UITabBarAppearance` overrides and no custom backgrounds are applied, so the system manages
  legibility as content scrolls beneath it.
- `.tabBarMinimizeBehavior(.onScrollDown)` (iOS 26 API, verified in the SDK) collapses the bar while
  scrolling down and restores it on scroll up.
- Navigation bar and toolbar buttons (Home's bell and avatar, "Mark All Read") get system glass
  through `NavigationStack` toolbars.
- Glass is **not** applied to content cards. Content surfaces stay opaque for readability.
- Badges use the native `Tab.badge(_:)` for the tab and `NotificationBadge` on the Home toolbar bell.

## Accessibility guidance

- Every interactive element is ≥ 44×44 pt and has an accessibility label. Stable
  `accessibilityIdentifier`s exist for UI tests (`login.*`, `home.*`, `metric.<id>`, `profile.*`, …).
- Composite views (`MetricCard`, `ActivityRow`, `NotificationRow`) combine into one VoiceOver element
  with a meaningful label and value (e.g. "Unread").
- Headings carry `.isHeader`. Charts provide a spoken summary (range, low, high).
- Login errors are announced with `AccessibilityNotification.Announcement`.
- Layouts adapt at accessibility Dynamic Type sizes (single-column grids, stacked rows).
- **Reduce Motion**: skeleton shimmer and root route transitions are disabled.
- When applying an identifier to a container whose children have their own identifiers, add
  `.accessibilityElement(children: .contain)` first. Otherwise SwiftUI overrides the children's identifiers.
