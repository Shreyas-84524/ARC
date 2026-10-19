# UI migration map

ARC uses Material widgets with custom dark/light themes. Preserve the established identity rather than redesigning it: dark background `#141414`, dark surface `#202020`, light background `#F9FAFB`, white light surfaces, and lime accent `#D7FF2F` are defined in `lib/core/theme/app_theme.dart`.

Map `MaterialApp.router`/GoRouter to a single-activity Compose app with Navigation Compose. Preserve the authenticated shell and bottom navigation for Dashboard, Tasks, Habits, and Money; keep Settings, Search, Notifications, Admin, and Secret Notes outside or above that shell according to current routes. Auth/admin/Secret Notes redirect rules must become explicit navigation state derived from immutable session state.

Shared Flutter components (`TopBar`, `EmptyState`, `SkeletonLoader`, `PremiumSegmentedControl`) should become reusable Compose components. Sheets and dialogs should preserve semantics and ordering. Responsive behavior in `responsive_layout.dart` should map to window-size/adaptive layout logic. Use screenshot/golden comparisons per screen; animations should be migrated after static visual and accessibility parity.
