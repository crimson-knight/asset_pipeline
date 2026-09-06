# Android app-private files checkpoint — September 5, 2026

Status: verified development implementation; the full Android goal remains active.
This implements the existing bounded Files interface, not streaming/media files,
external documents, a public release or complete Tier A rendering.

## Implementation

Amber's optional `amber/native/android_files` adapter connects to AssetPipeline's
canonical asynchronous byte-array transport. A dedicated JVM worker calls
`src/ui/native/android_private_files.c`; the backend never enters Crystal and
retains no JNI reference. Showcase and CLI-generated hosts compile this same C
source plus `PrivateFiles`/`FilePolicy`.

The [API contract](../../amber-v2-beta-release/docs/android-files.md) documents:

- Ordinary binary files under `context.filesDir/asset_pipeline_files_v1`; no
  external-storage permission or document grant. Backup follows host policy,
  unlike the separately protected no-backup Secrets vault.
- Strict relative UTF-8 paths: 1,024 bytes, 32 components, 255 bytes per component;
  traversal, empty components, URI/drive syntax, control bytes and reserved
  `.ap-` names are rejected. File data is arbitrary bytes, bounded to 1 MiB.
- Directory-descriptor-relative `openat`/`mkdirat` with `O_NOFOLLOW`, regular-file
  and link-count checks, nonblocking opens for special-file safety, a namespace
  lock with five-second contention timeout, and no recursive-delete behavior.
- Same-directory temporary writes, full write/file sync/close, atomic rename,
  then directory sync. Reads ignore uncommitted temporary data. Before-commit
  failures preserve old data; after-rename errors do not promise rollback.
- Owned submissions, shared 64-request capacity, deferred exactly-once replies,
  idempotent cancellation, terminal cancellation/drain and descriptor cleanup.
  Missing reads report IO; empty files are successful zero-byte values.

These use [Android app-specific storage](https://developer.android.com/training/data-storage/app-specific)
and public [NDK C APIs](https://developer.android.com/ndk/guides/stable_apis).
The C source passes strict `-Wall -Wextra -Werror` syntax checks against the
pinned NDK's ARM64 and x86_64 API 31 headers. This does not prove physical-device
or x86_64 runtime behavior, hostile same-UID isolation, pre-first-unlock execution,
cloud-backup restoration or every possible power-loss outcome.

## Native proof

`/tmp/amber-android-files-proof/native-final` runs on API 35 arm64, background
emulator `amber_secrets_20260905`, serial `emulator-5556`. The original visible
emulator remains separate and was not shut down or cleared.

- **40 canonical JVM tests:** HostSession 8, ServiceQueue 12, HttpWire 4,
  PlatformHttp 7, SecretVault 5 and FilePolicy 4. The new policy tests include
  Unicode-byte versus character limits, depth, malformed/overlong UTF-8,
  traversal, reserved paths and binary-data limits.
- **13 Android instrumentation tests, 14.927 seconds:** the Amber file fixture,
  two SQLite tests, five Keystore tests and five real file-backend tests.
- **88 native adapter checks** include owned binary input mutated immediately
  after submission, all byte values, Unicode filenames, a full 1 MiB JNI reply,
  empty/missing distinction, typed input rejection, queue overflow and cancellation.
  **32 further reads** are cancelled during terminal close; pending operations
  and native callback/reference counters drain to zero.
- Platform tests prove binary durability, maximum and oversized files, symlink
  and FIFO/directory rejection, interrupted temporary-file behavior, unsafe
  lock/temp rejection, direct JNI path validation and no namespace/root-handle
  leak after 100 write/read/delete cycles. A concurrent 200-cycle parent-directory
  symlink replacement never returns the external sentinel's bytes.
- Instrumentation process **6516** writes the public binary fixture; new process
  **6603** runs the strictly read-only `files-reopen` route and displays
  `Binary file restored after process restart`. XML, screenshot, process IDs,
  CheckJNI logs and source hashes are retained. The screenshot was inspected.
- Debug APK SHA-256:
  `a2b0ae164981ed6b5f3fd275ad59f0bcd39bcc85519bacaa322c99a7e54162ce`.
  Release-mode App Bundle SHA-256:
  `13cec089d166ef645866e45e37bce601527a025c9eaf5212ffb2f87103e8c946`.
  Both ABIs are packaged; runtime proof above is arm64 only.

## Hard-link finding and additional native checks

The first run, `/tmp/amber-android-files-proof/native-first`, is **not a pass**.
Its native Amber fixture and four of five filesystem cases passed, but Android
denied the test's hard-link creation with AccessDeniedException before the
backend could inspect a hard link. The test now records
`files_hardlink_policy=creation denied by platform` in this case; it does not
claim that the Android backend's hard-link branch executed. Other safety checks
still run, and a platform that permits hard-link construction must pass actual
backend rejection.

`scripts/tests/android_files_backend.sh` compiles the exact same POSIX backend
on the host, excluding only JNI glue. It passes real hard-link, symlink and FIFO
rejection, binary IO, path rules and bounded cross-process lock contention.
The shared code also passes AddressSanitizer/UndefinedBehaviorSanitizer on these
host cases, with no diagnostics. Evidence includes
`/tmp/amber-android-files-proof/backend-sanitized` and `sanitizer-result.txt`.
This supplements the emulator tests; it is not Android sanitizer coverage.
The initial host compile tried JBR JNI headers that are not packaged in this
installation; the host-only test no longer needs JNI headers or a mock JVM.

## Regression and consumer follow-through

- Secrets regression: **13 Android tests, 11.568 seconds**, including the actual
  82-check Amber secrets fixture, 32 terminal cancellations and different-process
  protected-value recovery. Evidence:
  `/tmp/amber-android-files-proof/secrets-regression`.
- Native boundary: **16 native examples**, runtime result 42, ARM64 isolation
  object, eight explanatory server-only import rejections and **319 web/schema
  examples** pass. Evidence: `/tmp/amber-android-files-proof/boundary`.
- CLI: **157 native/configuration/generator examples** pass. Generated build
  scripts include the new C backend, the test wrapper requires a successful
  FilePolicy XML report and the file platform suite, and artifact inspection
  requires both the file-submission and native file-backend JNI exports.
- Rebuilt CLI: `/tmp/amber-android-files-proof/amber`, SHA-256
  `a982937e429bd22fa87581605bf1c0e7311e2f054fb99b304c94cb159369a6ef`.
- HTTP regression: **13 Android tests, 17.082 seconds** under
  `/tmp/amber-android-files-proof/http-regression`. Platform TLS/hostname/cleartext
  policy, body bounds, cancellation, terminal shutdown, server receipt ledger and
  release test-CA exclusion pass. Temporary device port mappings are removed.
- Final denied-permission regression: **13 Android tests, 8.077 seconds** under
  `/tmp/amber-android-files-proof/http-denied-final`. The normal no-test-CA build
  replaces the TLS fixture APK, no temporary trust resources remain in the APK,
  and the real Amber HTTP request reports PermissionDenied without network access.

### Fresh generated consumer

The actual rebuilt CLI generated a new hybrid application under
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.ClzazL`.
Explicit local development shard overrides were used; no generated source was
repaired by hand. This is not public released-dependency proof.

Two shared Crystal examples, real web state/validation/CSRF/escaping checks,
**40 JVM tests** (all `skipped=0`), both ABI builds, debug/unsigned release APKs
and App Bundle pass. Packaged ELF/JNI inspection verifies both new file exports
and matching native debug symbols. Debug/release permission checks confirm no
unrequested INTERNET permission. **All 675 source entries** match before/after:
**33 generated, 240 Amber, 402 AssetPipeline**.

**13 Android tests pass in 22.352 seconds**, covering the generated counter,
SQLite, Keystore and native file backends. The counter itself still exercises
ordinary key/value storage; the dedicated fixture above proves the actual Amber
Files API. Android hard-link creation remains explicitly reported as
platform-denied in this application domain as well.

Process **7320** saves count **2** and name **Android**. New process **7446**
restores both and displays `Restored from local storage.` The screenshot was
inspected. This project uses the same test application ID as earlier runs and
preserves its prior saved data; fresh generation is not a claim of a cleared
device or a newly empty application database.

Artifact SHA-256 values:

- Debug APK: `fb7d685159db4b96ce821a4c14753b19b79deda096d63aafaab1056b90eae6ed`.
- Unsigned release APK: `77d0e2cb77e6b66c5f45cbaef89220dd33e00547099ec497d7c8bcf2d95ef7c7`.
- App Bundle: `51a079a044571be386cf8edafedf172e235a4014d1c5ed1a09ed16b7298d7305`.

The prior nullable-parent warning in the Keystore test cleanup was corrected.
Gradle future-version deprecations and the debug-only ELF dynamic-table warning
remain; they are not failed tests or missing native-debug-symbol evidence.

## Remaining full-goal work

Notifications/runtime permission flows, user-selected documents and streaming
media require separate adapters. The rest of Tier A rendering, navigation,
accessibility, IME/reconciliation and restoration, metadata regeneration and
unified CLI validation, the AgentC reference application, API/ABI/physical-phone
matrix, CI/signing/provenance and public released-consumer proof remain open.
The original full goal is not complete.

The next bounded implementation is the existing Notifications interface with
explicit capability/permission declarations, real permission outcomes, channel
policy, post/cancel behavior and lifecycle tests. Continue to use the verified
native dependency cache via
`CRYSTAL_CROSS_DEPS=/tmp/ap-android-dependency-proof.bTzNdZ/first`.
