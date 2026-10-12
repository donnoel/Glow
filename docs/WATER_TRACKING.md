# Water tracking

Added in Glow **2.3 (1)** for iPhone and iPad. The Watch companion also logs
8, 21 or 24 US fl oz drinks and shows today's progress against the daily goal,
with an Undo last drink control. Settings and reports remain on iPhone/iPad.
The widget continues to show habit progress.

Today places Water below the daily habit summary. The initial quick amounts are
8, 12, 21 and 24 US fluid ounces. Tapping one saves a drink immediately; Undo
removes the most recently added entry. Custom amounts, entry editing and swipe
deletion are available. The last used amount is highlighted and saved locally.

On a wide iPad, the Water card places daily progress beside a larger 2×2 group
of quick amounts. Narrow windows and accessibility text sizes use the stacked
layout. The Daily Summary spreads its metrics across the iPad card.

Water settings saves four editable presets, US fluid ounces or milliliters,
and a Male, Female or Custom goal. Male starts at 100 fl oz and Female at 75
fl oz; either can be adjusted. These are rounded beverage-intake starting
points, not universal requirements to drink that amount as plain water. The
settings screen explains food and other drinks and links to the source:
[National Academies water guidance](https://www.nationalacademies.org/read/10925/chapter/6).

Open the Water total to see today's entries; the sliders button beside Water
opens Water settings. In Insights, choose 7 or 30 days and open a day in history to correct
its entries. Settings persist in the model store; last-amount highlighting is a
device-local preference. A tap on a quick amount logs immediately.

Water settings also offers opt-in [gentle water nudges](WATER_NUDGES.md): adaptive
Watch notification taps, automatic daytime pacing, and an independent
switch for quiet phone copies. Logging, undo and goal completion update the
plan; no hourly repeating alarm is used.

The fourth default changed from 32 to 24 fl oz. Previously saved settings with
32 fl oz in that position show 24 fl oz on upgrade; other amounts, goals and
logged drinks stay intact. New settings saves use a keyed JSON payload in the
existing data field, so a later explicit choice of 32 fl oz remains available.
This compatibility update adds no model fields or CloudKit schema changes.

The first drink logged on a civil day saves that day's goal. Changing settings
afterward applies to the next day logged. Editing or deleting drinks never
changes the saved goal. A day without entries is labelled No log; averages
include only logged days, including any partially logged current day.

Insights provides 7-day and rolling 30-day charts, saved goal markers, goal-day
counts, average on logged days, and daily history with entry correction.
Water never changes habit scores, widget counters or Watch habit completion.

## Storage and migration

`WaterEntry`, `WaterDayGoal` and `WaterPreferences` are additive SwiftData models
in the existing Glow container. Every field has a default; there are no unique
constraints or new relationships. The existing Habit/HabitLog fields remain
unchanged. The local schema migration and cold loading are covered by tests.

Preferences resolve by newest update time, then ID. Offline duplicate goal
snapshots resolve by earliest creation time, then ID, on all devices. Entries
retain their original Gregorian civil-day keys. Amounts are stored as mL,
with a single US fluid-ounce conversion, so switching units preserves totals.

The models use the existing private CloudKit configuration. A local save or
successful install does not prove iCloud propagation; verify that separately.
Production CloudKit schema deployment is a separate release step and is not
performed by this feature's local/device delivery.

## Validation

WaterTrackingTests covers quantities and locale input, repeated logging, undo,
correction/deletion, settings and last-amount persistence, historical goals,
duplicate snapshots, unlogged days, DST rollover, invalid input, and migration
of an existing habit store. Focused UI tests cover quick logging and relaunch,
Female/preset settings persistence, custom entry correction and Insights.

Before release, manually verify VoiceOver, larger text, light/dark contrast,
midnight behavior and iCloud water propagation on the intended devices.
See [October 10 delivery evidence](WATER_DELIVERY_2026-10-10.md) for completed
checks, user acceptance and the remaining verification boundaries.
The [Watch water delivery](WATCH_WATER_DELIVERY_2026-10-10.md) records the
companion extension's tests, paired-device integration and physical installations.
