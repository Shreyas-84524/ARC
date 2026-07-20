# Project Arc
## design.md
Version: 1.0

---

# Design Philosophy

Project Arc is a premium personal productivity application designed around **clarity, focus, and consistency**. The application combines a Task Manager, Habit Tracker, and Money Tracker into one seamless experience that feels elegant, modern, and distraction-free.

The design should feel like a hybrid of:

- Todoist
- TickTick
- Things 3
- Linear
- Arc Browser
- Notion
- Apple Human Interface Guidelines
- Material 3

The interface should never feel cluttered. Every screen should guide the user toward completing their work with minimal friction.

---

# Design Principles

The application must follow these principles throughout every screen.

- Minimal
- Premium
- Fast
- Clean
- Highly Readable
- Dashboard First
- Mobile First
- Smooth Animations
- Rounded Components
- High Contrast
- Spacious Layout
- Accessible
- Modern
- Original Design

---

# Overall Theme

Style

Modern Dark Productivity Dashboard

Mood

Calm

Focused

Professional

Premium

Minimal

Future Ready

Elegant

---

# Design Language

Every component should share the same visual language.

Characteristics

- Rounded Corners
- Floating Cards
- Soft Shadows
- Thin Borders
- Large White Space
- Vibrant Accent Color
- Large Typography
- Minimal Icons
- Glassmorphism Inspired
- Dashboard Layout

---

# Color Palette

## Background

Primary Background

#141414

Secondary Background

#1B1B1B

Surface

#202020

Card Background

#242424

Elevated Surface

#2A2A2A

Modal

#1E1E1E

---

## Accent Color

Primary Accent

#D7FF2F

Hover

#E5FF5C

Pressed

#BCD91F

Glow

rgba(215,255,47,0.25)

---

## Priority Colors

### High Priority

Red

#FF4D4F

---

### Much Priority

Orange

#FF9F43

---

### Low Priority

Yellow

#FFD93D

---

## Status Colors

Success

#7DFF72

Information

#5AA9FF

Warning

#FFC857

Danger

#FF5D5D

---

## Money Tracker Colors

Income

#2ECC71

Expense

#FF5D5D

Savings

#D7FF2F

Budget Remaining

#5AA9FF

Budget Used

#FFC857

---

## Habit Tracker Colors

Completed

#D7FF2F

Remaining

#555555

Current Streak

#5AA9FF

Longest Streak

#FFD93D

---

## Text Colors

Primary

#FFFFFF

Secondary

#D6D6D6

Muted

#8A8A8A

Disabled

#5A5A5A

Placeholder

#757575

---

## Borders

Subtle Border

rgba(255,255,255,0.05)

Medium Border

rgba(255,255,255,0.08)

Strong Border

rgba(255,255,255,0.12)

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

Regular

400

Medium

500

SemiBold

600

Bold

700

---

# Font Sizes

Hero

42px

Large Title

34px

Page Title

30px

Section Heading

24px

Card Heading

20px

Body

16px

Small

14px

Caption

12px

Micro

10px

---

# Iconography

Library

Lucide Icons

Style

Outline

Stroke

2px

Rounded

Minimal

No Filled Icons

---

# Border Radius

Screen

40px

Cards

24px

Inputs

18px

Buttons

16px

Icon Buttons

16px

Bottom Navigation

999px

FAB

100%

Charts

24px

---

# Shadows

Cards

0 10px 30px rgba(0,0,0,0.35)

Floating Action Button

0 12px 35px rgba(215,255,47,0.20)

Modal

0 20px 60px rgba(0,0,0,0.45)

Dropdown

0 10px 40px rgba(0,0,0,0.40)

---

# Spacing System

4

8

12

16

20

24

32

40

48

64

96

Use an 8-point grid throughout the application.

---

# Layout

Horizontal Padding

20px

Vertical Padding

24px

Section Gap

24px

Card Gap

16px

Card Padding

20px

---

# Navigation

Bottom Navigation

Floating Pill

Rounded

Dark Surface

Blurred Background

Selected Tab

Neon Lime

Inactive Tab

Gray

Height

72px

Icons

24px

Labels

Hidden

---

Tabs

Task Manager

Habit Tracker

Money Tracker

---

Top Bar

Minimal

Contains

Current Greeting

Current Date

Search

Notifications

No Divider

---

# Dashboard

The Dashboard should act as the application's home screen.

Display

Today's Tasks

Today's Habits

Remaining Budget

Productivity Summary

Recent Activity

Quick Statistics

Upcoming Deadlines

Floating Action Button

---

# Task Manager

Inspired by premium task management applications like Todoist while maintaining a unique visual identity.

---

Task Card

Contains

Priority Indicator

Title

Description

Due Time

Due Date

Category

Labels

Completion Checkbox

Edit Button

Delete Button

---

Task Priority Indicators

🔴 High Priority

🟠 Much Priority

🟡 Low Priority

Priority should be visible before reading the task title.

---

Task Actions

Swipe Right

Mark Complete

Swipe Left

Delete Task

Long Press

Open Quick Actions

Tap

Open Details

Delete must include

Confirmation

Smooth Animation

Medium Haptic Feedback

---

Task Creation

Floating Action Button

Bottom Sheet

Rounded Corners

Large Input Fields

Priority Selector

Date Picker

Time Picker

Reminder Selector

Labels

Category

Notes

---

Task Reminders

If Due Time exists

Automatically schedule

1 Hour Before

30 Minutes Before

Due Time

Notifications

---

Task Filters

Priority

Completed

Pending

Today

Upcoming

Category

---

Task Search

Live Search

Animated Results

---

# Habit Tracker

Habit Screen

Displays

Habit Table

Completion Progress

Current Streak

Statistics

Pie Chart

---

Habit Table

Rows

Habits

Columns

Dates

Cells

Circular Checkboxes

Completed

Accent Green

Pending

Gray

---

Habit Creation

Habit Name

Color

Goal Type

Reminder Time

Category

Frequency

---

Goal Types

Daily

Weekly

Monthly

---

Pie Chart

Single Chart

Dropdown

Daily

Weekly

Monthly

Changing the dropdown should animate the chart.

Display

Completed

Remaining

Completion %

---

Habit Statistics

Total Habits

Today's Completion

Current Streak

Longest Streak

Completion Rate

---

Habit Reminder

Every evening

Notify if

Today's habits are incomplete.

---

# Money Tracker

Purpose

Track monthly budget and daily transactions.

---

Home Card

Remaining Budget

Monthly Budget

Money Used

Savings

---

Budget Setup

At the beginning of every month

Ask

"What is your budget for this month?"

Input

Currency

Amount

Save

---

Transaction Card

Contains

Amount

Type

Category

Date

Time

Notes

Edit

Delete

---

Transaction Types

Income

Green

Expense

Red

---

Categories

Food

Shopping

Fuel

Travel

Entertainment

Bills

Health

Education

Salary

Freelancing

Investment

Other

---

Daily Reminder

8:00 PM

"Have you recorded today's transactions?"

10:00 PM

Final Reminder

---

Charts

Monthly Spending

Category Distribution

Income vs Expense

Savings Progress

Charts should animate smoothly.

---

Monthly Summary

Display

Budget

Income

Expenses

Savings

Remaining

---

Buttons

Primary

Neon Lime

Black Text

Rounded

Height

50px

---

Secondary

Dark Surface

White Text

Thin Border

---

Danger

Red

White Text

---

Ghost

Transparent

White Text

---

Floating Action Button

56px

Circular

Neon Lime

Black Icon

Glow

Always visible.

---

Inputs

Rounded

Dark Background

Accent Border on Focus

Large Touch Area

Placeholder

Muted Gray

---

Cards

Rounded 24px

Dark Surface

Soft Shadow

Large Padding

Minimal Border

---

Charts

Use

Recharts

Style

Minimal

Animated

Rounded

No Visual Clutter

Hidden Grid Lines

---

Animations

Duration

200–250ms

Easing

Ease Out

---

Interactions

Card Hover

Scale

1.02

Button Press

0.97

Checkbox

Bounce

Delete

Slide + Fade

Modal

Scale + Fade

Screen Transition

Slide + Fade

Pie Chart

Animated Sweep

Charts

Animated Value Transitions

---

Haptics

Task Completed

Light

Task Deleted

Medium

Habit Completed

Light

Transaction Saved

Light

Budget Updated

Medium

---

Accessibility

Minimum Contrast Ratio

4.5:1

Minimum Touch Target

44px

Large Typography

Keyboard Navigation

Screen Reader Labels

Reduced Motion Support

---

Responsive Design

Mobile First

Tablet Optimized

Desktop Compatible

Landscape Support

---

Performance

Initial Load

<2 Seconds

60 FPS Animations

Lazy Loading

Optimistic Updates

Offline First

Background Sync

---

Micro Interactions

Checkbox Bounce

Card Elevation

Ripple Effect

Animated Counters

Progress Rings

Smooth Chart Updates

Priority Color Transitions

Budget Number Count-up Animation

Confetti Animation on Monthly Goal Completion

---

Empty States

Task Manager

"No tasks yet. Add your first task."

Habit Tracker

"Start building great habits today."

Money Tracker

"Record your first transaction."

Each empty state should include an illustration and a primary action button.

---

Overall User Experience

The app should feel like a premium personal operating system rather than three separate tools. Every interaction should be fast, fluid, and delightful. The visual hierarchy should direct attention to the most important actions, while subtle animations and consistent design patterns create a cohesive experience across the Task Manager, Habit Tracker, and Money Tracker. Simplicity should never come at the cost of functionality, and every screen should reinforce focus, organization, and progress.