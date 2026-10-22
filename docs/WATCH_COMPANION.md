# Glow Watch companion

GlowWatch shows existing active habits, with scheduled habits first and other
habits available for bonus check-ins. Tapping a habit row marks it done directly
on the main list; tapping again marks it incomplete, with no second screen or
confirmation. Habit creation, editing, archiving, and history stay in the
iPhone/iPad app. Large native controls, scalable text, explicit completion
labels, and a brief haptic keep check-ins simple.
No custom motion or glass effects are required.

The Water card shows today's total in US fluid ounces against the saved daily
goal, plus **12**, **21**, and **28 oz** quick buttons. Each tap logs immediately;
**Undo last drink** removes the most recent Watch drink. Goal reached is stated
explicitly. Goal settings, custom amounts, entry editing and reports stay in
the iPhone/iPad app. The Watch amounts are fixed and independent of phone presets.

## Data and delivery

The paired iPhone owns writes to Glow's existing SwiftData/CloudKit records.
Install the updated iPhone app and open it once to supply the initial habits.
The Watch retains the latest habit snapshot, calculates schedules at each day
rollover, and saves completion intentions before sending them. Pending changes
show **Saved on Watch · waiting to sync** until acknowledged by the phone.
Cached completion status from an earlier day is never presented as today's
status. Refresh or foreground activation requests a new snapshot and retries
pending intentions. Connectivity and background scheduling can delay delivery.

Water uses the same atomic local outbox and acknowledgement flow. Every drink
has a stable entry ID; retries reuse that ID instead of creating another entry.
Undo retains the ID with a later sequence so an older Add cannot restore it.
The phone writes existing `WaterEntry` and `WaterDayGoal` models, preserving the
original Gregorian civil day and daily goal. Snapshot entry IDs prevent pending
drinks from being counted twice while acknowledgements are in flight. Today's
water totals include phone/iPad entries received through the paired iPhone.
After midnight, yesterday's total is cleared from the display; pending deliveries
retain yesterday's day. Existing habit caches upgrade without losing check-ins.

Packets include an explicit status, original civil day, persistent Watch client
identifier, and monotonically increasing sequence. Foreground messages provide
the fast path; WatchConnectivity background transfers provide the queued path.
The phone's local receipt journal rejects duplicate or older intentions for
the same habit/day/client. Acknowledgements follow a successful model save and
atomic receipt write. Unavailable habits and invalid/future dates are rejected
with an explanation on the Watch. Persistence failures remain pending.

The Watch outbox and phone receipt journal use separate actor-owned atomic JSON
files under their respective Application Support/GlowWatch directories. The
Watch transport does not change Habit/HabitLog fields or the CloudKit container.
The iPhone/iPad app also includes additive water models described in
[Water tracking](WATER_TRACKING.md). Receipts are local transport
metadata; snapshots carry a bounded recent receipt window plus any receipt
needed for the current acknowledgement.

## Validation

- Build `GlowWatch` for watchOS Simulator and the named physical Watch with
  warnings treated as errors.
- Run `GlowTests/WatchCompanionTests` for offline completion/undo, late
  acknowledgements, day rollover, rejected changes, relaunch durability,
  corrupt-state preservation, explicit idempotent model writes, and packet/date
  validation. Run existing Glow unit tests for the app integration.
- `GlowTests/WatchWaterTests` covers repeated drinks, partial acknowledgements,
  undo before acknowledgement, rollover, relaunch, legacy cache decoding,
  duplicate phone delivery, saved goals and invalid/rejected commands.
- On paired physical devices, check initial habit loading, Watch completion and
  undo reaching iPhone, iPhone changes reaching Watch, offline/relaunch recovery,
  and eventual iPad/widget refresh. Simulator transport is not proof of physical
  WatchConnectivity delivery.
- Verify appearance, VoiceOver, large text, and the feel of the actual Watch
  separately from build/install/launch evidence.

See [Watch water delivery evidence](WATCH_WATER_DELIVERY_2026-10-10.md) for
the latest automated checks and named-device delivery; visual and real drink/undo
acceptance remain separate user checks.
