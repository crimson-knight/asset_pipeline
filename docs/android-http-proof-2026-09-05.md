# Android HTTP and platform-trust proof — September 5, 2026

Status: verified local implementation milestone; the full Android target goal is
still active. This follows [storage](android-storage-proof-2026-09-04.md) and is
not a release/support declaration. The [full plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md)
retains its original remaining renderer, service, generator, reference-app and
release/device gates.

## Implemented boundary

Amber's optional `amber/native/android_http` adapter now implements its existing
HTTPClient/Operation interfaces through AssetPipeline's canonical runtime.
`amber/native` itself still excludes Android, AssetPipeline and Crystal's HTTP/
OpenSSL server stack. See [the API contract](../../amber-v2-beta-release/docs/android-http.md)
for usage, wire format, errors, limits and cancellation semantics.

AssetPipeline owns the Kotlin HTTP backend, binary codec, checked byte-array JNI
submission/completion and service-queue integration. Four network workers are
separate from serial SQLite work. Android owns TLS trust and hostname validation;
there is no production custom trust manager, hostname-verification bypass or
Crystal SSL dependency. Redirects are explicit responses and automatic retries,
cookies and disk caching are disabled. HTTP 4xx/5xx retain response status/body.

The versioned big-endian wire preserves arbitrary body bytes and strict UTF-8
metadata without base64 or JNI modified UTF-8. Packet/body/header/count limits
are enforced, including unknown-length response bodies. Errors are sanitized and
typed. Call cancellation closes active network work, then host delivery removes
the pending operation and invokes its Crystal callback on the main looper.
Terminal session close cancels and drains outstanding network requests without
entering Crystal from workers or retaining an Activity.

Limits are explicit: at most 64 combined accepted services, a 1 MiB envelope,
900 KiB body, 128 headers/32 KiB, 8 KiB URL and 1..120000 ms call timeout. Queue
delay, first-use initialization and system DNS cleanup are not a hard real-time
completion guarantee. Cancellation cannot roll back a server-side effect. This
is bounded in-memory HTTP, not streaming downloads/uploads or WebSockets.

## Permission-merge finding and fix

The real OkHttp Android archive declares INTERNET itself. Initially the offline
host therefore inherited internet permission, despite not asking for it. Archive
and merged-manifest inspection found this; a source-only generator check would
have missed it.

The offline showcase and generated apps now explicitly remove transitive INTERNET
unless application metadata requests it (network capability or explicit permission).
The TLS test's higher-priority debug manifest deliberately opts in. Actual APK
permissions are inspected with pinned Build Tools, and a separate installed-app
test verifies the inverse: no INTERNET permission and an asynchronous Amber
PermissionDenied result through real JNI. No device/system trust settings change.

This follows [Android's manifest-merger rules](https://developer.android.com/build/manage-manifests).
The temporary debug CA uses [Android's declarative network-security configuration](https://developer.android.com/privacy-and-security/security-config),
and never enters the release source set/bundle.

## Toolchain and dependency decisions

Native API/minimum SDK 31, compile/target SDK 35, Crystal 1.21.0, NDK 28.2.13676358,
JDK 17, Gradle 9.3.1 and AGP 8.7.3 remain the current host contract. Kotlin moved
from 2.0.21 to **2.2.21**, required by the selected HTTP library's actual Kotlin
metadata. Build Tools **35.0.0** are now explicit in the machine-readable contract,
both Gradle hosts and the doctor/package checks.

`android/runtime/dependencies.gradle.kts` is shared by the showcase and generated
apps: OkHttp Android **5.3.2**, with matching JVM-only MockWebServer/TLS test
dependencies. Production code never depends on those test helpers. OkHttp 5.5.0
failed the real AAR compatibility gate because it requires compileSdk 37; the
check was not suppressed. Published metadata compatibility evidence is retained
under `/tmp/ap-http-compat.nBS8kt`. Library/toolchain upgrade and Gradle checksum/
lock/SBOM provenance remain explicit release work. See the upstream
[release history](https://lysine.dev/okhttp/changelogs/changelog/) and
[HTTP/cancellation recipes](https://lysine.dev/okhttp/recipes/).

The existing verified native dependency cache was revalidated, not rebuilt:
`/tmp/ap-android-dependency-proof.bTzNdZ/first`. Its ABI/API/native recipe keys
did not change; this milestone adds JVM dependencies, not Crystal OpenSSL archives.

## Verified native evidence

All execution used ARM64 API 35 `emulator-5554` with CheckJNI. The previous emulator
was confirmed absent, then the existing `crystal_test` AVD was started without
wiping its data. Both ARM64 and x86_64 libraries were cross-built; x86_64 was not
executed and no physical phone was visible.

- **Final TLS/permission-enabled lane:**
  `/tmp/amber-android-http-proof/tls-permission-final`.
  **OK (3 Android tests), 7.037 seconds**: real Amber HTTP fixture plus both
  SQLite backend/corruption-preservation tests. The mounted native screen records
  **32 Crystal checks**, followed by four more cancellation assertions after
  terminal close. The test closes/reopens/recreates Activities and requires zero
  pending operations and native references after cleanup.
- The receipt ledger contains trusted GET, POST, PATCH, HEAD, error/redirect,
  known-/unknown-length oversized bodies, timeout, four interactive cancellations
  and four close-time requests. No HTTP request reached the wrong-host, untrusted
  or cleartext servers, nor the forbidden redirect/input destination. Temporary
  reverse mappings were removed and all fixture servers stopped. The screenshot
  `http-contract.png` was inspected: native views show “HTTP contract passed” and
  “Checks: 32”. Release bundle entries exclude the CA and test network XML.
- **Permission-denied lane:** `/tmp/amber-android-http-proof/permission-denied`.
  **OK (3 Android tests), 2.848 seconds**. The installed target explicitly has no
  INTERNET permission, a real Amber request receives PermissionDenied, and no
  operation is retained. This reinstall also removes the temporary debug CA
  source-set configuration from the installed showcase app.
- **Canonical JVM contracts:** **31 passing tests**: HostSession 8, ServiceQueue
  12, HttpWire 4, PlatformHttp 7. The HTTP tests use controlled loopback servers:
  binary/error responses, redirect non-forwarding, unknown-length size limits,
  active-read cancellation, pre-publication cancellation, call timeout and default
  rejection of an untrusted certificate. All four nonempty successful XML reports
  are mandatory and retained by both native proof runners. Protocol fixtures
  explicitly reject missing/empty/failed reports before crashed-instrumentation
  tests; synthetic fixtures are not presented as real test execution.
- **Renderer regression:** `/tmp/amber-android-http-proof/renderer-final`,
  **OK (5 Android tests), 19.245 seconds**: original three renderer/bootstrap/
  input/layout/lifecycle tests plus both SQLite tests. This run preceded the
  subsequent permission-only manifest/Build Tools changes; later HTTP permission
  and generated-consumer lanes cover those changes. It is not a new full Tier A
  renderer claim.
- **Amber boundary:** `/tmp/amber-android-http-proof/boundary`: **16 native
  examples**, native executable, ARM64 isolation object, eight rejected server
  imports and **319 web/schema examples** pass. Four new shared wire examples
  exercise binary ownership, repeated headers, all response truncations, invalid
  metadata and input bounds.
- **CLI:** **157 focused native/configuration/generator examples** pass. The new
  permission regression checks default removal and explicit opt-in. The actual
  rebuilt CLI is `/tmp/amber-android-http-proof/amber-final`, SHA-256
  `dc61e5154c272bb5e80916decac4bcf7baa05c668da6973849580dad1978a59d`.

## Fresh generated consumer

The final fresh consumer passed under
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.aEC41t`.
The real rebuilt CLI generated a new hybrid project with no handwritten source
changes. Explicit local development overrides resolved Amber/AssetPipeline;
this is not released-dependency proof. Two shared examples and the real Amber
web state/validation/CSRF/escaping checks passed, followed by all 31 canonical
JVM tests, both native ABI builds, debug and unsigned release APKs, App Bundle,
required JNI exports and matching native debug symbols.

**OK (3 Android tests), 11.407 seconds** covers the generated application plus
both SQLite tests. Debug and release APK permission reports confirm INTERNET
is absent, matching the app's explicit metadata despite the dependency manifest.
All **661 source entries** match before/after: 33 generated, 238 Amber, 390
AssetPipeline. The source-freeze comparison completed successfully.

Instrumentation process **4877** saved count **4** and name **Android**. A forced
new process, **5009**, restored both values and displayed “Restored from local
storage.” The relaunch screenshot was inspected and CounterApp was left open in
the emulator. The generated counter exercises storage and package/runtime
regression, not real TLS itself; the direct Amber fixture above supplies the
actual Android TLS evidence.

Artifact SHA-256 values:

- Debug APK: `f9013a7af7750f312396eae7dbef89ce27ee2b33fba6737ca7d62019684ba423`.
- Unsigned release APK: `5ee807c10eb4a346976ddb793fcddd6a8c681cd61a70cc32ff5b46bfc1e04131`.
- App Bundle: `7e32c58407541bf1fa38751e50a83e3d1c67966e81b47a683b8c5417e1c3c900`.

## Remaining work

Protected secrets, files, notifications/runtime permissions, the rest of Tier A
rendering/navigation/accessibility/IME and restoration, metadata regeneration and
unified CLI ergonomics, AgentC reference application, full ABI/API/device matrix,
CI, dependency provenance/signing, public releases and released-consumer proof
remain open. The packaged permission check runs in build/test artifact validation;
moving all validation before installation in the unified run/test flow remains
part of the CLI workflow hardening. The original goal is not complete.

Resume commands use `CRYSTAL_CROSS_DEPS` (not `CROSS_DEPS`) to select the verified
cache. New source files and the surrounding worktrees remain dirty; unrelated
Voyager/native-reconciliation work and other user changes were not reverted.
