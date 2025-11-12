✨ Glow

Build better habits. Celebrate your wins. Feel your progress.


⸻

🌟 Overview

Glow is a mindful habit tracker that helps you build consistency through reflection—not pressure.
It transforms your daily practices into small moments of calm progress, wrapped in a smooth, glass-inspired interface built entirely with SwiftUI.

Glow celebrates the journey, not the numbers. Every tap, every pulse, every shimmer is designed to remind you: growth feels good.

⸻

💎 Core Features

🌈	Feature	Description
💫	Liquid Glass UI	Custom “Liquid Glass” design system built with .ultraThinMaterial, depth shadows, and light diffusion for a premium Apple feel.
🎯	Today Dashboard	A gentle daily view showing your active practices, progress, and completions—organized by focus and flow.
🔔	Reminders & Notifications	Subtle, human-paced reminders that help you remember without demanding attention.
📅	Detailed Insights	Weekly rings, monthly heatmaps, and streak tracking that keep you connected to your effort and growth.
🧠	Smart Refresh & Sync	Automatic updates across app, widgets, and background refresh—no manual reloads needed.
🥂	Celebration Pulse	A fluid glass animation plays when you complete your goals—because small wins deserve beauty.
🌙	Adaptive Themes	Designed for Light, Dark, and High-Contrast modes with full accessibility support.
🧩	Archive & Reflection	Archive habits to pause progress without losing data; bring them back anytime.


⸻

🛠 Built With
	•	Swift 6.2 — all-native, modern concurrency
	•	SwiftUI + Combine for reactive state
	•	SwiftData for persistence and iCloud sync
	•	GlowTheme: token-driven palette, typography, and depth materials
	•	StreakEngine: efficient streak logic for weekly/monthly summaries
	•	SharedProgressStore: cross-device progress cache for widgets and live data
	•	Zero third-party dependencies

⸻

🎨 Design Philosophy

“Every tap should feel like a breath.”

Glow was crafted for calm interaction. Its design follows Apple’s Human Interface Guidelines and personal principles of clarity, kindness, and lightness.
	•	Gentle motion over flashy animation
	•	Depth and translucency that invite touch
	•	Feedback that feels like encouragement, not correction
	•	Interfaces that disappear when not needed

⸻

🧭 Developer Notes

Glow is designed as a reference-quality SwiftUI architecture for habit-tracking and personal growth apps.

Project Layout

Glow/
├── App/
│   ├── GlowApp.swift
│   └── GlowAppConfig.swift
├── Models/
│   ├── Habit.swift
│   ├── HabitLog.swift
│   ├── HabitSchedule.swift
│   ├── Weekday.swift
│   └── StreakEngine.swift
├── Views/
│   ├── HomeView.swift
│   ├── HabitDetailView.swift
│   ├── ArchiveView.swift
│   ├── RemindersView.swift
│   └── Components/
│       ├── HabitRowGlass.swift
│       ├── GlassCard.swift
│       ├── QuickActionsBar.swift
│       └── ProgressRingView.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── HabitDetailViewModel.swift
│   └── RemindersViewModel.swift
├── Domain/
│   ├── NotificationManager.swift
│   ├── SharedProgressStore.swift
│   └── GlowDataEvents.swift
├── Theme/
│   ├── GlowTheme.swift
│   ├── GlowPalette.swift
│   └── GlowTypography.swift
└── Tests/
    ├── Unit/
    │   ├── HabitTests.swift
    │   ├── StreakEngineTests.swift
    │   └── ArchiveFilteringTests.swift
    └── UI/
        └── GlowUITests.swift

Engineering Highlights
	•	✅ 60fps SwiftUI layout — fully Instruments-verified
	•	✅ Test-driven model layer with isolation coverage
	•	✅ Clean separation between UI, logic, and persistence
	•	✅ SwiftData + WidgetCenter integration
	•	✅ Unified refresh pipeline via .glowDataDidChange notifications
	•	✅ No third-party libraries

⸻

🧪 Test Coverage

Glow ships with a full unit and UI test suite:

Suite	Focus
GlowTests/	Model consistency, streak math, and persistence integrity
GlowUITests/	Launch smoke tests, Add Practice flow, and accessibility regression coverage

Run all tests:

⌘U   # or xcodebuild test -scheme Glow -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'


⸻

🚀 App Store Readiness

✅ App Store-ready build
	•	Uses production entitlements, no debug logging
	•	Passes static analysis and Instruments leak check
	•	Complies with App Review Guidelines 4.4 and 5.1 (notifications, data privacy)
	•	Verified iCloud sync and widget refresh

⸻

❤️ Credits

Built with care by Don Noel
Designed and engineered with help from Bella, my AI collaborator ✨

⸻

📄 License

MIT License

⸻

Glow reminds you that progress can be gentle, beautiful, and yours.

⸻
