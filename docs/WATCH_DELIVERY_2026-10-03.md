# Watch companion delivery — October 3, 2026

## Implemented

- `GlowWatch/`: Today list, shared habit icons, habit selection, explicit
  completion/incomplete button, local feedback, and pending-sync status.
- `GlowShared/`: versioned packets, original civil-day check-ins, actor-owned
  atomic cache/outbox, foreground/background WatchConnectivity delivery.
- `Glow/Domain/GlowPhoneWatchSync.swift` and `HabitCompletionAction.swift`:
  phone-side saves to existing models, replay/order protection, receipt
  persistence, archived/deleted-habit rejection, and widget/UI refresh.
- Project and shared Watch scheme; app startup integration; one explicit
  nonisolated annotation on the existing pure martini icon shape for reuse in
  the Watch target. Existing habit setup and analytics stay on iPhone/iPad.
- Tests and project/README guidance. No CloudKit model schema migration.

## Automated validation

- All 91 Glow unit tests passed, including eight new Watch companion tests.
- After the final code adjustments, all eight Watch tests passed again, plus
  `GlowUITests/GlowUITests/testToggleFirstPracticeComplete`.
- Final named-device Debug builds for the Watch and iPhone passed without build
  warnings. Final unsigned Release Watch build passed without build warnings.
- Signing verification passed for Glow, its embedded Watch app, and its widget.
  All three carry version **2.1 (1)**.
- `git diff --check` and project plist validation passed.

## Physical delivery

| Device | Install | Launch | Additional evidence |
| --- | --- | --- | --- |
| Don's iPhone — iPhone 15 Pro Max, iOS 27.0.1 | Succeeded | Succeeded | Glow process observed running; updated companion installed |
| Don's Apple Watch — Ultra 4, watchOS 27.0.1 | Succeeded | Succeeded | CoreDevice acknowledged install and launch |

The user explicitly approved Xcode refreshing development provisioning,
including Watch registration if necessary. The resulting development profile
was verified to include the named Watch. The existing team and bundle
identifiers were preserved.

After hands-on testing, the user reported that everything was working and
accepted the current Watch companion for this sprint. Simulator appearance was
inspected using isolated sample habits. A physical Watch screenshot and cached
snapshot export could not be obtained: the Mac's diagnostic network tunnel to
the Watch disconnected after launch, and a bounded reconnect attempt failed.
This does not establish a WatchConnectivity failure between the Watch and
iPhone; that is a separate connection.

The user's hands-on acceptance is separate from the agent's automated evidence.
Prolonged offline/relaunch recovery, VoiceOver/large-text use, and eventual
iPad/widget propagation were not individually reported or independently
observed. The automated tests cover the outbox and model-write contracts; they
do not substitute for those specific device checks.

## Publication

After accepting the companion, the user authorized committing and pushing this
sprint to the repository's configured `github` remote on `main`. Feature commit
`07a87cb` was pushed successfully. No TestFlight submission or App Store release
was requested.

## Version 2.2 device follow-up

The user additionally requested an appropriate version increment and delivery to
all their devices. The new companion increments the shipping app, widget, and
Watch targets from 2.1 to **2.2 (1)**, including Debug and Release settings.

- Named-device Debug builds for the iPhone, iPad, and Watch passed with warnings
  treated as errors and no warnings reported.
- The signed app, widget, embedded Watch app, and standalone Watch app all
  report 2.2 (1). Strict signature checks passed, including deep verification
  of the containing iOS app. Profiles cover the named devices.
- The prior feature tests remain the behavioral validation. Tests were not
  repeated for this version-only follow-up.

| Device | 2.2 (1) install | Launch | Evidence |
| --- | --- | --- | --- |
| Don's iPhone — iPhone 15 Pro Max | Succeeded | Succeeded | Installed version read back; launch PID 1169 |
| iPad — iPad Pro 13-inch (M4), iPadOS 27.0.1 | Succeeded | Succeeded | Installed version read back; launch PID 890 |
| Don's Apple Watch — Ultra 4 | Succeeded | Succeeded | Installed version read back; launch PID 574 |

The first Watch launch attempt timed out establishing the Mac diagnostic
tunnel. A bounded retry using its CoreDevice identifier succeeded. Installation
preserved existing app data. These acknowledgements establish device delivery;
the user's hands-on acceptance above remains the product validation.

The version follow-up commit and final remote parity are recorded in Git and
the completion report.
