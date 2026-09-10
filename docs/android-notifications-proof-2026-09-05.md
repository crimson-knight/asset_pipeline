# Android local-notification checkpoint — September 5, 2026

Status: verified development implementation of the bounded local Notifications
interface. The full Android goal remains active. Push, scheduling, foreground
services, physical-device support and complete Tier A rendering are not proved
by this milestone.

## Implementation and policy

Amber's optional `amber/native/android_notifications` adapter implements
`request_permission`, `post` and `cancel`. AssetPipeline owns the canonical
versioned binary JNI transport, `NotificationWire`, `PermissionRequests` and
`PlatformNotifications`. Generated and showcase hosts compile these same sources.
See the [API contract](../../amber-v2-beta-release/docs/android-notifications.md).

- Explicit v2 native-manifest opt-in and a maximum 32-channel resource catalog;
  no permission-on-startup and no arbitrary channel creation. Target SDK must be
  at least 33 to retain application-controlled permission timing. The ordinary
  target is still 35/minimum 31, not a future store-policy promise.
- Default apps remove transitive POST_NOTIFICATIONS. Generated debug/release
  artifact inspection checks the selected permission declaration. A permission
  without the adapter's catalog does not enable its operations.
- Lifecycle-owned ActivityResultRegistry binding before STARTED; a needed prompt
  requires RESUMED. Configuration recreation preserves an in-flight request;
  non-configuration finish abandons it and rejects stale results. No callbacks
  or JNI references cross process death.
- One OS dialog can serve several callers. Cancellation releases a caller but
  cannot dismiss the OS dialog or revoke an app-wide grant. Accepted completions
  are deferred to main, exactly once, within the shared 64-request Crystal limit.
  Manager work has its own serial worker; terminal close cancels and drains it.
- New channels are silent, without vibration/badges. Existing channel settings
  are not reset. App/channel/group blocking is checked. Success means accepted
  by NotificationManager, not guaranteed presentation or reading.
- Nonnegative Int32 IDs, tag `asset_pipeline.local.v1`, immutable launcher intent,
  private lock-screen visibility, same-ID update and idempotent cancellation.
- Strict UTF-8, no NUL, title/body at most 1,024 bytes each, ASCII channel ID at
  most 128 bytes, total packet at most 2,194 bytes. The title must be nonblank.
  Bounds reject oversize rather than relying on Android's silent text trimming.

The design uses Android's documented [permission behavior](https://developer.android.com/develop/ui/compose/notifications/notification-permission),
[Activity Result lifecycle](https://developer.android.com/training/basics/intents/result),
and [channel settings](https://developer.android.com/develop/ui/compose/notifications/channels).

## Final native proof

`/tmp/amber-android-notifications-proof/native-bounded` is the final bounded-text
implementation on the isolated API 35 arm64 emulator `amber_secrets_20260905`,
serial `emulator-5556`. The original visible emulator was not shut down or cleared.

- **54 canonical JVM tests:** HostSession 8, ServiceQueue 12, HttpWire 4,
  PlatformHttp 7, SecretVault 5, FilePolicy 4, NotificationWire 3 and
  PermissionRequests 11. All have zero failures, errors and skipped tests.
- **13 Android instrumentation tests, 36.912 seconds:** the native Amber
  notification fixture and the existing two SQLite, five Keystore and five
  private-file platform tests. CheckJNI and app runtime diagnostics are clean.
- The real OS dialog is dismissed, denied, then granted. A direct Activity
  recreation is observed before granting the outstanding request. A batch of
  64 native requests cancels 32, coalesces the remaining 32, rejects overflow
  and drains both pending counters to zero. An already-granted request opens no
  dialog; a needed request without a host reports Unavailable.
- Actual post/update/cancel are read back from NotificationManager. Unicode
  title `Updated 雪 😀` and the body appear in the real system notification shade;
  `notification-shade.png` is retained and inspected. The maximum accepted
  1,024-byte ASCII title and body survive intact in title, text and big-text extras.
- A pre-existing blocked channel remains blocked, an unknown channel is not
  created, and only the test-owned ID and two contract channels are cleaned up.
- Terminal close cancels 32 additional permission operations in the same
  main-loop turn. Pending service, callback and JNI-reference counters reach zero.
- A separate non-instrumentation process, PID **9263**, relaunches the native
  preview successfully. Source hashes, UI XML, screenshot and logs are retained.
- Debug APK SHA-256:
  `889c843422ab4a64e2dc77d9b9dc13c424282df4fbc3e5799e59e4ee2fc8fcb9`.
  Release App Bundle SHA-256:
  `0ae0fc6fa7ec1290a7067b92f0641f48e6d3f80cd2301b353c568204e0ace284`.
  Both arm64 and x86_64 libraries are packaged; runtime proof is arm64 only.
  Shared sample build outputs are subsequently overwritten by regression lanes;
  the retained logs/hashes identify these particular outputs.

`/tmp/amber-android-notifications-proof/denied` separately removes permission
and catalog. **13 tests pass in 6.737 seconds**. All three real public Amber
operations report deferred PermissionDenied, no OS dialog opens, and the
separate-process relaunch displays `Notifications require explicit app opt-in`.
The debug fixture's notification catalog/icon do not appear in the release bundle.

## Failed attempts and corrections

Do not treat `native-first`, `native-second` or `native-final` as passes.

- `native-first`: the first touch occurred while the permission dialog was still
  transitioning; the screenshot showed it remained open. The test now requires
  the selected dialog to disappear and re-resolves a still-visible answer.
- `native-second`: ActivityScenario's recreate helper first required RESUMED,
  impossible while the OS dialog held the app paused. The test now invokes the
  actual Activity recreation API and observes a replacement before answering.
- `native-third` passed 13 tests in 26.995 seconds with the earlier body bound.
  `native-final` added shade inspection but clicked before input focus returned;
  the test now waits for both shade dismissal and app window focus.
- `native-verified` passed 13 tests in 38.767 seconds. Review then identified
  Android's platform string-trimming bound; `native-bounded` tightens body size
  from the earlier draft and verifies the entire maximum payload. The earlier
  9,362-byte packet/8,192-byte body draft is not the final API contract.

The early test timeouts closed a still-pending host; native fixture assertions
then rejected the resulting Unavailable cleanup reply and crashed those test
processes. These are retained failed test attempts, not hidden successful runs.

## Other validation and remaining proof

The final notification wire/native facade passes **19 Amber native examples**.
The boundary runner also verifies the isolated native executable (42), a real
ARM64 object, eight negative server-import guards and **319 web/schema tests**
in `/tmp/amber-android-notifications-proof/boundary`. The final lower wire bound
was rerun in all 19 native examples. **159 CLI generator/configuration examples**
pass, including the new capability/escaped resource tests and mandatory missing,
empty or failed notification/permission report gates.

Remaining branches include API 31–32 notification settings, channel-group/user
settings changes, denial-after-repeated-prompts behavior, process-death with an
open OS dialog, physical-phone and x86_64 runtime tests. Push, scheduled delivery,
custom actions and foreground/background execution require separate contracts.
These do not block continued renderer, CLI, AgentC template and release work;
they remain explicit gates in the overall Android plan.

The shared JNI packet helper also serves HTTP. The current-source regression in
`/tmp/amber-android-notifications-proof/http-regression` passes **13 tests in
12.588 seconds**, including real trusted/wrong-host/untrusted TLS, blocked
cleartext, payload limits, cancellation, receipt-ledger checks and release CA
exclusion. Its temporary servers and emulator port mappings are removed.
`http-denied` passes **13 tests in 8.042 seconds**, proving the missing-INTERNET
path and replacing the temporary TLS APK with the ordinary opted-out host.

## Fresh CLI-generated consumer

`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.JVVekO`
was generated by the newly compiled, actual CLI executable
`/tmp/amber-android-notifications-proof/amber`, SHA-256
`4d772f08b7707310fbe2fac958175e6a9a19afe1383f1905f987e1ebe6858e14`.
This is explicitly the development lane with local Amber/AssetPipeline overrides,
not a published/released-consumer result. No generated project was repaired by hand.

- Real Shards resolution, two shared examples and actual web state/validation,
  CSRF and escaping checks pass.
- All **54 JVM tests** and **13 Android tests (22.762 seconds)** pass. The new
  permission/wire tests are mandatory; existing generated Counter, SQLite,
  Keystore and private-file device contracts remain intact.
- Both arm64/x86_64 debug and unsigned release APKs plus App Bundle contain the
  required runtime exports, including `android_host_notifications_submit`, and
  matching native debug symbols. Both APK variants exclude unrequested INTERNET
  and POST_NOTIFICATIONS. Release artifacts are not production-signed.
- All **682 source entries** are identical before/after: 33 generated, 242 Amber
  and 407 AssetPipeline. The runner's final source-freeze result is PASS.
- Instrumentation PID **10135** saves count **3** / name **Android**; new process
  **10253** restores that state. The relaunch screenshot was inspected, and the
  app remains running on `emulator-5556`. The same package's earlier saved state
  was preserved; fresh generation does not mean a cleared device/database.
- Debug APK: `d862ffffb67f8475e20673d527472e000ecf0bd94bfd3e1910449ac23e2ef985`.
  Unsigned release APK: `70541c8ecd13cb318ee55dc4384b3895fc5547e63424a769002a20199d577a40`.
  App Bundle: `31c791f978fc9669dbf02b997a9ee9e5554fa04cb6baf10627d73f97d82571b2`.

The generated Counter uses ordinary Storage, not Notifications. Its passing
result proves current canonical-host integration and opt-out packaging; the
dedicated Amber fixture above proves actual notification API behavior. An
opted-in generated consumer with application-authored channels remains a separate
generation/resource proof to add, alongside the broader renderer/asset matrix.

ADB currently lists only the original and isolated arm64 emulators. The physical
phone is not visible. No HTTP reverse mappings remain, and the ordinary reference
host APK has replaced the ephemeral CA/notification debug fixture. No unrelated
worktree edits were reverted, and no public release or store submission was made.
