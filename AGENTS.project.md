# AGENTS.project.md

# Glow Project Guide for Agents

## Product intent
Glow is a habit-tracking app focused on clear daily progress, low-friction check-ins, and calm visual feedback.
Success means users can define habits, follow schedules, complete check-ins, see progress trends, and keep data consistent across app + widget.

Current source version: **2.3 (2)** across Glow, GlowWidgetExtension and GlowWatch
(Debug and Release). Version settings live in `Glow.xcodeproj/project.pbxproj`;
About Glow and the system Settings version row read the built app bundle.

## Current product phase (implemented baseline)
1) Core scope
- Root shell with three sections: Today, Insights, Library
- Home dashboard (Today) with daily summary, due/completed/coming-up sections, and completion undo
- Water card on Today with editable 8/12/21/24 US fl oz presets, custom amounts, undo and entry correction
- Male/Female/Custom water goals and units persist; a day's first log saves its historical goal
- Opt-in gentle water nudges: progress-driven timing chosen automatically, up to three Watch taps per day, quiet overnight, independent quiet phone copies
- Water reporting in Insights covers 7/30 days and treats days with no entries as unlogged
- Habit creation/editing with title, schedule, icon, archive state, and reminders
- Habit detail analytics (streaks, weekly summary, monthly history)
- Integrated Insights screen (momentum, weekly activity, patterns, milestones)
- Insights momentum report preview with native text sharing for last 7 days, month/quarter/year to date, and lifetime; All habits (default) or Active only, archived check-in history, and separate hydration summaries
- Dedicated iPad Insights composition: full-width weekly story, habit rhythm table, highlights and a 2×2 metrics grid
- Library management for active/archived habits plus reminder management entry
- Onboarding gate controlled by `hasSeenGlowOnboarding`
- Home screen widget backed by shared App Group progress values
- SwiftData persistence with CloudKit private database configuration and local fallback
- Watch companion: existing habits, today's completion/undo, 8/21/24 oz water logging and daily goal progress, with a durable local outbox sent through the paired iPhone

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
- Water quantities, locale input, settings persistence, saved daily goals and additive-store migration
- Watch packet validation, durable outbox/receipts, original-day completion and idempotent water entries/undo

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
  - `/Users/donnoel/Development/Glow/Glow/ViewModels/InsightsViewModel.swift`
  - `/Users/donnoel/Development/Glow/Glow/ViewModels/WaterTrackerViewModel.swift`
- Core models:
  - `/Users/donnoel/Development/Glow/Glow/Models/Habit.swift`
  - `/Users/donnoel/Development/Glow/Glow/Models/HabitLog.swift`
  - `/Users/donnoel/Development/Glow/Glow/Models/HabitSchedule.swift`
  - `/Users/donnoel/Development/Glow/Glow/Models/WaterTracking.swift`
- Domain/services:
  - `/Users/donnoel/Development/Glow/Glow/Domain/StreakEngine.swift`
  - `/Users/donnoel/Development/Glow/Glow/Domain/NotificationManager.swift`
  - `/Users/donnoel/Development/Glow/Glow/Domain/WaterAnalytics.swift`
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
- Water entries remain separate from habit completion, global scores and widget counts; Watch water messages use their own commands and receipts.
- Water is stored in additive CloudKit-compatible models; never replace existing habit data during a schema update.
- Water nudges own `water.nudge.` identifiers, honor spent opportunities and quiet spacing, and never change water goals or habit reminders. Phone-copy preference is device-local; nudge configuration uses the existing presets payload.
- WaterDayGoal snapshots remain after entry deletion. Earliest snapshot wins if offline devices create duplicates.
- Global streak/lifetime activity summaries are based on active-habit completed logs.
- Completion toggle undo remains fast, local, and non-modal.
- Reminder lists include only non-archived habits with reminders enabled and valid hour/minute.
- Reminder notifications use stable per-habit/per-weekday identifiers.
- Widget shared defaults use the existing keys: `today_done`, `today_total`, `today_bonus`, `today_date`, `today_stamp`, `last_updated`.
- App-group identifier remains `group.movie.Glow` unless explicitly migrated.
- CloudKit-backed model container failure falls back to local storage rather than crashing.
- Watch packets set an explicit completion status for their original civil day; retries must not toggle or move a check-in to the delivery day.
- A Watch check-in stays pending until the iPhone saves it and returns a receipt. Archived/deleted habits are rejected without recreating them.
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
- Targets: `Glow`, `GlowTests`, `GlowUITests`, `GlowWidgetExtension`, `GlowWatch`
- Watch scheme: `GlowWatch`; sync contracts and actor-backed outbox live in `GlowShared/`.
- App Store release evidence: `docs/APP_STORE_RELEASE_2026-10-10.md`.
- Watch setup and validation: `docs/WATCH_COMPANION.md`.
- Watch water delivery evidence: `docs/WATCH_WATER_DELIVERY_2026-10-10.md`.
- Water behavior, migration and sync boundaries: `docs/WATER_TRACKING.md`.
- Gentle nudge pacing, permission, delivery and offline boundaries: `docs/WATER_NUDGES.md`.
- Water build/test/device evidence: `docs/WATER_DELIVERY_2026-10-10.md`.
- Build command:
  - `xcodebuild -project Glow.xcodeproj -scheme Glow -destination 'generic/platform=iOS Simulator' clean build`
- Test command:
  - Inspect installed destinations with `xcodebuild -project Glow.xcodeproj -scheme Glow -showdestinations`.
  - `xcodebuild -project Glow.xcodeproj -scheme Glow -destination 'platform=iOS Simulator,id=<installed-simulator-UDID>' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES test`

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
