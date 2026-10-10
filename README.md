# ✨ **Glow**  
### *Build better habits. Celebrate your wins. Feel your progress.*

<p align="center">
  <img src="https://img.shields.io/badge/SwiftUI-Apple_native-orange?logo=swift">
  <img src="https://img.shields.io/badge/Platform-iOS_26_|_iPadOS_26_|_watchOS_26-blue">
</p>

---

## 🌟 What is Glow?

Glow is a modern, mindful habit-tracking app built entirely with **SwiftUI**, **SwiftData**, and **CloudKit**.  
It focuses on clarity, aesthetic calm, and meaningful progress — not guilt or dopamine loops.

Glow is about *celebrating* the tiny wins that build toward growth.

The current source version is **2.3 (2)**, including the app, widget and Watch
companion. This update adds water tracking to the daily habit loop.

---

## 💎 Core Features

### A beautiful overview:

| Feature | Description |
|--------|-------------|
| 💫 **Liquid Glass UI** | A fully custom translucent design using `.ultraThinMaterial` and GlowTheme tokens. |
| 🧭 **Today Dashboard** | Track your practices, see today’s progress, and enjoy smooth completion animations. |
| 🎯 **Habits & Scheduling** | Custom icons, schedules, reminders, and archiving. |
| 📅 **Habit Detail View** | Weekly rings, monthly heatmaps, and complete history. |
| 📈 **Insights** | A weekly story, habit rhythm, highlights, milestones and history, with a dedicated iPad composition. |
| 💧 **Water Tracking** | Editable quick amounts, custom entries, saved goals, undo, corrections and 7/30-day reporting. |
| 🔔 **Reminders** | Gentle notifications aligned with your schedule. |
| 🗂️ **Archive** | Hide old practices without losing data. |
| 🧩 **Home Screen Widgets** | Glanceable daily progress synced from the app. |
| ⌚ **Watch Companion** | Direct habit completion/undo, 8/21/24 oz water logging and daily goal progress, with a durable queue through the paired iPhone. |
| 🪄 **Four-Page Onboarding** | A smooth intro featuring gestures, reminders, iCloud, and widget setup. |
| 🌙 **Adaptive Themes** | Light, Dark, High-Contrast, and Reduce Motion. |
| 🥂 **Completion Pulse** | A gentle celebration when you finish your day. |

### 🆕 Recent Product Updates (2026)

- **Native section shell:** Glow now uses a three-section root experience: **Today**, **Insights**, and **Library**.
- **iPhone + iPad navigation:** iPhone uses `TabView`; iPad uses a native `NavigationSplitView`.
- **Weekly habit rhythm:** Insights combines a weekly story, a habit-by-day rhythm table, highlights and supporting metrics. iPad uses a full-width story and a two-column metric grid.
- **Unified Add/Edit flow:** Habit creation and editing route through one shared form implementation.
- **Faster daily loop:** Completion interactions include a lightweight undo path for quick correction.
- **Water tracking:** Today includes one-tap amounts, custom entries and saved Male/Female/Custom goals. Insights shows 7/30-day water reporting with saved daily goals and visibly unlogged days (see [Water tracking](docs/WATER_TRACKING.md)).
- **Watch daily check-ins:** The companion lists existing habits, supports completion and undo for the original civil day, logs 8/21/24 oz drinks and shows water goal progress. Pending actions remain until the paired iPhone acknowledges them (see [Watch companion](docs/WATCH_COMPANION.md)).
- **Settings app version row:** `Settings > Apps > Glow` now shows a single `Version` row using live app bundle version/build values.

---

## 🛠 Built With

- **Swift**
- **SwiftUI**
- **SwiftData + CloudKit**
- **App Groups** (for widget sync)
- **GlowTheme** (tokens for colors, spacing, materials)
- **StreakEngine**
- **Hero Card Engine**

---

## 🧭 Onboarding Experience

Glow includes a fully custom **4-screen onboarding flow**:

1. Welcome ✨
2. Add a practice ➕
3. Swipe actions and app sections 👆
4. Add the Glow Widget 📦

Users may tap **Skip** or flow through with smooth spring animations.

---

## 📁 Project Structure

```
Glow/
├── App/
│   └── GlowApp.swift
├── Models/
│   ├── Habit.swift
│   ├── HabitLog.swift
│   ├── HabitSchedule.swift
│   └── WaterTracking.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── HabitDetailViewModel.swift
│   ├── InsightsViewModel.swift
│   └── WaterTrackerViewModel.swift
├── Views/
│   ├── HomeView.swift
│   ├── RootTabShell.swift
│   ├── InsightsRootView.swift
│   ├── LibraryRootView.swift
│   ├── WaterTodayView.swift
│   ├── WaterSettingsView.swift
│   ├── WaterHistoryView.swift
│   ├── WaterInsightsView.swift
│   ├── HabitDetailView.swift
│   ├── AddOrEditHabitForm.swift
│   ├── RemindersView.swift
│   ├── TrendsView.swift
│   ├── ArchiveView.swift
│   ├── YouView.swift
│   └── Components/
│       ├── ProgressRingView.swift
│       ├── IconPickerRow.swift
│       ├── SchedulePicker.swift
│       └── HabitRowGlass.swift
├── Theme/
│   ├── GlowTheme.swift
│   └── GlowModalScaffold.swift
├── Domain/
│   ├── NotificationManager.swift
│   ├── StreakEngine.swift
│   └── WaterAnalytics.swift
├── Utilities/
│   ├── SharedProgressStore.swift
│   ├── GlowExtensions.swift
│   ├── GlowOnboardingView.swift
│   └── Date+Extensions.swift
└── Resources/
    └── HabitIconLibrary.swift
```

`GlowWatch/` contains the companion UI; `GlowShared/` contains its sync contracts,
outbox and receipts. `GlowWidgetExtension/` contains the home-screen widget.

---

## 🧩 Core Components

### **GlowTheme**
Token-driven system for:
- Colors  
- Materials  
- Radius  
- Spacing  
- Typography  
- Glass cards  

### **StreakEngine**
Handles:
- Daily streaks  
- Weekly percentage  
- Heatmap data  
- Fast calculations  

### **Habit System**
- SwiftData models  
- Future-date clamping  
- Archiving  
- Reminder scheduling  

### **Hero Progress Card**
- Animated pulse  
- Overdrive effect at 100%  
- Reduce Motion-aware  

### **Widgets**
- Uses `SharedProgressStore`
- Shows today's progress from the shared app group
- Updates when app progress values change

### **Water Tracking**
- Starts with 8, 12, 21 and 24 US fl oz; all four amounts are editable
- Saves Male (100 fl oz), Female (75 fl oz) or Custom suggestions and fl oz/mL units
- Highlights the last amount locally and supports custom drinks, undo and correction
- Saves each day's goal with its first entry, preserving historical comparisons
- Distinguishes unlogged days from measured intake in 7/30-day reports
- Keeps water separate from habit scores, widget counts and Watch habit completion

Suggested goals are adjustable beverage-intake starting points. Food and other
drinks also contribute water; see the explanation and source in
[Water tracking](docs/WATER_TRACKING.md).

---

## ⚡ Performance

Glow is tuned for smoothness:

- Cached month heatmaps  
- Minimal dependency injection  
- Reused materials (low GPU cost)  
- Lazy views everywhere  
- 60fps animations with soft springs  
- SwiftData query minimization  

---

## 🧪 Tests

Glow includes tests for:

- StreakEngine  
- Habit schedules  
- Habit log normalization  
- Notifications  
- Archive filtering  
- App config  
- Icon library  
- Weekly Insights calculations
- Watch packets, durable outbox, receipts and civil-day actions
- Watch water retries, undo, partial acknowledgements, rollover and cache upgrades
- Water input, persistence, saved goals, reports and additive store migration

UI tests cover onboarding, adding and completing practices, and water logging,
undo/relaunch, saved Female/preset settings, custom correction and Insights.

The initial October 10 water feature validation passed 100 unit tests, the existing habit
completion smoke test, and the three water flows on iPhone and iPad simulators.
Build/install evidence and remaining manual checks are recorded in
[Water delivery](docs/WATER_DELIVERY_2026-10-10.md).
The Watch water extension passed all 108 unit tests, including eight additional
Watch water tests (see [Watch water delivery](docs/WATCH_WATER_DELIVERY_2026-10-10.md)).

---

## 🧩 Roadmap

- [x] Native iPad sidebar and dedicated Today/Insights layouts
- [x] watchOS companion for direct habit check-ins, water logging and daily goal progress (see [Watch companion](docs/WATCH_COMPANION.md))
- [x] Water logging, saved goals and reporting (see [Water tracking](docs/WATER_TRACKING.md))
- [ ] Shared Habits (Glow Circles)  
- [ ] More widget styles  
- [ ] Custom practice colors  

## Documentation

- [Water behavior, storage and release checks](docs/WATER_TRACKING.md)
- [Water feature and 2.3 delivery evidence](docs/WATER_DELIVERY_2026-10-10.md)
- [Watch setup, transport and validation](docs/WATCH_COMPANION.md)
- [Watch water feature and device delivery evidence](docs/WATCH_WATER_DELIVERY_2026-10-10.md)
- [Historical Watch 2.2 delivery evidence](docs/WATCH_DELIVERY_2026-10-03.md)

---

## Credits

Built with care by **Don Noel** and Codex collaboration.

---

> *Glow should feel like a breath. Every win should feel like a smile.*
