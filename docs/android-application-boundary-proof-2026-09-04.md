# Android application boundary checkpoint — 2026-09-04

**Historical checkpoint:** the subsequent
[generated-consumer checkpoint](android-generated-consumer-proof-2026-09-04.md)
completes the development generator work listed as next below. Runtime/service,
release and other full-goal gates remain open.

The full Android goal remains active. This is an implementation checkpoint,
not a release or complete Android support claim. It follows the earlier
[runtime checkpoint](android-runtime-proof-2026-09-04.md) and remains governed by
the full [implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md).

## Outcome

An Amber application now imports `amber/native` and
`asset_pipeline/ui/android/application`, renders real Android controls, validates
input through the same schema/state implementation used by an Amber web
controller, and passes an emulator interaction/recreation test. Its Crystal
entrypoint no longer imports showcase screen code. The Kotlin Activity shell is
still AssetPipeline's development host, not a newly generated standalone app.

The APK and release-mode App Bundle include ARM64 and x86_64 libraries and both
ABI debug-symbol files. Only ARM64 has been executed. No Play publication,
physical-phone, API 31 runtime or x86_64 runtime proof is implied.

## Implemented during this checkpoint

### AssetPipeline

- Native dimensions use current View/Context density, including fractional
  padding, fixed dimensions, stack gaps, elevation, borders and corner radii.
  `MATCH_PARENT`/`WRAP_CONTENT` sentinels survive child attachment. Native tests
  cover 160/320 dpi and font scales 1.0/1.5; text stays in Android sp.
- `src/ui/android/application.cr` owns configuration, root lifetime, the
  fiber/channel runtime probe and exported rendering/teardown boundary.
- Canonical JNI startup and dispatch moved to `src/ui/native/android_host_jni.c`.
  The old sample C path is a compatibility include, not a duplicate runtime.
- Reusable Kotlin bridge/listeners moved to `android/runtime/src/main/java`.
  The sample compiles that source directory. The package remains
  `dev.assetpipeline.androidhost` because native helper names already depend on
  it; a consumer's application ID is independent.
- The smoke runner supports an explicit external application entrypoint,
  instrumentation source/class and relaunch marker. Source hashes now include
  the canonical Kotlin runtime directory.

### Amber V2

Repository: `amber-v2-beta-release`, base
`813dca5b9670a8ebfb568bed40d6a367b3d1133d`, with local changes.

- `src/amber/native.cr`: server-free configuration, lifecycle/process-manager,
  value-schema and platform-service contracts.
- Value validation was extracted from HTTP multipart parsing while preserving
  the old parser class alias and all existing schema behavior under test.
- Eight server-facing entrypoints now fail Android compilation with a direct
  explanation of the web/native boundary.
- Native configuration copies its public values and does not mutate server
  environment settings. Lifecycle tests cover duplicate notifications,
  transition ordering, reverse cleanup, failed startup, reentrancy and invalid
  transitions.
- `examples/hybrid_counter` shares state/name-validation rules between a web
  controller and the actual Android screen. The store survives Activity
  recreation but intentionally starts over after process death.
- `scripts/test_native_boundary.sh` checks forbidden loaded modules at compile
  time, executes real native-safe logic and builds an ARM64 Android object.
- `scripts/test_native_android_app.sh` builds/packages/installs/tests the native
  application using an isolated local AssetPipeline dependency lookup.

The HTTP/storage/secrets/files/notification classes are adapter **interfaces**,
not implementations. Android lifecycle forwarding beyond the fixture's initial
start remains unfinished. Details are in Amber's
`docs/native-application-boundary.md`.

### Amber CLI

Repository: `amber_cli`, base `9f170cc06d76915e27c431299c51722974f6f6da`,
with local changes.

- Native capability manifest v2 adds public app metadata and explicit targets,
  Android identity, SDK/ABI policy, permission/feature declarations, service
  capability intent, deep links and typed resource references.
- Legacy Apple v1 reads remain supported without silently adding Android.
  Web/Android-only v2 manifests do not require an Apple identity.
- Optional sensitive capabilities default off. Declarations are not runtime
  grants or adapter support. Unknown/invalid/duplicate values fail validation.
- Removed generated machine-specific `local.properties`.
- Removed the device-test `|| echo 'Skipped (no device)'` false-success path.
  A shell-execution regression proves a simulated failing device test fails the
  generated runner. The former always-true launch test now launches the actual
  installed Activity and expects an AssetPipeline native View.

The old native scaffold still lacks the complete Android host/build/runtime
integration. Its v2 configuration is not yet consumed by a complete generated
Gradle project. See CLI `docs/android-manifest-v2.md` for exact status and
official Android policy references.

## Validation evidence

| Check | Result |
| --- | --- |
| AssetPipeline focused host specs | 85 examples, zero failures/errors |
| Amber native contracts | 11 examples, zero failures/errors |
| Amber existing schemas plus shared web controller | 319 examples, zero failures/errors |
| Native-only executable | Returns validated shared state count 42, with forbidden-module compiler checks |
| Android boundary | Real ARM64 object plus eight expected, explanatory server-import rejections |
| CLI native/configuration/generator suite | 149 examples, zero failures/errors, including failed-device-command propagation |
| Extracted runtime with combined showcase/Amber fixture | `OK (4 tests)`, 39.466 s; `/tmp/amber-native-android.c0xjus` |
| Direct public-runtime Amber app | `OK (1 test)`, 12.685 s; `/tmp/amber-native-android.v7BpjS` |
| Diff whitespace checks | Clean in the three changed repositories |

The combined four-test run proved the extracted runtime against the original
renderer/density/lifecycle suite. The subsequent direct application run selects
only its own app test because its native entrypoint no longer includes showcase
studies. This is intentional, not a silently skipped failing suite.

Final boundary evidence: `/tmp/amber-native-boundary.se3pAV`.
Final emulator: `emulator-5554`, `sdk_gphone64_arm64`, API 35, CheckJNI enabled.
Final separate relaunch PID: 7686 (an observation, not a reusable identifier).
The final native-app runner records 396 AssetPipeline and 235 Amber source file
hashes. Its screenshots, view hierarchy, logs, artifact listings and manifests
are in the evidence directory; temporary evidence can be removed by the OS.

| Final direct-app artifact | SHA-256 |
| --- | --- |
| Debug APK | `c9458012a9cd4fedd802a060bf3ce862ff223d01c47b081e30a47a534e6030f2` |
| Instrumentation APK | `13de5d5e5146012d227e2c912b1d0bac5423f1138fa13d5ee79982c29e1c5619` |
| Release-mode App Bundle | `83e1bd1c12b912bac1162c180b0678d7dd36f699f9e5dc192ee316bf4de09b4a` |
| ARM64 unstripped native library | `c0033d8a23807fba6ceb3a45f9168d328e41492aaa5d362543d58249d711e3eb` |
| x86_64 unstripped native library | `75e748c697354ec7958435c9b7fe7920afbbb631df769d90015fd033bedda886` |
| AssetPipeline source manifest | `61651dc8f7f9b705aaa9d28321d108b06c5f3f62adda3954b3022915b2ec8a46` |
| Amber source manifest | `e9b4b911d49818733a8dbe5310d8ce8fbc72437e50983a08d437ae058dedb6dd` |

## Reproduce the direct application

From `amber-v2-beta-release`, with the existing pinned SDK/NDK/JDK and verified
Android dependencies:

```bash
CRYSTAL_CACHE_DIR=/tmp/amber-native-cache bash scripts/test_native_boundary.sh

ASSET_PIPELINE_ROOT=/absolute/path/asset_pipeline \
CRYSTAL_CROSS_DEPS=/tmp/asset-pipeline-android-goal-deps \
CRYSTAL_CACHE_DIR=/tmp/ap-android-crystal-cache \
bash scripts/test_native_android_app.sh emulator-5554
```

For the separate AssetPipeline showcase regression lane, invoke its ordinary
`scripts/run_android_smoke.sh emulator-5554` without an external entrypoint.
Each runner builds fresh source and rejects empty/crashed instrumentation even
when ADB returns zero.

## Next implementation slice and remaining gates

1. Build `AndroidShellGenerator` around the canonical runtime, then add the
   `--type hybrid --targets web,android` workflow. Generate complete Gradle
   wrapper/settings/app/Activity/resources/manifest/native entrypoint/tests.
   Consume the v2 metadata instead of leaving it descriptive. Keep existing web
   defaults and Apple generation compatible.
2. Prove a generated consumer from an empty directory using explicit local
   development dependencies first. Released CLI/shard consumer proof remains a
   later, mandatory gate; no released artifacts were changed here.
3. Implement Android-hosted service adapters, lifecycle forwarding, safe
   asynchronous completion/cancellation and permission flows. Preserve the
   no-server/no-OpenSSL application boundary.
4. Complete independent dependency rebuild/provenance and stale-cache rejection.
   Existing archive manifest stability was revalidation, not two clean rebuilds.
5. Finish Tier A behavior/accessibility/navigation/modals and layout gaps
   (maximum/ranged constraints, equal-fill stacks and spacer axes), Unicode/IME,
   reconciliation and state restoration. One retained native tree per process
   is the current ownership limit.
6. Migrate the three AgentC reference screens and shared domain operation; finish
   full platform regressions, visual matrices, CI, release/support documentation
   and clean released-consumer proof.
7. Run x86_64 on a suitable emulator/CI host and prove the authorized physical
   phone. The current ADB inventory only contains the ARM64 emulator. The phone
   authorization question was already sent; do not repeatedly ask while useful
   implementation work remains.

No build/test processes remained running at this checkpoint. The emulator was
left running with the direct Amber app open. Preserve unrelated existing dirty
work (including AssetPipeline Voyager/native reconciliation work and CLI metadata
files); do not commit or clean whole working trees indiscriminately.
