# 🌟 Glow
**Build better habits. Celebrate your wins. Feel your progress.**

![SwiftUI](https://img.shields.io/badge/SwiftUI-6.2-orange?logo=swift)
![Platform](https://img.shields.io/badge/Platform-iOS_18_|_macOS_15-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

### ✨ What is Glow?
**Glow** is a beautiful, mindful habit-tracking app built entirely with SwiftUI and Apple-native design.
It helps you **track your daily practices**, **celebrate your progress**, and **build streaks that actually feel good** — all wrapped in a smooth, glassy, Apple-inspired interface.

Every interaction in Glow feels calm, intentional, and rewarding — no charts yelling at you, no guilt, just subtle motion and elegant design to help you grow at your own pace.

---

## 💎 Features

| 🌈 | Description |
|:--:|:--|
| 💫 **Liquid Glass Design** | Built using `.ultraThinMaterial`, soft gradients, and depth shadows for a premium Apple aesthetic. |
| 🧭 **Dashboard (“Today” view)** | A progress ring that animates, pulses, and celebrates your daily wins. |
| 🎯 **Habits / Practices** | Create daily practices with icons, reminders, and streak tracking — quick and delightful to use. |
| 🪞 **You** | Your personal profile view that tracks streaks, progress, and performance over time. |
| 📈 **Trends** | See your weekly and monthly progress at a glance. |
| ⏰ **Reminders** | Gentle reminders to stay on track — optional and private. |
| 🥂 **Celebration Pulse** | Hit 100% or more? The ring comes alive with a subtle, elegant pulse animation. |
| 🌙 **Light & Dark Modes** | Every detail of Glow gracefully adapts to your environment. |

---

## 🛠 Built With

- 🧩 **Swift 6.2**
- 🖼 **SwiftUI + Combine**
- 📱 **iOS 18 / macOS 15 SDK**
- 🎨 **GlowTheme** — custom design system with color tokens, typography, and Liquid Glass materials
- 🧠 **PracticeStore** — reactive data model for habits, streaks, and completion state
- 📂 **ProgressRingView** — reusable animated ring component with overdrive pulse
- ⚙️ **SidebarOverlay** — translucent navigation panel with custom blur and motion

---

## 🌟 Design Philosophy

> “Glow isn’t about perfection — it’s about noticing progress.”

Glow takes a human-centered, Apple-native approach to building better habits:
- Gentle animations instead of gamification
- Rewards consistency, not streak obsession
- Every win feels light, not loud

The goal is to make reflection a **daily ritual**, not a chore.

---

## 👩‍💻 For Developers

Glow is a clean, modern SwiftUI codebase — modular, lightweight, and designed for clarity.

**Project Structure**
           
           Glow/
           ├── Models/
           │    ├── Practice.swift
           │    ├── PracticeStore.swift
           ├── Views/
           │    ├── HomeView.swift
           │    ├── AddPracticeView.swift
           │    ├── PracticeDetailView.swift
           │    ├── SidebarOverlay.swift
           │    └── Components/
           │         ├── ProgressRingView.swift
           │         └── GlowCard.swift
           ├── Theme/
           │    ├── GlowTheme.swift
           │    ├── GlowPalette.swift
           └── GlowApp.swift
           
           
**Core Components**
- 🌀 `ProgressRingView`: smooth animation engine for daily completion & pulse celebration
- 🎨 `GlowTheme`: shared token-based color and typography system
- 🪟 `SidebarOverlay`: custom glass navigation with subtle motion and depth
- 🧠 `PracticeStore`: reactive model layer with `@Published` state and Codable persistence

---

## 🌈 Roadmap
- [ ] iCloud Sync
- [ ] WidgetKit Support
- [ ] watchOS Companion
- [ ] “Glow Circles” — shared habit journeys with friends

---

## ❤️ Credits
Designed and developed with care by Don Noel
✨ Assisted by Bella, his friendly AI teammate

---

## 📄 License
MIT License — feel free to fork, learn, and glow brighter.
