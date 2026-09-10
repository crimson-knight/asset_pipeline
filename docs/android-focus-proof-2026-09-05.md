# Native focus checkpoint — September 5, 2026

Status: **verified native and fresh generated-consumer development progress**.
The full Android goal remains active. This is not full accessibility/Tier A,
physical-device, AgentC reference application or public-release completion.

## Behavior implemented and proved

An explicit newly mounted focus request now takes precedence over an older
viewport snapshot. After restoring native state, the host requests visibility
for the target's complete rectangle through its scroll ancestors. A fixture
places an editor beyond both axes of a bounded nested viewport; the actual
editor becomes fully visible, retains focus and remains visible after recreation.

Radio groups and segmented controls now preserve the exact focused option,
including an unchecked option distinct from the checked selection. The bounded
locator contains its ordinal plus a SHA-256 digest of the entire length-framed,
ordered option catalog. Changed labels/order invalidate restoration rather than
focusing a different option at the old position. A digest is a change detector,
not encryption or secret storage. Limits are 256 options, 4096 UTF-16 units per
caption and 32 KiB total UTF-8. No plaintext captions or native IDs are saved.

The group is not an extra keyboard tab stop. Opt-out and disabled semantics
apply to actual option children after construction. Explicit group focus uses
the current eligible child, checked option or first eligible option. Optional
Bundle-v1 locator fields retain old-v1 compatibility; partial/mistyped/out-of-range
extensions are rejected. Existing snapshot and actual Parcel budgets still apply.

Real keyboard opening, recreation, Back dismissal and subsequent non-reopening
also pass. That keyboard behavior already passed the baseline; no speculative
keyboard-policy change was made. Focus and keyboard visibility are separate
contracts; see [Android's keyboard visibility guidance](https://developer.android.com/develop/ui/views/touch-and-input/keyboard-input/visibility).

## Focused and full regression evidence

Evidence root: `/tmp/amber-android-focus-visibility-proof`.

- `baseline`: 14 Android tests, one expected regression identifying the old
  horizontal viewport overriding newly requested focus. Keyboard recreation
  already passed.
- `compound-first`: test-source compilation rejected use of `indices` on a Map;
  corrected to a bounded size range before rerunning.
- `compound-second`: **79 JVM and 17 Android tests**, 59.927 seconds, including
  five new native focus tests plus the 12 platform contracts. CheckJNI and a fresh
  normal relaunch pass.
- Host regression: **1,439 Crystal examples, zero failures/errors, 66 pending**.
  The four shared fixture examples pass. Pending examples are not implemented
  Android coverage. CLI regression: **159 examples**, no failures/errors/pending.
- `native-final`: **79 JVM and 33 Android tests**, 305.631 seconds. The existing
  100 malformed-semantics partial renders, six Crystal failure lanes (600 partial
  renders), and eight Java failure cases (400 partial renders) all pass. Original
  Throwable preservation, rejected terminal reuse, final zero native ownership
  and normal CheckJNI relaunch remain green.
- All **490 native source ledger entries** verify without mismatch. Both ARM64
  and x86_64 packages build; only API 35 ARM64 executes in this checkpoint.

Native final clean-lane artifact SHA-256:

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `350971a329c9c4cc04ca69138a6d4ee6b63895535705f8a8089bd8e98b476d49` |
| Test APK | `79446a112989205831e4134ce250a1df92d0cee0a3fb9b0556a09104e2d55ad6` |
| Release App Bundle | `abaea8bbc627582e837649db7f61c9fce1092a2f102bb2852f0dafc30578516a` |
| Source ledger | `2e259def4a6d9dc47a9b505fd09879be3be34a39af813b8bd49275f11933147e` |

## Fresh actual-CLI consumer

Evidence:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.L0MqUx`.

The rebuilt `/tmp/amber-android-focus-visibility-proof/amber` executable has SHA-256
`83bf9549818f8e74408daa5c2faf88c09f9a6ec7dc9aecd1f6a084875a643cc8`.
The fresh app uses explicit local-development dependencies; no generated source
was repaired in place and no public released-consumer result is implied.

- Two shared examples and real web state/validation/CSRF/escaping checks pass.
- **79 JVM tests, 13 Android tests in 46.275 seconds**, and the separate exact
  state-restoration test in **6.879 seconds** pass.
- All **720 source entries** remain unchanged: 36 generated, 242 Amber and
  442 AssetPipeline entries, including untracked runtime sources.
- Process 31617 persists count **18** and `Android 雪 😀 é` (decomposed final
  accent); process 31748 restores the exact values. Final cold process 31802
  remains the visible `com.example.counter.app` Activity on emulator-5556.
- The final screenshot is visually inspected: native image, heading, controls,
  bounded editor, restored values and navigation fit without overlapping.
- Both ABI/package/export/debug-symbol gates pass. The separated debug symbol
  file's readelf dynamic-table warning is not a package failure.

Generated artifact SHA-256:

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `2653ab2fd7c7947772493d9f1087c072645cd8106da06323c3bbc9e0791dd395` |
| Unsigned release APK | `727cdac31d9d14009465a728ab2a03fb39f36997a23775a072caac8a6eceb3a3` |
| Release App Bundle | `db8f6e4df92b7b1da8f58ee336733f610c4253808a5671dc6a06ab8a0b86e39a` |

Only emulator-5554 and emulator-5556 are visible to ADB. The original visible
emulator is preserved; the physical phone is unavailable to debugging. Remaining
work includes other picker/control styles, full TalkBack behavior and touch
targets, route/process restoration, remaining Tier A layout/modal controls,
AgentC's real authenticated shared flow, the CLI existing-project target surface,
supported-device/OS matrix, CI and public releases.
