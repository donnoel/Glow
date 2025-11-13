# ✨ Glow
Build better habits. Celebrate your wins. Feel your progress.

![SwiftUI](https://img.shields.io/badge/SwiftUI-6.2-orange?logo=swift)
![Platform](https://img.shields.io/badge/Platform-iOS_18_|_macOS_15-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 🌟 What is Glow?

Glow is a mindful, beautifully-crafted habit-tracker built with SwiftUI and SwiftData.  
It helps you build consistency, understand your patterns, and celebrate progress — all wrapped in a smooth, glassy interface.

Glow isn’t about chasing numbers or guilt-driven streaks.  
It’s about clarity, reflection, and feeling proud of the small wins that add up.

---

## 💎 Core Features

| 🌈 | Feature | Description |
|:--:|:--|:--|
| 💫 | Liquid Glass Design | A fully custom, translucent interface built using `.ultraThinMaterial` and GlowTheme tokens. |
| 🧭 | Today Dashboard | View your practices, track today’s progress, and enjoy smooth completion animations. |
| 🎯 | Practices & Scheduling | Create habits with custom icons, weekday schedules, reminders, and optional archiving. |
| 📅 | Habit Detail View | Explore streaks, weekly progress rings, and monthly heatmaps backed by optimized precomputation. |
| 🪞 | You View | A reflective overview of your best streaks, timing patterns, and overall consistency. |
| 📈 | Trends & Analytics | Understand long-term performance through human-readable insights and visual summaries. |
| 🔔 | Reminders | Gentle notifications aligned with your personal schedule. |
| 🗂️ | Archive | Hide old practices without losing their history. |
| 📦 | Cloud Sync | SwiftData + CloudKit keeps habits and logs synced privately across devices. |
| 🧩 | Home Screen Widgets | Quick check-ins and daily progress right from your Home Screen. |
| 🪄 | Smooth Onboarding | A warm, six-page introduction that now includes widget setup. |
| 🌙 | Adaptive Themes | Beautiful in Light, Dark, High-Contrast, and Reduce Motion modes. |
| 🥂 | Celebration Pulse | Completing all your practices triggers a gentle, glass-based celebration pulse. |

---

## 🛠 Built With

- Swift 6.2  
- SwiftUI  
- SwiftData + CloudKit  
- App Groups for widget sharing  
- GlowTheme — token-driven design (colors, materials, spacing, typography)  
- StreakEngine — streak & success-rate calculations  
- Hero Card — animated daily progress with pulse overdrive  

---

## 🧭 Design Philosophy

> “Glow isn’t about perfection — it’s about noticing progress.”

Glow’s design follows Apple’s Human Interface Guidelines and adds its own aesthetic layer:

- Calm interactions over dopamine loops  
- Smooth transitions, natural motion, and glass depth  
- Zero guilt — Glow encourages reflection, not punishment  
- Every interaction should feel like a breath of clarity  

---

## 👩‍💻 For Developers

Glow is 100% SwiftUI, cleanly modular, and built to be easy to read, extend, and contribute to.

### Project Structure

Glow/  
├── Models/  
│   ├── Habit.swift  
│   ├── HabitLog.swift  
│   └── HabitSchedule.swift  
├── ViewModels/  
│   ├── HomeViewModel.swift  
│   └── HabitDetailViewModel.swift  
├── Views/  
│   ├── HomeView.swift  
│   ├── HabitDetailView.swift  
│   ├── AddOrEditHabitForm.swift  
│   ├── RemindersView.swift  
│   ├── TrendsView.swift  
│   ├── ArchiveView.swift  
│   ├── YouView.swift  
│   └── Components/  
│      ├── ProgressRingView.swift  
│      ├── IconPickerRow.swift  
│      ├── SchedulePicker.swift  
│      └── HabitRowGlass.swift  
├── Theme/  
│   ├── GlowTheme.swift  
│   └── GlowPalette.swift  
├── Utilities/  
│   ├── Date+Extensions.swift  
│   ├── SharedProgressStore.swift  
│   ├── GlowExtensions.swift  
│   ├── GlowOnboardingView.swift  
│   └── EnvironmentKeys.swift  
└── GlowApp.swift  

### Core Components

- **GlowTheme** – centralized design system for colors, materials, radius, spacing  
- **ProgressRingView** – animated daily progress ring used in detail view  
- **HabitDetailView** – optimized with monthly heatmap caching & lazy rendering  
- **StreakEngine** – performance-tuned streak engine powering multiple screens  
- **NotificationManager** – schedules and cancels habit reminders  
- **SharedProgressStore** – app-group bridge used by Glow’s widgets  

### Developer Highlights

- Zero third-party dependencies  
- Fully Apple-native  
- Clean MVVM-ish SwiftUI organization  
- On-device caching for heavy computations (heatmaps, streaks)  
- 100% SwiftData storage + CloudKit sync  
- Tests for streaks, schedules, reminders, archive logic, icons, and more  

---

## ⚡️ Performance Engineering

Glow is optimized for consistency and smoothness:

- Uses `LazyVStack` for lightweight rendering  
- Caches calendar/month views to avoid heavy recomputation  
- Reuses blur/material layers for low GPU overhead  
- Minimal view invalidation through memoized logic and isolated state  
- 60fps animations tuned with soft spring dynamics  

---

## 🧩 Roadmap

- [ ] iPad optimization  
- [ ] watchOS companion  
- [ ] Shared Habits (Glow Circles)  
- [ ] More widget styles  
- [ ] Custom practice colors  

---

## ❤️ Credits

Built with care by **Don Noel**  
Assisted by **Bella**, your AI teammate & design collaborator ✨

---

## 📄 License

MIT License

---

> Every tap should feel like a breath. Every win should feel like a smile.
