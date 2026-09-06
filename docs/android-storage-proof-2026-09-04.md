# Android asynchronous storage proof — September 4, 2026

Status: verified local development milestone. The full Android goal remains
active. This follows the [lifecycle checkpoint](android-lifecycle-proof-2026-09-04.md)
and does not replace the remaining gates in the
[full implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md).

## Implemented

AssetPipeline owns a bounded asynchronous service transport and an Android
app-private key/value backend. Amber provides an explicit optional adapter at
`amber/native/android_storage`, implementing its existing Storage/Operation
interfaces. Ordinary `amber/native` still has no AssetPipeline/Android dependency.
The CLI-generated counter now uses that interface to save and restore a validated,
versioned snapshot. Neither Amber nor the CLI duplicates the Kotlin/JNI backend.

The backend uses platform SQLite on one serial JVM worker. Keys are bound SQL
parameters and values are blobs; synchronous=FULL is configured. Reads, writes,
deletes and database close run off the main looper. Completions enter Crystal
only on the main looper, through checked GC-thread entry. JNI carries byte arrays
with explicit lengths, preserving real UTF-8, supplementary characters and NUL.
It does not use modified UTF-8 for service payloads.

The queue bounds accepted work at 64 requests, keys at 512 UTF-8 bytes and values
at 1 MiB. Rejected submissions throw before returning an Operation and do not
also complete. Accepted requests complete asynchronously exactly once, including
typed failures/cancellation. Idempotent cancellation waits for work to finish
and **does not roll back an already committed write**. Pending records are removed
before invoking user callbacks. Duplicate/stale deliveries cannot remove or
repeat another operation. Activity recreation retains the store; explicit
terminal session close cancels accepted replies and closes the worker store.

Service completions no longer inherently refresh the entire UI. The app calls
`Application.invalidate` after changing visible state. The host defers this
refresh, and hidden screens pick up state when rendered again. Full View-tree
reconciliation and focus/composition preservation remain separate work.

The generated app gates controls on successful load, validates the complete
snapshot before mutating live state, refuses to overwrite invalid stored state,
and reports save success only after completion. A sequence number prevents stale
save results from replacing a later save/validation status. Typed input drafts
are not automatically persisted as accepted names.

This is ordinary app-private state, **not secret storage, Grant/ORM support,
general file access, or a networking implementation**. Backups follow the app's
explicit manifest policy. The optional adapter and cancellation contract are
documented in `amber-v2-beta-release/docs/android-storage.md`.

## Data preservation

The SQLite helper installs an explicit corruption handler that fails instead
of deleting/recreating a damaged database. An Android test writes a deliberately
damaged, uniquely named test database, attempts to open it, requires a real
SQLite exception, and checks that the original file remains byte-for-byte intact.
Corrupt UTF-8 values, missing tables, schema upgrades without a migration and
invalid application snapshots also fail rather than silently becoming valid data.
Only randomly named test databases are removed by the backend tests.

Android exposes the relevant [SQLiteOpenHelper](https://developer.android.com/reference/android/database/sqlite/SQLiteOpenHelper)
and [custom database error-handler](https://developer.android.com/reference/android/database/DefaultDatabaseErrorHandler)
contracts. Recovery/migration UX remains app-owned; this adapter does not claim
to repair damaged data. Never put server credentials or secrets in this store.

## Verified evidence

All device execution used `emulator-5554`, ARM64, API 35 and CheckJNI. Both
ARM64/x86_64 libraries were cross-built for native API 31 using Crystal 1.21.0,
NDK 28.2.13676358 and the existing independently reproduced dependency cache
`/tmp/ap-android-dependency-proof.bTzNdZ/first`. This turn revalidated those cache
entries; it did not repeat the independent dependency build or execute x86_64.

- **Native storage fixture:** 78 Crystal-side checks through the real Amber
  adapter and JNI. Covers read/write/delete/missing/empty semantics, Unicode/NUL,
  deferred completion, GC rooting, invalid input, repeated cancellation, 64
  simultaneous accepted reads, queue overflow, typed errors and zero pending
  callbacks. Latest run also includes both Android database tests:
  **OK (3 tests), 8.351 seconds**.
  Evidence: `/tmp/amber-android-storage-proof/storage-preservation-final`.
- **Shared JVM contracts:** eight HostSession plus eleven ServiceQueue tests
  pass. The service tests cover deferred host delivery, queued/late cancellation,
  duplicate and stale ID delivery, bounded capacity, closing/draining, typed
  error conversion, executor rejection, consumer exceptions and wrong-thread
  bookkeeping. Both reports are mandatory and retained in native proof lanes.
- **Renderer regression:** existing input/editor identity, callbacks, eight
  bootstrap-worker calls, five lifecycle/recreation cycles, reference cleanup,
  themes/system bars, densities and font scales still pass. That run included
  the first database backend test: **OK (4 tests), 31.252 seconds**.
  Evidence: `/tmp/amber-android-storage-proof/renderer-final`. The later corruption
  guard is covered by the storage fixture and final fresh consumer below.
- **Amber boundary:** 12 native examples, the native executable and ARM64
  isolation object, eight negative server imports, and 319 web/schema examples
  passed. Evidence: `/tmp/amber-android-storage-proof/boundary`.
- **CLI regression:** 156 native/configuration/generator examples passed.
  Shell-protocol fixtures explicitly reject missing/empty/failed host and service
  reports before testing crashed instrumentation, even when tools exit zero.

### Final fresh generated consumer

Evidence:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.4Sk137`.

The real rebuilt CLI created a new hybrid app. Explicit local development shard
overrides resolved Amber/AssetPipeline. There were no hand edits to generated
application sources. Two shared Crystal examples and the actual Amber HTTP
state/validation/CSRF/escaping checks passed. Gradle ran all nineteen canonical
JVM tests, built both native ABIs, debug APK, unsigned release APK, App Bundle and
native debug symbols. **OK (3 Android tests), 20.936 seconds** covers the generated
app plus both database tests. All **653 source entries** match before/after:
33 generated, 235 Amber and 385 AssetPipeline.

The application test uses the existing saved count as its baseline, increments
it, saves the name `Android`, waits for completed saves, checks validation,
background/foreground, recreation and Activity reopen, and verifies zero pending
services/native references after close. It records its process ID and expected
saved count. The runner then force-starts a **different process** and requires
the saved count/name and `Restored from local storage.` in the actual native UI.

Final instrumentation PID: **12339**. Relaunch PID: **12440**. Restored count:
**3**; restored name: **Android**. The screenshot was inspected and CounterApp
was left open in the emulator. Prior successful fresh runs restored count 1 and
then count 2, so the lane also exercised nonempty persisted state across APK
reinstallation. Tests mutate this demo's counter/name without clearing its data;
use a dedicated development application ID, not important user data.

The artifact inspector checks exact dynamic startup/render/lifecycle/storage
exports, the packaged ABI, absence of host/OpenSSL/XML dependencies, matching
debug-symbol build IDs and per-ABI dependency receipts. This is development-source
proof, not released-dependency or signed Play-distribution proof.

```text
CLI: /tmp/amber-android-storage-proof/amber-final
CLI SHA256                32a536984a8cdd953a3ae3c3e8a4f8ea480bd6458aab04518aeb3e3c1be9b463
debug APK SHA256          5c382169fdad51097ea0f914d2903bfab7aecd0ba8f66cc77f5c69b9024e55d6
unsigned release SHA256   411b98c1b8e20d9c3324e2208db92dcd01d6fbead722fc8f9a962d2bddf19c36
App Bundle SHA256         ab6cd26457fcf3eda782c58d0c7cc2a8dcde6ac78cbc9657941d1914189326fd
```

Temporary evidence can be removed by the operating system. The final CLI binary
embeds the current templates; older binaries under this proof directory are not
equivalent. Do not manually relabel old flat dependency caches as verified v2
cache entries if the temporary dependency directory is gone.

## Verification improvements found during this work

The generic native builder sometimes incorrectly reported that `JNI_OnLoad`
was missing. The actual dynamic symbol was present and the independent packaged
artifact check passed. The old `nm | grep -q` pipeline returned 74, 74, 0, 74
over four checks of the same library: early consumer exit broke the producer
under pipefail. The check now consumes the full dynamic-symbol stream and tests
the exact symbol. Both final ABI builds report the symbol correctly.

A stale-delivery unit test also tightened the service queue: it checks an entry's
identity before removing it, so a duplicate old delivery cannot discard a newer
operation using the same ID. Production Crystal IDs are monotonic, but the queue
now protects this contract independently. Completion exceptions remove their
records before propagating, and service error messages do not include payloads.

## Reproduce

From the Amber CLI checkout:

```sh
crystal build src/amber_cli.cr -o /tmp/amber-android-storage
CRYSTAL_CROSS_DEPS=/tmp/ap-android-dependency-proof.bTzNdZ/first \
  bash scripts/test_generated_android.sh emulator-5554 \
  /tmp/amber-android-storage --development \
  /Users/crimsonknight/open_source_coding_projects/amber-v2-beta-release \
  /Users/crimsonknight/open_source_coding_projects/asset_pipeline
```

From Amber, set `AMBER_ANDROID_FIXTURE=storage` when running
`scripts/test_native_android_app.sh`; the default remains the original in-memory
hybrid counter fixture. AssetPipeline's `scripts/run_android_smoke.sh` selects
its renderer fixture and now includes the canonical database instrumentation.

## Remaining goal work

Next implement Android-hosted HTTP/TLS and the remaining platform adapters behind
Amber's existing interfaces, including cancellation, permissions and safe secret
storage. Do not generalize this key/value implementation into those claims.

Still required: safe CLI target/metadata regeneration and unified commands;
remaining Tier A constraints/layout, accessibility, navigation, Unicode/IME,
asset handling and screen restoration; AgentC's reference screens and shared
operation; existing-platform/CI coverage; API-level and x86_64 runtime matrix;
physical-phone proof; release/signing/current store-policy review; independently
verified public releases and a clean released-consumer lane. The doctor still
lists only the emulator. No completion gate is waived by this checkpoint.
