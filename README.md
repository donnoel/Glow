# Glow

Glow is a SwiftUI + SwiftData habit tracker focused on calm daily execution, clear progress, and reliable reminders/widgets.

## Current App Structure

Glow currently uses a three-section root shell:

- **Today**: daily summary, due/completed/coming-up lists, fast check-ins, completion undo, add habit
- **Insights**: integrated reflection screen for momentum, weekly activity, patterns, and milestones
- **Library**: active/archived habit management plus reminder management entry

On iPhone this is presented with `TabView`; on iPad it is presented with `NavigationSplitView`.

## Core Features (Implemented)

- Unified Add/Edit habit flow (`AddOrEditHabitForm`) used across Today/Library/Detail
- Habit Detail with identity, schedule/reminder status, streaks, and monthly history
- Reminder scheduling + archive-aware reminder sync
- Schedule-aware due-state behavior (daily and custom weekday schedules)
- Empty/low-data states for Today, Insights, and Library
- App Group-backed widget progress sync + timeline reloads
- SwiftData persistence with CloudKit-backed container and local fallback

## Tech Stack

- Swift 6.2
- SwiftUI
- SwiftData + CloudKit
- WidgetKit
- UserNotifications

## Project Layout

```text
Glow/
├── App/
│   └── GlowApp.swift
├── Models/
│   ├── Habit.swift
│   ├── HabitLog.swift
│   └── HabitSchedule.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── HabitDetailViewModel.swift
│   └── TrendsViewModel.swift
├── Views/
│   ├── RootTabShell.swift
│   ├── HomeView.swift
│   ├── InsightsRootView.swift
│   ├── LibraryRootView.swift
│   ├── HabitDetailView.swift
│   ├── AddOrEditHabitForm.swift
│   ├── RemindersView.swift
│   └── Components/
├── Domain/
│   ├── NotificationManager.swift
│   └── StreakEngine.swift
├── Utilities/
│   ├── SharedProgressStore.swift
│   ├── ModelContext+Save.swift
│   └── GlowOnboardingView.swift
└── Resources/
    └── HabitIconLibrary.swift
```

## Build

```bash
xcodebuild -project Glow.xcodeproj -scheme Glow -destination 'generic/platform=iOS Simulator' clean build
```

## Test

```bash
xcodebuild -project Glow.xcodeproj -scheme Glow -destination 'platform=iOS Simulator,name=iPhone 16' test
```
