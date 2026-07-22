# Project Arc — UI Design System Specification

> **Version:** 1.0.0 (Production Release)  
> **Document Purpose:** Complete specification of theme tokens, colors, typography scales, component styles, micro-animations, and responsive layout guidelines.

---

## 1. Color Palette (`AppColors`)

### Dark Mode (OLED Optimized Base)
- **Primary Background (`darkBg`)**: `#0d0f12`
- **Surface (`darkSurface`)**: `#16191f`
- **Card Background (`darkCard`)**: `#1e222a`
- **Modal Surface (`darkModal`)**: `#252a34`
- **Accent Primary (`accent`)**: `#ccff00` (Electric Lime)
- **Accent Pressed (`accentPressed`)**: `#b8e600`
- **Text Primary (`textPrimaryDark`)**: `#f0f2f5`
- **Text Secondary (`textSecondaryDark`)**: `#9ca3af`
- **Text Muted (`textMutedDark`)**: `#6b7280`

### Light Mode (High Contrast Clean)
- **Primary Background (`lightBg`)**: `#f8fafc`
- **Surface (`lightSurface`)**: `#ffffff`
- **Card Background (`lightCard`)**: `#ffffff`
- **Text Primary (`textPrimaryLight`)**: `#0f172a`
- **Text Secondary (`textSecondaryLight`)**: `#475569`
- **Text Muted (`textMutedLight`)**: `#94a3b8`

### Status & Priority Palette
- **Success**: `#10b981`
- **Warning**: `#f59e0b`
- **Danger**: `#ef4444`
- **Info**: `#3b82f6`
- **Priority Low**: `#10b981`
- **Priority High**: `#f59e0b`
- **Priority Much**: `#ef4444`

---

## 2. Radii & Spacing Design Tokens

- **Card Radius (`radiusCard`)**: `16.0`
- **Button Radius (`radiusButton`)**: `12.0`
- **Input Field Radius (`radiusInput`)**: `12.0`
- **Pill Navigation Radius (`radiusPill`)**: `100.0`
- **Container Padding**: `16.0` or `20.0`
- **Grid Gap**: `12.0` or `16.0`

---

## 3. Component System

### Floating Glassmorphic Navigation Pill (`ShellScreen`)
- Positioned floating above bottom edge (`SafeArea` bottom `20.0`).
- Background: `BackdropFilter` with `ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0)`.
- Border: `Border.all(color: borderStrong, width: 1.0)`.
- Shadow: `BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 8))`.

### Empty States (`EmptyStateWidget`)
- Circular icon badge with `accent.withValues(alpha: 0.1)`.
- Title with bold weight, secondary description text, and optional primary action button.

### Skeleton Loaders (`SkeletonLoader`)
- Pulse animation (`flutter_animate`) looping opacity from `0.4` to `1.0` every `800ms`.
