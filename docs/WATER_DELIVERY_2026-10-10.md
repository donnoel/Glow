# Water tracking delivery — October 10, 2026

## Outcome

Implemented water tracking and installed/launched the signed **2.3 (1)** development build
on Don's iPhone 15 Pro Max and iPad Pro 13-inch (M4). Both running processes
were independently read back after launch. The user reviewed the delivered
feature and said "looks good," then authorized versioning, documentation updates,
commit and push. Detailed physical interaction checks and iCloud water
propagation remain unverified.

## Implemented

- Today water card below Daily Summary, with 8/12/21/32 US fl oz quick amounts,
  custom amounts, immediate logging, last-amount highlighting and Undo.
- Saved Male/Female/Custom goals, four editable quick amounts and fl oz/mL units.
  The initial male goal is 100 fl oz; the female suggestion is 75 fl oz.
- Entry history with correction and deletion, plus 7/30-day Insights charts,
  saved goal markers, logged-day averages and goal-day counts.
- Daily goal snapshots survive edits and deletion. New goals apply to the next
  day logged once today's first entry has saved its goal.
- Water stays independent of habit completion scores, widgets and Watch packets.
- Water sheets and Undo live outside the refreshed Today List, so SwiftData
  saves do not dismiss history or discard Undo.

## Changed files

- Storage: `Glow/Models/WaterTracking.swift`, `Glow/App/GlowApp.swift`.
- Quantities/reporting: `Glow/Domain/WaterAnalytics.swift`.
- Intents/settings: `Glow/ViewModels/WaterTrackerViewModel.swift`.
- UI: `Glow/Views/WaterTodayView.swift`, `WaterSettingsView.swift`,
  `WaterHistoryView.swift`, `WaterInsightsView.swift`, `HomeView.swift`,
  `InsightsRootView.swift`.
- Tests: `GlowTests/WaterTrackingTests.swift`, `GlowUITests/GlowUITests.swift`.
- Guidance: `AGENTS.project.md`, `README.md`, `index.md`,
  `docs/WATCH_COMPANION.md`, `docs/WATER_TRACKING.md` and this note.
- Version: `Glow.xcodeproj/project.pbxproj` (app, widget and Watch, Debug/Release).

## Validation

- Simulator and signed iOS device builds passed with no build warnings, with
  Swift and GCC warnings treated as errors.
- Full unit suite: **100 passed, 0 failed, 0 skipped**, including nine new water
  tests and an upgrade of a disk-backed Habit/HabitLog store to the additive
  water schema, followed by a cold reload.
- iPhone simulator: Female/preset settings persistence passed; final reruns for
  logging/Undo/relaunch and custom amount correction/Insights both passed after
  fixing accessibility and moving water presentation outside the refreshed List.
- iPad simulator: all three water UI tests passed after the presentation fix.
- Existing habit completion UI smoke test passed.
- Simulator Today and Insights layouts were visually inspected on iPhone and
  iPad. Runtime semantic snapshots verified the Water button's label/value and
  the quick-add and Undo actions. Full VoiceOver and larger-text acceptance
  were not performed.
- App, widget and embedded Watch signatures passed `codesign --verify --deep
  --strict`. Existing profiles cover both physical devices; no signing changes
  or device registration were needed.
- Initial feature validation/delivery used **2.2 (1)**. The approved publication
  follow-up increments the app, widget and Watch to **2.3 (1)** in Debug/Release.
  No TestFlight upload or store submission occurred.

## Initial physical delivery (2.2)

| Device | UDID | Install | Launch | Running process |
| --- | --- | --- | --- | --- |
| Don's iPhone 15 Pro Max | `00008130-0006448620E1401C` | Passed | Passed | PID 1605 |
| iPad Pro 13-inch (M4) | `00008132-000628660229001C` | Passed | Passed | PID 2252 |

Both devices report `movie.Glow`, version 2.2, build 1. Installation updated the
existing app without uninstalling it or resetting its data. No test fixtures
were written to either physical device.

## Version 2.3 follow-up

- Incremented all six shipping target settings (app/widget/Watch, Debug/Release)
  from 2.2 to **2.3**, retaining build **1**.
- Rebuilt the signed Debug iOS app and included extensions with Swift/GCC
  warnings treated as errors: passed with no warnings.
- Read app, widget and embedded Watch Info.plists: all report **2.3 (1)**.
  Strict deep signature checks passed for all three bundles. Release app/widget
  resolved settings and all shipping Debug/Release source settings agree.
- Updated and relaunched the existing app on each physical device, preserving
  its data. Installed versions and running processes were read back separately:

| Device | Installed version | Launch | Process readback |
| --- | --- | --- | --- |
| Don's iPhone 15 Pro Max | 2.3 (1) | Passed | PID 1616 |
| iPad Pro 13-inch (M4) | 2.3 (1) | Passed | PID 2259 |

The follow-up changes only version settings and documentation. The feature's
passing tests above were retained; no functional code changed after those tests.
README, project guidance and the landing-page source now describe current
water tracking, weekly Insights, iPad layouts and Watch check-ins. Relative
documentation links and `git diff --check` passed. The physical Watch was not
part of this two-device water delivery.

## Migration and remaining checks

Three new defaulted, CloudKit-compatible models are added to the existing
container. Existing Habit/HabitLog fields are unchanged; the disk-store upgrade
test retained an existing habit and completion log. Production CloudKit schema
deployment was not performed. Cross-device water sync is not claimed as verified.

The user's general visual acceptance is recorded above; it does not identify
specific functional checks on each device. Pending manual checks: detailed
physical water interactions, VoiceOver/larger text, and iCloud water propagation.

## Fourth quick amount follow-up

Changed the fourth default from **32 to 24 US fl oz**. Legacy saved settings
upgrade that fourth amount when it is still 32 fl oz; other presets, goals,
logged drinks and daily snapshots remain intact. New settings saves use a keyed
payload in the existing Data field so users can explicitly choose 32 fl oz again.
No model fields or CloudKit schema changes were introduced.

- Focused validation: **10 water unit tests + 1 quick logging/Undo/relaunch UI
  test passed**, with zero failures or skips. The UI test verified the fourth
  button's label and that tapping it adds exactly 24 fl oz.
- Signed device build passed without warnings; app, widget and embedded Watch
  versions remain **2.3 (1)** and strict signature verification passed.
- Updated the existing app without uninstall/reset on Don's iPhone and iPad.
  Install, launch, installed-version and running-process checks passed separately:
  iPhone PID **1625**, iPad PID **2270**.
- Updated README, project guidance and water behavior documentation.

The physical-device button appearance and interactions remain pending user
verification; installation and running-process checks do not establish them.

## iPad Today layout follow-up

The wide iPad Water card now places daily progress beside larger quick-add
buttons in a 2×2 grid. Narrow windows and accessibility text sizes retain the
stacked layout. Daily Summary metrics use the card's width and stack at
accessibility text sizes. iPhone and Watch presentation stays unchanged.

- Signed builds for the named iPad and iPhone passed with no warnings; strict
  deep signature verification passed. Version remains **2.3 (1)**.
- The existing iPad quick logging/Undo/relaunch UI test passed. It verified
  8 + 24 fl oz, Undo back to 8 fl oz, and the total after relaunch.
- Inspected a screenshot captured from the physical iPad. The user reviewed
  the delivered layout and said "yep i like that better," then authorized
  delivery to all devices and commit/push.
- Installed and launched the current app independently on Don's iPhone 15 Pro
  Max, iPad Pro 13-inch (M4), and Apple Watch Ultra. Existing data was preserved;
  no test drinks or habits were inserted on physical devices.
- Updated water behavior documentation. No model or persistence changes.

This records iPad portrait visual acceptance. Full VoiceOver, larger text and
narrow-window interaction checks remain pending; the layout includes fallbacks
but those checks were not performed in this follow-up.
