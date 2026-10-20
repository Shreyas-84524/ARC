# Project Arc
## designlight.md
Version: 1.0 (Light Theme)

---

# Design Philosophy

Project Arc is a premium personal productivity application designed around **clarity, focus, and consistency**. The application combines a Task Manager, Habit Tracker, and Money Tracker into one seamless experience that feels elegant, modern, and distraction-free.

The light theme maintains the hybrid feel of premium apps (Todoist, Things 3, Linear) but adapts the visual hierarchy for bright, daylight-optimized environments. 

---

# Design Principles

The application must follow these principles throughout every screen.

- Minimal
- Premium
- Fast
- Clean
- Highly Readable (High Contrast for Light Mode)
- Dashboard First
- Mobile First
- Smooth Animations
- Rounded Components
- Spacious Layout
- Accessible
- Modern
- Original Design

---

# Overall Theme

Style
Modern Light Productivity Dashboard

Mood
Fresh
Energetic
Professional
Premium
Minimal
Vibrant
Elegant

---

# Design Language

Every component should share the same visual language.

Characteristics
- Rounded Corners
- Floating Cards
- Soft, Airy Shadows
- Thin, Crisp Borders
- Large White Space
- Vibrant Accent Color
- Large Typography
- Minimal Icons
- Frosted Glassmorphism
- Dashboard Layout

---

# Color Palette (Light Theme)

## Background

Primary Background
#F9FAFB (Very Light Cool Gray)

Secondary Background
#F3F4F6

Surface
#FFFFFF (Pure White)

Card Background
#FFFFFF

Elevated Surface
#FFFFFF

Modal
#FFFFFF

---

## Accent Color

Primary Accent
#D7FF2F (Neon Lime) - *Note: Use with black text for high contrast*

Hover
#E5FF5C

Pressed
#BCD91F

Glow
rgba(215,255,47,0.4)

Dark Accent (For text/icons requiring contrast against white backgrounds)
#5C7000 

---

## Priority Colors

### High Priority
Red
#FF4D4F

### Much Priority
Orange
#FF9F43

### Low Priority
Yellow
#FFC857

---

## Status Colors

Success
#52C41A

Information
#1890FF

Warning
#FAAD14

Danger
#FF4D4F

---

## Money Tracker Colors

Income
#52C41A

Expense
#FF4D4F

Savings
#D7FF2F (or #5C7000 for text)

Budget Remaining
#1890FF

Budget Used
#FAAD14

---

## Habit Tracker Colors

Completed
#D7FF2F (with dark checkmark)

Remaining
#E5E7EB

Current Streak
#1890FF

Longest Streak
#FAAD14

---

## Text Colors

Primary
#111827 (Near Black)

Secondary
#4B5563 (Dark Gray)

Muted
#9CA3AF (Medium Gray)

Disabled
#D1D5DB (Light Gray)

Placeholder
#9CA3AF

---

## Borders

Subtle Border
rgba(0,0,0,0.05)

Medium Border
rgba(0,0,0,0.08)

Strong Border
rgba(0,0,0,0.15)

---

# Typography

Primary Font
SF Pro Display

Fallback
Inter

Alternative
Manrope

---

# Font Weights
Regular: 400
Medium: 500
SemiBold: 600
Bold: 700

---

# Font Sizes
Hero: 42px
Large Title: 34px
Page Title: 30px
Section Heading: 24px
Card Heading: 20px
Body: 16px
Small: 14px
Caption: 12px
Micro: 10px

---

# Iconography

Library
Lucide Icons

Style
Outline
Stroke: 2px
Rounded
Minimal
No Filled Icons
Color: #111827 (Primary Text Color)

---

# Border Radius

Screen: 40px
Cards: 24px
Inputs: 18px
Buttons: 16px
Icon Buttons: 16px
Bottom Navigation: 999px
FAB: 100%
Charts: 24px

---

# Shadows (Light Theme)

Cards
0 4px 20px rgba(0,0,0,0.04)

Floating Action Button
0 12px 30px rgba(215,255,47,0.40)

Modal
0 20px 50px rgba(0,0,0,0.10)

Dropdown
0 10px 30px rgba(0,0,0,0.08)

---

# Spacing System
4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 96
*Use an 8-point grid throughout the application.*

---

# Navigation

Bottom Navigation
Floating Pill
Rounded
Light Surface (White/Frosted)
Blurred Background (Backdrop-filter: blur)
Selected Tab: Neon Lime (#D7FF2F) block with Black icon
Inactive Tab: Gray (#9CA3AF)
Height: 72px
Icons: 24px
Labels: Hidden

Top Bar
Minimal
Contains: Current Greeting, Current Date, Search, Notifications
No Divider

---

# Components

Buttons

Primary
Neon Lime (#D7FF2F)
Black Text (#111827)
Rounded
Height: 50px

Secondary
White Surface
Black Text
Medium Border (rgba(0,0,0,0.08))

Danger
Light Red Background (#FFF1F0)
Red Text (#FF4D4F)

Ghost
Transparent
Black Text

Inputs
Rounded
White Background
Medium Border (rgba(0,0,0,0.08))
Accent Border on Focus (#5C7000 or #111827)
Large Touch Area
Placeholder: Muted Gray

Cards
Rounded 24px
White Surface
Soft Shadow (0 4px 20px rgba(0,0,0,0.04))
Large Padding
Subtle Border (rgba(0,0,0,0.03))

---

# Interactions & Animations

Animations
Duration: 200–250ms
Easing: Ease Out

Interactions
Card Hover: Scale 1.02, Shadow slightly deepens
Button Press: Scale 0.97
Checkbox: Bounce
Delete: Slide + Fade

---

# Empty States

Each empty state should include a light, modern illustration and a primary action button.
Text color should be Secondary (#4B5563) to avoid harshness.
