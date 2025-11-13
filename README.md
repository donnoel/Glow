# ✨ **Glow**  
### *Build better habits. Celebrate your wins. Feel your progress.*

<p align="center">
  <img src="https://img.shields.io/badge/SwiftUI-6.2-orange?logo=swift">
  <img src="https://img.shields.io/badge/Platform-iOS_18_|_macOS_15-blue">
  <img src="https://img.shields.io/badge/License-MIT-green">
</p>

---

## 🌟 What is Glow?

Glow is a modern, mindful habit-tracking app built entirely with **SwiftUI**, **SwiftData**, and **CloudKit**.  
It focuses on clarity, aesthetic calm, and meaningful progress — not guilt or dopamine loops.

Glow is about *celebrating* the tiny wins that build toward growth.

---

## 💎 Core Features

### A beautiful overview:

| Feature | Description |
|--------|-------------|
| 💫 **Liquid Glass UI** | A fully custom translucent design using `.ultraThinMaterial` and GlowTheme tokens. |
| 🧭 **Today Dashboard** | Track your practices, see today’s progress, and enjoy smooth completion animations. |
| 🎯 **Habits & Scheduling** | Custom icons, schedules, reminders, and archiving. |
| 📅 **Habit Detail View** | Weekly rings, monthly heatmaps, and complete history. |
| 🪞 **You View** | A reflective summary of your best streaks and patterns. |
| 📈 **Trends & Analytics** | Understand your long-term rhythm with beautiful insights. |
| 🔔 **Reminders** | Gentle notifications aligned with your schedule. |
| 🗂️ **Archive** | Hide old practices without losing data. |
| 🧩 **Home Screen Widgets** | One-tap check-ins and instant progress. |
| 🪄 **Six-Page Onboarding** | A smooth intro featuring gestures & widget setup. |
| 🌙 **Adaptive Themes** | Light, Dark, High-Contrast, and Reduce Motion. |
| 🥂 **Completion Pulse** | A gentle celebration when you finish your day. |

---

## 🛠 Built With

- **Swift 6.2**
- **SwiftUI**
- **SwiftData + CloudKit**
- **App Groups** (for widget sync)
- **GlowTheme** (tokens for colors, spacing, materials)
- **StreakEngine**
- **Hero Card Engine**

---

## 🧭 Onboarding Experience

Glow includes a fully custom **6-screen onboarding flow**:

1. Welcome ✨  
2. Add a practice ➕  
3. Practice details 📊  
4. Swipe actions 👆  
5. Menu overview 📁  
6. Add the Glow Widget 📦  

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
│       ├── ProgressRingView.swift
│       ├── IconPickerRow.swift
│       ├── SchedulePicker.swift
│       └── HabitRowGlass.swift
├── Theme/
│   ├── GlowTheme.swift
│   └── GlowModalScaffold.swift
├── Domain/
│   ├── NotificationManager.swift
│   └── StreakEngine.swift
├── Utilities/
│   ├── SharedProgressStore.swift
│   ├── GlowExtensions.swift
│   ├── GlowOnboardingView.swift
│   └── Date+Extensions.swift
└── Resources/
    └── HabitIconLibrary.swift
```

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
- Check in directly from the widget  
- Updates instantly with new logs  

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

Plus a UI test that covers onboarding → add practice.

---

## 🧩 Roadmap

- [ ] iPad layouts  
- [ ] watchOS app  
- [ ] Shared Habits (Glow Circles)  
- [ ] More widget styles  
- [ ] Custom practice colors  

---

## ❤️ Credits

Built with care by **Don Noel**  
Designed & engineered with help from Bella, my AI collaborator ✨

---

## 📄 License  
MIT License

---

> *Glow should feel like a breath. Every win should feel like a smile.*
