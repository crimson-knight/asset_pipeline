# Android runtime support

This directory owns the reusable Kotlin half of AssetPipeline's native Android
runtime. It is not a complete application or a released Android library module.
The showcase and generated hosts should compile these same sources rather than
maintain separate listener/JNI implementations.

The runtime contract consists of:

- `src/ui/android/application.cr`: the public Crystal application entrypoint,
  embedded-runtime probe, retained root ownership, lifecycle registration and
  exported render/teardown/lifecycle functions;
- `src/ui/native/android_host_jni.c`: JNI startup, checked GC thread entry,
  callbacks and debug counters;
- `src/ui/native/android_bridge.c` and `jni_collection_bridge.c`: native Android
  View construction, collections, reference ownership and thread-local JNI use;
- `scripts/crystal_init.cr` and `crystal_gc_threads.c`: the pinned Crystal/Boehm
  embedding contract;
- `android/runtime/src/main/java`: Kotlin library loading, single-surface session
  ownership and listener helpers;
- `android/runtime/src/test/java`: shared host-session contract tests, compiled
  by the showcase and generated applications.
- `src/ui/android/services.cr` and `CrystalServices`/`ServiceQueue`/`PrivateStorage`:
  bounded asynchronous key/value requests, platform SQLite storage and main-looper
  completion; no Crystal worker-thread callbacks or modified-UTF-8 payloads.
- `HttpWire`/`PlatformHttp`: bounded binary HTTP transport, four independent
  networking workers, platform TLS/trust, cancellation, explicit redirects and
  checked response limits. Hosts apply `android/runtime/dependencies.gradle.kts`
  to share pinned runtime/test dependencies.
- `PrivateSecrets`/`SealedSecrets`/`SecretVaultCodec`: a separate no-backup
  AES-256-GCM vault with Android Keystore keys, bounded identifiers/values,
  serial off-main work and fail-closed corruption/key-loss handling.
- `PrivateFiles`/`FilePolicy` and `src/ui/native/android_private_files.c`:
  app-private binary files, directory-descriptor-relative path handling,
  atomic replacement and a separate serial file worker. The C backend runs on
  that JVM worker and never enters Crystal; hosts must compile this C source too.
- `NotificationWire`/`PermissionRequests`/`PlatformNotifications`: bounded local
  notifications, an asynchronous lifecycle-owned permission dialog, explicit
  channel catalogs and a dedicated notification manager worker. This is not
  push messaging, scheduling or background execution. See Amber's
  [optional API contract](../../../amber-v2-beta-release/docs/android-notifications.md).
- `ImageAssets` and `scripts/compile_android_assets.cr`: explicit application
  image catalogs compiled into native resources, strict UTF-8 lookup, per-view
  tint state and bounded local bitmap decoding. Hosts include the compiler's
  generated resource directory; see the [image contract](../../docs/android-images.md).
- `unicode_text_codec.h`/`android_text_bridge.h`: length-delimited standard UTF-8
  and JNI UTF-16 conversion for UI text, routes, callbacks and collection strings.
  NUL, supplementary characters and combining sequences are preserved; malformed
  bytes/unpaired surrogates are replaced with U+FFFD, not treated as modified UTF-8.
- `EditorActions`/`CrystalEditorActionListener`: explicit TextField submission,
  with native composition preserved until commit and deferred host refresh.
  TextArea/TextEditor share a plain multiline implementation with read-only mode.
- `NavigationState`/`NativeNavigation`: retained Crystal screen stacks, scoped
  native links, Material toolbar Up and lifecycle-aware Android system Back.
  Hosts install `NativeNavigation` after attaching and synchronize it after
  every mount. See the [bounded navigation contract](../../docs/android-navigation.md).
- `CallbackBoundary`/checked callback exports and `HostSession.nativeCall`:
  contained Crystal UI errors, explicit failure statuses and terminal failed
  sessions. The renderer explicitly releases partially constructed trees.
  Hosts must use matching canonical Kotlin/C sources; see the
  [failure contract and remaining JNI limits](../../docs/android-failure-boundaries.md).
- `android_jni_guard.h`/`JavaBoundary`: checked View and collection operations
  preserve pending Java exceptions, stop further non-cleanup JNI calls and
  unwind Crystal ownership before returning the original Throwable to Android.
  Optional lookups clear only their expected missing-member/class exception.
  Application diagnostics now report exception types without messages or traces.
- `LayoutPolicy`/`NativeLayout`: density-aware min/max bounds, native stack
  alignment/RTL, flexible spacers and one-/two-axis scroll containers. Bounds
  preserve the actual widget inside an owned wrapper when needed; see the
  [layout contract and remaining limits](../../docs/android-layout.md).
- `NativeScreenHost`/`NativeViewState`/`ViewStatePolicy`: Activity-owned full-tree
  replacement, composition-aware asynchronous refresh and bounded keyed
  focus/selection/scroll restoration. Hosts include `src/main/res`, delegate
  their saved-state lifecycle and never independently save Crystal-owned editor
  text. This is not in-place reconciliation; see the
  [view-state contract and remaining limits](../../docs/android-view-state.md).
- `NativeSemantics`/`SemanticsPolicy`: separate spoken labels and automation
  identifiers, preserved native/Material delegates, bounded owned custom actions,
  post-mount focus requests and native keyboard shortcuts. Hosts forward both
  Activity key dispatch methods. See the [bounded semantics contract](../../docs/android-semantics.md);
  this is not full TalkBack, compound-control or Tier A accessibility parity.
- `NativeCompoundFocus`/`CompoundFocusPolicy`: exact focused radio/segmented
  option restoration with a bounded ordinal/catalog signature. Changed catalogs
  do not reuse stale ordinals, option captions are not saved, and group-wide
  focus/disabled settings reach the actual native options. Explicit focus also
  requests visibility after saved nested scroll offsets have been restored.

The Kotlin/JNI package remains `dev.assetpipeline.androidhost` for binary
compatibility with the proven renderer helper names. This is a runtime package,
not the consumer application's application ID. Consumer Activities may use their
own package and import `CrystalBridge`. A generated app supplies its library
name to `CrystalBridge.initialize(name)`; the existing showcase default remains
`android_material_host`. Loading a second different library through the same
runtime instance is rejected.

## Crystal application entrypoint

```crystal
require "asset_pipeline/ui/android/application"

UI::Android::Application.configure do |route|
  UI::Label.new("Hello from Crystal")
end
```

The builder runs for each mount/refresh and can read a retained application
store. `configure` is called once during Crystal startup. Application-domain
lifecycle and platform services are separate from the renderer's ownership;
Amber native supplies contracts for those layers.

An app may register `Application.on_lifecycle` once during startup. Its
`LifecycleEvent` values are `Foreground = 1`, `Background = 2`, and `Stop = 3`.
The callback returns `Nil`; exceptions are logged and returned to Kotlin as
failure, never unwound through JNI. An Amber app maps these to its retained
`Lifecycle#activate`, `#background`, and `#stop` respectively. The renderer has
no Amber dependency, and apps without a handler still use the same host contract.

## Host responsibilities and current limits

- Initialize on the main looper, then `attachHost(activity)` from `onCreate`.
  A ComponentActivity must attach before STARTED so the notification result
  registry can be bound to its lifecycle. Prompting itself requires RESUMED;
  the existing foreground/started session state is not sufficient.
  The bridge enforces main-looper calls for application/UI entrypoints and debug
  reads. Only the C once-gate test entrypoint may be exercised by JVM workers.
- Call `foregroundHost(activity)` from `onStart` before rendering; call
  `backgroundHost(activity)` from `onStop`, cancelling pending visual refreshes.
  Foreground means started/visible, not necessarily resumed/input-focused.
- Include the canonical Kotlin source directory in the app's main source set.
  Compile the canonical host, View, collection and private-file C bridge files plus runtime initialization through
  `scripts/build_android.sh` for each required ABI.
- Mount the returned View and retain application state outside its transient
  tree. Remove mounted Views, then `detachHost(activity)` from `onDestroy`.
  Detaching backgrounds a still-visible session, clears its observer, releases
  native references and drops the owner even after a lifecycle failure.
  `teardown()` is a view-only primitive, not a lifecycle/session shutdown.
- Only one retained tree and callback observer per process are currently
  supported. A second owner is explicitly rejected; simultaneous Activity and
  multi-window surface ownership remain unsupported.
- Recreation/reopening in the same process keeps the session and state. A
  configuration change may emit background/foreground but not a new start.
  `closeSession()` is an explicit terminal operation allowed only after detaching;
  it is not an Activity-destruction hook. Failed or closed sessions reject new
  surfaces. Android process termination does not guarantee a final callback.
- The basic host refreshes the whole tree after non-text actions. Text callbacks
  update state without replacing the focused editor. Unicode round trips,
  native composition, code-point deletion, explicit submit and multiline/read-only
  basics have device contracts. Full reconciliation, selection/focus restoration
  across replacement, rich editing and general screen/process restoration remain
  separate work.
  Saved key/value data now survives process restart; in-memory View state does not.
- Keep the debug counters and CheckJNI enabled in test lanes. A successful
  native link does not prove runtime safety.

`samples/cross_platform/android_host/android_host_jni.c` is now a compatibility
include of the canonical C file. The showcase registers only its screen factory;
it no longer owns a separate runtime probe or retained native root.

## Storage and asynchronous state changes

Pass `applicationContext` to `CrystalBridge.initialize(name, applicationContext)`
before application lifecycle activation. The service singleton retains only the
application context and creates/open its database on a serial JVM worker when
first needed. No storage/network work runs on the Android UI thread. The default
store uses app-private SQLite; it is neither protected secret storage nor an ORM.

`UI::Android::Services.storage(operation, key, value)` returns a cancellation
token. Operation codes are read=1, write=2 and delete=3. Keys are nonempty UTF-8,
at most 512 bytes; values are UTF-8, at most 1 MiB. Byte-array JNI transport
preserves supplementary characters and embedded NUL. This does not fix the
renderer/text-input bridge's separate Unicode/composition limitations.

There are at most 64 accepted requests. Capacity/closed/uninitialized transport
and oversized submissions fail synchronously before an Operation is returned;
accepted input/IO failures complete asynchronously with a typed status. Every
accepted request completes once on the main looper, even when cancelled.
Cancellation is idempotent, waits until per-request work has ended, and is not
rollback: a write already committed may remain despite a Cancelled result.
The shared executor/database live across Activity recreation, and terminal
`closeSession` cancels accepted requests, drains their replies and closes the
database on the worker. Android process death can preempt this cleanup.

Service completions do not automatically replace the View tree. After changing
application state, call `UI::Android::Application.invalidate` to request the
host's deferred refresh. Hidden screens pick up new state when rendered again.
The current host still uses whole-tree refreshes; full reconciliation is pending.

Compile `android/runtime/src/test/java` into host JVM tests and
`android/runtime/src/androidTest/java` into instrumentation. Both native runners
require nonempty successful HostSession, ServiceQueue, HttpWire, PlatformHttp, SecretVault and FilePolicy
XML reports. The shared
platform test exercises SQLite independently; Amber's native-storage fixture
exercises the real Crystal adapter and JNI round-trip.

The optional Amber HTTP adapter is documented in
`amber-v2-beta-release/docs/android-http.md`. Hosts must explicitly declare network
permission. Service wire status Network=7 extends existing statuses 0..6.
`android_host_http_submit(id, bytes, size)` passes an at-most-1-MiB packet to the
canonical host; response bodies are at most 900 KiB. HTTP cancellation uses the
queue's one-shot cancellation hook to abort active calls; storage cancellation
continues to wait for its serial work without pretending to roll it back.

The optional Amber secrets adapter is documented in
`amber-v2-beta-release/docs/android-secrets.md`. `Services.secrets` uses the
same read/write/delete operation codes but a separate encrypted store and worker.
Identifiers are limited to 512 UTF-8 bytes, values to 64 KiB, and the complete
vault to 128 entries/1,000,000 plaintext bytes. Missing keys never cause a vault
reset. Hardware backing, biometric gating, rollback protection and plaintext
memory zeroization are not promised. Canonical SecretsPlatformTest cases execute
real Android Keystore behavior independently of the native adapter fixture.

The optional Amber file adapter is documented in
`amber-v2-beta-release/docs/android-files.md`. `Services.files` uses read/write/
delete codes and owned binary payloads up to 1 MiB. Relative UTF-8 paths are
bounded to 1,024 bytes/32 components, reject traversal and reserve `.ap-` names.
The native backend opens components without following symlinks, requires regular
single-link files and closes all descriptors before reply. Canonical FilesPlatformTest
tests binary durability, unsafe paths/types, temporary-file recovery, a directory
replacement race and descriptor cleanup. `scripts/tests/android_files_backend.sh`
also checks the exact POSIX backend on the host, including hard links that the
Android app domain may prohibit constructing. Neither is a streaming/media API.
