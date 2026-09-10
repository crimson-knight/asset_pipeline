# Fresh generated Android consumer — 2026-09-04

**Status: development generator milestone passed; full Android goal active.**

Subsequent [dependency proof](android-dependency-proof-2026-09-04.md) completes
the independent dependency build/cache work listed as remaining below.

This follows the [application boundary checkpoint](android-application-boundary-proof-2026-09-04.md).
The governing [full implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md)
has not been narrowed. No public release, physical phone, x86_64 runtime,
full Tier A renderer or service-adapter completion is claimed.

## Outcome

The real locally built Amber CLI now generates a complete native Android
application and a separate web application from an empty directory:

```text
amber new counter_app --type hybrid --targets web,android --no-deps
```

The two presentations share Crystal counter/state/schema rules. Android imports
the public AssetPipeline application boundary and Amber native facade, not the
showcase entrypoint or Amber's HTTP/OpenSSL stack. The generated Activity,
Gradle wrapper/settings/app, manifest/resources and instrumentation are owned
by the app. Canonical JNI/Kotlin/listener/runtime sources come from its installed
AssetPipeline shard.

The explicit `--type native --targets android` route emits only Android.
Legacy multi-platform native generation now includes the same Android shell,
but its full Apple/desktop runtime regression is not covered by this proof.

## Proof run

Runner: `amber_cli/scripts/test_generated_android.sh` using the compiled public
CLI entrypoint, not an isolated generator class.

Evidence root:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.60JcSX`.

| Check | Result |
| --- | --- |
| Fresh destination | Generated at the requested absolute path |
| Dependencies | Actual Shards resolution with explicit local development overrides |
| Shared Crystal state/schema spec | One example, zero failures/errors |
| Real web server | State, validation, rejected CSRF and HTML escaping passed |
| Native compile/link | ARM64 and x86_64, current generated Crystal source |
| Android packages | Debug APK, unsigned release APK and release-mode App Bundle |
| Emulator interaction | `OK (1 test)`, 10.6 seconds, ARM64 API 35 |
| Test coverage | Button increment, text input, valid/invalid rename, Activity recreation, zero retained refs/callbacks after close |
| Separate process launch | Initial Count 0 and runtime fiber/channel probe 42; observed PID 8300 |
| Runtime diagnostics | CheckJNI verified; instrumented/relaunched app logs passed crash checks |
| Package inspection | Selected ABI ELF/JNI exports and matching build IDs across native build/APK/AAB/debug symbols |
| Source stability | 33 generated, 234 Amber and 372 AssetPipeline source hashes unchanged before/after |
| CLI regressions | 156 examples, zero failures/errors after final orchestrator regression |
| Released lane | Intentionally rejected development-branch dependency metadata |

The real fresh-project run required no generated-source repairs. An earlier
exploratory project exposed and led to fixes for absolute destination handling
and the Kotlin host's layout-parameter declaration. It is not the final proof.

The wrapper and distribution hashes were checked against Gradle's official
checksum endpoints and added to AssetPipeline's shared toolchain contract.
They are enforced by the generated CLI wrapper. APK/AAB native symbol inspection
checks the actual packaged library, not merely the pre-package build output.

## Receipts

| Artifact | SHA-256 |
| --- | --- |
| CLI binary used by the fresh run | `161e94285ae6175cef67509906647d710cbd614677627c17c09b8c82f8a33df9` |
| Debug APK | `4b748515ffd70197908fb1170e88dac61208d3f05c11a9115553204b56443704` |
| Unsigned release APK | `4b6ce15b096f873f26025e682696d9e06eb5285bcb399281639637a683f3dd0e` |
| Release-mode App Bundle | `61f1c39bfc37f937b0bb8569e504265e49bd76f15657c140bfb4add5bdfc0f1f` |
| Generated source manifest | `2d6e26934754d61b35820b9b90c5f385f769b4c9cee5cbe664d06f43efd782ff` |
| Amber source manifest | `1dc16fcf1461e22773a1b117ea5db42c991913553e25c40c248afbbda5bfaa2b` |
| AssetPipeline source manifest | `56b13f5a86e114a9483e80b135e5ec70e02f3a59b1107638e7e4ebd84ef7fdbc` |

Source manifests, logs, view hierarchy, screenshot, toolchain, ELF inspections,
debug symbols and artifacts remain in the evidence directory. Temporary
evidence is not durable release storage and can be removed by the OS.

## Reproduce

From the CLI checkout with its dependencies installed:

```bash
crystal build src/amber_cli.cr -o /tmp/amber-android-development
CRYSTAL_CROSS_DEPS=/tmp/asset-pipeline-android-goal-deps \
CRYSTAL_CACHE_DIR=/tmp/ap-android-crystal-cache \
bash scripts/test_generated_android.sh emulator-5554 \
  /tmp/amber-android-development --development \
  /absolute/path/amber-v2-beta-release /absolute/path/asset_pipeline
```

CLI details and ownership rules live in `amber_cli/docs/android-generator.md`.
The prerelease-aware override helper reads the actual Amber shard version.
Do not replace local development overrides with an invented released version.

## Remaining work and next slice

1. Expose safe target/metadata regeneration and unified Android doctor/build/run/
   test commands in the CLI. Generation alone currently materializes metadata;
   later YAML edits do not automatically update Gradle/resources.
2. Implement Android lifecycle forwarding and service adapters with safe
   asynchronous dispatch, cancellation, permission behavior and injectable
   Crystal interfaces. The current service declarations remain interfaces.
3. Complete independent GC/PCRE2 dependency rebuilds, trustworthy source
   provenance, ABI/API cache isolation and stale-cache rejection. This run used
   previously built/revalidated archives and warm caches, not two clean builds.
4. Complete the full Tier A renderer, layout constraints, keyboard/Unicode/IME,
   accessibility, navigation/modal behavior and state restoration. The current
   host supports one mounted native root per process and an in-memory example.
5. Migrate AgentC's three real reference screens/shared operation; preserve web
   behavior; finish CI, existing-platform regressions and visual/device matrices.
6. Run x86_64 and minimum-API runtime lanes, then the authorized physical phone.
   ADB currently lists only the ARM64 emulator; the phone question was already
   sent. Do not repeatedly ask while implementation can continue.
7. Verify/publish the approved release artifacts, pin actual releases, complete
   clean released-consumer proof and signing/current store-policy checks.

The legacy all-platform test orchestrator's remaining Android `|| true` path
was removed and covered by an executing regression. Unrelated pre-existing
macOS/iOS optional-test behavior was not silently reclassified as Android proof.
No new build/test process remains at the checkpoint; the emulator is left open.
