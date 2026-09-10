# Android equal-width rows and RTL spacing — September 6, 2026

Development implementation. The full Android target goal remains active.
Evidence root: `/tmp/ap-android-ime-proof.MD7civ`.

## Baseline and implementation

The preceding [input/API 31 checkpoint](android-input-api31-proof-2026-09-06.md)
finishes the required API 31 48-test/failure target and an API 35 48-test
instrumentation recheck. Those frozen packages precede the layout changes here;
they do not validate the new implementation.

The Android renderer previously ignored `HStack#fill_equally`. It now forwards
the setting through the checked `android_stack_set_equal_width` bridge to
`NativeLayout.configureEqualWidth`. Native equal-cell containers preserve real
widget identity, bounded/pinned content, callbacks and ownership. Content-sized
rows resolve a natural largest-cell width before the final equal allocation;
constrained rows obey the actual parent allocation. See the
[layout contract](android-layout.md) for the exact policy and limits.

The first implementation passes all four layout tests on API 35 (31.986 seconds)
but fails one of four on API 31 (25.312 seconds). The failure is a missing gap,
not unequal allocated widths. The focused diagnostic reproduces it in 2.668
seconds: `equal-pinned`, density 160, RTL, light mode, cells
`191:246, 136:191, 78:133, 20:75`; the first adjacent gap is zero instead of
three pixels. All results are retained in `equal-width-focused-*.txt` and
`equal-width-spacing-diagnostic-31.txt`.

Inspection of the official [Android 12 layout implementation](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-12.0.0_r1/core/java/android/widget/LinearLayout.java)
and [Android 15 implementation](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-15.0.0_r1/core/java/android/widget/LinearLayout.java)
confirms that the older horizontal layout checks the before-child divider while
walking RTL children in reverse; the newer version checks after-child instead.
The measured gap moves to an outer edge on the older API. Both primary sources
were read directly; this is not inferred solely from a passing recheck.

HStack spacing now uses owned logical margins instead of transparent dividers.
Margins are recomputed over visible children and resolved for the current
direction on each measure. VStack's middle-divider behavior remains unchanged.
The C spacing bridge delegates to the same canonical runtime. Tests assert exact
adjacent gaps for ordinary and equal rows; no assertion is relaxed to match the
older platform error.

## Verified so far

- `equal-width-structure-spec.txt`: five Crystal structure examples pass.
- `equal-width-shared-specs.txt`: 1,454 shared UI examples, zero failures/errors,
  66 existing pending cases. This is a shared host suite, not iOS runtime proof.
- `equal-width-spacing-jni-guard.txt`: sanitizer-backed checked-JNI guards pass.
- `equal-width-spacing-build.txt`: both ABI native libraries and debug/test APKs
  build in 30 seconds; 70 tasks, 14 executed and 56 up-to-date.
- `equal-width-spacing-focused-5558.txt`: four Android layout tests pass on
  API 31 in 26.182 seconds.
- `equal-width-spacing-focused-5556.txt`: four Android layout tests pass on
  API 35 in 31.306 seconds.
- The new measurements cover 12 density/direction/appearance configurations,
  natural/AT_MOST/exact sizing, pinned and maximum-bounded widgets, hidden
  children, Spacer minima, empty/single/all-hidden rows and Fill heights. Real
  taps, retired-button invocation, recreation and zero terminal native counts
  are separate assertions. Existing two-axis gestures and layout tests remain.
- The deliberate partial-render fixture now creates an equal-width cell around
  a callback-bearing bounded button before failing. Full failure-lane results
  for this revision are still required.

After the focused passes, further assertions were added for both outer edges,
identical shared metadata paths with/without cells and actual retired-button
detachment. These strengthened assertions are part of the complete run below;
they are not retroactively attributed to the earlier focused runs.

## Generated consumer and full regression

The CLI artifact inspector now requires the new equal-width export in both ABI
libraries. The generated counter uses a shared equal-width Save/Open Details
row; its own Android test measures the two cells and still performs the existing
validation, navigation, keyboard and process-restoration checks.

`equal-width-cli-full-spec.txt` passes **526 examples** in 15.37 seconds.
The actual rebuilt CLI is `/tmp/ap-android-ime-proof.MD7civ/amber-equal-width`,
SHA-256 `44f5937ffc620554739d655882f268f4347165288d2e7f28e84e879a4809e700`.

The fresh actual-CLI proof completes with exit zero from
`/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.6vbGKT`
against API 31 (`equal-width-fresh-consumer31.txt`):

- Shared model specs and the real web state/validation/CSRF/escaping checks pass.
- The fresh build takes 49 seconds; all 126 tasks execute. All 15 JVM reports
  contain **93 tests**, with zero failures/errors/skips; these are fresh tests.
- **13 Android tests pass in 28.381 seconds**, followed by a separate exact-state
  restoration test in 4.189 seconds. The real two-cell action-row assertion,
  Save, navigation, validation, keyboard and lifecycle checks are included.
- Process 11385 persists count **6** and `Android 雪 😀 é`; process 11507 performs
  read-only restoration. Normal process **11557** cold-launches in 1.335 seconds
  and displays that exact restored state. The screenshot is visually reviewed:
  Save name and Open details are two equal-width native buttons.
- Both ABI packages, required JNI exports and matching debug symbols pass.
  All **733** source entries match after completion: 36 generated, 242 Amber and
  455 AssetPipeline inputs (`equal-width-consumer-*-verification.txt`).

The same generated project's real script now also passes on API 35
(`equal-width-consumer35-run.txt`, `equal-width-consumer35/`): 13 tests in
37.473 seconds, then separate restoration in 5.406 seconds. Process 27841 saves
count 34 and the same exact Unicode name; process 27975 restores it, and normal
process 28025 relaunches. The actual equal-row screenshot is reviewed. The
22-second rebuild executes three of 126 tasks and reuses the 93 JVM reports;
it is not a second fresh JVM execution. This uses explicit development
dependencies, not released public packages. No generated source is manually
repaired.

The actual full Make target now passes with exit zero against API 35 in
`equal-width-native35/` (`make-equal-width-native35.txt`): **50 native tests in
746.306 seconds**, both ABI/package gates, all six isolated Crystal failures,
400 Java partial-render failures/original Throwable (12.100 seconds), Sheet
window failure (8.524 seconds), terminal cleanup and normal relaunch in process
27695. The 37-second build executes 21 of 123 tasks; unchanged JVM reports are
reused. All 512 source-ledger entries match after completion
(`equal-width-native35-final-source-verification.txt`). The stronger edge,
metadata-path and retired-widget assertions pass in this full run.

The complete API 31 Make target also passes with exit zero in
`equal-width-native31/` (`make-equal-width-native31.txt`): **50 native tests in
730.267 seconds**, all six isolated Crystal failure cases, 400 Java partial
renders/original Throwable (12.794 seconds), Sheet window failure (5.218 seconds)
and a normal final relaunch in process **13207**. All **512** source inputs match
after completion (`equal-width-native31-final-source-verification.txt`). The
debug/test APKs, release bundle and source-ledger hashes match the API 35 run.
The generated API 35 project's 36 generated and 242 Amber entries were also
reverified alongside the 455 AssetPipeline inputs: all **733** match.

## Still open

Before release, the toolchain also needs the newly verified API 36 target
requirement and an actual 16 KB runtime checkpoint; see
[Android 16 readiness](android-36-readiness.md).
The earlier intermittent input/insertion and first-use keyboard findings remain
recorded in the preceding checkpoint. Broader Tier A, keyboard/accessibility,
logical padding, tablet/device, independent x86_64 CI, AgentC integration and
public-release gates remain governed by the full implementation plan.
