# Android bundled-image checkpoint — September 5, 2026

Status: **bounded development implementation; full Android goal remains active**.
The API/packaging limits are in [android-images.md](android-images.md).

## Implementation

- One host-side AssetPipeline compiler reads `config/android_assets.yml`, emits
  deterministic native drawable resources plus a logical-name lookup catalog,
  and records the source bytes/checksums in a build-only ledger. Both showcase
  and real CLI-generated projects invoke this same compiler from Gradle.
- Project-relative sources, strict catalog fields, byte/count limits, stable
  hashed resource names, Unicode logical names, night variants and explicit
  density qualifiers. PNG, JPEG, WebP and VectorDrawable XML source containers;
  SVG needs an explicit Android export. This is not general font/media support.
- Publishing preserves invalid-input outputs, handwritten/hidden files and
  directories, symlinks and modified generated payloads. It replaces only a
  validated compiler-owned tree (or an empty Gradle-created output directory).
  Ledger paths are validated before traversal; malformed paths cannot hang
  parent traversal or reach outside the generated tree.
- Native `UI::Image` uses length-delimited strict UTF-8 lookup, resolves against
  the current View resources/theme, and gets isolated mutable drawable state.
  Missing/invalid sources report failure. Existing Kotlin bindings preserve an
  already-loaded image on rejection.
- Fixed two pre-existing renderer defects: Fill/Stretch passed the wrong bridge
  values and fell through to Fit; tint was ignored. Fit, center-cropped Fill,
  stretched bounds and SRC_IN tint now use explicit native contracts.
- Bitmap dimensions/area are checked before allocation, including density
  expansion. This remains synchronous small bundled-image loading, not a
  streaming/photo cache or an asynchronous image service.

## Native evidence

`/tmp/amber-android-images-proof/native-raster-verified` passed **54 JVM tests**,
**six compiler examples** at that checkpoint, and **16 Android instrumentation
tests in 36.999 seconds** on the isolated API 35 ARM64 emulator `emulator-5556`.
The suite includes the existing input/callback/lifecycle/layout/theme tests and
two SQLite, five Keystore and five private-file device contracts.

The real Crystal image fixture is rendered at 160/320 dpi in light/night
configurations. Tests inspect actual pixel output for Unicode-named vector
assets and variants, Fit letterboxing, Fill/Stretch, tint isolation, PNG colors
and JPEG color tolerance. Valid 768×768 mdpi PNG loading succeeds at 160 dpi and
is rejected before density-expanded allocation at 320 dpi. Valid 1,025×1,025 and
4,097×1 bitmaps are rejected for area/dimension bounds. Invalid UTF-8, missing
names, paths, URLs and oversized names preserve the previous drawable.
Every native-tree teardown reaches zero JNI references and callbacks.

CheckJNI and runtime diagnostics are clean. A separate non-instrumentation
process (PID **10966**) mounts the ordinary interaction screen. That screenshot
is a runtime-relaunch proof, not an image screenshot. The native image proof is
the pixel/scale/configuration contract and four `AssetPipelineImages: PASS` log
entries. Debug APK SHA-256:
`d0e8f6629c9f5b13b8584c8396e4d5cc42c5844066d9bfd2b6357a8c6099526b`.
Release App Bundle SHA-256:
`0bc1f29c3b67f9acc420048af12bcd439f1f758929bbdc0761cd199604d36ec3`.
Both ARM64 and x86_64 libraries are packaged; runtime proof is ARM64 only.

Subsequent host-only hardening adds preservation of handwritten empty
directories and strict validation of tampered ledger paths. The final
current-source proof, `/tmp/amber-android-images-proof/native-final`, passes
**eight compiler examples, 54 JVM tests and 16 Android tests in 41.044 seconds**.
The APK/test-APK/App-Bundle hashes remain identical to `native-raster-verified`;
the source ledger hash changes to
`00322dc6a8d931a376f64dff0cf6ef1d3f75f615f0f772d22088e7e580622a77`.
Separate-process relaunch PID is **11590**.

## Fresh generated-app attempt and inspection correction

`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.Z5lmUn`
is a retained **incomplete end-to-end attempt**, not the final consumer pass.
The real CLI creates its own catalog, VectorDrawable source and `UI::Image`
in the counter screen; no generated application code is repaired by hand.
Two shared examples, actual web/CSRF/escaping checks, 54 JVM contracts and
13 Android tests (19.279 seconds) pass, including a non-null native image.
The final artifact inspector then fails because it assumes release resource
files retain debug names. AAPT2 shows `xml/ap_image_catalog` is really present,
with its release payload renamed to `res/l2.xml`; the drawable is present too.

The CLI inspector now resolves the catalog and every declared drawable through
each APK's compiled resource table and checks the resolved payload actually
exists. It also retains the source ledger and verifies the App Bundle catalog.
This correction is made in the generator, not the already-generated app. A new
CLI executable and a fresh generated-consumer run were then required for the
final source-freeze and packaging claim; the following run satisfies that gate.

## Final fresh CLI-generated consumer

`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.uB2MiN`
is the **passing final development-consumer run**. The actual rebuilt CLI is
`/tmp/amber-android-images-proof/amber`, SHA-256
`6803f51947c6f7b1d2b7b36f5b14263f6bab00826d1fb4d3f4cc7c4d5186b095`.
Local Shards overrides are explicit; this is not a public released-consumer proof.

- Two shared examples and actual web state/validation/CSRF/escaping checks pass.
- **54 JVM tests**, all with zero skips/failures/errors, and **13 Android tests
  in 23.402 seconds** pass. The real generated counter loads its own `app_mark`
  through Crystal `UI::Image`, alongside state/action/recreation/persistence tests.
- Both ABI libraries, required JNI exports, debug and unsigned release APKs,
  App Bundle and matching native debug symbols pass package inspection. Each
  APK's resource table resolves every declared image/catalog to a present
  payload, including shortened release paths. The source ledger is retained.
  Unrequested INTERNET and POST_NOTIFICATIONS remain absent from both APKs.
- All **687 source entries** are unchanged before/after: 35 generated, 242
  Amber and 410 AssetPipeline. No generated app was patched to make it pass.
- Instrumentation process **11790** saves count **5** / name **Android**.
  A separate process **11911** restores both. The inspected relaunch screenshot
  visibly includes the blue bundled app mark and restored state. Existing
  device data was preserved; the earlier incomplete attempt explains count 4.
- Debug APK: `b53a351ab9abfdb2085f31dca2fbefbf68fcdb8dd0164e3293b2dd73cfa67d49`.
  Unsigned release APK: `240252e7da962ec94dce5870a0c6ac02f81a4233cbe308f9dea4627291c1e13f`.
  App Bundle: `ae5af3c36f8fd0afa621a517cb231ceae248541c5dcfd0e55acd6e1b6857e446`.

Final CLI regression coverage is **159 examples**, with no failures/errors.
The standalone compiler and touched Crystal files pass formatting checks;
the generated inspector passes shell syntax checks and targeted whitespace checks.
The sample image route is separately captured as `native-final/images-native.png`
using `--es app_slug image-smoke`. The earlier `images.png` attempt used the
catalog's unknown `study_slug` and showed its fallback button study, so that
earlier image is not image-rendering proof. Both raw captures are retained.
After inspection, CounterApp was cold-launched again and left running as PID
**12030** on `emulator-5556`. ADB still lists only the original and isolated
emulators; the physical phone is not visible. Neither emulator was cleared.

Other retained failed attempts: `native-first` found an old IconButton call
site after changing the shared image function signature; `native-raster` found
a Gradle DSL `java` name collision in procedural bitmap fixture construction.
Both were fixed at source. `native-second` passed the vector-only 16-test suite
in 51.153 seconds before bitmap fixtures were added.

## Remaining gates

WebP-specific decode, malformed/animated bitmap policy, richer density sets,
custom fonts, asynchronous/network/media assets, complete accessibility,
physical-phone and other API/ABI runtime proof remain open. This is not full
Tier A renderer parity or a released Android target. The wider implementation
still requires navigation/layout/input work, metadata regeneration/unified CLI,
AgentC reference screens, CI, signing/public releases and released-consumer proof.
The original visible emulator was not shut down or cleared; all new device
mutations in this checkpoint target only the isolated test emulator.
