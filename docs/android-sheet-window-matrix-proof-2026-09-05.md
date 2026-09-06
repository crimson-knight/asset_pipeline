# Android Sheet cramped-window checkpoint — September 5, 2026

Status: complete native/failure, focused matrix, AgentC package and fresh
generated-consumer checks pass. The full Android goal remains active. This is
not physical-device, full Tier A, independent CI or public-release proof.

## Measured defects and changes

Evidence root: `/tmp/ap-sheet-window-matrix.nfZcid`. These temporary logs and
screenshots are development evidence, not published artifacts.

Task emulator: `emulator-5556`, ARM64 API 35, CheckJNI 1. The existing
`emulator-5554` is preserved; `devices.txt` still lists no physical phone.
`native-final/crystal-failures/positive/doctor.txt` verifies Crystal 1.21.0,
NDK 28.2.13676358, native API 31 for ARM64/x86_64, platform/build tools 35/35.0.0
and Java 17.0.6. Gradle is pinned at 9.3.1 and Material at 1.12.0.

1. `landscape-baseline-instrumentation.txt` fails because the small-only sheet
   offers an 81-pixel viewport for a 153-pixel native editor. The adapter now
   grows nominal compact heights to fit measured actionable controls plus native
   chrome, bounded by the available window. `landscape-v1-instrumentation.txt`
   passes the same check: frame 342, viewport/editor 153 pixels, including
   scrolling to the bottom action and sequencing a native Alert.
2. `matrix-v2-instrumentation.txt` passes the four enlarged-text/RTL cases but
   fails the landscape keyboard check: the keyboard replaces the sheet with
   fullscreen extraction. The sheet now preserves editor option/action bits
   while adding `IME_FLAG_NO_FULLSCREEN`. Android documents this as a request
   to compliant keyboards, not a guarantee about arbitrary third-party IMEs.
   `matrix-v3-instrumentation.txt` passes all three initial tests (85.252s),
   including exact text/selection/focus and keyboard restoration on recreation.
3. `matrix-v4-instrumentation.txt` extends keyboard coverage to enlarged text
   and rotation, finding a 215-pixel editor clipped to 205 pixels. When an open
   keyboard leaves insufficient room for the controls plus the optional native
   handle, the handle temporarily becomes `GONE`; its touch area is not shrunk.
   It returns when sufficient space returns. The same logical detent is retained.
   `matrix-v5-instrumentation.txt` measures a 266-pixel enlarged-text viewport,
   but fails the new keyboard-Back check. This is not a passing final matrix.
4. The isolated `matrix-v6-instrumentation.txt` catches keyboard visibility
   disappearing after rotation. The restoration path previously retained
   `SOFT_INPUT_STATE_ALWAYS_HIDDEN` and could issue a show request directly in
   the window-focus listener. A saved visible editor now clears the hidden
   policy, and both focus paths post the request after focus dispatch. The
   expanded five-test `matrix-v7` run passes three tests but exposes two
   orientation/handle assertion failures. The debug profile used a full copied
   configuration; it now overrides only font scale and locale, and the test
   requires the focused editor's window to match the current display and have
   stable visible IME insets/active input connection. `matrix-v8-instrumentation.txt`
   passes all five tests in 209.225 seconds, including Back and handle restoration.
   The test does not add a retrying keyboard opener, a forced keyboard, a longer
   failure timeout, a production Back override, or a global configuration reset.

Primary Android references: [editor options](https://developer.android.com/reference/android/view/inputmethod/EditorInfo#IME_FLAG_NO_FULLSCREEN)
and [reliable keyboard visibility](https://developer.android.com/develop/ui/views/touch-and-input/keyboard-input/visibility).

## Test scope

`AndroidSheetWindowMatrixTest` uses the real sample host/native sheet. A
non-exported, debug-only `WindowMatrixActivity` wraps its configuration context
for font scale 1/2 and English/Arabic layout; global emulator font, language and
density are not changed. Activity orientation overrides are restored, scenarios
are closed, and zero native/dialog ownership is required after each profile.
No runtime configuration intent or production application mode was added.

The checks measure actual native font pixels and layout direction, full control
bounds, keyboard exclusion, logical detents, Unicode values and selections,
recreation, portrait/landscape rotation, Back, optional-handle restoration and
bottom-action reachability. Insets alone are not considered proof that an
editor is above the keyboard. The enlarged-text fixture is not a translation
or complete TalkBack/accessibility audit. Unicode values are delivered through
real native EditText callbacks; the app locale override does not change Gboard's
language or prove Arabic keyboard composition.

The visually inspected `rtl-large-keyboard-v8.png` shows the enlarged editor and
its exact selected range above Gboard, with the optional handle hidden.
`rtl-large-keyboard-closed-v8.png` shows the same dark RTL sheet with the handle
restored after keyboard Back. These complement, not replace, geometry and action
assertions. The initial fullscreen and clipped-editor captures were also reviewed;
the latter caught a transient screenshot before the compositor drew the keyboard,
so the numerical clipping failure is established by instrumentation, not that image.
The final `rtl-large-keyboard-final.png` was also visually checked and is a usable
keyboard capture. The optional `rtl-large-editor-final.png` and
`rtl-large-keyboard-closed-final.png` caught in-flight text/layout or compositor
frames and are **not** promoted as settled visual evidence. The passing native
bounds/action checks and earlier settled v8 capture are not replaced by these
images. Synchronizing every optional capture with completed drawing remains a
test-harness follow-up.

The five-test class is now in the default mandatory native smoke lane. The
sample's explicit TLS/notification debug-manifest override hooks replace the
debug manifest: an external full-matrix fixture using those hooks must preserve
the non-exported matrix Activity declaration. Ordinary isolated service lanes
may select their own existing test class as before.

## Integration verification

- `shared-ui-spec.txt`: 1,450 examples, no failures/errors, 66 existing pending.
- `cli-spec.txt`: complete CLI host suite, 525 examples, no failures/errors/pending.
- `cli-build.txt`: fresh CLI compilation completed; the actual consumer proof
  below uses that executable, not a direct generator-class call.
- `agentc-build.txt`: 93 JVM tests, zero failures/errors/skips; all 126 build
  tasks complete in 1m31s. The isolated actual AgentC target produces both ABIs,
  debug/release APKs, test APK and App Bundle. `agentc-inspect.txt` verifies
  packaged ELF/JNI exports and matching native debug symbols. The debug-symbol
  files' absent-dynamic-table warnings are not packaged-library errors.
- `agentc-source-verification.txt`: all 41 selected native application inputs
  remain byte-identical in both the original and development projection. No
  installed libraries, lock, live account, database or server was changed.
- The fresh full native build passes all 93 JVM tests. All 48 positive Android
  tests pass in 723.808 seconds, including the original four Sheet window tests,
  three portrait viewport/gesture tests and five new window-matrix tests. The
  complete `scripts/test_android_java_failures.sh` driver also passes all six
  isolated Crystal failure cases (600 partial renders), 100 malformed semantics
  probes, 400 Java partial-render failures and the separate Sheet window failure.
  The Java/Sheet lanes take 12.177/8.675 seconds. Original Throwable identity,
  terminal cleanup and a fresh normal CheckJNI relaunch are verified; the checked
  logs contain no unexpected runtime failures or escaped private test sentinels.
- `debug-manifest.txt` records `WindowMatrixActivity` with `exported=false`;
  it appears in `debug-dex-symbols.txt` but neither `release-dex-symbols.txt`
  nor `release-bundle-manifest-strings.txt`. These checks use the actual freshly
  packaged APK/App Bundle, not only source-set declarations.
- All 509 current native inputs match the full driver's ledger in
  `native-source-verification.txt`, rechecked after the complete driver and
  fresh consumer run.

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `47e4f319859e59a2a60640b5e69a1c820d3d0a2e6773e5358fd75ec1b9c936d0` |
| Test APK | `957fcc6504c125f37eb284d61a1d3019983c5dfe61a9d20035e8a53706ba3ac3` |
| Release App Bundle | `66e76cc2ac6bccaae7f78edb6b934a321f3af17ce8171c0e1c516e4525667601` |
| Native source ledger | `26d7deff013c5efc9a4ef0022ff80a7d1c5bd1b5f176142656bee128a05b6b8e` |

### Fresh actual-CLI hybrid consumer

Fresh CLI: `<evidence>/amber`, SHA-256
`5b51abef42e9657ca8b073fae0ed4ecf820be3de7cec9e6676b720e86d80386a`.
`amber_cli/scripts/test_generated_android.sh` generates a new hybrid project at
`/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.omsVlW`.
Its explicit local development dependencies are disclosed: this is not released
shard resolution, a public release, or a manually repaired generated app.

- Two shared examples and real web state, validation, CSRF and escaping checks pass.
- All 93 JVM tests pass; the full 126-task package build succeeds in 33 seconds,
  including both ABIs, debug/release APKs, test APK, App Bundle and native symbols.
- Thirteen Android tests pass in 29.66 seconds. A separate new-process
  restoration test passes in 4.747 seconds.
- Process 17155 persists count **28** and the name `Android 雪 😀 é`;
  process 17285 proves restoration. Final normal process **17336** remains
  running with count 28, the exact Unicode name and restored-local-storage
  status. Its `android-runtime/relaunch.png` was visually reviewed.
- All **730** source entries remain identical: 36 generated application inputs,
  242 Amber inputs and 452 AssetPipeline inputs. All 509 canonical native
  inputs also still match the independent full-driver ledger.

The temporary web listener on port 3191 has exited, the task emulator has no
reverse mappings, and its orientation override is released (`user_rotation=0`).
No app-data reset, account server or account database was used. This counter
proves generated runtime/package integration, not its own Sheet UI; the real
sheet interactions belong to the canonical fixture above.

## Remaining full-goal gates

The fixture is an ARM64 API 35 phone-sized emulator, not a tablet, different
density/API, x86_64 runtime or physical-device proof. Oversized application
controls can still exceed the available screen even without the handle. Other
keyboards may ignore the no-fullscreen request. Nested popup controls,
TalkBack/accessibility focus, other Tier A rendering/layout/state work, actual
independent CI, public release and released-consumer proof remain open.
