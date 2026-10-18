# Momentum reports

Insights has one report toolbar button. It opens a read-only preview with two
choices: reporting period and included habits. Share uses the native share
sheet to send the preview's text to Messages, Mail, Copy, or another destination.
Mail receives a report subject. Generating a report does not send anything.

## Periods and included data

- Weekly: last seven civil days, including today, matching Insights.
- Monthly: current calendar month through today.
- Quarterly: current calendar quarter through today.
- Annual: current calendar year through today.
- Lifetime: earliest included habit creation or valid water log through today.
- All habits is the default, including saved archived habits and their history.
- Active only restricts habit history to currently non-archived habits.
- The habit filter does not affect the separate water summary.

Reports include total check-ins, distinct days with a check-in, a scheduled
completion rate for currently active habits, bonus check-ins for active habits,
and a per-habit breakdown. Multiple completed logs for one habit/day count once.
Dates before a habit's creation and future days do not contribute.

Archived habits contribute their recorded check-ins to total check-ins and days
with activity. They are labeled Archived and do not contribute scheduled
opportunities or lower the scheduled rate. Their earliest creation date remains
eligible for the lifetime window when All habits is selected. Reactivating a
habit makes its existing history available under Active only again.

Glow does not store past schedule changes or pause/archive dates. Active-habit
scheduled rates therefore use current schedules from creation; reports cannot
reconstruct exact scheduled opportunities during past pauses. Deleted habits
cannot be recovered. These limits and the current-device data boundary are
included in the preview and shared report. Today is labeled as still in progress.

Water reporting uses existing civil-day analytics and the earliest saved goal
snapshot for each day. It includes logged days, total volume, average on logged
days, and goal attainment among logged days with saved goals. Missing goals are
reported separately; unlogged days are not interpreted as zero intake. Water
never changes habit totals or completion rates.

## Implementation

- `Glow/Domain/MomentumReport.swift`: periods, scope, calculations and shared text.
- `Glow/ViewModels/MomentumReportViewModel.swift`: report snapshot for the sheet.
- `Glow/Views/MomentumReportView.swift`: native selectors, preview and ShareLink.
- `Glow/Views/InsightsRootView.swift`: toolbar entry and sheet presentation.
- `GlowTests/MomentumReportTests.swift`: calculation and historical-data coverage.
- `GlowUITests/GlowUITests.swift`: period/scope selection, preview and share sheet.

No model, schema, entitlement, dependency or persistence changes are needed.
Reports use dynamic text, semantic native controls and headings, labeled share
actions, reading order matching the text preview, and scrollable content. They
add no custom motion or transparency effects.

Suggested commit message: `Add shareable momentum reports to Insights`.

## Validation and device delivery — October 18, 2026

- Signed universal iOS Debug build, including widget and bundled Watch content,
  succeeded with Swift and C warnings treated as errors and no build warnings.
  Deep/strict signature verification passed for `movie.Glow`, team `H7LG8SK72M`.
  Existing component versions remain 2.3 (2); this is a local feature delivery.
- Nine report tests and four existing Insights tests passed. Coverage includes
  civil-date and calendar boundaries, leap year/DST, duplicate check-ins,
  creation dates, active/all scope, archived history and reactivation, hydration
  goals/units/missing days, empty data, and weekly parity with Insights.
- Report UI flow exercises all five periods, both habit scopes and native text
  sharing. iPad's largest accessibility text size and dark appearance were
  visually checked. The native compact share menu exposes Copy through View
  More; the test follows that step and captures the full system screen.
- Updated the existing installation without an uninstall or data reset on
  Don's iPhone 15 Pro Max (`00008130-0006448620E1401C`) and iPad Pro 13-inch (M4)
  (`00008132-000628660229001C`). Both launched and their live app processes were
  independently verified (PIDs 790 and 1370).
- No new Watch reporting screen, App Store submission, message or email send
  was performed. Full VoiceOver testing, physical-device share sending and
  cross-device CloudKit reconciliation remain hands-on checks.

Focused calculation evidence: `/tmp/glow-momentum-final-iphone.xcresult`.
Final UI evidence: `/tmp/glow-momentum-iphone-verified.xcresult` and
`/tmp/glow-momentum-ipad-verified.xcresult`.
