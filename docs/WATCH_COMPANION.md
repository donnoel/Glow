# Glow Watch companion

GlowWatch shows existing active habits, with scheduled habits first and other
habits available for bonus check-ins. Selecting a habit opens **Done today** or
**Mark incomplete**. Habit creation, editing, archiving, and history stay in the
iPhone/iPad app. Large native controls, scalable text, explicit completion
labels, and a brief haptic keep check-ins simple. No custom motion or glass
effects are required.

## Data and delivery

The paired iPhone owns writes to Glow's existing SwiftData/CloudKit records.
Install the updated iPhone app and open it once to supply the initial habits.
The Watch retains the latest habit snapshot, calculates schedules at each day
rollover, and saves completion intentions before sending them. Pending changes
show **Saved on Watch · waiting to sync** until acknowledged by the phone.
Cached completion status from an earlier day is never presented as today's
status. Refresh or foreground activation requests a new snapshot and retries
pending intentions. Connectivity and background scheduling can delay delivery.

Packets include an explicit status, original civil day, persistent Watch client
identifier, and monotonically increasing sequence. Foreground messages provide
the fast path; WatchConnectivity background transfers provide the queued path.
The phone's local receipt journal rejects duplicate or older intentions for
the same habit/day/client. Acknowledgements follow a successful model save and
atomic receipt write. Unavailable habits and invalid/future dates are rejected
with an explanation on the Watch. Persistence failures remain pending.

The Watch outbox and phone receipt journal use separate actor-owned atomic JSON
files under their respective Application Support/GlowWatch directories. The
CloudKit model schema and container are unchanged. Receipts are local transport
metadata; snapshots carry a bounded recent receipt window plus any receipt
needed for the current acknowledgement.

## Validation

- Build `GlowWatch` for watchOS Simulator and the named physical Watch with
  warnings treated as errors.
- Run `GlowTests/WatchCompanionTests` for offline completion/undo, late
  acknowledgements, day rollover, rejected changes, relaunch durability,
  corrupt-state preservation, explicit idempotent model writes, and packet/date
  validation. Run existing Glow unit tests for the app integration.
- On paired physical devices, check initial habit loading, Watch completion and
  undo reaching iPhone, iPhone changes reaching Watch, offline/relaunch recovery,
  and eventual iPad/widget refresh. Simulator transport is not proof of physical
  WatchConnectivity delivery.
- Verify appearance, VoiceOver, large text, and the feel of the actual Watch
  separately from build/install/launch evidence.
