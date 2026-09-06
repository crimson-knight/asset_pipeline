# Android Material Host

This host is the Android validation shell for the `asset_pipeline` Material
phase. It is intentionally scoped to `asset_pipeline` ownership:

- renderer behavior lives in `src/ui/renderers/android_renderer.cr`
- shared validation truth lives under `docs/android-material-validation/`
- this host owns the Android showcase shell, capture entry point, and renderer
  mount surface

The Crystal/JNI render mount is wired. The host launches renderer-backed Android
studies, applies the requested appearance, and records the study status that is
meant to match the validation ledger. The ledger still decides whether a study
is accepted; the host should not be treated as a shortcut around that review.

## Local expectations

- canonical SDK root on this machine:
  `/opt/homebrew/share/android-commandlinetools`
- recommended AVDs:
  - `crystal_test`
  - `test_api35`
  - `Pixel_3a_API_34_extension_level_7_arm64-v8a`
  - `pixel_tablet_api35`

## Build

The pinned versions are in `config/android_toolchain.env` at the repository
root. The Gradle project consumes its SDK, NDK, JDK, AGP and Kotlin entries and
checks the wrapper version. Crystal 1.21.0 is required for the current embedded
startup contract. Both `arm64-v8a` and `x86_64` libraries build by default.

From the repository root, first build the native dependencies:

```bash
./scripts/doctor_android.sh
./scripts/cross_compile_deps.sh android
```

Set `CRYSTAL_CROSS_DEPS` when using a dependency directory other than
`/tmp/crystal-cross-deps`. `ANDROID_ABIS=arm64-v8a` can select an ARM-only local
build; release/matrix validation must build both architectures.

Dependency caches now contain immutable ABI/API/toolchain-keyed bundles. The old
`android-arm64`/`android-x86_64` flat directories are not accepted by the linker.
Run the current dependency builder to produce verified entries; do not rename
old archives or rewrite their manifests. The published bundle includes headers,
all archive checksums, source provenance and license texts. Source/build work
directories remain available for diagnostics.

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
cd samples/cross_platform/android_host
./gradlew :app:assembleDebug
adb -s emulator-5554 install -r app/build/outputs/apk/debug/app-debug.apk
```

## Runtime proof

From the repository root, with an already booted emulator or authorized phone:

```bash
./scripts/run_android_smoke.sh emulator-5554
```

This rebuilds both native libraries, APK, test APK and release App Bundle,
installs the app, enables CheckJNI, and runs real input/callback/lifecycle and
theme/inset tests. It then starts a separate app process and captures its view
tree, screenshot, logs and artifact checksums in a printed evidence directory.
Missing devices, crashed instrumentation, absent tests and missing runtime
probe output are failures. A compile or screenshot alone does not pass this
command. Native debug symbols are retained in the release bundle metadata.

The host executes Crystal's top-level initialization once on the Android main
thread. Embedded entrypoints must declare/export application behavior and must
not start an HTTP server or an endless top-level loop. Runtime state survives
Activity recreation; process restart currently starts fresh application state.
Text callbacks update Crystal state while retaining the focused native editor;
other callbacks refresh the sample tree. General incremental reconciliation
and persistent process-state restoration remain separate work.

The September 4 proof covers the ARM64 emulator. x86_64 runtime, the physical
phone and the full renderer support matrix remain unverified.

The host accepts these activity extras:

- `study_slug`
- `study_appearance`
- `study_story`

Example launch:

```bash
adb shell am start -S \
  -n dev.assetpipeline.androidhost/.MainActivity \
  --es study_slug buttons \
  --es study_appearance light
```

Current showcase studies include:

- `buttons`
- `text-fields`
- `cards`
- `dialogs`
- `app-bars`
- `selection-controls`
- `transient-surfaces`
- `share-color`
- `webview`
- `map-view`
- `video-player`
- `chart-view`
- `interaction-smoke` for internal callback verification only

## Capture Workflow

Use the shared runner from the repo root so screenshot naming, renderer-mount
readiness checks, splash-screen exit checks, and serial-specific host
installation stay consistent with the Android validation ledger.

```bash
./scripts/run_android_material_tests.sh --serial emulator-5554 --device-role phone --appearance both
./scripts/run_android_material_tests.sh --serial emulator-5556 --device-role tablet --appearance both --skip-build
```

Helpful flags:

- `--only buttons,text-fields`
- `--appearance light|dark|both`
- `--device-role phone|tablet`
- `--skip-build` to reuse the installed host APK
  This assumes the currently installed APK on the target serial already
  matches your local source tree. If you changed `android_material_bridge.cr`,
  JNI bridge code, or Kotlin host files, rebuild and reinstall before using
  `--skip-build`.
