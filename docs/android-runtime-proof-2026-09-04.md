# Android runtime proof — 2026-09-04

This is a development checkpoint for the full
[Android compile-target plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md),
not a release or a declaration of complete Android support.

The later [application-boundary checkpoint](android-application-boundary-proof-2026-09-04.md)
records canonical runtime extraction, the direct Amber native app and CLI
capability/safety changes after the integrated run described below.

## Proven in this checkout

| Requirement | Evidence |
| --- | --- |
| Fresh dual-ABI build | Crystal 1.21.0 emitted ARM64 and x86_64 objects; NDK 28.2.13676358 linked both libraries with no undefined symbols |
| Native dependencies | All 28 members of each GC/PCRE2 archive match the requested architecture; required symbols exist |
| Packaging | Debug APK and release App Bundle include both `arm64-v8a` and `x86_64`; bundle includes each ABI's separate `.dbg` file |
| Runtime startup | `GC.init`, `Crystal.init_runtime`, then `Crystal.main_user_code`; JNI log confirms fiber/channel probe returns 42 |
| Repeated initialization | Eight concurrent JVM-thread calls observe one successful initialization without resetting the mounted application |
| Input and state | Slow key-by-key text input keeps the same focused EditText; a button callback renders the complete Crystal-owned text state |
| Lifecycle | Five stop/resume/recreate cycles retain text state and stable callback/global-reference counts; closing the Activity returns both counters to zero |
| Theme and insets | Light and dark resource configurations, surface luminance, native label colors, and toolbar position are asserted on-device |
| Density and text scale | Fractional padding, fixed sizes, stack gaps with hidden siblings, radius, borders, elevation and sp text pass at 160/320 dpi and font scales 1.0/1.5 |
| Shared Amber application | Amber's native-safe facade renders a counter and name form; the same state/use-case implementation is exercised by web controller tests; valid/invalid input and Activity recreation pass on Android |
| Separate launch | Fresh app process mounts the native tree in dark mode and remains alive after capture |
| CheckJNI | Test process confirms `-Xcheck:jni`; app-scoped logs contain no JNI error, native fatal signal, bootstrap/render error or uncaught Java exception |
| Host regressions | 85 focused callback/native-view/swipe-action examples pass; archive tests reject empty, mixed-architecture, missing-symbol and absent archives |

Device: `sdk_gphone64_arm64`, Android API 35, `arm64-v8a`, emulator serial
`emulator-5554`. Native API/minSdk baseline is 31. API 31 runtime itself has not
been tested by this API 35 run. The physical phone was not visible in ADB.

Source base commit: `5f63d9adb02be566cdade67e4616ca0bb3cbf30b`, with local
modifications and untracked files. This commit alone does not identify the
tested build. The latest combined run saved hashes of 393 actual AssetPipeline
source/toolchain/host files and 235 Amber source/fixture/script files, including
untracked development files. Amber base commit:
`813dca5b9670a8ebfb568bed40d6a367b3d1133d`, also with local changes.

## Reproduce

From the repository root with the pinned toolchain installed:

```bash
./scripts/doctor_android.sh
./scripts/cross_compile_deps.sh android
./scripts/run_android_smoke.sh emulator-5554
```

The checkpoint used prebuilt dependencies from a fresh earlier source build:

```bash
CRYSTAL_CROSS_DEPS=/tmp/asset-pipeline-android-goal-deps \
CRYSTAL_CACHE_DIR=/tmp/ap-android-crystal-cache \
./scripts/run_android_smoke.sh emulator-5554
```

The runner always invokes the native bridge builder, assembles the application,
installs it, verifies the instrumentation result protocol, and captures a
separate relaunch. It has no device-absence success path. ADB returning zero is
insufficient: Android actually returned zero for a crashed probe during this
work, so the script requires a nonempty `OK` result and normal instrumentation
completion.

The combined Amber application checkpoint used the same dependency/cache
overrides with this command from `amber-v2-beta-release`:

```bash
ASSET_PIPELINE_ROOT=/absolute/path/asset_pipeline \
CRYSTAL_CROSS_DEPS=/tmp/asset-pipeline-android-goal-deps \
CRYSTAL_CACHE_DIR=/tmp/ap-android-crystal-cache \
bash scripts/test_native_android_app.sh emulator-5554
```

Final evidence directory: `/tmp/amber-native-android.UQJq2B`.
It contains the build log, doctor result, installation output, instrumentation
result, complete and app-scoped logs, package listings, relaunch view hierarchy,
screenshot, source hashes and `proof.txt`. Temporary evidence may be removed
by the OS; rerun the command to regenerate it.

Final instrumentation result: `OK (4 tests)`, 39.052 seconds.
Separate relaunched process: PID 6988. These are observations from the run, not
identifiers that future runs should reuse.

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `11d6447be4d847aed702f679532985ead7a7f80ac62f907b567343df54cc784d` |
| Test APK | `13de5d5e5146012d227e2c912b1d0bac5423f1138fa13d5ee79982c29e1c5619` |
| Release App Bundle | `63dc6bd77f71c4a3ffe40b177537c6e9b85390309b6dcebc2ae4c6a57890961a` |
| Unstripped ARM64 library | `1d795518e2d4941c4625ee8b23f38910f835697933409d234f43539d94fb51e0` |
| Unstripped x86_64 library | `d9db7ffa3bf0e865ad3bdc9d027600b8918e96a0b37d50535a3989f41cf815de` |
| AssetPipeline source hash manifest | `d40b121316644394570f507573f6b2b7845c9348c5133847dfa14f9ab0c0a1ab` |
| Amber source hash manifest | `1f8581cbcfef81b51750a5e9912ee26aef669c29fec4d4f2a5cda1e9a42c1ae3` |

The native runtime links only system `libc`, `libm`, `libdl`, `liblog`, and
`libz`; GC and PCRE2 are static. x86_64 load segments have 16 KiB alignment.
This inspection is not a 16 KiB-page device runtime test.

## Root causes corrected

- The x86_64 libc overlay lacked Crystal's `<architecture>-android` lookup
  alias. The final linker also still forced an ARM64 target. Both now use the
  selected ABI, and the x86 bionic `stat`, `va_list`, syscall and other key
  layouts are checked against the NDK headers.
- Calling only `GC.init` and `Crystal.init_runtime` allowed simple rendering
  but left eager globals and the default execution context uninitialized.
  Directly initializing just the scheduler also failed because its eager
  context registry had not run. Calling `Crystal.main_user_code` supplies the
  normal global initialization without calling process exit/cleanup.
- A C `pthread_once` gate protects startup before Crystal synchronization is
  available. A failed initialization does not expose a ready runtime, and
  entry before readiness is rejected by the C registration boundary.
- The host forced a light-only theme despite a dark appearance request.
  DayNight resources now drive both Kotlin widgets and native-renderer semantic
  colors. Logical label roles now map to the active Material theme.
- API 35 edge-to-edge layout placed the toolbar under the status bar. Host
  window-inset handling now protects content from system bars and the keyboard.
- Gradle now reads the common SDK/NDK/JDK/plugin contract. Setting its NDK
  revision also enabled native symbol stripping with separate full debug data
  retained in the bundle.
- Layout dimensions were treated as raw pixels, stack gaps were omitted and
  child attachment discarded explicit sizing. The bridge now converts dp using
  each View's current Resources, preserves layout sentinels/fixed sizes, uses
  native middle dividers for stack spacing and leaves text sizing in sp. Tests
  use overridden Context densities/font scales, not just the emulator default.
- Amber's value validator depended on a class bundled with HTTP upload parsing.
  File metadata validation is now independent, with a backwards-compatible
  parser alias. `amber/native` can validate shared data without HTTP or OpenSSL.
- An integration runner initially exposed the whole parent checkout directory
  as a shard search path, accidentally mixing a sibling Crystal compiler's
  standard library into the build. The runner now exposes only the intended
  AssetPipeline dependency through an isolated shard lookup.

Amber boundary evidence: `/tmp/amber-native-boundary.hJ9k2w`. Eleven native
unit tests, a native-only host executable, an ARM64 Android object build,
eight expected server-import failures and 319 web/schema examples pass. The
isolation fixture rejects HTTP/OpenSSL/XML/YAML and server modules at compile
time. Android platform-service interfaces are contracts only; no production
network/storage/secret/notification/file adapters are claimed by this result.

## Remaining work and next execution slice

The full goal remains active. No phase has been declared complete based only
on this smoke test.

1. Finish Phase 0 dependency provenance: independently rebuild dependencies
   twice, compare manifests, include configuration flags, and reject stale
   cached archives when API/NDK/source settings change. The current manifest
   comparison only proves stable *revalidation* of the same archives.
2. Run x86_64 on an appropriate emulator/CI host; this Apple Silicon run only
   executes ARM64. Run the same APK and test on the authorized physical phone.
3. Finish the core renderer contract beyond the measured density subset.
   Maximum-only/ranged constraints, equal-fill stacks, spacer axis behavior,
   semantic IDs/accessibility roles/actions, navigation/modal behavior and full
   Tier A tests remain open. The optional glass helper was not runtime-tested.
4. General state reconciliation, background scheduling/thread ownership,
   Unicode input/composition, configuration transitions, persistence after
   process death, and the phone/tablet visual matrix need broader proof. The
   current smoke covers ASCII typing and Activity state retention; the sample
   intentionally starts fresh state after process restart.
5. Build on the implemented native-safe facade with actual Android services,
   lifecycle forwarding and capability metadata. Implement the complete CLI
   generator, generated consumer E2E and AgentC shared-domain reference.
   The current shared counter still uses AssetPipeline's development host.
6. Replace placeholder CI, complete existing-platform regressions, publish
   tested releases/support matrices and prove a consumer using released shards
   and CLI. Local bundles and source builds are not release/consumer proof.

The emulator was left running with the sample open. Its original local process
handle was session 31648; inspect current ADB/process state before reuse.
There were no build/test processes left running at this checkpoint.
