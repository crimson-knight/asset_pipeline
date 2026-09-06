# Native semantics checkpoint — September 5, 2026

Status: **verified native and fresh generated-consumer development progress**.
This advances the existing full Android goal; it does not complete Tier A support,
the AgentC reference template, physical-device validation or public releases.
The [bounded contract](android-semantics.md) distinguishes implemented native
behavior from remaining accessibility and keyboard coverage.

## Implementation

Shared View metadata now crosses a length-delimited checked JNI export into a
bounded canonical Kotlin policy. Automation identifiers are separate from spoken
labels. The runtime decorates the existing Android/Material delegate, retaining
native editor text, errors, built-in actions, checked state and slider range data.
It targets real text editors and menu Spinners inside their shared-view wrappers.

Custom actions have owned callback tokens, resource IDs and live-view/foreground
guards. Pending tokens are accounted for before metadata setup and adopted by
the owned native view before bounds wrapping. Failed construction unregisters
both pending and already-adopted callbacks without relying on GC.

Explicit focus opt-out is native and takes precedence. Eligible focus requests
run after mounting, ahead of saved-state focus. Non-editor focus participates in
the existing conservative restoration policy. Modified keyboard shortcuts use
the real click handler; plain keys only activate a focused non-editor owner.
Repeat/release do not produce additional clicks. Native `tab_index` remains
advisory, not a new numeric traversal policy.

The actual CLI template forwards the canonical key dispatch, labels its image
and heading, assigns separate editor metadata, and gives Increment a Control-I
shortcut. Its mandatory report gates include `SemanticsPolicyTest`; package
inspection requires `android_view_semantics` in both ABIs. Existing test-ID
matchers migrate to `NativeTestIds` while genuine spoken toolbar labels remain.

## Verified focused proof

Evidence: `/tmp/amber-android-semantics-proof/focused`.

- Six new Crystal metadata/fixture examples and **76 canonical JVM tests** pass.
- **17 Android tests in 42.691 seconds** pass on the isolated API 35 ARM64 emulator
  (`emulator-5556`): five new semantics tests plus 12 platform-storage/file/secret
  contracts. Both ARM64 and x86_64 libraries build; this is not x86 runtime proof.
- The actual accessibility service node invokes the custom action and observes
  the changed Crystal value. Detached old, hidden, disabled and background views
  cannot dispatch the action.
- Native nodes retain editable text/Material errors/editing actions, checkbox and
  toggle state, slider range/actions, radio selection and menu Spinner selection.
  Identifiers remain in node extras, not spoken content descriptions.
- Real injected Tab input skips the explicitly non-focusable button. Explicit
  focus skips ineligible controls; non-editor focus survives background and
  Activity recreation. Modified/plain shortcut tests retain normal editor typing.
- **100 malformed-semantics partial renders** return the original checked Java
  error with no payload/cause exposure, return native ownership counts to the
  live-tree baseline immediately and leave the isolated probe session usable.
- CheckJNI, the embedded-runtime probe and fresh normal relaunch pass. The focused
  relaunch PID is 28358. Continuous app-UID capture retains startup diagnostics.

Additional host regression: **1,435 Crystal examples, zero failures/errors,
66 pending**, recorded in `/tmp/amber-android-semantics-proof/shared-ui-spec.txt`.
Pending examples are not counted as implemented Android coverage. CLI regression:
**159 examples**, zero failures/errors/pending, in the adjacent `cli-spec.txt`.

## Final native and fresh-consumer gate

Final native evidence: `/tmp/amber-android-semantics-proof/native-final`.
The clean lane passes **76 JVM tests and 28 Android tests in 159.993 seconds**,
including the five semantics tests and their 100 malformed-construction probes.
The existing six Crystal failure cases add **600 partial renders** and the eight
Java cases add **400 partial renders**, now also unwinding custom actions on
already-adopted bounded buttons/editors. Original Throwable preservation, terminal
session rejection, zero final ownership and a fresh normal CheckJNI launch pass.
The native source ledger verifies **483 entries with zero mismatches**.
The six Crystal failure processes are 28948, 29007, 29061, 29117, 29174 and 29230.
The Java failure process is 29346 (9.861 seconds); the subsequent normal native
application mounts in process 29400.

Native package SHA-256 values from the final clean lane:

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `13122831c9c8c7fd11377d673d1e2d72b795a33ff818db26e7b75c529af09f3e` |
| Test APK | `0af29ff3828ee0a92aa3051bbfad2708eeabefda77bd02f3dd7e50846827f0a8` |
| Release App Bundle | `369c5d199ac10937925940e2f0a2c7ff5ae238213e840bd68f66dce942b2920e` |
| Source ledger | `31565de6af366650e55b4a83d044c0e80f2f2713adb542aafb9a44815512e1f0` |

## Final fresh generated consumer

Evidence:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.N1U2wa`.

The rebuilt CLI executable is `/tmp/amber-android-semantics-proof/amber`, SHA-256
`54f40e5543e31737433856c61543bec825b92f5a5513b624f20a04df6dc722a5`.
The new app uses the explicit local-development Amber/AssetPipeline shards.
This is not the public released-consumer lane. No generated app or test source
was repaired in place.

- Two shared examples and actual web state/validation/CSRF/escaping checks pass.
- **76 JVM tests, 13 Android tests in 30.966 seconds**, and a separate read-only
  exact-Unicode restoration test in **4.630 seconds** pass.
- The actual generated image has an intentional spoken label, its heading has
  heading semantics, and its native editor preserves text/editing semantics with
  separate test/accessibility identifiers. Control-I activates Increment once;
  repeat/release do not increment again. Existing lifecycle/selection and both
  Back paths remain green.
- All **717 source entries stay unchanged**: 36 generated, 242 Amber and 439
  AssetPipeline entries, including untracked runtime files.
- Process 29548 persists count **16** and the exact name `Android 雪 😀 é`
  (the final accent is decomposed). Process 29678 restores both. Final cold
  process 29730 remains the foreground `com.example.counter.app` Activity.
- Both ABI/package/export/debug-symbol gates pass, including the new semantics
  export. The final screenshot is visually inspected: the real native app mark,
  heading, controls, bounded editor, restored state and navigation fit without
  overlap. It is retained at `android-runtime/relaunch.png` in the evidence root.

Generated package SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `47a3db8e5728aa2f75005127698dcee699f8b9159223de132c6672865d7e92c3` |
| Unsigned release APK | `4160c6796da32d6fc46fa34abce11cbb481643cc6556e2066765a48214516362` |
| Release App Bundle | `34aa7f96ef146675f647dbb9f2f7f5de580bec598e34771bfc502ceb0ff1591a` |

The final ADB inventory contains only emulator-5554 and emulator-5556. The
original visible emulator is preserved; the physical phone is not available to
ADB. No physical-device evidence or changed phone settings are implied.

## Investigation notes and limits

Retained unsuccessful attempts are `first`, `second` and `third` under the same
proof root. The first exposed a mistaken test assumption that a menu Picker's
shared owner was the Spinner itself, and a test that tried to reuse a terminal
failed public application session. The corrected implementation resolves the
inner Spinner; malformed construction is tested through a separate nonterminal
ownership probe, without adding any production session-reset escape hatch.
The second caught a fixture export needing an Android-only compilation guard.
The third showed direct Activity Tab dispatch bypassed ViewRootImpl's traversal
fallback; the successful test injects a real system key. None is counted as a
successful proof lane or repaired generated consumer.

Remaining gates include TalkBack speech/exploration and accessibility focus;
all roles/traits/compound controls/picker styles; touch targets; RTL/large-font
and hardware-keyboard variants; keyboard reopening and route process restoration;
the rest of Tier A, AgentC integration, API/device matrix, CI and public releases.
No physical-phone or released-consumer claim is made here.
