# Native layout checkpoint — September 5, 2026

Status: **verified development progress, not full Android target completion**.
This is not full Android target completion. The [layout contract](android-layout.md)
defines native allocation behavior and explicitly unsupported extensions.

## Implemented scope

- Native min/max sizing now distinguishes unspecified, zero, fixed and bounded
  axes. Maximum-only and distinct bounds retain the actual widget in an owned
  wrapper; the parent allocation versus content bound is explicit.
- VStack/HStack cross-axis alignment and ZStack alignment/draw order are
  configured through native parent-specific layout parameters. START/END track
  resolved direction; exact pins survive Fill.
- Fractional Spacer minima are converted after density multiplication and
  flexible space applies only along a linear parent's axis. Hidden bounded
  children do not introduce layout space or stack gaps.
- ScrollView has real vertical-only, horizontal-only, both-axis and neither-axis
  implementations, actual indicator flags and explicit/flexible viewport sizing.
- New layout JNI operations use the existing checked exception boundary. Both
  widget and bounds wrapper participate in immediate explicit ownership cleanup.
- Generated apps require all five layout exports in both ABI package inspections
  and require the canonical LayoutPolicy JVM report. The generated counter's
  native name field uses a bounded flexible width and asserts that bound.

## Focused native proof

Evidence: `/tmp/amber-android-layout-proof/layout-focused`.

The actual native layout matrix passes **24 configurations**: densityDpi
160/240/320, LTR/RTL, available widths 400/800 dp and light/night contexts.
Assertions measure real widget dimensions/positions, exact and maximum-only
bounds, zero size, parent-exact outer allocation, every overlay alignment and
draw order, horizontal/vertical/intrinsic spacers, fractional gaps, hidden bounded
children, growing fields, flexible vertical scroll sizing and all four axes.
Every matrix iteration explicitly tears down to zero references/callbacks.

A separate Activity test uses actual horizontal and vertical touch swipes,
asserts each native viewport moved, positions the final corner deterministically,
activates the real button and verifies the Crystal callback result before and
after Activity recreation. It does not claim scroll-position restoration.

The focused lane passes **14 Android tests in 15.086 seconds** (two new layout
tests plus the mandatory twelve storage/secrets/files tests), **64 JVM tests**,
**four Crystal layout structure examples**, and existing host callback/navigation/
asset/C safety prerequisites. CheckJNI and the embedded runtime probe are
required. A separate normal process mounts the native application.

These are API 35 ARM64 emulator results. Width/context measurements are not
independent tablet screenshots or API 31/x86_64 runtime proof.

## Earlier attempts retained

- `compile-first`: Android builds, but repeated Espresso `typeText` clicks put
  the caret in the middle of the newly compact field. The append test now places
  the caret once, sends real focused-view key events and checks exact text,
  selection, focus and widget identity after each character.
- `native-first`: catches a missing import for that focused keyboard action.
- `native-second`: all eighteen existing Android tests pass. The new matrix
  catches a test expectation that rounded half-size dp instead of centering
  already-rounded pixel sizes; the gesture fixture also used a catalog-only
  route extra and fell back to the Buttons study. Both fixture issues are fixed
  without loosening the native assertions.
- The first host structure test attempted to sort Boolean tuples, which Crystal
  does not order. It now sorts by an explicit numeric axis mask. CLI fake-report
  tests now include LayoutPolicyTest so they continue reaching/rejecting the
  intentionally crashed instrumentation protocol.
- `native-final`: all layout configurations/gestures pass, but the Unicode
  composition test encounters a pre-existing composing span from the real
  keyboard after tapping the compact field. It now calls finishComposingText
  before beginning its deliberate select-all composition, asserting unchanged
  original text, no composing span and the exact selected range. The keyboard
  remains enabled and the test still exercises the real InputConnection.
  Android specifies that [setComposingText replaces an existing composing region
  before using the selection](https://developer.android.com/reference/android/view/inputmethod/InputConnection).

## Final native regression and ownership proof

Evidence: `/tmp/amber-android-layout-proof/native-verified`.

The clean lane at `crystal-failures/positive` passes **20 Android tests in
107.151 seconds**, all **24 layout configurations**, **64 JVM tests**, **four
layout structure examples**, **30 callback/registry examples**, **21 navigation
examples** and **eight asset compiler examples**. The existing host file-backend,
1,112,064 Unicode scalar and 31-entrypoint checked-JNI sanitizer tests also pass.

The deliberately broken partial trees now include a callback-bearing bounded
Button and a bounded TextField, so their newly owned wrappers participate in
the existing cleanup assertions. **600 Crystal partial-render failures** pass
across six isolated processes (22062, 22121, 22175, 22230, 22286, 22341), with
immediate exact-count restoration, terminal-session rejection and final zero
resources. The six cases take 5.656, 6.970, 6.765, 7.290, 6.164 and 6.851 seconds.

**400 actual Java partial-render failures** pass in process **22458**, taking
**8.595 seconds**, covering the eight existing checked-JNI failure types. The
original Throwable identity and failed-session cleanup remain intact. A separate
normal process **22511** then mounts the native application with clean logs.
The gate requires CheckJNI, runtime probe 42, bounded diagnostics and no escaped
callback/application/JNI errors in the ordinary lane.

Both ARM64 and x86_64 libraries and native debug symbols are packaged; actual
runtime coverage remains API 35 ARM64. Artifact SHA-256 values:

- Debug APK: `39a7a1c1c2d9582c43c0954577950a669b839628243ed599407977df8095b6c3`.
- Test APK: `6a9a63b60fd4b8841b404e57a9a90fd9c1383647946da284a215996db27c5a36`.
- Release AAB: `5781153840ef78df1d543d4ef7089a6a657e006986bb8a454498c9871a4a071b`.
- Source ledger: `e3ee03a119a7d765d017ff8003a12f675456e6b358873abd15b9bcb413a8b72d`.

## Fresh actual-CLI consumer

The rebuilt CLI `/tmp/amber-android-layout-proof/amber` has SHA-256
`2fcb51eb9d9ea5fb140097d87e31314c3a77ba696880622256c34217a308ba6d`.
All **159 generator/configuration examples** pass; retained output is
`/tmp/amber-android-layout-proof/cli-spec.txt`.

Completed fresh consumer:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.BQ8rlx`.

- **Two shared Crystal examples**, actual web state/validation/CSRF/escaping
  checks, **64 JVM tests**, and **13 Android tests in 30.426 seconds** pass.
- The generated app's bounded flexible native name field passes its actual
  dimension assertion, text input, Unicode commit, save, validation, lifecycle
  and two-screen navigation checks.
- A separate read-only exact-state restoration test passes in **4.636 seconds**.
  Process **22658** saves count **12** and `Android 雪 😀 é` (the final accent
  remains decomposed); process **22797** verifies the exact state. A normal
  cold-launch process **22847** then displays it on `emulator-5556`.
- All **706 source entries** are unchanged before/after: **36 generated,
  242 Amber and 428 AssetPipeline**. The consumer was not repaired in place.
- Both ABI packages contain all five new layout exports, existing runtime/
  service exports and matching native debug symbols. The bundled app image and
  explicit permission policy still pass compiled-resource/manifest checks.
- The final `android-runtime/relaunch.png` was visually inspected: the native
  counter, app image, bounded name field, restored Unicode text and navigation
  control are visible, without overlap or system-bar intrusion.

Generated artifact SHA-256 values:

- Debug APK: `ff8d22c10b3adfb11cd7c4aab0d19e8a594e3970fffaaab70fa044c9aa58f668`.
- Unsigned release APK: `357c739ff48b94e610f3c6cc343def1ae6b6eddeb49ef9a9da18593b24f89260`.
- Release AAB: `1b9b8582084b5e469a2a104b3f690721999250809794db8c86477403c02fd697`.

This is the explicit **local development dependency lane**, not a publicly
released-consumer proof. The original visible `emulator-5554` was preserved.

## Remaining full-goal gates

The full goal retains HStack equal-width distribution, general focus/
selection and scroll-state preservation, accessibility, remaining Tier A
components, route/process restoration, CLI metadata workflows, AgentC's
reference screens, API/ABI/device matrices and public release/consumer proof.
ADB still lists only the two emulators; physical-phone proof remains open.
