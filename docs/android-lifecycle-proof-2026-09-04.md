# Android lifecycle integration proof — September 4, 2026

Status: verified local development milestone; the full Android goal remains active.
This follows the [dependency proof](android-dependency-proof-2026-09-04.md).

## Implemented

AssetPipeline now separates a process-retained application session from its
transient native View tree. The public Crystal entrypoint accepts one
`Application.on_lifecycle` handler. Its `Foreground`, `Background` and `Stop`
events travel through the canonical JNI bridge; exceptions return failure rather
than unwinding through JNI. The Kotlin session becomes terminal on failure.

The canonical `CrystalBridge` enforces Android's main looper for library loading,
application/UI calls and debug reads. The deliberately separate C bootstrap
once-gate test remains callable from JVM workers. `HostSession` tracks the owner,
rejects simultaneous second surfaces, suppresses duplicate visibility events,
rejects reentrant transitions, and releases ownership even when cleanup fails.

Both the AssetPipeline host and CLI-generated Activity now attach in `onCreate`,
forward visibility from `onStart`/`onStop`, and release their native tree in
`onDestroy`. Refresh work is cancelled when the Activity stops. The showcase no
longer converts a failed native root into a placeholder that could hide failure.

Amber's `Lifecycle#activate` starts a new session once or resumes the retained
one. The direct Amber fixture and generated app map host events to this lifecycle
outside their screen factories. Their sample process manager exposes real
start/background counts in the native UI for end-to-end assertions.

## Semantics and boundaries

- Foreground means **started/visible**, not necessarily resumed/input-focused.
  A temporary focus change is not automatically application backgrounding.
- Configuration recreation may produce a background/foreground pair. It does
  not restart managers or replace the retained domain state.
- Closing/reopening an Activity in the same process preserves the session.
  Destroying an Activity releases its View references, not the entire session.
- `closeSession()` is an explicit terminal operation after detaching the host,
  not an `onDestroy` hook. Failed/stopped runtime sessions reject new surfaces;
  a fresh Android process creates a fresh session.
- Process termination does not guarantee a final callback. Important state must
  be persisted independently. This milestone does **not** add durable storage.
- One surface/process is enforced; multiple simultaneous Activities/windows are
  not supported yet. Background services, focus-sensitive permissions and
  asynchronous service completions remain separate work.

These choices follow Android's [Activity lifecycle](https://developer.android.com/guide/components/activities/activity-lifecycle)
and [Application.onTerminate contract](https://developer.android.com/reference/android/app/Application#onTerminate()).

## Verification

All runtime execution below used `emulator-5554`, ARM64, API 35, CheckJNI enabled,
Crystal 1.21.0, NDK 28.2.13676358, and the previously independently reproduced
API 31 dependency cache `/tmp/ap-android-dependency-proof.bTzNdZ/first`.
Cache validation is not another independent dependency build. Both ABIs were
compiled/packaged; x86_64 was not executed.

1. Amber native boundary: **12 examples passed**, native-only executable and
   ARM64 object passed, all eight server-import guards rejected the expected
   imports, and **319 web/schema examples passed**.
   Evidence: `/tmp/amber-android-lifecycle-proof/boundary`.
2. Direct Amber/AssetPipeline fixture: **OK (1 test), 17.241 seconds**.
   Verified shared counter/name validation, first start, real Activity background
   and foreground, recreation without restart, and zero native references and
   callbacks after closing. Separate-process launch also passed.
   Evidence: `/tmp/amber-android-lifecycle-proof/native-fixture`.
3. AssetPipeline renderer regression: **OK (3 tests), 29.785 seconds**.
   Retains real keyboard typing/editor identity, callbacks, eight worker calls
   to the bootstrap once gate, five background/recreation cycles, reference
   cleanup, light/dark system-bar handling and density/font-scale assertions.
   **Eight HostSession JVM unit tests** also passed; their report is retained.
   Evidence: `/tmp/amber-android-lifecycle-proof/renderer`.
4. Amber CLI native/configuration/generator suite: **156 examples passed**.
5. Fresh generated hybrid consumer: real rebuilt CLI, fresh temporary project,
   explicit local development shard overrides, shared Crystal spec, live Amber
   web state/validation/CSRF/escaping checks, both ABI native libraries, debug
   APK, unsigned release APK, release-mode App Bundle and debug-symbol checks.
   **Eight canonical HostSession unit tests passed** and **OK (1 instrumented
   test), 17.168 seconds**. All **646 source entries** were unchanged across
   the run: 33 generated, 234 Amber and 379 AssetPipeline.

Fresh consumer evidence:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.QBg7ZA`.
Its instrumentation additionally rejects worker-thread UI dispatch, a second
surface owner, closing while attached, and reopening a terminal session. It
asserts actual Amber manager counts after background/foreground, recreation,
and Activity close/reopen in the same process, then explicitly closes the
session. Native reference/callback counts return to zero after each close.
A separate process is then launched and must show initial `Count: 0` and the
runtime probe. CounterApp was left open; observed relaunch PID was **10323**.
The screenshot was inspected and shows the native counter, lifecycle label,
input and actions. Temporary evidence can be removed by the operating system.

The runner now requires a nonempty passing canonical host-session XML report
and retains it, alongside instrumentation. Runtime-log checks also reject the
new `Crystal application error` diagnostic. Missing/crashed tests are failures.
The final CLI regression run initially exposed an outdated shell-test fixture:
its stub Gradle produced no host-test report, so it never reached the simulated
ADB crash. The fixture now separately asserts missing/empty/failed reports are
rejected, then supplies a clearly synthetic passing prerequisite to exercise
crashed instrumentation. The final 156-example suite passes; the real fresh-app
lane above executes the actual eight JVM tests, not that stub.

### Artifact identity

Latest CLI: `/tmp/amber-android-lifecycle-proof/amber-final`.

```text
CLI SHA256                9826b04f6120794dd85136ab7c751bfa5d27e673f28e90a11acf72cd93f5bc50
debug APK SHA256          a4b721ea4a58821936aa05078be5c27ad54b559497eead039ab74276647b1cee
unsigned release SHA256   1062f1176484f9e342d77f34dfc00508dd68ffe02cce8c00f1277e49f7a68b88
App Bundle SHA256         bbd57a4a6f955aaf2fa3ae926e04164cafaca46f8be6de7b8416300c377c76ec
```

The generated proof retains per-ABI dependency receipts and matches debug-symbol
build IDs to packaged libraries. Local dirty sources and explicit overrides are
not published releases. Gradle/Kotlin deprecation warnings remain; debug-only
ELF files have no dynamic table, but their build IDs were verified.

## Reproduce

From the Amber CLI checkout:

```sh
crystal build src/amber_cli.cr -o /tmp/amber-android-lifecycle
CRYSTAL_CROSS_DEPS=/tmp/ap-android-dependency-proof.bTzNdZ/first \
  bash scripts/test_generated_android.sh emulator-5554 \
  /tmp/amber-android-lifecycle --development \
  /Users/crimsonknight/open_source_coding_projects/amber-v2-beta-release \
  /Users/crimsonknight/open_source_coding_projects/asset_pipeline
```

If the temporary dependency cache is gone, build a new verified keyed cache;
do not relabel the old flat archives. See the dependency proof for clean builds.

## Next implementation work

Add real platform adapters behind Amber's existing service interfaces, beginning
with app-private key/value persistence and a main-looper asynchronous completion
transport. Prove exactly-once completion, cancellation, error handling, thread
and foreign-reference cleanup, and persistence across actual process restart.
Keep secrets out of ordinary preferences. Networking must use Android-hosted TLS.

Safe CLI target/metadata regeneration and unified commands; remaining Tier A
layout, accessibility, navigation, Unicode/IME and restoration; AgentC reference
screens; existing-platform regression, CI and independently verified releases;
API-level/x86_64 runtime matrix; physical-phone testing; and signing/current
store-policy review all remain required. The doctor still lists only the
emulator. This checkpoint does not waive any gate in the
[full implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md).
