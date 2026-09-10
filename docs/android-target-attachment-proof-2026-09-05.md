# Existing-project Android target checkpoint — September 5, 2026

Status: **verified development implementation and emulator progress**. The full
Android goal remains active. This checkpoint adds a real target to AgentC without
replacing its web application; it does not claim the final native account flow,
full Tier A support, physical-device validation, CI or public released-consumer
completion.

## CLI implementation

The actual CLI now exposes `target add android`, `doctor android`, `build android`,
`run android --device SERIAL`, and `test android --device SERIAL`. `--project`
selects an explicit project directory; attachment also supports `--dry-run`.
Run/test require a bounded explicit ADB serial and preserve subprocess failures.
Arguments are passed as an argument vector, not interpolated into shell code.

The additive installer obtains the name/declarations from the existing project,
preserves web configuration, dependency files and installed libraries, and uses
an existing valid v2 `config/native.yml` without rewriting its bytes. Otherwise
it creates public web/Android metadata. Existing file/parent conflicts and
symlinks are rejected before writing. Files are staged first and published with
exclusive hard links. Failed publication rolls back only unchanged files it still
owns, preserving a separately edited file. This is not crash-atomic across the
whole directory tree; concurrent installers/parent edits are not supported.

Apple-v1/custom-path manifests and source collisions require explicit migration;
there is no force-overwrite switch. Safe metadata regeneration is still open.
The default attached app is a native counter starter, not a translation of web
HTML, native authentication or proof of a shared AgentC account operation.

## CLI verification

Evidence root: `/tmp/amber-android-target-attachment-proof`.

- **181 Crystal examples**, no failures/errors/pending, 12.67 seconds, including
  22 new attachment/command contracts.
- The actual-process command fixture proves dry-run, additive file creation,
  unchanged web/dependency bytes, duplicate refusal, explicit device validation,
  exact IPv6/space-containing project arguments, and child exit-code 23 propagation.
  Its stubbed shell is explicitly not SDK/emulator evidence.
- The executable `/tmp/amber-android-target-attachment-proof/amber` has SHA-256
  `b3f1f30871a72c4798e03c9ee1290c11ff4a2abaaf61cd293be3d7305b95d613`.
- Formatting and targeted whitespace checks pass. Retained unsuccessful attempts
  include parser/test-fixture/path-alias/API-call issues and a host-cache permission
  error, corrected before the passing runs; they are not Android runtime failures.

## Actual AgentC attachment and web preservation

The real CLI dry-run finds no conflicts in `agentc_app_template_oss`, then adds
**33 files**. All **83 pre-existing source/configuration/spec/script/dependency
entries** retain their exact SHA-256 values. No existing library directory,
web entrypoint, `.amber.yml`, `shard.yml` or lockfile is overwritten.

The isolated database regression now has **309 examples, zero failures/errors,
three pre-existing pending permission checks**, in 1:24 minutes. The two added
examples exercise the shared starter; this is not yet the required AgentC account
use case. The actual server rebuilds, boots at localhost:38247 and passes five
read-only route checks: home/login/signup render, signed-out dashboard/settings
redirect to login. The server is stopped after validation. The existing test
environment omits the CSRF pipe, so these boot checks are not CSRF-enforcement
or mobile-authentication proof.

The task-owned database remains `agentc_android_20260905_ivvezn`. Its guarded
runner verifies the configured writer before registering destructive spec hooks.
No existing development/production database is included in the test scope.

## Attached native application

The native source projection at
`/tmp/amber-android-target-attachment-proof/agentc-native/project` contains **36
byte-verified inputs** copied from the actual attached target. Server source and
server environment/secret files are not copied into this native proof. Its only
installed shard links are the explicitly selected current local Amber and
AssetPipeline roots. This preserves the user's older installed libraries and is
labelled `local-development-source-projection-no-shard-resolution`; it is not a
public installation or released-dependency proof.

- The actual `amber doctor android` passes SDK, NDK, JDK, compiler and ABI checks.
- The actual `amber test android --device emulator-5556` builds both ABIs and
  package variants, passes **79 JVM tests**, **13 Android tests in 34.630 seconds**,
  and separate exact-state restoration in **6.009 seconds**.
- Process 32005 persists count **2** and `Android 雪 😀 é` (decomposed final
  accent); process 32131 restores the exact values. Its subsequent cold process
  is 32183. CheckJNI, lifecycle/selection/navigation, image/semantics, native
  platform contracts, package/export/debug-symbol gates and normal relaunch pass.
- A standalone actual `amber build android` also passes package inspection.
- The actual `amber run android --device emulator-5556` rebuilds/installs and
  cold-launches the attached app successfully. Final process **32591** is the top
  resumed `com.example.agentc.app.template.oss` Activity; the final native UI dump
  retains its title, count 2 and restored-storage state. Debug APK, release APK
  and App Bundle hashes still exactly match the packages above after this run.
- All 36 original/project target inputs, **441 selected AssetPipeline runtime
  inputs**, **242 Amber inputs**, and the 83 preserved existing web entries verify
  unchanged. The native snapshot verification and source ledgers are retained.
- The screenshot is visually inspected: the AgentC template title, native image,
  controls, bounded editor, restored values and details navigation fit without
  overlap. It remains visibly a counter starter, not a native sign-in screen.

Attached app SHA-256 values from the passing native test:

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `0af81e3b500c4755c5e3ae72a5e993e657563f318067ee99520e2273189d34cb` |
| Unsigned release APK | `2cc88447b21ad26aa9369e677967e3faf25074e91542f9971a4bf872e60291a1` |
| Release App Bundle | `bcbd5c32fd544903df2d671cb597d1118c09ca05f09a2d603ec54783c7f8c0a0` |

## Fresh new-project regression with the same CLI

Evidence:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.o3taMt`.

The actual rebuilt CLI also creates a new hybrid app. Two shared examples, real
web state/validation/CSRF/escaping, **79 JVM tests**, **13 Android tests in 39.064
seconds** and exact-state restoration in **4.831 seconds** pass. All **720 source
entries** remain unchanged: 36 generated, 242 Amber and 442 AssetPipeline.
Process 32327 persists count **20** and the exact Unicode name; process 32458
restores them, and the subsequent cold process is 32509. The counter retains the
previous test installation's app-local data; this is a fresh project/build, not a
claim that its device storage was newly empty.

Fresh generated artifact SHA-256:

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `0d5a5453f82b41b4ede55e0364c8510ecf8d5bcf26ad59879b4dfce536bd1a0a` |
| Unsigned release APK | `d4f38b95a9f6462eff5c4fe70213360bf9b8e94a2f93481d02250900eb5d5b14` |
| Release App Bundle | `77a37308d09d7548d38deb346066200861add59ab99eed4df9bcf555202fc0af` |

## Remaining work

The next AgentC milestone is a genuine shared account operation, intentional
server/mobile authentication boundary and native sign-in, dashboard/list and
settings/detail screens. The counter does not satisfy that gate. Remaining Tier A
controls/layout/modal/accessibility contracts, device/OS matrix, CI, release pins
and public artifacts still require implementation and proof. Only emulator-5554
and emulator-5556 are visible to ADB; physical-phone proof remains unavailable.
