# Native alert checkpoint — September 5, 2026

Status: **verified bounded native-alert progress**. The full Android goal remains
active. This checkpoint does not complete sheets, Tier A renderer support,
physical-device testing, CI, or public releases.

## Implemented behavior

`UI::Alert` and `UI::ConfirmationDialog` now use real, Activity-owned Material
dialog windows and native action buttons. Their old inline cards have been
removed. The sample's Dialogs study now opens one actual dialog at a time; its
previous simultaneous inline alert/confirmation composition is no longer valid.
See the [bounded API/lifecycle contract](android-dialogs.md).

Native tests verify separate window tokens, modal/focusable/dim flags, actual
48 dp minimum button height, Unicode title and accessibility pane metadata,
action automation IDs, focused-action recreation, stale listener retirement,
background closure/reopening, confirm/cancel/default OK, Back/outside dismissal,
programmatic closure without fabricated cancellation, and final zero native
references/callbacks/services. Both light and dark appearances are exercised.

The outside-tap test measures a currently visible underlying control outside
the actual window bounds. It verifies that the tap cancels the alert without
activating the control. It does not assume a coordinate survives scrolling.

Malformed descriptors do not expose their packet or parser cause. Simultaneous
declarations fail without opening a window. Metadata-only screen hosts may
validate saved state without owning a surface; a second host attempting to
render fails before touching the first host's live dialog. The low-level public
render path also retires its previous window before replacing the Crystal root.

## Regression evidence

Evidence root: `/tmp/ap-native-dialog-proof.mUx0Cb`.

- `first-instrumentation.txt`: failed outside-tap coordinate assertion. The
  screenshot and lifecycle/action checks showed a real window; the stale
  coordinate was inside it. The test now measures current geometry.
- `second-instrumentation.txt`: focused light/dark test passes, 92.188 seconds.
- `native-final`: intermediate 35-test regression, one failed saved-state test.
  Eager dialog registration rejected its metadata-only host. Registration now
  occurs at first render, with a new explicit second-renderer rejection test.
  This intermediate source ledger predates the final ownership changes.
- `native-v2`: **84 JVM and 36 Android tests pass**, with the native suite taking
  **330.466 seconds**. All six isolated Crystal failure cases (600 partial-render
  cleanup checks), the existing 100 malformed-semantics partial renders, and
  eight Java failure cases (400 partial renders) also pass. The Java lane now
  starts with a live dialog, preserves the original Throwable, rejects terminal
  reuse and verifies that the window and native resources are released. Its
  test takes 14.465 seconds. Ordinary post-failure relaunch and CheckJNI pass.
- `shared-ui-specs.txt`: **1,442 Crystal examples**, zero failures/errors,
  **66 existing pending**. Pending tests are not implemented support.
- `cli-specs-final.txt`: **181 examples**, zero failures/errors/pending. The
  intermediate shell-protocol fixture lacked the new mandatory dialog report;
  its missing/empty/failed-report cases now include `DialogPolicyTest`.
- `native-source-final-verification.txt`: all **496 native input ledger entries**
  match the final build sources. Crystal formatting and repository diff checks
  pass. Both ABI libraries/package entries build; runtime evidence is API 35
  ARM64 on task-owned `emulator-5556`, not x86_64 execution or a device matrix.

Final clean native artifacts:

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `e6e1bc294f997ddd7059ef0f92ebbf11e40875030456aa2276e1150658e2de24` |
| Test APK | `fdf88c73b7541127d224a9d798dd9d046cdd9b5dfd36d2da488f299c59b9dfc6` |
| Release App Bundle | `b9ccff0c555c4bf6ed1a44562c54890298d51830ed0b51498012e680911d8e2f` |
| Native source ledger | `f9ff4263fa9e4bf9dc4b44640116cc21885f0c8b99dfa611291179cdd836c57f` |

Final native screenshots are under `final-screenshots`; alert-dark and
confirmation-light are visually inspected, along with the earlier alert-light
and confirmation-dark captures. Titles, native actions and themed modal surfaces
fit the tested phone viewport. Earlier captures remain under `first-screenshots`
and `second-screenshots`. This is not a large-font/tablet/RTL screenshot matrix.

## AgentC template build regression

`agentc-current/project` is a fresh native-only development projection of the
actual AgentC checkout, not a rewritten counter app. Its **41 selected inputs**
remain byte-identical in the original and projection. Installed project shards,
web configuration, account database and installed emulator account app were not
changed. Current Amber and AssetPipeline are explicit local dependencies.

`agentc-build.txt` reports **84 JVM tests** and successful debug/release APK and
App Bundle builds in **46 seconds** (100 tasks). `agentc-artifacts` proves both
ABIs, matching native debug symbols, required exports including
`android_dialog_configure`, explicit permissions and absence of synthetic
password/local test trust in release artifacts. The debug-symbol-only ELF file's
missing-dynamic-table warning is not a package failure. This pass uses the safe
default unconfigured account origin; it does **not** rerun the prior live account
UI/API proof or claim that AgentC's own screens now use dialogs.

| AgentC artifact | SHA-256 |
| --- | --- |
| Debug APK | `6f327b7bf7f2c4281eb05a175d9d50f71ae8d9d86d2a37d7f62f87a0e721af1b` |
| Unsigned release APK | `73976992848af023bf45837a1f9038637bcaa0373e1eb17b46f73e7db134d948` |
| Release App Bundle | `6424dac8c9201479fd26774a6b1e2a2e579911af09b92a80dd102ddf9e60cf85` |

## Fresh CLI consumer

The rebuilt actual CLI is `/tmp/ap-native-dialog-proof.mUx0Cb/amber`, SHA-256
`8d262642215666a217d11ef2fe786b710b46a6d2aaad527188b2af46992eff6b`.
The fresh consumer evidence is
`/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.mVGS6p`,
also tracked by `generated-consumer-driver.txt`. It is an untouched actual-CLI
hybrid app with explicit local-development dependencies, not released-consumer
proof or a claim that the counter UI itself exercises alerts.

- Two shared examples and real web state/validation/CSRF/escaping checks pass.
- **84 JVM tests**, **13 Android tests in 36.672 seconds**, and a separate
  exact-Unicode restoration test in **4.96 seconds** pass. The build takes
  34 seconds, 126 tasks.
- All **724 source entries** match before/after: 36 generated, 242 Amber and
  446 AssetPipeline. Both ABI/package/export/debug-symbol gates pass.
- Process **5710** saves count **22** and `Android 雪 😀 é` (decomposed accent);
  process **5853** restores those exact values. The final cold process **5906**
  remains the native counter on emulator-5556. Its screenshot is visually
  inspected: image, heading, native editor, buttons, restored state and navigation
  fit without overlapping.

| Generated artifact | SHA-256 |
| --- | --- |
| Debug APK | `0769ac6d4a6d17151beaa29aea5a688ddab7c183530da27d2aa6412f3efe955d` |
| Unsigned release APK | `c566d55a8ef29845b0a7e1cb972173e1b520b0f7c2dfba8f91dd03828cbbe18c` |
| Release App Bundle | `f6df77b0aa99c31c81628f0b58269ae0789ca114f12115f6e4990b0903988066` |

## Remaining work

Implement the real canonical Sheet/custom-content path, its editor/keyboard and
detent behavior, interactive-dismiss-disabled policy, and shared exactly-once
programmatic dismissal. `UI::Sheet` is still the inline preview. Full TalkBack
exploration/focus retention, RTL/large-font/window transitions, richer modal
actions and styling, remaining core controls/layout, phone/tablet/OS/runtime ABI
matrix, CI and release-consumer work remain open. The physical phone is still
absent from ADB; the existing emulator-5554 was preserved.
