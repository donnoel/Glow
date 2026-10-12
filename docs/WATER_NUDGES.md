# Gentle water nudges

Water settings includes **Gentle water nudges**, off until enabled. Glow chooses
reminder times from logged progress; there are no reminder-time controls.
Save, then open Glow on the paired Watch and choose **Enable water taps** if
watchOS has not granted notification permission. System notification, Haptics
and Focus settings control actual presentation.

The aim is activity-reminder-style encouragement: a normal Watch notification
tap and a short water-break message. It is based on logged progress toward the
user's chosen goal. It does not infer unlogged drinks or change the goal.

## Timing and delivery

- At most three nonrepeating opportunities per day, at least three hours apart.
- Glow estimates steady progress through an automatic 8 AM–9 PM daytime window
  and allows a ten-percentage-point cushion behind that pace. Current intake
  determines the first useful opportunity, rather than fixed checkpoints.
- A drink gets 90 minutes of quiet when near pace, or 45 minutes when at least
  25 percentage points behind. Automatic nudges remain three hours apart.
- Enabling or refreshing late in the day while behind can schedule one nudge
  about five minutes later, subject to drink/nudge cooldowns. Refreshes preserve
  that deadline. No automatic alert is scheduled at or after 9 PM; there is no
  extra cutoff an hour earlier. Late copy encourages comfortable sips without
  suggesting rushing the remainder of the goal.
- Today uses the goal saved with that day's first entry, the current valid
  drinks, display units and most recent remaining drink timestamp. Corrections,
  deletion, undo and goal completion refresh the plan. Goal completion cancels
  the rest of today's alerts.
- Today’s wording is conditional: “If you haven’t logged more…” followed by the
  amount remaining and time to spread it over. Later-day fallbacks invite a
  small water break without claiming a deficit or a known amount consumed.

Watch requests are scheduled on the Watch with normal active notification
presentation and default sound, which uses the system notification haptic.
This works without an app timer running in the background. Direct background
calls to `WKInterfaceDevice.play` are not used to deliver nudges. Water alerts
also request normal presentation while Glow is frontmost, so keeping the app
open during a check-in does not silently suppress them.

The Watch shows the next automatic request read from its notification center.
No button press is needed to trigger a nudge. Logging more water can postpone
or cancel the next request as progress changes.

**Quiet phone notifications** keeps an optional passive, sound-free copy in
this device's Notification Center. This switch is local to each phone/iPad and
can be disabled while Watch taps remain enabled. Passive presentation avoids
requesting a second interrupting wrist alert when iOS forwards a notification.
Apple controls forwarding and presentation; paired-device behavior needs
physical verification.

A finite rolling seven-day plan supplies conditional reminders if the apps
remain closed. Opening Glow, logging/undoing on Watch, receiving a phone
snapshot, or changing phone data/settings refreshes that horizon. If there has
been no app activity or snapshot delivery for seven days, reminders expire.
Background refresh is not a guaranteed daily execution service. A stale Watch
snapshot never becomes a claim about today's intake.

Watch totals include locally queued drinks and exclude locally undone drinks,
so offline logging can quiet the Watch immediately. Phone and iCloud changes,
including disabling all nudges, reach the Watch on its next successful
WatchConnectivity delivery. A disconnected Watch can retain its previous plan
until then.

## Persistence and boundaries

Nudge settings are encoded alongside amounts in the existing `presetsData`
dictionary-of-numeric-arrays payload. Older array/keyed presets still load,
and released clients can still read custom quick amounts after a new save.
Editing water settings in an older client can drop the nudge configuration;
re-enable it in the updated app or update other devices before editing settings.
Existing amounts remain intact,
and older Watch packets without nudge fields decode with nudges disabled.
There are no new SwiftData fields, CloudKit record types, dependencies or
network services.

The scheduler actor serializes updates and owns `water.nudge.` requests.
It preserves habit notifications. A device-local ledger remembers
spent slots across dismissal, relaunch, setting changes and re-enabling;
rescheduling cannot create more than three daily opportunities.
The queue conservatively reserves notification capacity for existing habit
reminders, so the fallback horizon can be shorter when many are scheduled.

## Validation

Planner and scheduler tests cover pacing, recent drinks, quiet hours, limits,
cancellation, permission denial, stale snapshots, day rollover/DST, dismissed
slots, relaunch, notification presentation modes and overlapping updates.
Water tests cover settings payload compatibility, cold loading, unchanged
amounts and Watch timestamps/optimistic undo. The focused settings UI test
checks enabling nudges, independently disabling phone copies, and relaunch.

Before accepting device behavior, verify actual Watch taps, locked/unlocked phone
forwarding, Focus/Silent Mode, background snapshot updates, iCloud settings
propagation, VoiceOver and larger text on the intended devices. A simulator
build or passing tests do not prove those physical interactions.

Apple references: [notification forwarding](https://developer.apple.com/documentation/watchos-apps/taking-advantage-of-notification-forwarding),
[notification haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics),
[background updates](https://developer.apple.com/documentation/watchos-apps/keeping-your-watchos-app-s-content-up-to-date).

## Initial October 11, 2026 delivery evidence

- All 134 unit tests passed after the final app changes. The new settings UI
  test passed independently, including opt-in, phone-copy disable, relaunch and
  switching nudges off again. The existing water-settings UI test also passed.
- Final simulator, named iPhone and named Watch builds passed with warnings
  treated as errors and zero compiler warnings. Deep/strict signing validation
  passed for the phone bundle and standalone Watch bundle.
- An existing in-memory ModelContext save-test helper tried CloudKit setup for
  `/dev/null` and crashed. Explicit `.none` CloudKit configuration keeps that
  test local; the full unit suite then passed.
- Glow 2.3 (2) Debug was installed and launched on Don’s iPhone (iPhone 15 Pro
  Max, launch PID 892) and Don’s Apple Watch (Watch8,1, launch PID 2344). Both
  installed versions were read back as 2.3 (2). The first Watch connection
  timed out; retrying with its current CoreDevice identifier succeeded.
- The user enabled notifications and reported the initial UI looked good.
  Scheduled haptic delivery, actual tap feel, Focus/forwarding behavior and
  background/CloudKit propagation remain pending hands-on verification.
- No physical water entries or habit completions were inserted by the agent.
  No iPad delivery, version bump, TestFlight or App Store submission was
  requested or performed for this change.
- The user subsequently authorized committing and pushing the feature to the
  configured `github` remote on `main`. Source publication remains separate
  from the pending scheduled-haptic acceptance check.

## October 11 automatic-timing correction

The original checkpoints ended at 6:24 PM and excluded the final hour before
9 PM, so enabling later could leave no opportunity that evening. The updated
planner derives timing from progress, gives late starts a useful opportunity,
and removes the time pickers. Existing saved hour fields remain compatible but
do not choose reminder times. The Watch presents water notifications while
Glow is frontmost and displays its next actual pending automatic request.

A temporary diagnostic button verified delivery: the user reported receiving
the explicitly requested test notification. That button and its scheduling
path were then removed from the normal app. Automatic scheduling does not
require a button press; actual automatic delivery remains a separate check.

- Final 138 unit tests passed with no failures or compiler warnings after
  removing the diagnostic path. The settings UI regression passed during the
  timing correction, including the absence of reminder-time pickers.
- Signed phone and generic watchOS builds passed with warnings treated as
  errors and zero compiler warnings. Deep/strict code-signature checks passed.
  The named Watch build destination had stalled connecting, so the signed
  generic Watch artifact was installed on the explicit physical Watch instead.
- Glow 2.3 (2) was installed and launched on Don’s iPhone (PID 992) and Don’s
  Apple Watch (PID 2361). No physical water entries or habit completions were
  inserted by the agent.
- After reinstall, the Watch’s persisted scheduler ledger retained today’s
  8:56:34 PM request. The latest input was 61 oz toward a 100 oz goal, with the
  most recent drink at 8:11:34 PM. The 45-minute pause applied because progress
  was at least 25 percentage points behind daytime pace. Further water logging
  can revise that plan. The user has not yet confirmed this automatic alert.
- The user authorized committing and pushing this correction after device
  installation, with automatic nudge behavior to be checked tomorrow. Source
  publication remains separate from that hands-on check. The initial feature
  was published separately as `28639c8`.
