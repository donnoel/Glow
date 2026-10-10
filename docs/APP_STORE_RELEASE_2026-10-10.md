# Glow App Store update — October 10, 2026

## Release candidate

- App Store Connect app: Glow Daily Practice, Apple ID `6755254758`.
- Public baseline: **2.1 (1)**, Ready for Distribution April 18, 2026.
  The April 18 version commit is `61e9bdc`; current feature source is `ef3fb13`.
- Candidate: **2.3 (2)** across Glow, GlowWidgetExtension and GlowWatch,
  Debug and Release. Build 2 follows the local development build 1; no 2.3
  build had previously been uploaded.
- Existing automatic release, immediate updates and retained rating settings
  were preserved. Description, keywords, URLs, existing iPhone/iPad screenshots,
  privacy information, age rating, pricing and availability were not edited.

## What’s New

• Glow comes to Apple Watch: check off today’s habits, undo check-ins, and log water from your wrist.
• Track daily water intake with quick amounts, custom goals, editable entries, and 7- and 30-day reports.
• Refreshed Insights highlight your weekly habit rhythm, with layouts designed for iPad.
• Updated app and widget visuals, easier check-ins, and improvements to reminders and reliability.

## Focused validation

- Release archive succeeded with **zero warnings**, using Xcode 27.0
  (`27A266a`), Swift/GCC warnings treated as errors, and the existing automatic
  signing setup for team `H7LG8SK72M`.
- Archive app, widget and embedded Watch Info.plists all read **2.3 (2)**.
  Strict deep code-signature verification passed.
- Xcode App Store Connect export/upload succeeded. Apple processed the build,
  which was attached and submitted for review as recorded below.
- No application behavior changed for this release preparation. The feature
  validation and physical acceptance records remain in the water/Watch delivery
  notes; no test-suite expansion or additional physical-device testing was run.
- Archive saved in Xcode Archives as `2026-10-10/Glow 2.3 (2).xcarchive`.
  Build/upload logs are in `/tmp/glow-appstore-2026-10-10/`.

## CloudKit release prerequisite

A live schema comparison found Production `iCloud.movie.Glow` lacked the water
record types. Development contained WaterEntry and WaterDayGoal but had not yet
created WaterPreferences. The user explicitly authorized initialization of the
missing preferences schema and additive deployment of all three water types.

The development schema was exported before importing a copy with only the
CD_WaterPreferences definition added. Apple’s import validation passed. The
Production deployment preview contained only creation of CD_WaterEntry,
CD_WaterDayGoal and CD_WaterPreferences, with 13, 13 and 18 indexes respectively
and the same generated role grants as the existing model types. Existing habit
and user definitions were preserved. No user records were changed.

CloudKit Console confirmed “The schema is deployed to Production.” Production
record-type pages independently showed all three water types and their expected
fields, primitive types and query/search/sort indexes. Habit and user types
remained present. This verifies schema readiness; it does not establish runtime
cross-device water synchronization.

## App Store submission

Apple finished processing **2.3 (2)**. The required export-compliance question
was answered “None of the algorithms mentioned above”; repository inspection
found no app-implemented cryptography, only Apple system services. Build **2**
was selected and saved on the 2.3 App Store version record.

The first Add for Review attempt identified one required additional asset:
“Your binary indicates support for Apple Watch. You must provide an Apple Watch
screenshot.” Added `app-store/2.3/watch-water.png`, an unedited **422 × 514**
screenshot of the current Release Watch simulator app with synthetic habit and
water data. No personal records were uploaded. The previous simulator cache
was backed up and restored after capture; existing iPhone/iPad screenshots were
retained. The screenshot build also succeeded without warnings.

Final Submit for Review succeeded on October 10, 2026 at **4:14 PM Pacific**.
The submission details independently showed **iOS App 2.3, build 2.3 (2)** and
**Waiting for Review** for both the submission and its app-version item.
Submission ID: `e12363f6-4008-4a94-8d96-6661de126b56`.
