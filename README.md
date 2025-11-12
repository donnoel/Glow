✨ Glow

Build better habits. Celebrate your wins. Feel your progress.


⸻

🌟 Overview

Glow is a mindful habit-tracking app built entirely with SwiftUI and SwiftData.
It focuses on calm progress, gentle reflections, and celebrating small wins — wrapped in a soft, glass-inspired interface.

Glow isn’t about perfection.
It’s about momentum, awareness, and enjoying the feeling of progress over time.

⸻

💎 Core Features

✨ Liquid Glass Interface

A custom design system using .ultraThinMaterial, depth shadows, and subtle lighting to create a premium Apple feel.

🎯 Today Dashboard

Your habits are organized by what matters now:
Today, Focused, Coming Up, and Archived — each updating live.

📅 Habit Details

Beautiful insights including:
	•	Weekly progress ring
	•	Monthly heatmap
	•	Streaks and best streak
	•	Calendar-accurate logic backed by a robust streak engine

🔔 Reminders

Soft, human-paced notifications you can enable per habit.

🥂 Celebration Pulse

When you complete your goals, Glow responds with a gentle pulse made of layered glass.

🌙 Adaptive Themes

Full support for Light, Dark, High Contrast, and Dynamic Type.

🧩 Archive & Restore

Archive any habit to pause it — bring it back anytime.

⸻

🛠 Built With
	•	Swift 6.2
	•	SwiftUI
	•	SwiftData
	•	Combine
	•	WidgetKit
	•	No third-party dependencies

Glow uses a token-driven design system (GlowTheme) and a precise streak engine (StreakEngine) for all math-based calendar calculations.

⸻

🧱 Project Structure

Glow/
├── App/
│   ├── GlowApp.swift
│   └── GlowAppConfig.swift
│
├── Models/
│   ├── Habit.swift
│   ├── HabitLog.swift
│   ├── HabitSchedule.swift
│   ├── Weekday.swift
│   └── StreakEngine.swift
│
├── Views/
│   ├── HomeView.swift
│   ├── HabitDetailView.swift
│   ├── ArchiveView.swift
│   ├── RemindersView.swift
│   └── Components/
│       ├── HabitRowGlass.swift
│       ├── GlassCard.swift
│       ├── ProgressRingView.swift
│       ├── QuickActionsBar.swift
│       └── MetricCard.swift
│
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── HabitDetailViewModel.swift
│   └── RemindersViewModel.swift
│
├── Domain/
│   ├── SharedProgressStore.swift
│   ├── NotificationManager.swift
│   └── GlowDataEvents.swift
│
├── Theme/
│   ├── GlowTheme.swift
│   ├── GlowPalette.swift
│   └── GlowTypography.swift
│
└── Tests/
    ├── Unit/
    └── UI/


⸻

⚙️ Developer Notes

Glow is designed as a clean, modern SwiftUI architecture:
	•	Uses @Model SwiftData types
	•	All heavy work isolated in view models
	•	UI is pure and stateless
	•	Calendar grids calculated lazily
	•	Notifications wired through a central .glowDataDidChange event
	•	Widgets updated with SharedProgressStore
	•	100% Apple-native — no dependencies

⸻

🧪 Tests

Glow includes a robust suite of unit tests and UI tests covering:
	•	Habit model logic
	•	Streak calculations
	•	Archive/unarchive behavior
	•	Reminder filtering
	•	UI flows such as:
	•	Add habit
	•	Mark complete
	•	Open detail view
	•	Archive and restore

Run tests with:

⌘ + U   // or via CLI: xcodebuild test


⸻

🚀 App Store Ready

Glow ships with:
	•	No debug logging
	•	Clean production entitlements
	•	Passes static analyzer
	•	Verified iCloud sync
	•	Fully accessible UI
	•	Smooth performance on all supported devices

This codebase is clean, stable, and ready for submission.

⸻

❤️ Credits

Built with care by Don Noel
Designed and engineered with help from Bella, your AI collaborator ✨

⸻

📄 License

MIT License

⸻

Glow reminds you that growth can be gentle — and beautiful.

⸻
