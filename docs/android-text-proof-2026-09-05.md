# Android Unicode and native-editor checkpoint — September 5, 2026

Status: **development progress; the full Android compile-target goal remains active**.
The bounded API behavior and remaining editor limitations are documented in
[android-text.md](android-text.md).

## Changes

Replaced duplicated modified-UTF-8 assumptions with shared standard-UTF-8/UTF-16
conversion in `unicode_text_codec.h` and `android_text_bridge.h`. View text/hints,
routes, callback values, JNI collection strings and clipboard conversion now
share the corrected codec. Added length-aware route and callback exports while
retaining old C-string exports. Typed Crystal string maps pass lengths for both
keys and values. No binary-service wire format was changed.

Added native TextField submission and an independently tested action policy.
TextEditor now reuses the real multiline TextArea implementation instead of its
raw EditText placeholder, including callbacks and native read-only mode.
The test uses current native editing APIs, not string substitution in the app.

## Verified native proof

`/tmp/amber-android-text-proof/native-final` is the final native run:

- Sanitizer-backed C test: **1,112,064 scalar round trips**, embedded NUL,
  malformed UTF-8, unpaired UTF-16 surrogates and empty input; no sanitizer errors.
- **Eight asset-compiler examples**, preserving the preceding image milestone.
- **58 JVM tests**, all with zero skips/failures/errors: the existing 54 plus
  four EditorActions tests. The report is mandatory in both host runners.
- **17 Android tests, 61.134 seconds**, including the previous image, layout,
  theme, input/lifecycle and platform-storage contracts plus the new editor test.
- The actual route `text/雪😀\0end` selects the Crystal fixture without
  truncation. Labels and initial input preserve mixed Unicode/NUL. The public
  Crystal JString wrapper completes 128 live JNI round trips and reports seven
  UTF-16 units for `key\0雪😀`; a native Java map preserves NUL/Unicode in keys
  and values.
- Native composing spans change from `か` to `漢字 😀`, then commit a string
  containing NUL, emoji, combining marks, ZWJ and Arabic. UTF-16 selection offsets
  remain correct, code-point deletion removes a complete supplementary character,
  and the editor identity/focus are preserved until explicit submission.
- Done submits exactly once; the refreshed Crystal state is valid UTF-8 with
  the expected byte length and exact text. Multiline edits survive recreation,
  read-only key listeners remain absent, and all JNI/callback counts return to zero.
- CheckJNI/app diagnostics are clean. A separate non-instrumentation process
  (PID **13205**) successfully remounts the ordinary interaction screen.

Debug APK SHA-256:
`af1da11984239fd6d6355d060a4ce11cee8e0c7d0c893246f6d2d8490fb69041`.
Release App Bundle SHA-256:
`006ddff5bd9bc29d34090cf5bd3448c752307cee98b864d4ea71c4c74296b98c`.
The source ledger is retained in the proof directory. Both ARM64 and x86_64
libraries are packaged; device runtime proof remains API 35 ARM64 only.
The subsequent runtime README edit documents behavior but does not change these
compiled artifacts.

The touched shared callback registry also passes **26 host examples**; the
new length-aware dispatch case proves embedded NUL and zero/invalid lengths.
Final current generator/configuration coverage is **159 examples**, including
missing/empty/failed EditorActions report rejection. Crystal formatting and
targeted whitespace/shell syntax checks pass.

## Failed attempts, retained honestly

- `native-first`: read-only TextEditor failed. The new read-only setter had
  reached TextArea, but TextEditor still used an unrelated placeholder visitor.
  Both now share the same native multiline implementation.
- `native-second`: the submit assertion captured the old label before the
  host's deliberate 250 ms deferred refresh. Logs show the refresh happened
  afterward. The test now waits for submitted state rather than assuming
  Espresso's immediate assertion observes a future scheduled refresh.
- `native-focused` passes 13 tests in **15.903 seconds** (editor plus existing
  storage/Keystore/file tests). `native-final` adds the full regression matrix
  and real Crystal string/map wrapper checks above.

## Fresh generated consumer

The real rebuilt CLI now enters `Android 雪 😀 é` through ASCII typing plus the
native input connection. Its generated scripts run a second read-only
instrumentation process to verify exact Unicode state and a different PID,
then cold-launch the app for final inspection. This avoids treating an XML dump
as exact Unicode proof; the completed run below includes runtime, packaging and
source-freeze evidence, not merely generation or compilation.

The completed final run is
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.ECNehM`.
Its actual rebuilt CLI, `/tmp/amber-android-text-proof/amber`, has SHA-256
`b3455bbd15bc291b53d13e75daeb05cbc4acec6b342db7e4afbe6f8588fec0d0`.

- The actual CLI generates the project; real Shards resolution uses explicit
  local development overrides. Two shared examples and actual web state,
  validation, CSRF and escaping checks pass.
- **58 JVM tests** and **13 Android application/platform tests (23.857 seconds)**
  pass. A second **one-test restoration run (4.719 seconds)** passes separately.
  Process **13364** saves count **6** and `Android 雪 😀 é`; process **13495**
  reads and verifies exact saved native text without saving or incrementing it.
- A final cold launch, PID **13544**, displays both the saved Unicode name and
  the bundled image. The relaunch screenshot was inspected and the app remains
  running on the isolated `emulator-5556`. Device app data was not cleared.
- All **694 source entries** are unchanged before/after: 36 generated, 242
  Amber and 416 AssetPipeline. No generated-source repair was made.
- Both ARM64/x86_64 debug/release packages, App Bundle and matching debug symbols
  pass inspection, including the new length-delimited route/callback exports and
  the image resource-table/payload checks. Neither APK gains unrequested INTERNET
  or POST_NOTIFICATIONS. Runtime/CheckJNI logs for each tested process are clean.
- Debug APK: `2db63a4ed00f13a0f106d5aa5841720c56b9c2658744f69dc4646d9e9b0bc878`.
  Unsigned release APK: `18ccde336db601b46ee3d7d357399e24317a841ef5d514fceefb6b734bd89199`.
  App Bundle: `df2588a8f31f50b3ae2fe350d6989c7db3cfb047700c74de1e4c3dff67e70d3f`.

This is local-development consumer proof, not a production-signed/public release
or a released-dependency consumer result. The generated test's distinct-process
state check is now a mandatory script gate, not a visual-only/manual conclusion.
ADB was rechecked at handoff: only the original `emulator-5554` and isolated
`emulator-5556` are visible, and CounterApp PID **13544** is still alive. The
physical phone remains unavailable to ADB. No emulator was cleared or shut down,
and no public release, store submission or unrelated source cleanup was performed.

## Remaining full-goal gates

Complete renderer/accessibility/theme/keyboard coverage, focus and selection
restoration, navigation/layout/modals, rich assets/fonts, unified CLI metadata
regeneration, AgentC reference screens, physical-phone/API/ABI matrix, CI,
signing/public releases and released-consumer proof remain open. General
callback exception containment and allocation-failure handling need a broader
boundary audit. This checkpoint neither narrows nor completes the full goal.
