# AGENTS.project.md

# Glow Project Guide for Agents

## Product intent
Glow is a habit-tracking app focused on clear daily progress, low-friction check-ins, and calm visual feedback.
Success means users can define habits, follow schedules, complete check-ins, see progress trends, and keep data consistent across app + widget.

## Current product phase (implemented baseline)
1) Core scope
- Root shell with three sections: Today, Insights, Library
- Home dashboard (Today) with daily summary, due/completed/coming-up sections, and completion undo
- Habit creation/editing with title, schedule, icon, archive state, and reminders
- Habit detail analytics (streaks, weekly summary, monthly history)
- Integrated Insights screen (momentum, weekly activity, patterns, milestones)
- Library management for active/archived habits plus reminder management entry
- Onboarding gate controlled by `hasSeenGlowOnboarding`
- Home screen widget backed by shared App Group progress values
- SwiftData persistence with CloudKit private database configuration and local fallback

2) Architecture boundaries
- SwiftUI views handle presentation and user interaction
- View models own screen-level derived state and user intents
- Domain/utilities own pure calculations, reminders, persistence helpers, and widget synchronization

3) Reliability + UX goals
- Clean build with zero warnings
- Reminder scheduling is idempotent and safe to re-run
- Archived habits do not influence active-day stats or reminder scheduling
- Widget progress keys are written consistently and widget timelines reload after writes
- App remains functional even if CloudKit container setup fails (local fallback)
- UI test mode bypasses onboarding via `--uitesting`

4) Testing priorities
- HomeViewModel derived-state consistency (scheduled, completed, bonus, streak, summaries)
- Reminder filtering/scheduling and archived-habit exclusions
- Archive filtering and sort ordering
- Habit/HabitLog/HabitSchedule model rules
- Widget shared progress store key/value contracts
- Onboarding state transitions

## Architecture snapshot (current)
- App entry: `/Users/donnoel/Development/Glow/Glow/App/GlowApp.swift`
- Root shell: `/Users/donnoel/Development/Glow/Glow/Views/RootTabShell.swift`
- Section roots:
  - `/Users/donnoel/Development/Glow/Glow/Views/HomeView.swift`
  - `/Users/donnoel/Development/Glow/Glow/Views/InsightsRootView.swift`
  - `/Users/donnoel/Development/Glow/Glow/Views/LibraryRootView.swift`
- Primary view models:
  - `/Users/donnoel/Development/Glow/Glow/ViewModels/HomeViewModel.swift`
  - `/Users/donnoel/Development/Glow/Glow/ViewModels/HabitDetailViewModel.swift`
  - `/Users/donnoel/Development/Glow/Glow/ViewModels/TrendsViewModel.swift`
- Core models:
  - `/Users/donnoel/Development/Glow/Glow/Models/Habit.swift`
  - `/Users/donnoel/Development/Glow/Glow/Models/HabitLog.swift`
  - `/Users/donnoel/Development/Glow/Glow/Models/HabitSchedule.swift`
- Domain/services:
  - `/Users/donnoel/Development/Glow/Glow/Domain/StreakEngine.swift`
  - `/Users/donnoel/Development/Glow/Glow/Domain/NotificationManager.swift`
- Utilities:
  - `/Users/donnoel/Development/Glow/Glow/Utilities/SharedProgressStore.swift`
  - `/Users/donnoel/Development/Glow/Glow/Utilities/ModelContext+Save.swift`
  - `/Users/donnoel/Development/Glow/Glow/Utilities/GlowOnboardingView.swift`
- Widget extension:
  - `/Users/donnoel/Development/Glow/GlowWidgetExtension/GlowWidgetExtensionBundle.swift`

## Concurrency rules (important)
- Keep SwiftUI and observable view-model state on `@MainActor`.
- Keep non-UI domain logic deterministic and side-effect-scoped.
- Do not use broad actor annotations to hide isolation problems.

## Behavior invariants (do not regress)
- Archived habits are excluded from active home metrics and reminder scheduling.
- `scheduledTodayHabits`, `dueButNotDoneToday`, and `bonusCompletedToday` stay schedule-accurate.
- Distinct-day logic is preserved for consistency calculations (multiple same-day logs count once).
- Global streak/lifetime activity summaries are based on active-habit completed logs.
- Completion toggle undo remains fast, local, and non-modal.
- Reminder lists include only non-archived habits with reminders enabled and valid hour/minute.
- Reminder notifications use stable per-habit/per-weekday identifiers.
- Widget shared defaults use the existing keys: `today_done`, `today_total`, `today_bonus`, `today_date`, `today_stamp`, `last_updated`.
- App-group identifier remains `group.movie.Glow` unless explicitly migrated.
- CloudKit-backed model container failure falls back to local storage rather than crashing.
- Onboarding visibility remains controlled by `hasSeenGlowOnboarding` and UI tests can bypass onboarding.

## UX rules
- Keep primary flows fast: add habit, check in, and review daily status.
- Preserve readable, content-first hierarchy with restrained visual treatment.
- Keep Today, Insights, and Library predictable and easy to scan.

## Coding conventions
- Prefer small, testable helpers for date/schedule logic.
- Keep view files focused on composition; move derived logic into view models/domain.
- Preserve existing naming and data contracts unless migration is explicitly included.

## Build/run notes
- Project: `Glow.xcodeproj`
- Scheme: `Glow`
- Targets: `Glow`, `GlowTests`, `GlowUITests`, `GlowWidgetExtension`
- Build command:
  - `xcodebuild -project Glow.xcodeproj -scheme Glow -destination 'generic/platform=iOS Simulator' clean build`
- Test command:
  - `xcodebuild -project Glow.xcodeproj -scheme Glow -destination 'platform=iOS Simulator,name=iPhone 16' test`

## Near-term priorities
- Expand automated coverage for reminder + widget edge cases.
- Keep SwiftData + CloudKit behavior stable across schema updates.
- Maintain smooth rendering and interaction performance across Today, Insights, Library, and Habit Detail.

## Output expectations per patch
Provide:
- Summary of change
- Files modified
- Any migration considerations
- Commit message suggestion
