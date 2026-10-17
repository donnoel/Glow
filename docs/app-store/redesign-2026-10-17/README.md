# Glow screenshot direction — October 17, 2026

**Approved and submitted: Glow 2.4 (3), Waiting for Review.**
[Submission details](https://appstoreconnect.apple.com/apps/6755254758/distribution/reviewsubmissions/details/7c3add5e-9d44-406c-a24c-598d4f22d939) · `submitted-waiting-for-review.png` · `submission.json`. Open `index.html` for the
local gallery, enlarged previews, original captures, size variants and contact sheets.

## Current app and live state

Glow Daily Practice (`movie.Glow`), App Store ID **6755254758**.
[App Store Connect](https://appstoreconnect.apple.com/apps/6755254758/distribution/ios/version/deliverable)
initially showed **iOS 2.3 (2), Ready for Distribution**, with no pending/editable version.
After screenshot approval and the user’s correction to the version convention,
**2.4 (3)** was created, uploaded, attached and submitted. Apple independently
showed **Waiting for Review** for the submission and its app-version item at
**10:50 AM Pacific on October 17, 2026**. No existing submission was removed.

Shipping native targets support iPhone, iPad and Apple Watch. There is no tvOS,
macOS or visionOS target; no Apple TV screenshot set is proposed. Compatibility
availability on other hardware is not a separate native screenshot platform.

Existing English (U.S.) assets in Media Manager:
- iPhone Dynamic Island large: five custom screenshots, old framed design.
- iPhone Dynamic Island medium: five inherited screenshots, Using Existing Assets.
- iPhone Face ID large: five inherited screenshots, Using Existing Assets.
- iPad 13-inch: five custom portrait screenshots, old framed design.
- Apple Watch Ultra 4: one `watch-water.png` screenshot.

The existing iPhone/iPad sequence was Today, old Insights, Library, habit history
and an empty New Practice form. Its captions were Stay focused today; See your
momentum clearly; Keep habits organized; Track progress over time; Build routines
your way. The replacement emphasizes the actual water feature and current weekly
rhythm, populated histories and a configured form. The released 2.3 assets remain intact. Only the new 2.4 screenshot placements
and Description were changed. The localization menu confirmed only English (U.S.).
Face ID large still uses inherited assets and now shows the approved sequence.
Apple’s iPad and Watch scaling/localization confirmations were read and accepted.
No app previews existed in the changed sets; none were added or removed.

## Proposed sequence

| Order | iPhone | iPad |
| --- | --- | --- |
| 1 | Daily habits. One clear view. | Your daily habits, clearly in view. |
| 2 | See your weekly rhythm. | See your weekly rhythm. |
| 3 | Log every drink. See your daily total. | Water, alongside your daily habits. |
| 4 | See your progress over time. | Every habit has a history. |
| 5 | Choose the days that work for you. | Your week. Your schedule. |

First three: identify the habit tracker; show the usefulness of scheduled versus
completed habits; introduce water alongside habits. iPad uses its real landscape
sidebar and wide report/table layouts. Selected exports use one contiguous crop
of a genuine capture, documented in `manifest.json` and `tools/render.swift`.
No app UI was reconstructed, repainted, retouched, rearranged or generated.

The Watch set uses two full, native captures: daily habit/water progress;
quick water amounts with today’s check-ins. Watch captions are review labels in the gallery, not overlays
on the small screenshots. The dark Watch appearance is the app's real watchOS UI.
The phone/iPad direction uses pale mint, subtle lavender, dark evergreen text and
Glow's teal accent, derived from `GlowTheme` and its asset colors. There are no
added device frames, reflections or ornamental illustrations.

## Deliverables and Apple specifications

12 compositions / **17 upload PNGs**:
- Five iPhone medium, **1206 × 2622**.
- Five matching iPhone large, **1320 × 2868**. These uniformly scale the genuine
  medium-size capture within the composition; UI proportions are preserved.
- Five iPad 13-inch landscape, **2752 × 2064**.
- Two Apple Watch Ultra, **422 × 514**, consistent with the existing Watch size.

Exports are opaque RGB PNGs with sRGB color space. Original captures remain in
`captures/`; upload candidates are only in `exports/`. Four contact sheets include
both iPhone size variants. File dimensions, PNG color type and SHA-256 hashes are
recorded in the manifest; `SHA256SUMS` covers the review package.

Apple's [current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
were checked on October 17. They require the medium Dynamic Island iPhone size,
iPad 13-inch when supported, one to ten images per device size, PNG/JPEG without
alpha, and a consistent Watch size across localizations. The proposed large
source set also matches the existing inheritance setup. iPhone Duo is optional
for this release; no Duo optimization claim is made.

## Capture provenance and validation

- Source commit: `34b2538` (full SHA in manifest), unchanged application source.
- Current source is labelled **2.3 (2)**. The only changes after published release
  commit `29d3f07` add water nudges; they are not shown or claimed in the proposal
  or Description draft. This capture source must not be confused with the exact
  published binary. Screen features shown here already exist in the released 2.3.
- Release Simulator builds: Glow and GlowWatch, Xcode 27 RC, warnings treated as
  errors; both passed with zero build warnings. No signing changes, dependency
  installations, behavior changes, test additions or new archive/upload.
- Captures: iPhone 18 Pro / iOS 27.0; iPad Pro 13-inch (M5) / iPadOS 27.0;
  Apple Watch Ultra 4 / watchOS 27.0.
- Fictional data: five habits, 35 days of completion history, 30 days of water
  reporting with two deliberately unlogged days, 80 fl oz custom goal. Today has
  four scheduled habits, two completed, 57 fl oz logged. No personal data used.
- `--uitesting` uses the existing onboarding bypass and prevents the phone's
  Watch/nudge coordinators from starting. Models were seeded only in backed-up
  Simulator stores using their existing schema, without CloudKit record writes.
  The Watch cache was likewise seeded with synthetic snapshots, no pending actions.
- Original Simulator data/preferences were backed up under
  `/tmp/glow-screenshots-2026-10-17/` and restored after capture. Status-bar overrides
  were cleared; initially shut-down iPhone and Watch simulators were shut down.
- Visual QA includes every final contact sheet, the enlarged gallery and selected
  full-resolution exports. All capture/placement rectangles stay inside their
  source images; rendering uses uniform scaling only. No feature-test rerun was
  needed for assets/tooling/documentation.

## Approved publication and release evidence

The user approved the complete screenshot direction and Description and authorized
upload and submission. They then required the existing two-part version convention;
the new release uses **2.4 (3)**, not a three-part marketing version.

Apple’s released-version controls were disabled, requiring a new editable release.
`tools/archive_release.py` extracts the exact published source commit
`29d3f071ab45bb51d9c4aabffc7e9f614cbba614` into a temporary folder, applies Xcode
`MARKETING_VERSION=2.4` and `CURRENT_PROJECT_VERSION=3` overrides to all targets,
and archives with warnings treated as errors. The app, widget and Watch bundles
all verified **2.4 (3)**, with zero warnings and strict deep signature verification.
No application source or checked-in version settings were modified. The later
water-nudge commits on main remain intact and are excluded from this binary.

The archive is saved in Xcode Archives as `2026-10-17/Glow 2.4 (3).xcarchive`.
`release-build.json` records source, binary/log hashes, archive and persistent log
paths. Xcode export/upload succeeded using the existing automatic signing setup;
Apple processed build 3, and it was selected and saved on version 2.4. The required
encryption questionnaire used the same system-only answer as the unchanged shipped
source: None of the algorithms mentioned above. No legal agreement was accepted.

All **17 approved PNGs** were uploaded to the matching size sets. Their exact hashes
and the approved Description hash still match `approval.json`. Old screenshot
placements on the new version were removed using Apple’s normal confirmation;
original assets remain in Asset Library. The prior What’s New text was copied
verbatim into the new version’s initially empty field. Keywords, URLs, privacy,
age rating, pricing, availability, review contact, previews and other metadata
were preserved. Automatic release, immediate updates and retained rating were
preserved. No signing or account settings changed.

Both **Add for Review** and final **Submit for Review** completed. The resulting
submission details showed **iOS App 2.4, build 2.4 (3), Waiting for Review**, with
submission ID `7c3add5e-9d44-406c-a24c-598d4f22d939`. See `submission.json` and the
saved full-page proof. Apple review completion remains pending.

Validation remained focused: release archive, bundle versions/signatures, upload,
Apple processing/attachment, all screenshot filenames/counts and inherited source,
Description and retained metadata, final review status, PNG dimensions/color mode,
approved content hashes and repository diff checks. No new tests, dependency
installation, signing reconfiguration or app behavior changes.
