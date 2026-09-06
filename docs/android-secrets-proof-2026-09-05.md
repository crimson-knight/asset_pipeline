# Android protected-secrets checkpoint — September 5, 2026

Status: verified development implementation; the full Android goal remains active.
This adds one platform service, not a public release or full renderer support.

## Implemented contract

Amber's optional `amber/native/android_secrets` adapter implements the existing
Secrets interface through AssetPipeline's canonical byte-array JNI transport.
The native-safe core remains independent of Android/AssetPipeline imports.
See [the API and security contract](../../amber-v2-beta-release/docs/android-secrets.md).

- Separate serial worker and encrypted vault; ordinary SQLite Storage is not
  reused for secrets. The shared accepted-operation limit remains 64.
- AndroidKeyStore AES-256-GCM, provider-generated random nonce, authenticated
  version/app/vault identity; both identifiers and values are encrypted.
- Credential-encrypted `noBackupFilesDir`; no plaintext index or software-key
  fallback. Directory/file/key/crypto work is lazy and off the main looper.
- Bounded, strict UTF-8 payloads: identifiers 512 bytes, values 65,536 bytes,
  128 entries and 1,000,000 encoded plaintext bytes per vault.
- File locking, AtomicFile, explicit file/directory sync and post-commit
  ciphertext verification before success. This does not claim immunity to every
  power-loss/storage-controller failure or rollback to older valid ciphertext.
- Missing key, authentication failure, malformed data, symlinks and invalid
  file types fail closed without resetting or overwriting the vault.
- Exactly-once deferred completion and idempotent cancellation; terminal close
  cancels/drains accepted work and stops the worker. Cancellation is not rollback.

No hardware-backed/StrongBox, biometric-gated or plaintext-memory-zeroization
claim is made. The policy supports background use after first user unlock, not
locking the vault on each screen lock. Cloud backup/restore, pre-first-unlock
execution and physical-device key behavior were not exercised. Android's
[Keystore](https://developer.android.com/privacy-and-security/keystore),
[cryptography](https://developer.android.com/privacy-and-security/cryptography)
and [backup](https://developer.android.com/identity/data/autobackup) contracts
underpin these choices; automatic backup exclusion is not a measured cloud run.

## Native and platform evidence

Final fixture: `/tmp/amber-android-secrets-proof/native-final`.
API 35 arm64 emulator `amber_secrets_20260905`, serial `emulator-5556`.
Both ARM64 and x86_64 native libraries/package entries build; x86_64 execution
and the connected-phone gate remain unproved.

- **36 canonical JVM tests:** HostSession 8, ServiceQueue 12, HttpWire 4,
  PlatformHttp 7, SecretVault 5. The five new tests cover codec limits,
  UTF-8/NUL/empty values, truncation/duplicate/hostile lengths, fresh nonces,
  and rejection of modified nonce/ciphertext/identity/key/version.
- **Eight Android instrumentation tests, 10.703 seconds:** the native Amber
  fixture, two SQLite platform tests and five real Keystore platform tests.
  Non-exportability (`encoded == null`), AES-256/GCM key properties, encrypted
  names/values, reopen durability, ciphertext tampering, deleted-key preservation,
  AtomicFile backup recovery, input preservation and symlink/type rejection pass.
- **82 native adapter assertions** pass through Crystal/JNI, including owned
  Unicode/NUL payloads, deferred completion after GC, missing versus empty values,
  separation from ordinary Storage, queue overflow and cancellation. A further
  **32 accepted reads** are cancelled by terminal session close; both pending
  counters and native reference/callback counters drain to zero.
- Instrumentation process **4655** persists only a public test value. The runner
  starts process **4745** with the read-only `secrets-reopen` route and verifies
  `Protected test value restored after process restart`. The route never writes.
  Screenshots/XML, process IDs, source hashes and CheckJNI logs are retained.
- Debug APK SHA-256:
  `23e20510c66a48083a0e730f0c159bd8502b12bfdfcba67da000e11dd6153d9e`.
  Release-mode AAB SHA-256:
  `c1cafcfbff9483bd87968ffd42604cbead82891f595f4a5942309634f1dcab30`.
- Amber native-boundary regressions: **16 examples**, native execution result 42,
  an ARM64 isolation object, eight explanatory server-import rejections and
  **319 web/schema examples** pass. Evidence:
  `/tmp/amber-android-secrets-proof/boundary`.
- CLI native/configuration/generator regressions: **157 examples** pass. Missing,
  empty and failed SecretVault reports now fail the generated test wrapper;
  both native/generated lanes require the shared platform tests. Artifact
  inspection now requires `android_host_secrets_submit` in both ABIs.

## Emulator interruption and recovery

The first run built successfully but never completed installation:
`/tmp/amber-android-secrets-proof/native-first`. The visible `crystal_test`
emulator's ADB transport stalled while the Mac was locked. Reconnecting that
one transport ended the incomplete install; it was not counted as a passing run.
The existing emulator/data were preserved, and an isolated no-window API 35
device was created from the already-installed image for the passing runs.
The Mac lock was not bypassed. The original transport subsequently reappeared.

`doctor_android.sh --serial <id>` now checks the selected device rather than
letting an unrelated offline device invalidate the run. A healthy selected
serial passes; a nonexistent selected serial fails. Unscoped doctor retains
its whole-device inventory behavior.

## Regression and generated-consumer follow-through

- Ordinary Storage regression: **eight Android tests, 9.182 seconds**, including
  the unchanged 78 native adapter assertions. Evidence:
  `/tmp/amber-android-secrets-proof/storage-regression`.
- HTTP/TLS regression: **eight Android tests, 12.334 seconds**, with trusted,
  wrong-host/untrusted/cleartext, bounds, cancellation and terminal-close tests.
  The controlled server's receipt ledger and release CA-exclusion check pass;
  temporary reverse mappings are removed. Evidence:
  `/tmp/amber-android-secrets-proof/http-regression`.
- The final missing-permission run also passes **eight Android tests, 8.161
  seconds** under `/tmp/amber-android-secrets-proof/http-denied-final`. It replaces
  the TLS fixture APK with the normal no-test-CA/no-INTERNET build and verifies
  an actual deferred PermissionDenied response through Amber.
- Actual rebuilt CLI: `/tmp/amber-android-secrets-proof/amber`, SHA-256
  `e53a889add10f10bc05d5eef421cce340f2501f7d73728fffdd9a5b23788d94f`.

### Fresh generated consumer

The actual CLI generated a new hybrid application in
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.43EQkg`.
Explicit local development shard overrides were used; no generated source
was repaired by hand and this is not released-dependency proof.

Two shared Crystal examples, actual web state/validation/CSRF/escaping checks,
all **36 canonical JVM tests**, both native ABI builds, debug/unsigned release
APKs and App Bundle pass. Package inspection confirms both ABI JNI exports,
matching debug symbols and no unrequested INTERNET permission in either APK.
All **667 source entries** match before/after: **33 generated, 239 Amber and
395 AssetPipeline**. The runner's final source-freeze comparison passes.

**Eight Android tests pass in 32.188 seconds**: the generated counter plus two
SQLite and five Keystore platform tests. Process **5518** saves count **1** and
name **Android**; new process **5722** restores both and displays
`Restored from local storage.` The screenshot was inspected. The generated
counter exercises ordinary storage, not the public Secrets API itself; the
native fixture above supplies the actual Crystal secrets round-trip proof.

Artifact SHA-256 values:

- Debug APK: `39e1a7486f9e36615cab17672800f1a1da457305ba2af62b2aad816d23fef396`.
- Unsigned release APK: `cda613068584b4476dbe69ec1d6d48ea8caef998cade0e95fd0bc5dd4079598f`.
- App Bundle: `bebb06a4590076b3f91c5505446bad5cbae7267969f45bde11e654105622d82a`.

Kotlin reports a nullable-parent warning in the test-only namespace cleanup;
the validated, absolute test path has a parent and all cleanup tests pass.
The next test-maintenance pass should make that assertion explicit. Existing
Gradle future-version deprecation and debug-only ELF dynamic-table warnings
also remain; they are not test failures or missing debug-symbol evidence.

## Remaining goal work

App-private files, notifications and runtime permission flows remain separate
adapter work. Tier A renderer parity/reconciliation, metadata regeneration and
unified CLI workflow hardening, the AgentC reference application, ABI/API/device
matrix, CI, signing/provenance and public released-consumer proof remain open.
Key recovery/reset/rotation and independently reviewed security hardening are
not implied by this milestone. The full original goal is not complete.

Next bounded implementation: the existing Amber Files interface, using app-private
binary storage with bounded byte-array transport, atomic writes, path/symlink
rejection and cancellation/lifecycle proof. User-selected documents and external
storage belong to a separately authorized permission/document-picker API.

Continue using `CRYSTAL_CROSS_DEPS=/tmp/ap-android-dependency-proof.bTzNdZ/first`
for the verified native dependency cache. The background emulator is
`amber_secrets_20260905` on serial `emulator-5556`; the original visible
`crystal_test` was not shut down or cleared. Preserve unrelated dirty worktrees.
