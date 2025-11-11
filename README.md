# ✨ Glow
Build better habits. Celebrate your wins. Feel your progress.

![SwiftUI](https://img.shields.io/badge/SwiftUI-6.2-orange?logo=swift)
![Platform](https://img.shields.io/badge/Platform-iOS_18_|_macOS_15-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 🌟 What is Glow?

Glow is a mindful habit-tracking experience designed for people who want growth without pressure.  
It helps you track your daily practices, build meaningful streaks, and celebrate progress — all wrapped in a smooth, glassy interface.

Glow isn’t about chasing numbers.  
It’s about reflection, momentum, and feeling good about the small wins that add up over time.

---

## 💎 Core Features

| 🌈 | Feature | Description |
|:--:|:--|:--|
| 💫 | Liquid Glass Design | Crafted entirely with `.ultraThinMaterial`, vibrant translucency, and depth shadows — a premium Apple-style aesthetic. |
| 🧭 | Dashboard (“Today”) | See your active practices, streaks, and gentle progress animations at a glance. |
| 🎯 | Habits / Practices | Create personal habits with icons, reminders, and streak tracking that encourages reflection instead of guilt. |
| 📅 | Habit Detail View | Review your performance through a weekly progress ring and monthly heatmap that update instantly. |
| 🪞 | You View | A personal summary showing your consistency, best streaks, and ongoing growth. |
| 📈 | Analytics & Trends | Track your activity patterns over days, weeks, and months — visually elegant and human-readable. |
| ⏰ | Reminders | Optional, gentle nudges to stay mindful of what matters most. |
| 🌙 | Adaptive Themes | Full support for Light, Dark, and High-Contrast modes — always in harmony with your system settings. |
| 🥂 | Celebration Pulse | When you hit 100%, Glow gently celebrates with a fluid, glass-based pulse animation. |

---

## 🛠 Built With

- Swift 6.2  
- SwiftUI + Combine  
- SwiftData (Core Data optional)  
- iOS 18 / macOS 15 SDK  
- GlowTheme — token-driven color palette, typography, and materials  
- HabitStore — reactive model layer for persistence and syncing  
- StreakEngine — efficient logic for computing daily/weekly/monthly streaks  
- ProgressRingView — high-performance animated ring with pulse overdrive  
- Weather Integration (optional) — displays local weather and conditions directly in the Hero Card  

---

## 🧭 Design Philosophy

> “Glow isn’t about perfection — it’s about noticing progress.”

Glow’s design follows Apple’s Human Interface Guidelines and a few personal principles:

- Focus on calm interaction, not constant stimulation  
- Gentle transitions, fluid depth, and natural motion  
- No competition, no guilt — just presence and growth  
- Every touchpoint should feel like a breath of calm

---

## 👩‍💻 For Developers

Glow is a clean, modular SwiftUI codebase.

### Project Structure

Glow/
├── Models/
│   ├── Habit.swift
│   ├── HabitLog.swift
│   ├── HabitStore.swift
│   ├── StreakEngine.swift
├── Views/
│   ├── HomeView.swift
│   ├── HabitDetailView.swift
│   ├── AddHabitView.swift
│   ├── Components/
│   │   ├── ProgressRingView.swift
│   │   ├── GlassCard.swift
│   │   ├── QuickActionsBar.swift
│   │   └── MetricCard.swift
├── Theme/
│   ├── GlowTheme.swift
│   ├── GlowPalette.swift
│   └── GlowTypography.swift
├── Utilities/
│   ├── DateHelpers.swift
│   └── EnvironmentKeys.swift
└── GlowApp.swift

### Core Components
- GlowTheme — centralized color and material system with light/dark awareness  
- ProgressRingView — smooth animated ring for daily progress  
- HabitDetailView — optimized with precomputed heatmaps and lazy rendering  
- QuickActionsBar — keyboard-aware toolbar with New / Filter / Refresh actions  
- StreakEngine — lightweight streak computation engine, built for performance  

### Developer Highlights
- Zero third-party dependencies  
- Fully Apple-native (SwiftUI, Combine, SwiftData)  
- Modular design — easy to extend or integrate into your own apps  
- Optimized with `@StateObject` and memoized calculations for performance  
- Adheres to Apple’s Human Interface Guidelines  

---

## ⚡️ Performance Engineering

Glow has been tuned for speed and efficiency:
- Uses `LazyVStack` and memoized date grids to reduce re-renders  
- Caches calendar computations in MonthHeatmap  
- Shares blur and material layers between cards for lower GPU cost  
- Smooth 60fps animation target across macOS and iOS  
- Instruments-verified: minimal layout thrash and memory footprint

---

## 🧩 Roadmap

- [ ] iPad optimized
- [ ] watchOS companion app  
- [ ] Shared Habits (Glow Circles)  
 

---

## ❤️ Credits

Built with care by Don Noel  
Assisted by Bella, my AI teammate and design collaborator  

---

## 📄 License

MIT License

---

> Every tap should feel like a breath. Every win should feel like a smile.
