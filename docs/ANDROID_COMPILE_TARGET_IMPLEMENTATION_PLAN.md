# Android compile target: assessment and implementation plan

**Status:** Active implementation; full completion gates remain open  
**Assessment date:** 2026-09-01  
**Scope:** AssetPipeline, Amber V2, Amber CLI native/hybrid generator, and the AgentC open-source application template  
**First proof target:** A current Crystal build installed and running on an Android emulator and the connected physical Android device

This plan supersedes the Android assumptions in `ANDROID_MATERIAL_EXECUTION_PLAN.md`, `CROSS_COMPILE.md`, and the Android row of `native-compile-matrix.md` where they conflict with current evidence. Those documents should be corrected during Phase 0 rather than treated as proof.

## Implementation checkpoint — 2026-09-05

The initial assessment below records the September 1 baseline. Current proof is
tracked in [Android runtime proof](android-runtime-proof-2026-09-04.md).
The [application-boundary proof](android-application-boundary-proof-2026-09-04.md)
records the direct Amber app, canonical runtime and CLI metadata work. The latest
[generated-consumer proof](android-generated-consumer-proof-2026-09-04.md) records
a complete CLI-generated hybrid application passing web and Android runtime
tests without generated-source edits.
The subsequent [dependency proof](android-dependency-proof-2026-09-04.md)
records verified ABI/API/toolchain-keyed caches, two independent byte-identical
dependency builds for both ABIs, negative cache tests and emulator regression.
The subsequent [lifecycle proof](android-lifecycle-proof-2026-09-04.md) records
main-looper/single-surface enforcement, Android visibility forwarding into Amber,
recreation and reopen without manager restart, plus a fresh generated-consumer regression.
The subsequent [storage proof](android-storage-proof-2026-09-04.md) records
asynchronous platform key/value storage, cancellation/cleanup, corruption
preservation and a generated app restoring saved state in a different process.
The subsequent [HTTP proof](android-http-proof-2026-09-05.md) records platform TLS,
binary requests, response bounds, timeout/cancellation/terminal cleanup, independent
storage progress, and explicit permission enforcement against transitive manifests.

- ARM64 and x86_64 dependencies, native libraries, debug APK and release App Bundle build from source.
- ARM64 API 35 emulator tests pass for runtime initialization, a fiber/channel round-trip, text input, callbacks, five lifecycle cycles, JNI cleanup, light/dark theme and system-bar insets.
- Android initialization now runs `GC.init`, `Crystal.init_runtime`, and `Crystal.main_user_code` behind a C `pthread_once` gate. The third step is essential for eager globals and the default execution context; `init_runtime` alone is insufficient.
- Fresh proof is available through `scripts/run_android_smoke.sh <serial>`. It rejects crashed or empty instrumentation results even when ADB exits zero.
- Logical dimensions now convert through each View's current display density. Native tests cover fractional padding, stack gaps (including hidden children), fixed sizes, corner radii, borders, elevation and sp text at two densities and two font scales. Maximum-only constraints and other Tier A layout behavior remain open.
- Amber now has a development `amber/native` facade, extracted value-only schema validation, explicit configuration/lifecycle contracts, platform-service interfaces and explanatory Android server-import guards. Its host/unit and ARM64 object boundary tests pass; a shared use-case counter also passes Android interaction/recreation tests.
- CLI capability manifest v2 now validates explicit shared metadata, targets and Android SDK/permission/link/appearance policy while preserving legacy Apple v1 reads. The old generator no longer turns failed device tests into success or uses an always-true launch assertion. These configuration/safety changes do not complete the generator or Android service adapters.
- The standalone Android/hybrid generator now emits the full host and consumes v2 metadata. Its actual CLI-generated app resolves explicit local development dependencies, passes shared/web/emulator state and validation tests, and builds debug APK, unsigned release APK and App Bundle with both ABIs and matching debug symbols. CLI regression coverage is 156 examples. Released-consumer, metadata regeneration and service-adapter gates remain open.
- Dependency provenance/reproducibility now passes on this host: pinned source archives, full payload checksums, identity-keyed caches enforced at link time, 18 negative cache cases and two independent byte-identical ARM64/x86_64 API 31 builds. The old flat cache cannot be relabeled or reused. This is not cross-host or API-level runtime-matrix proof.
- Android lifecycle forwarding now passes through the public runtime into Amber's retained session. Tests cover actual foreground/background, recreation and Activity reopen without restarting managers, explicit terminal close, worker-thread/second-owner rejection and native reference cleanup. Eight canonical host-session unit tests, 12 Amber native examples, 319 web/schema examples, the renderer suite and another untouched CLI-generated hybrid consumer pass.
- App-private storage now works through Amber's optional Android adapter and AssetPipeline's bounded asynchronous transport. Nineteen JVM contracts, 78 native adapter checks, actual SQLite corruption-preservation tests and a fresh generated app's different-process restoration pass. All 653 generated/dependency source entries remain unchanged through the final consumer run. This is ordinary key/value state, not secret storage, networking, ORM support or general View-state restoration; those remaining platform/UI gates are still open.
- The physical phone is not visible to ADB. x86_64 runtime testing, remaining Tier A renderer behavior, Amber/CLI/AgentC implementation, CI, public releases and consumer proof remain open. These are not covered by the emulator smoke result.
- Android HTTP now works through the optional Amber adapter and canonical AssetPipeline transport. Thirty-one JVM contracts, real trusted/wrong-host/untrusted TLS and denied-cleartext tests, active/terminal cancellation and a separate missing-permission app pass. A library-declared INTERNET permission was found in the merged package and is now removed unless the app explicitly opts in. Kotlin is pinned to 2.2.21, Build Tools to 35.0.0 and the SDK-compatible OkHttp line to 5.3.2. Streaming transfers, remaining services and full release gates are not covered by this bounded HTTP milestone.
- The final HTTP-era CLI consumer also passes: 157 generator examples, two shared examples, actual web checks, 31 JVM tests and three Android tests. Both packaged APK variants exclude unrequested INTERNET permission. All 661 source entries remain unchanged and the generated counter restores count 4/name Android in a different process. This is local development-consumer proof, not a public released-consumer or generated-counter TLS claim.
- Protected secrets now work through a separate optional Amber adapter and Android Keystore-backed AssetPipeline vault. Thirty-six JVM contracts, eight Android tests, 82 native adapter assertions, 32 terminal-close cancellations and different-process restoration pass. Both names and values are encrypted; corruption and lost keys preserve ciphertext without reset. See [the secrets checkpoint](android-secrets-proof-2026-09-05.md) for evidence and explicit security limits. This does not complete files, notifications, renderer parity or release gates.
- The secrets-era fresh CLI consumer passes 36 JVM tests, eight Android tests, shared/web checks and both ABI/package/symbol gates, with all 667 source entries unchanged. Count 1/name Android restore in a different process on an isolated background API 35 emulator. The existing visible emulator was preserved after its debugging transport stalled; this is still development-consumer proof, not a public release or physical-phone result.
- App-private binary files now work through the optional Amber adapter and a canonical descriptor-relative Android file backend. Forty JVM contracts, 13 Android tests, 88 native adapter checks, 32 terminal cancellations and different-process binary restoration pass. Traversal/symlink/type checks, atomic replacement, directory-race and descriptor cleanup are exercised; hard-link creation is denied by this Android app domain, with actual backend hard-link rejection proved separately on the host. See [the file checkpoint](android-files-proof-2026-09-05.md). Streaming/external documents and the remaining platform/UI/release gates are not covered.
- The file-era fresh CLI consumer passes 40 JVM tests, 13 Android tests, shared/web checks and both ABI/package/symbol gates, with all 675 source entries unchanged. Count 2/name Android restore in a different process. Its generated application uses ordinary Storage while canonical platform tests exercise the file backend; the dedicated Amber fixture proves the public Files API. Notifications, remaining UI/CLI/AgentC work and full release/device gates are still open.
- Local Notifications now implement explicit permission requests, bounded posting/update/cancel, configured channels, main-thread completions and lifecycle-safe dialog ownership. The final native fixture passes 54 JVM tests and 13 Android tests, including real dismissal/denial/grant across recreation, a 64-request batch, full maximum text, visible system-shade output and terminal cancellation. A separate opted-out app proves deferred PermissionDenied for all operations. See [the notification checkpoint](android-notifications-proof-2026-09-05.md); remaining UI/CLI/AgentC, device and release gates are still open.
- The notification-era actual-CLI consumer passes all 54 JVM and 13 Android tests with 682 unchanged source entries, required exports/symbols in both ABIs, and no unrequested INTERNET/POST_NOTIFICATIONS in either APK variant. New-process restoration shows count 3/name Android. Real HTTP/TLS and missing-INTERNET regressions also pass; fixture trust material and port mappings are cleaned up. These are local-development results, not public releases or full Android support.
- Bundled native images now have a shared build-time catalog/compiler and real `UI::Image` rendering: Unicode aliases, night variants, Fit/Fill/Stretch, isolated tint and bounded PNG/JPEG decoding. Eight compiler examples, 54 JVM contracts and 16 native tests pass at two densities in light/night configurations; see [the image checkpoint](android-images-proof-2026-09-05.md) and [bounded API contract](android-images.md). WebP-specific proof, richer assets/fonts, accessibility and the remaining renderer/template/release gates remain open.
- The image-era fresh actual-CLI consumer passes 54 JVM and 13 Android tests, shared/web checks and package/symbol gates with all 687 source entries unchanged. Its own bundled app mark visibly loads and count 5/name Android restore in a new process. Both APK variants resolve catalog/drawable payloads through their compiled resource tables, including shortened release paths; no unrequested network/notification permissions are added. This remains local-development proof, not full Tier A support or a public release.
- Native text now uses standard UTF-8/UTF-16 conversion with byte-length-aware routes, callbacks and typed string maps. Sanitizer-backed tests cover every Unicode scalar; 58 JVM and 17 native tests cover labels, actual JNI collections, composition, submission, multiline/read-only behavior and cleanup. The fresh actual-CLI consumer passes 13 Android tests plus a separate exact-Unicode restoration test with all 694 source entries unchanged. See [the text checkpoint](android-text-proof-2026-09-05.md). Focus/selection restoration, complete keyboard/accessibility/theme behavior and the remaining renderer/template/device/release gates are still open.

- Native navigation now connects retained `NavigationStack`/`NavigationLink` views, Material toolbar Up and lifecycle-aware Android Back. Nested screen history, stale taps, drafts, recreation, root exit and gesture cancellation pass native checks. The full host regression passes 18 Android tests; the final actual-CLI two-screen app passes 58 JVM tests, 13 Android tests and separate exact-state restoration, with all 696 source entries unchanged. See [the navigation checkpoint](android-navigation-proof-2026-09-05.md). Route process restoration, coordinator integration, full navigation accessibility/visibility/animation behavior and the broader renderer/AgentC/device/release gates remain open.

- Checked native callbacks and terminal UI failure handling now contain all five callback signatures, while partial renders explicitly clean up their native resources. The separate six-process failure matrix passes 600 immediate partial-render cleanup checks, rejected reuse and final zero references/callbacks/services; the clean regression passes 60 JVM and 18 Android tests. A fresh actual-CLI consumer passes 13 Android tests plus separate exact-state restoration, with all 698 source entries unchanged. See [the failure-boundary checkpoint](android-failure-boundaries-proof-2026-09-05.md). Pending Java exceptions, allocation/cleanup failures, broader renderer/AgentC work and physical-device/public-release gates remain open.

- The canonical View/collection JNI layer now preserves pending Java exceptions and unwinds Crystal ownership before delivering the original Throwable to Android. All 31 checked-operation host contracts, eight real Java failure types across 400 partial renders, the prior 600 Crystal partial-render checks and terminal cleanup pass; normal regression remains 60 JVM/18 Android tests. The final fresh CLI consumer passes 13 Android tests plus exact-state restoration with 703 source entries unchanged. See [the checked-JNI checkpoint](android-jni-errors-proof-2026-09-05.md). Direct platform-service/async failure policy, broader renderer/state/accessibility work, AgentC, physical devices and release gates remain open.

The preceding [native-layout checkpoint](android-layout-proof-2026-09-05.md) adds
maximum-only/distinct bounds, stack/overlay alignment and RTL, flexible spacers,
real two-axis scrolling and explicit/flexible viewport sizing. All 24 native
measurement configurations, 20 normal Android tests, 64 JVM tests and 1,000
deliberate partial-render cleanup checks pass. The fresh actual-CLI consumer
passes 13 Android tests plus exact-state restoration with all 706 source entries
unchanged. See [the bounded layout contract](android-layout.md) for native
parent-allocation semantics and explicit limitations. HStack equal distribution,
broader Tier A/AgentC/CLI work and
physical-device/public-release gates remain open; this is development progress.

The [native view-state checkpoint](android-view-state-proof-2026-09-05.md)
adds explicit keys, scoped focus/selection/scroll restoration, composition-aware
refresh, bounded value-only saved state and framework text-snapshot suppression.
Expanded native tests also cover stopped-window capture and hidden/disabled
fields. Fresh-consumer validation exposed and corrected a template type-inference
issue and a real stopped-window visibility gap. The final native proof passes
70 JVM tests, 23 Android tests and 1,000 deliberate failure-cleanup cases with
continuous app-only log capture. The fresh actual-CLI app passes shared/web
checks, 13 Android tests plus separate exact-state restoration, and all 712
source entries remain unchanged. Count 14 and the exact Unicode name restore
in a new process. This checkpoint does not complete Tier A support or the full goal.

The [native semantics checkpoint](android-semantics-proof-2026-09-05.md)
separates automation IDs from spoken labels, preserves native/Material node
behavior, owns bounded custom-action callbacks, implements native focus opt-out
and post-mount requests, and handles keyboard shortcuts without stealing editor
typing. Real accessibility-node activation, injected Tab traversal and simple
non-editor focus restoration pass. Final proof: 76 JVM tests, 28 Android tests,
1,100 deliberate partial-render cleanup checks and 483 matching native source
entries. The final fresh actual-CLI consumer passes shared/web checks, 13 Android
tests and separate exact-Unicode process restoration with all 717 source entries
unchanged; count 16 and its name restore in a new process. Full TalkBack and
compound-control coverage, touch targets, the remaining Tier A/AgentC work,
device matrix, CI and public releases remain open. The full goal is still active.

The latest [native focus checkpoint](android-focus-proof-2026-09-05.md) makes
explicit offscreen focus visible after restoring nested viewports, preserves the
exact focused radio/segmented option with conservative catalog validation, and
proves keyboard recreation/dismissal behavior. Final proof: 79 JVM tests,
33 Android tests, all 1,100 deliberate partial-render cleanup checks and 490
matching native source entries. A fresh actual-CLI consumer passes shared/web
checks, 13 Android tests and separate exact-state restoration with all 720 source
entries unchanged. Count 18 and its Unicode name restore in a different process.
This remains local-development proof, not completion of the full goal.

AgentC's dependency migration now has a verified safe web baseline: an explicit
task-owned database guard precedes destructive spec hooks; all 307 web examples
pass with the current local Amber/AssetPipeline projection (three pre-existing
pending permission checks). Logical component imports preserve the existing
HTML/Tailwind presentation and installed library directories. The actual server
build and five localhost route checks pass without the installed Amber version's
obsolete process-fork path. One earlier connection-availability failure remains
unexplained; two later full runs pass without a health/authentication policy
workaround. See `agentc_app_template_oss/docs/android-reference-migration.md`
for evidence and limits. This is web preflight, not native AgentC sign-in or the
required three-screen shared application flow.

The latest [target-attachment checkpoint](android-target-attachment-proof-2026-09-05.md)
implements the actual CLI add/doctor/build/run/test surface with additive file
installation and explicit device selection. AgentC receives 33 new target files
with all 83 existing web/configuration/dependency/test inputs unchanged. Its web
suite now passes 309 examples (three existing pending checks), and its attached
native starter passes 79 JVM tests, 13 Android tests and exact-state process
restoration. A fresh new hybrid consumer also passes with all 720 source entries
unchanged. This proves attachment and preservation, not the required AgentC
account API/shared use case/three-screen native application, public releases or
physical-device gates. The full goal remains active.

The [AgentC account-boundary checkpoint](android-agentc-account-api-proof-2026-09-05.md)
adds a real shared display-name operation, private session/account API, direct
TLS enforcement, pre-routing input bounds and a native-safe HTTP client. Real
browser/API bidirectional edits, CSRF and logout pass; correct ARM64/x86_64
client objects are produced. This is not an Android account UI result: protected
session coordination and the three native screens remain the next Phase 5 work,
followed by emulator/phone proof and the other full-goal gates.

The subsequent [AgentC native-account checkpoint](android-agentc-native-accounts-proof-2026-09-05.md)
replaces the counter starter with real sign-in, account dashboard and settings,
using protected origin-bound credentials and the actual TLS API. The final
actual-CLI proof passes 79 JVM tests, 13 Android tests, separate new-process
account restoration, signed-out relaunch and both ABI/package/debug-symbol gates.
Native Unicode edits appear in real web settings before the web smoke makes any
changes. Shared/web regression passes 350 examples (three existing pending
permission checks); source records verify 41 app inputs and 239 selected native
framework inputs. Light/dark editor contrast is tested, with native defaults
corrected to track Material appearance. Phase 5 now has its three-screen emulator
proof; physical phone, full Tier A/device coverage, CI and public-release gates
remain open. The full goal is still active.

The [native-alert checkpoint](android-dialogs-proof-2026-09-05.md) replaces inline
Alert/ConfirmationDialog cards with real Activity-owned windows. It passes 84
JVM contracts, 36 emulator tests, the isolated Crystal/Java failure lanes and
1,442 shared UI examples (66 existing pending). The actual AgentC native target
also builds both architectures and all package variants with 41 unchanged app
inputs. The [bounded contract](android-dialogs.md) specifies one active dialog,
callback retirement, native actions and keyboard-focus restoration. A fresh
actual-CLI hybrid consumer passes 84 JVM and 13 Android tests, separate exact
new-process restoration and shared/web checks with 724 unchanged source entries.
That alert checkpoint did not yet implement a real Sheet/custom-content path;
the subsequent checkpoint below adds it without claiming full Tier A promotion.

The [native Sheet checkpoint](android-sheets-proof-2026-09-05.md) replaces inline
cards with a real Material window, Crystal-owned editor content, native detent
state, keyboard/selection restoration, retired-control protection and exactly-once
explicit/structural dismissal. The complete proof passes 87 JVM contracts,
40 emulator tests, all isolated Crystal/Java/Sheet failure lanes and 1,449 shared
UI examples (66 existing pending); all 504 native source entries match. A fresh
actual-CLI hybrid app passes shared/web checks, 13 Android tests and separate
exact-Unicode process restoration with 729 unchanged source entries. The real
AgentC account target also builds both ABIs/package variants with 87 JVM tests
and 41 unchanged app inputs. Shorter-detent viewport/keyboard behavior, remaining
gestures/accessibility/device coverage, full Tier A, CI and public releases are
still required. The physical phone remains absent from ADB; the full goal is active.

The subsequent [Sheet viewport checkpoint](android-sheet-detents-proof-2026-09-05.md)
corrects offscreen scrolling-area measurement, duplicate system insets and
compact-keyboard focus loss. All declared height sets and actual restricted/
downward/locked gestures pass, as do small-only Unicode editor recreation and
keyboard Back. The complete proof passes 91 JVM contracts, 43 Android tests,
all isolated failure lanes and 1,450 shared UI examples (66 existing pending),
with 506 matching native inputs. The real AgentC target builds both ABIs/package
variants with 91 JVM tests and 41 unchanged app inputs. The broader CLI host
suite passes 525 examples. A freshly rebuilt actual CLI generates another
hybrid app that passes shared/web checks, 91 JVM tests, 13 Android tests and
separate exact-state process restoration with 730 unchanged source inputs;
count 26 and its Unicode name restore in the final normal emulator process.
Landscape/font/accessibility/device coverage, the other Tier A work, actual CI
and public releases remain open; the full goal is active.

The next [Sheet cramped-window checkpoint](android-sheet-window-matrix-proof-2026-09-05.md)
adds adaptive compact heights, inline landscape keyboard requests, temporary
handle removal when the keyboard crowds out enlarged controls, and safer
visible-keyboard restoration. Its focused five-test matrix passes font scale
1/2, English/Arabic layout, recreation, rotation in both directions, Back and
handle restoration on API 35 ARM64. The actual AgentC target builds with 93 JVM
tests and 41 unchanged app inputs; shared UI/CLI suites remain 1,450/525 examples
(66 existing UI pending). The full native driver passes 93 JVM contracts,
48 Android tests and all isolated failure lanes, with 509 matching inputs.
A fresh actual-CLI consumer passes shared/web checks, 93 JVM contracts,
13 Android tests and separate exact-state process restoration; all 730 source
entries remain unchanged. Its final normal emulator process restores count 28
and its Unicode name. This is not a broader device, accessibility, CI or release
promotion. Optional screenshot capture synchronization remains an explicit
test-harness follow-up; settled captures are distinguished from in-flight frames.

The September 6 [entrypoint/CI checkpoint](android-ci-entrypoint-proof-2026-09-06.md)
replaces the message-only Android Make target and ignored CI placeholder with
the real required driver and a pinned Linux API 31/35 workflow declaration.
Twenty routing contracts, seven configuration checks and workflow lint pass.
The Linux host run exposes a shared callback-token reuse defect: a later
NativeView finalizer can remove a new callback after registry clearing. Three
deterministic regressions reproduce it on macOS; preserving process-unique
tokens passes 88 focused tests and all 1,460 host examples on macOS and the
same-machine Linux container (66 existing pending). CLI host checks pass all
525 examples, and the isolated AgentC target still packages both ABIs with
41 unchanged application inputs.

The pre-fix complete Make invocation passes all 48 native tests and isolated
failure lanes. The post-fix device run reports three failures: an unexpected
Unicode edit after submission and two Sheet observation/sequence assertions.
The input-method sequence is still being investigated with a bounded,
failure-only synthetic-test trace; focused repetitions pass without
explaining the original edit. Sheet tests now wait for actual gesture settling
and post-Alert root replacement before their next assertion/action. Do not
promote the current native checkpoint until the failures are explained and the
fresh complete driver passes. The three combined focused checks now pass in
88.788 seconds. A fresh actual-CLI hybrid app passes shared/web checks, all
93 freshly executed JVM tests, 13 Android tests and separate process restoration;
all 733 source entries remain unchanged. Its normal emulator process restores
count 30 and the exact Unicode name. This does not establish remote CI, phone,
wider Tier A or released-consumer completion; the full goal remains active.

The later September 6 [input/minimum-version checkpoint](android-input-api31-proof-2026-09-06.md)
corrects external-edit coordination in the sample test and restores a complete
passing API 35 checkpoint: 48 native tests, all isolated failure lanes and
512 unchanged native inputs. The original asynchronous Unicode edit remains
untraced; a passing checkpoint is not a claim of causal proof. A separate
Android 12/API 31 emulator now runs the native app. Its first-use keyboard
readiness check fails while Gboard initializes; the unchanged warm check passes.
The actual generated app also exposes a composing-range protocol defect in its
test, now fixed in the CLI template with a deterministic active-composition
regression. All 526 CLI examples pass. A fresh actual-CLI consumer passes
shared/web checks, 93 freshly executed JVM tests, 13 Android tests and separate
exact-state restoration on both API 31/35 ARM64, with 733 unchanged inputs.
The first complete API 31 sample run reports four test-contract failures:
two final-batch return assertions ignore Android's documented pre-API-33
off-by-one, and two Sheet checks infer keyboard space from a font/orientation
profile instead of measuring it. Version-aware batch assertions and actual
control/window geometry checks now pass all four focused API 31 cases, followed
by the complete required target: 48 tests in 700.571 seconds, all isolated
failure lanes, normal cold relaunch and 512 unchanged source entries. The
focused API 35 run exposes a separate intermittent Insert sibling visible-text
failure; three diagnostic rechecks pass without reproducing or explaining it.
A fresh all-48 API 35 instrumentation recheck also passes in 881.540 seconds
against the frozen pre-equal-width package. Fresh-IME
readiness, those unresolved intermittent failures, independent CI, physical
phone, remaining Tier A and release gates are not closed. The full goal remains
active.

The September 6 [API 36 checkpoint](android-36-proof-2026-09-06.md) completes
the Android 16 migration: the migrated compile/target 36, AGP 8.13.2 build is
green after the SDK 36 listener signature fix, the target-36 libraries and APK
are 16 KB-aligned, and the complete driver passes exit 0 with all 50 tests and
every failure lane on the 16 KB API 36 emulator and again on API 35. The
[behavior audit](android-36-readiness.md) found one real delta, keyboard
restoration after dialog-window recreation, now handled in the sheet runtime
per [the sheet contract](android-sheets.md). The two previously unexplained
intermittent failures were test races (an injected Tab whose traversal
completes on a later main-loop turn; taps during sheet layout) and are fixed
with explicit waits. Three fail-open or host-bound defects were removed: the
raw-JNI gate passed without ripgrep, the NDK resolver took an ambient
`ANDROID_NDK_HOME` over the pin, and `gradle.properties` carried a macOS JDK
path. The declared workflow ran for real on GitHub's `ubuntu-24.04` runners:
every API level cross-compiles both ABIs, packages the APK and bundle, and
executes the suite on x86_64 emulators for the first time; see
[the CI notes](android-ci.md) for the runner findings and the per-run results.
The snapshot is also available as plan-package commits on
`android-target-packages` in all four repositories. Physical phone, Tier A
promotion, released-artifact consumer proof and the remaining Phase 7 gates are
still open; the full goal remains active.

The September 7 checkpoint adds four things. The x86_64 runner findings are
named and controlled: API 31's dropped first taps were Android 12
untrusted-touch blocking by androidx test-core's `EmptyActivity` (CI runs 15
and 16), and API 35's focus-stealing popup is Android's own text-suggestions
window, opened because the sheet fixture's persisted draft ends in a combining
accent that the image's Gboard spell checker flags and the landscape centering
tap lands on that span (run 17; screenshots and content classes in
[the CI notes](android-ci.md)). The driver sets `block_untrusted_touches`
permissive and `spell_checker_enabled` to `0` for the run and restores both;
the runtime is unchanged. Tier A grew from 26 to 46 core controls through the
basics, structure, pickers, list and tabs suites, each with a fixture, host
spec and device suite green on the local API 31, 35 and 36 emulators
([the tier matrix](android-renderer-tiers.md)). The AgentC three-screen flow
ran end to end against a live TLS account server on the API 35 emulator (the
template's `docs/android-reference-migration.md`). Release signing now comes
from the environment in both the AgentC template and the CLI's generated
project: with `AMBER_ANDROID_KEYSTORE`, `AMBER_ANDROID_KEYSTORE_PASSWORD`,
`AMBER_ANDROID_KEY_ALIAS` and `AMBER_ANDROID_KEY_PASSWORD` set, `android.sh
build` produces a signed release APK and App Bundle that the artifact
inspector verifies with `apksigner` and `jarsigner`; unset keeps them unsigned
and a partial set fails configuration. Both were proven with a throwaway key,
on the template and on a fresh CLI-generated project whose emulator suite
passed. The template's dropped-shard defect is closed the same day: Grant
moved to the fork head, whose transaction dispatch no longer needs every
adapter constant (Grant commit 4ae3216), `pg` to 0.30 on crystal-db 0.14, the
Postgres adapter is the only one required, and the unused i18n configuration
is gone; the web target compiles from a clean lock and the isolated-database
spec suite passed with 350 examples and 0 failures (the template's
`docs/android-reference-migration.md`). CI run 19, the first push carrying the spell-checker control and the tabs suite, is the first run green on all three API levels at once: 64 tests on each x86_64 emulator. Runs 20 and 21 then each failed one test on one API level, both tests asserting a frame the runtime updates one pass later (the sheet's drag handle after Back, the multiline editor after recreation); both waits now live in the tests, the runtime is unchanged, and run 22 is green on all three levels again ([the CI notes](android-ci.md)).
The physical phone gate closed the same day: `make test-android` passed on a
Samsung Galaxy A15 5G (SM-A156U, Android 16, One UI 8), 64 device tests and
both isolated failure lanes, on the sixth run after the first named six
differences from the emulators: one renderer defect (One UI hands a nested
vertical viewport's drag to the parent; `CrystalScrollView` now keeps the
drags it can consume), four test assumptions about the emulators' taller
screens and slower main loops, and one open runtime timing race (two page
taps inside the host's 250 ms debounce can lose a sheet presentation), all in
the CI notes' physical-device section. Released tags and version pins, store
upload and the remaining unverified controls stay open; the full goal remains
active.

The afternoon opened the next frontier: a customer app authored for the iOS
shell, rendered by the Android renderer from the same Crystal views. The
generated [view parity matrix](view-parity-matrix.md) says 78 of the 87 view
types render on both phones; the AgentC shell's QuiltPerfect branch uses only
Tier A types, and its first Android build compiled unchanged, yet its first
render was a blank page background. Bisecting the decoded page on the phone
found two renderer defects, both fixed here with the `layout-hugging` fixture:
Android's `LinearLayout` gave a fill child no say in a wrap-content stack's
cross size, so a section of a 38 dp accent bar and a fill heading measured
38 dp wide, and `root_fill` (`fill_screen!`), which UIKit pins and web sizes
to the viewport, was never read on Android. With both, the shell's sample
lead app draws at full width on the Galaxy A15 5G. The host contract that the
iOS shell provides and Android does not yet (a periodic tick, viewport and
insets, bundled assets and fonts, cache paths, TLS transport under
`-Dwithout_openssl`, the photo picker) and the attribute reads the matrix
names for that app are the next waypoints; they are planned outside this
repository with the customer work.

The host tick is the first of those waypoints and landed as d24983c8 with
the [host tick contract](android-host-tick.md): `UI::Android::Application.on_tick`,
a `TickPolicy` the JVM suite pins, a ticker in the bridge that posts the
first tick behind the first render and stops on background, detach, close
and failure, and the `tick-contract` fixture whose device test proves that
ticks advance without a touch, land one render each, and stop in the
background. CI run 25 passed API 31 and 36 and, after one rerun, API 35 (67
tests each); the one miss was a tap delivered one row above its target,
recorded in the CI notes. On the phone the AgentC shell now leaves its
Waiting screen by itself: the tick runs the parked boot fetch and the
result re-roots the tree.

The viewport is the second and landed as 11ab92f3 with the
[host viewport contract](android-viewport.md): `UI::Android::Viewport`,
`UI::Android::Application.on_viewport`, `viewport` and `mounted?`, a
`ViewportPolicy` the JVM suite pins (a padded host reports zero insets and
the bar-free height, an edge-to-edge host reports the bars, the keyboard
changes nothing), `NativeScreenHost` measuring before every render and,
coalesced after each layout pass, on every change, and the
`viewport-contract` fixture whose device test measures the sample host's
mount and container itself, bounds the pre-layout correction to one
refresh, checks a bar and a wrapped label against the column, and rotates
the host. `UI::Label#preferred_max_layout_width` is read on Android as the
label's maximum width, which moves Label to 7 of 8 in the parity matrix.
The scoped device run passed on the local API 35 emulator (14 tests) after
one defect in the first cut: Android sets a view's laid-out flag only after
its layout-change listeners have run, so the measurement now waits for the
end of the pass. Run 27 is the CI check. On the phone the AgentC shell
copies the report into `HappyCoach::Viewport` the way the iOS setters do,
so its views size against the real screen instead of the 480 by 760
defaults.

Bundled assets and fonts are the third, with the
[bundled assets and fonts contract](android-assets.md): the APK's
`assets/ap_bundle/` tree is extracted once per install into private
storage by `BundledAssets` when the runtime initializes, and
`UI::Android::Application.bundled_assets_dir` names it; `UI::Image#source`
accepts an absolute path inside private storage at the density the file
name declares the iOS way; `UI::Android::Fonts.register` loads a bundled
TTF under a family name and `UI::Font#family` resolves to it, then to
Android's generic families, then the default. `BundlePolicy` and
`FontPolicy` are pinned by JVM suites, and the `assets-contract` fixture's
device test proves extraction, the path-loaded mark at 32 dp, the
registered and generic faces, and that a recreated host does not extract
again. The CLI's generator stages `android.bundled_assets` from
`config/native.yml` into the APK (amber_cli 13f9e74), so the AgentC shell
packages the same tree its iOS target carries as a folder reference and
registers its eight faces at boot.

Private directories are the fourth: `UI::Android::Application.files_dir`
and `cache_dir` hand Crystal the host's canonical files and cache
directories (`AppDirectories`, initialized with the other services), and
the `directories-contract` fixture's device test compares them with the
activity's own and writes a marker under each. The AgentC shell's Android
entry now takes its directories from the host instead of a guessed
`/data/data` path, keeps its payload cache under the cache directory and
its cookie jar under the files directory (the split iOS makes between
Caches and Application Support), and with a cached payload draws the lead
app on its first frame with no network, the build 19 contract.

Transport is the fifth, in two slices. The first landed on the shell's
side: one HTTP seam (a request and a completion block) that runs on the
stdlib client on a Mac or an iPhone and on Amber's native Android client
(`amber/native/android_http` over this runtime's HTTP service) on Android,
with the bridge document fetch and the photo prefetch on it and the boot
machine finishing its work inside the completion blocks. The CLI's
generated project gained a debug-only trust block (a public task CA for
an explicit `https://localhost:<port>` origin, the AgentC template's
recipe), and on the phone the demo fetched its document from a local TLS
stand-in over `adb reverse` with no cache: the lead app on the first
frame, the request in the stand-in's log, the cache written. The identify
and shop clients are the second slice.

## Initial executive assessment — September 1 baseline

The target is feasible, and the repository is not starting from zero.

AssetPipeline already contains a substantial Android Views renderer, a JNI bridge, a Kotlin host application, a Crystal-to-Android cross-build script, and a 12-study screenshot harness. A current arm64 Crystal object, Android shared library, and debug APK can be produced on this Apple Silicon Mac. The APK installs and starts on the local arm64 emulator.

It is not yet a supported Android target. The freshly built app currently crashes while constructing the first renderer because the embedded Crystal entrypoint initializes Boehm GC but omits `Crystal.init_runtime`, which initializes `Thread`, `Fiber`, and `Crystal::Once` in Crystal 1.21.0. The build-dependency script also reports success while producing empty Android GC archives because it lets the Apple `ranlib` process NDK archives. These are concrete P0 blockers, not architectural unknowns.

Amber CLI's public native generator includes Android-shaped files and green generator specs, but it does not emit a complete runnable Android project. It omits the root Gradle project, wrapper, manifest, activity, resources, JNI entrypoints, and a real AssetPipeline UI entrypoint. Its Android test deliberately turns a missing device or failed instrumentation run into success. This is preview scaffolding, not Android support.

Full Amber V2 also cannot currently be linked wholesale into the Android library. `require "amber"` eagerly loads the HTTP stack, cookie encryption, and OpenSSL. A live Android cross-compile reaches `openssl/cipher` and fails under `-Dwithout_openssl`. The correct product boundary is a hybrid Amber application: shared Crystal domain/state/use-case code plus shared `UI::View` screens where desired, with separate web-server and Android-native entrypoints. Amber needs a native-safe facade instead of pretending its server runtime belongs inside the APK.

The AgentC open-source template is a downstream migration target. It currently uses Amber's web entrypoint and AssetPipeline's older HTML/Tailwind component path; it has no Android host or native `UI::View` application. It should validate the platform after AssetPipeline, Amber's native-safe boundary, and the CLI generator are real.

## Product definition

“Android is a compile-time target” means all of the following:

1. Application code selects Android with a deterministic Crystal target triple and `-Dandroid`.
2. Shared Crystal application logic compiles without importing Amber's server-only dependencies.
3. An AssetPipeline `UI::View` tree renders as native Android Views through the Android renderer.
4. The Crystal object, Android dependencies, JNI support code, and renderer bridge link into ABI-specific `.so` files.
5. A complete Gradle host packages those libraries into an installable APK and releaseable App Bundle.
6. App lifecycle, callbacks, state updates, input, accessibility, cleanup, and native-thread behavior work on an emulator and a physical device.
7. A newly generated Amber hybrid/native project builds and runs without copying undocumented files from the AssetPipeline sample.
8. CI treats compilation, packaging, instrumentation, and runtime crashes as failures. It never turns an absent device into a passing device test.

The first supported baseline will use the versions that were proven locally:

- Crystal 1.21.0 and LLVM 22.1.8.
- Android NDK 28.2.13676358.
- Native API 31 for the first runtime slice.
- `compileSdk` and `targetSdk` 35 for the first packaged host.
- JDK 17 from Android Studio as the pinned build JDK.
- `arm64-v8a` for Apple Silicon emulators and the physical device.
- `x86_64` added before CI and generator support are called complete.

API 31 is a proof baseline, not a permanent minimum. Lowering `minSdk` to 26 is a separate compatibility work package that must audit every native API and run an actual API-level matrix before changing the support claim.

## Initial assessment evidence — 2026-09-01

### Verified now

| Area | Current result | Meaning |
| --- | --- | --- |
| Crystal cross-compilation | `android_material_bridge.cr` produces an AArch64 Android ELF object from macOS | A separate Linux Crystal compiler is no longer a hard prerequisite for this target |
| Android native link | The current AssetPipeline sources link into a roughly 4 MB `libandroid_material_host.so` with `JNI_OnLoad` and Crystal exports | The NDK link model is viable |
| Android host build | The sample Gradle project assembles a debug APK containing the arm64 library | Packaging is viable |
| Emulator install | The debug APK installs and its activity launches on the API 35 arm64 emulator | Android host wiring reaches native load and entry |
| Current runtime | The process then crashes in `Thread::LinkedList(Fiber)#push`, reached through `Crystal::Once` during renderer construction | Embedded Crystal runtime startup is incomplete |
| Full Amber import | Cross-compiling `require "amber"` reaches Amber cookie encryption and `openssl/cipher`, then fails under `-Dwithout_openssl` | A native-safe Amber boundary is required |
| Amber CLI generator specs | 135 focused examples pass | Text generation is covered, but runnable Android behavior is not |
| Physical phone | The phone is physically connected but not listed by ADB | USB debugging/RSA authorization or USB mode still needs enabling on the phone |

### Existing but not current proof

- The April Android screenshot matrix contains phone/tablet and light/dark captures for 12 studies. Only Cards is marked accepted; the rest are pending review.
- Those captures demonstrate that an older binary reached the renderer, but they do not prove the current Crystal 1.21 runtime, current dirty working tree, interactions, callbacks, lifecycle, or cleanup.
- The Android-native spec directory and Android CI job are placeholders.
- The existing screenshot runner proves image capture, not that controls are semantically correct or interactive.

### False-green behavior to remove

- `cross_compile_deps.sh android` prints success even when `libgc.a` and `libcord.a` are empty 96-byte archives.
- The Amber CLI-generated Android test command converts `connectedAndroidTest` failure into a passing shell command.
- The generated instrumentation test contains a trivial assertion while its real activity rule is commented out.
- Older documentation says macOS cannot emit the Android object, which the current toolchain disproves.

## Repository ownership

| Repository | Owns | Must not own |
| --- | --- | --- |
| `asset_pipeline` | `UI::View` model, Android renderer, JNI bridge, runtime embedding support, canonical Android host fixture, renderer and device tests | Amber application/domain conventions |
| `amber-v2-beta-release` | Native-safe Amber facade, shared application boundaries, platform-neutral configuration/capabilities | Kotlin host templates or renderer internals |
| `amber_cli` | Complete generated project, dependency/version policy, Gradle wrapper, manifest/activity/resources, generated build and test commands | A second handwritten JNI/runtime implementation that drifts from AssetPipeline |
| `agentc_app_template_oss` | Downstream hybrid reference app and migration proof | The canonical Android bridge or build toolchain |

The canonical host and JNI contract should be exercised in AssetPipeline first and then copied through versioned Amber CLI templates. The generator must not independently re-invent a different Android architecture.

## Target architecture

```text
shared Crystal domain, state, use cases, and process managers
                          |
            shared AssetPipeline UI::View screens
                          |
       +------------------+------------------+
       |                                     |
web entrypoint                         Android entrypoint
Amber HTTP/runtime                     Amber native-safe facade
WebRenderer or web components          -Dandroid + target triple
                                             |
                                  Crystal Android object
                                             |
                         NDK link + libgc + PCRE2 + JNI bridge
                                             |
                               ABI-specific shared library
                                             |
                           Kotlin Activity + Android Views host
                                             |
                                      APK / App Bundle
```

### Recommended application layout

```text
src/
  app/
    domain/                  # platform-neutral entities and rules
    use_cases/               # platform-neutral application operations
    state/                   # observable app state/process managers
  ui/
    screens/                 # UI::View trees shared by native renderers
  platform/
    web/                     # controllers, routes, web-only adapters
    android/                 # exported entrypoint and Android adapters
  my_app_web.cr              # requires full Amber server runtime
  my_app_android.cr          # requires Amber native + AssetPipeline UI
mobile/
  android/                   # complete generated Gradle application
```

Existing ECR/HTML/Tailwind views do not become native Android views automatically. An Amber hybrid app may either:

- implement selected screens as shared `UI::View` trees and render them through native renderers; or
- keep distinct web and native presentation layers over the same domain/state/use-case code.

A WebView wrapper can be an explicit compatibility surface, but it is not the definition of the full-native target.

### Android UI host decision

Use the Android View system as the canonical first host because AssetPipeline already returns native `View`/`ViewGroup` instances. `MainActivity` should mount the returned root in a `FrameLayout` or `Fragment`. Compose may later host that View through `AndroidView`, but Compose must not be required to prove the renderer.

This eliminates the current generator mismatch in which the build and tests assume Compose while the renderer produces Android Views.

### Native lifecycle contract

The lifecycle needs one documented, tested ownership model:

1. `System.loadLibrary` triggers `JNI_OnLoad`.
2. `JNI_OnLoad` stores the process `JavaVM`, obtains the current `JNIEnv`, and calls one idempotent Crystal bootstrap.
3. Crystal bootstrap calls `GC.init`, `Crystal.init_runtime`, and `Crystal.main_user_code` in the order used by the pinned Crystal standard library. The last step initializes eager globals and the default execution context without exiting the host process.
4. The activity calls one generated JNI render entrypoint with the activity context.
5. Crystal renders the `UI::View` tree and returns a valid Android root View.
6. The host mounts the root on the main looper.
7. Android listeners invoke retained Crystal callbacks on registered threads; any native-created thread is registered with Boehm GC and attached to the JVM before JNI work.
8. Activity destruction invokes an explicit teardown path that removes listeners and releases callbacks and global references.
9. Global JNI references are released through a valid thread-local `JNIEnv` obtained from the stored `JavaVM`; a `JNIEnv*` is never cached and reused across threads.

This follows Android's JNI model: the `JavaVM` is process-wide, while `JNIEnv` is thread-local and native-created threads must attach before JNI calls.

## Required implementation work

## Phase 0 — Establish a truthful, reproducible baseline

**Goal:** one command reports the real state of every prerequisite and cannot succeed with unusable artifacts.

### AssetPipeline

- Replace hard-coded host paths with a resolver for `ANDROID_SDK_ROOT`, `ANDROID_HOME`, Android Studio, `sdkmanager`, and explicit overrides.
- Pin the NDK, native API, compile SDK, target SDK, JDK, Gradle, AGP, Kotlin, and Crystal versions in one machine-readable toolchain file.
- Make the first build use Android Studio's JDK 17 or a documented override.
- In `scripts/cross_compile_deps.sh`:
  - use the NDK's target Clang, `llvm-ar`, `llvm-ranlib`, and `llvm-strip` explicitly;
  - clear or replace host `CPPFLAGS`, `CFLAGS`, and `LDFLAGS` so Homebrew PostgreSQL or macOS paths cannot leak into Android configuration;
  - build once per ABI/API tuple into isolated directories;
  - verify archive size, member count, target architecture, and symbol presence before printing success;
  - emit a manifest containing source versions, checksums, configure flags, NDK revision, API, and ABI.
- Correct the stale Android build matrix and sample documentation.
- Add `doctor android` behavior, initially as a script and later exposed by Amber CLI.

### Exit gate

- A clean temporary directory can build Android GC/PCRE dependencies twice with identical manifests.
- Empty or host-architecture archives fail immediately.
- The doctor identifies a missing ADB authorization separately from a missing SDK or NDK.

## Phase 1 — Make the existing native host boot and interact

**Goal:** the current AssetPipeline Android sample runs a minimal interactive screen on the emulator and physical device.

### Runtime bootstrap

- Change `scripts/crystal_init.cr` to call the current standard-library runtime initializer after `GC.init`.
- Make initialization thread-safe and idempotent; record the initialized state and fail clearly if an exported Crystal function is called first.
- Add a small embedded-runtime fixture that initializes, allocates, uses `Crystal::Once`, creates a `Fiber`, and returns through JNI.
- Test the supported Crystal version matrix. When Crystal changes, compare its `Crystal.main` startup sequence and fail CI until the embedding contract is reviewed.
- Replace the no-op GC thread registration functions with a real contract, or delete them if all calls are guaranteed to arrive on JVM-created registered threads and prove that assumption.

### JNI ownership and cleanup

- Store `JavaVM*` in the native bridge at `JNI_OnLoad`.
- Add a helper that calls `GetEnv`, attaches when required, and detaches native-created threads on exit.
- Choose one owner for every local/global reference and listener callback.
- Fix `NativeHandle::JNIGlobalRef` release so explicit teardown actually deletes the global reference.
- Add counters available in debug builds for live global references and retained callbacks.
- Run with CheckJNI in the emulator lane.

### Minimal vertical slice

The first screen should intentionally exercise the smallest meaningful set:

- `VStack`/`HStack` layout;
- label and button;
- text field;
- state update from a button callback;
- text input round-trip from Kotlin/Android to Crystal;
- explicit test IDs/content descriptions;
- light/dark background and text tokens;
- destroy/recreate through activity rotation or process restart.

### Exit gate

- Fresh libraries and APK build without copying an old binary.
- The process remains alive after render.
- Button interaction changes visible Crystal-owned state.
- Text input reaches Crystal and renders back.
- Rotation/recreation and a second launch succeed.
- Logcat contains no native crash, CheckJNI error, or uncaught exception.
- Debug callback/global-reference counters return to their expected baseline after teardown.
- The same APK passes on the arm64 emulator and the connected phone.

## Phase 2 — Turn the renderer into a supported core UI target

**Goal:** define and prove a production-worthy core instead of claiming every existing visitor is complete.

### Renderer tiers

Classify every Android visitor and modifier:

- **Tier A — supported:** real native behavior, state/callbacks, accessibility, lifecycle, theme, and tests.
- **Tier B — preview:** renders a useful native approximation with documented limitations.
- **Tier C — placeholder:** visual stub or pass-through; it cannot appear in supported API claims.
- **Tier D — unsupported:** explicit diagnostic rather than a silent empty View.

Known items requiring classification or completion include Map, Chart, VideoPlayer, Canvas, Tooltip, DisclosureGroup, SwipeActionRow, sheets, popovers, full-screen cover, action sheets, and advanced navigation.

### Core Tier A set

- Text, image, spacer, divider.
- VStack, HStack, ZStack, scroll container, list/form basics.
- Button, text field/secure field/text editor.
- Toggle, checkbox, radio, slider, picker.
- Navigation container, toolbar, and back behavior.
- Alerts and one canonical modal/sheet path.
- Progress and loading states.
- WebView only as an explicitly named native WebView component.

### Cross-cutting renderer work

- Convert AssetPipeline logical dimensions to Android dp and text to sp through `DisplayMetrics`; stop treating values as raw pixels.
- Map semantic colors and typography through Android resources/theme attributes.
- Re-render or reconcile state changes predictably. Rebuilding the whole tree may remain a first implementation, but lifecycle and focus preservation must be specified.
- Dispatch UI mutations to the main looper.
- Map test IDs and accessibility labels, hints, roles, enabled state, and selected state.
- Handle keyboard/insets, focus traversal, screen rotation, configuration changes, and state restoration.
- Surface unsupported modifiers during debug builds instead of silently ignoring them.
- Separate renderer code from optional Google/Media dependencies so the core target stays buildable.

### Exit gate

- Every Tier A primitive has Crystal structure tests plus Android instrumentation tests.
- Phone/tablet and light/dark screenshot matrices are regenerated from the current commit and reviewed.
- Interaction, keyboard, accessibility, and lifecycle tests pass in addition to screenshot capture.
- Unsupported/preview components are visible in generated documentation and release notes.

### Next renderer work after view-state and native semantics

The layout implementation now introduces owned bounds wrappers and an inner
two-axis viewport, so native children are no longer universally one-to-one with
shared View children. Do not transplant the older Apple positional reconciler
without modeling that topology and callback ownership.

The [bounded view-state contract](android-view-state.md) now distinguishes
same-screen refresh from navigation, defers asynchronous replacement during
composition and keeps application values in Crystal. Do not reintroduce
accessibility descriptions as identity or persist entered text in native view
snapshots. The full-tree policy is explicit, not in-place reconciliation.

The [bounded semantics implementation](android-semantics.md) now separates
automation IDs from spoken labels, decorates the native/Material delegate,
owns custom-action callbacks, applies native focus opt-out/post-mount requests
and restores simple non-editor focus. Its [checkpoint](android-semantics-proof-2026-09-05.md)
tracks actual native action, keyboard and generated-consumer evidence rather
than treating serialized metadata alone as support.

The [focus checkpoint](android-focus-proof-2026-09-05.md) now proves nested
offscreen visibility, exact radio/segmented child focus, and keyboard recreation
and explicit Back dismissal on API 35 ARM64. Other compound/picker styles and
window/OS transitions are not implied by those fixtures.

The [native Sheet contract](android-sheets.md) now replaces inline sheet cards
with an owned custom-content window, separate view-state metadata, detent state
and structural-dismissal reconciliation. Its [viewport follow-up](android-sheet-detents-proof-2026-09-05.md)
proves shorter-detent sizing/scroll reachability, small-only keyboard usability
and actual downward/locked gestures on the portrait API 35 ARM64 fixture.
The [cramped-window follow-up](android-sheet-window-matrix-proof-2026-09-05.md)
now passes focused and complete-regression enlarged-text/RTL, landscape,
keyboard and rotation checks. Before promotion,
extend coverage to nested popup controls, TalkBack/accessibility focus and the
phone/tablet/density/API/keyboard matrix. In particular, an integer-bounded
viewport is not proof that a short window can fit an oversized control.
Preserve single-event dismissal,
retired-control protection and metadata privacy; this work does not narrow any
other full-goal gate.

Still required before broader Tier A promotion: wider keyboard/window-focus
transitions and route/process restoration; remaining compound-control focus;
useful duplicate/missing-key and unsupported-key
diagnostics without exposing identifiers; complete accessibility roles/traits,
TalkBack exploration/accessibility-focus retention and touch targets. Native
`tab_index` remains advisory; numerical native traversal was not promised.
The [equal-width checkpoint](android-equal-width-proof-2026-09-06.md) now implements
HStack equal cells and fixes older Android's RTL gap placement. The strengthened
50-test/failure target passes on both API 31 and 35, with all 512 source inputs
reverified. A fresh actual-CLI app passes shared/web checks, 93 freshly executed
JVM tests, 13 Android tests and separate exact-state restoration on API 31 and
35, with 733 unchanged inputs and the equal-width action row visually reviewed.
The API 35 consumer rebuild reuses the JVM reports. These remain local proof,
not full Tier A promotion.
The remaining layout modifiers still need
separate behavioral coverage. Finish the other core controls, their
theme/font/state contracts and the phone/tablet/device matrix rather than
equating a passing counter fixture with complete renderer support.

## Phase 3 — Introduce the Amber native-safe application boundary

**Goal:** regular Amber applications can share their application code with Android without importing the HTTP server into the native library.

### Amber V2 changes

- Add a supported native-safe require path such as `require "amber/native"` or `require "amber/core"`.
- Keep this facade free of HTTP server, router cookies, websocket, mailer, OpenSSL, and server process boot.
- Move or expose only platform-neutral pieces needed by applications: environment/config contracts, lifecycle hooks, schema/value support, and application/process-manager conventions.
- Add compile guards that make server-only imports on Android produce a direct, explanatory error.
- Define adapter protocols for storage, HTTP client, secrets, notifications, and files.
- For the first Android target, use Android-hosted networking through a small Kotlin/Java adapter rather than pulling Crystal OpenSSL into the APK.
- Treat database support as a separately proved adapter. Do not claim Grant/database parity until SQLite or another Android storage path is implemented and tested.

### Hybrid application contract

- Web entrypoint requires full Amber and boots routes/controllers/server adapters.
- Android entrypoint requires Amber native, AssetPipeline UI, and Android adapters.
- Domain, use cases, validation, state, and selected `UI::View` screens remain shared.
- Platform services are injected behind Crystal interfaces.

### Capability manifest v2

Extend the current Apple-focused manifest to describe platform-neutral metadata plus Android fields:

- application ID/package and display name;
- minimum/target SDK policy;
- requested permissions and feature declarations;
- URL/deep-link schemes;
- network, file, camera, microphone, location, notification, and background capabilities;
- icons, splash screen, and theme metadata;
- platform-specific overrides that are explicit rather than inferred.

### Exit gate

- An Amber fixture shares one use case and one state store between web and Android.
- The Android fixture cross-compiles without the Amber HTTP/OpenSSL stack.
- Attempting to import a server-only module under `-Dandroid` fails with a useful message.
- The web application behavior remains unchanged.

## Phase 4 — Replace preview scaffolding with a runnable Amber CLI target

**Goal:** a new project generated by the public CLI builds, installs, and interacts without manual file recovery.

### CLI surface

Implemented development command model (public released-consumer gate remains open):

```text
amber new my_app --type hybrid --targets web,android
amber target add android
amber doctor android
amber build android
amber run android --device <serial>
amber test android --device <serial>
```

Keep existing web defaults stable. “Hybrid” communicates separate platform entrypoints with shared application code more accurately than treating a server application as one universal binary.

`target add` is additive and supports `--dry-run`; all target commands accept
`--project`. It preserves existing web/dependency files and a valid v2 canonical
manifest, with collision/symlink preflight and exclusive publication. It does not
silently migrate Apple-v1/custom-path manifests or regenerate changed metadata.
The initial starter is not an automatic translation of the existing web app.

### Generated Android project must include

- `settings.gradle.kts` and root build configuration.
- A checked-in Gradle wrapper and verified distribution checksum.
- `gradle.properties` and project JDK guidance without hard-coded user paths.
- App module, manifest, activity/fragment, theme, colors, strings, icons, and splash assets.
- Kotlin bridge whose JNI signatures match the generated package and library names.
- Canonical AssetPipeline JNI/runtime support copied from versioned templates.
- `jniLibs` output directories for supported ABIs.
- Generated Crystal Android entrypoint that actually requires AssetPipeline UI and renders a screen.
- Configurable package, SDK/API, ABI, signing, and application metadata.
- Debug APK, release APK, and App Bundle tasks.
- Instrumentation tests that locate and interact with the real activity.

### Generator corrections

- Remove the current standalone `crystal_trace`-only JNI stub.
- Stop hard-coding the NDK prebuilt-host folder as `darwin-x86_64`; resolve it for Apple Silicon and other supported hosts.
- Link verified GC/PCRE dependencies and every required bridge source.
- Align the generated UI host with Android Views. Add Compose only as an optional wrapper after the View path is proven.
- Do not generate `local.properties` with a developer-specific SDK path.
- Replace the fake “skipped device” success path with explicit test outcomes: passed, skipped because no device, or failed. CI must require the device lane.
- Change specs from emitted-string assertions alone to a generated-fixture build.
- Pin released AssetPipeline and Amber versions; development branches may be opt-in.

### Exit gate

From a clean temporary directory, the released CLI can:

1. generate a hybrid web/Android app;
2. resolve shards and Android dependencies;
3. build every native dependency;
4. link ABI-specific libraries;
5. assemble the APK;
6. install and launch it;
7. pass a button/state instrumentation test;
8. build an App Bundle;
9. repeat without relying on files from a developer checkout.

## Phase 5 — Migrate the AgentC open-source template as the reference consumer

**Goal:** demonstrate that a real Amber V2 application can add Android without replacing its web application.

### Confirmed migration preflight — September 5

The current AgentC checkout contains unrelated in-progress web/auth/configuration
changes; preserve them. Its `spec/spec_helper.cr` runs a `TRUNCATE ... CASCADE`
against regular/admin user tables before each example. `config/database.cr`
prioritizes `DATABASE_URL`/`DATABASE_URI` over its test database defaults, so
setting the test environment alone does not establish isolation. Before any
web suite or migrations, create/select a task-owned disposable database, force
the exact connection configuration, verify `current_database()` read-only, and
keep existing development/production databases outside the test scope.

Settings currently projects the authenticated user's email/account type;
dashboard and login presentation are server-side components. Extract explicit
value/use-case boundaries without importing Grant, PostgreSQL, server sessions
or mailers into Android. Native sign-in must use an intentionally designed,
tested server/API boundary; do not present a local form or a demo identity as
working account authentication.

### Migration shape

- Preserve its existing Amber web server, routes, controllers, and HTML/Tailwind component tree.
- Extract platform-neutral domain operations, validation, and state from web-only entrypoints.
- Add the hybrid directory structure and generated Android host.
- Build three representative native screens first:
  - sign-in/onboarding;
  - dashboard/list state;
  - settings/detail form.
- Share state/use cases with the web application while allowing separate native presentation where the old HTML components cannot be reused.
- Add Android adapters only for services actually used by those screens.

### Exit gate

- Web tests and server boot remain green.
- The same domain operation is exercised from web and Android.
- The three screens run on emulator and physical phone with Tier A controls only.
- The template documents what is shared, what is web-only, what is Android-only, and what remains preview.

## Phase 6 — Extended Android platform features

**Goal:** expand from the supported core to a competitive native surface without hiding previews.

Promote features one at a time through the same Tier A gate:

- richer navigation and deep links;
- bottom sheets, popovers, full-screen covers, and menus;
- media playback and capture;
- maps and location;
- charts and canvas/drawing;
- share sheet and document picker;
- notifications and background work;
- camera, microphone, and permission flows;
- accessibility services and dynamic type/font scaling;
- optional Compose interop;
- Android-native persistence and networking adapters.

Each optional feature should live behind a small adapter and capability declaration so core apps do not pay for every dependency.

## Phase 7 — CI, releases, and support policy

**Goal:** Android support is repeatable outside one developer machine.

The September 6 [Android 16 readiness audit](android-36-readiness.md) identifies
an additional current release gate: ordinary new apps and updates now need
target SDK 36 under Google's August 31, 2026 requirement. Existing target-35
proof remains a dated development baseline. Migrate the canonical toolchain,
sample/generator/CI expectations and behavior checks, preserve minimum/native
API 31, and prove actual 16 KB native execution plus package alignment. SDK
packages and an isolated 16 KB emulator are prepared. A frozen target-35 app
cold-launches on verified API 36/16384-byte pages and passes 17 focused native
tests with CheckJNI. Canonical SDK/AGP pins are now migrated and the first build
is in progress; target-36 support is not yet claimed. This does not narrow any
other phase or authorize publication.

The September 6 [Android validation entrypoint](android-ci.md) replaces the
message-only `make test-android` with the complete native/failure driver and
explicit device selection. It rejects inherited partial-smoke overrides and
propagates test failures. The old `continue-on-error` Android placeholder is
removed; unrelated Apple/web jobs remain intact. A separately declared, pinned
Ubuntu 24.04 workflow now declares API 31/35/36 x86_64 emulators, both packaged ABIs,
host contracts, native/failure gates and retained artifacts.

This local implementation and declaration do **not** close Phase 7. Actual
independent Linux native builds, all remote emulator jobs, artifact retention,
generated-consumer integration CI and required-check/release evidence still
need proof. Do not infer remote CI completion from local emulator scripts,
configuration specs, lint or a same-machine Linux container.

### Required CI lanes

| Lane | Proof |
| --- | --- |
| Crystal host specs | Shared view/state/generator behavior |
| Cross-build matrix | Crystal object and native dependencies for every ABI/API tuple |
| Link inspection | ELF architecture, exported JNI symbols, no macOS objects, required libraries present |
| Gradle assemble | Debug APK and release App Bundle package correctly |
| Emulator instrumentation | Boot, render, callbacks, input, lifecycle, accessibility, CheckJNI |
| Visual matrix | Current phone/tablet and light/dark reviewed captures |
| Physical-device checkpoint | At least one arm64 phone before a release candidate |
| Generated-project E2E | Public CLI creates and runs an app from an empty directory |
| Existing-platform regression | Web, macOS, and iOS lanes remain green |

### Release artifacts

- ABI-split debug libraries for development and an App Bundle for distribution.
- Native debug symbols retained and associated with the release.
- Dependency manifest and checksums.
- Toolchain/version manifest.
- Supported/preview/unsupported component matrix.
- Installation and device-onboarding instructions.
- Reproducible generated-project proof attached to the release.

Android officially packages native libraries by ABI and recommends App Bundles or APK splits to avoid shipping every ABI in one oversized APK. The initial support matrix should be `arm64-v8a` plus `x86_64`; 32-bit ABIs are out of scope unless a concrete supported-device requirement is added.

## Validation ladder

No upper level substitutes for a lower one, and a screenshot does not substitute for interaction.

### L0 — Static and host tests

- Crystal specs for view construction, state, renderer dispatch, handle ownership, and generator output.
- Kotlin/JVM unit tests where logic exists outside Android framework classes.
- Shell/build-script tests for path resolution and false-success cases.

### L1 — Cross-compile and native link

- Fresh Crystal object per ABI/API.
- Fresh dependency archives with target verification.
- Shared library link, symbol inspection, and dependency inspection.
- Supported Crystal-version matrix.

### L2 — Package

- Gradle configuration from a clean cache where practical.
- Debug APK and release App Bundle.
- Manifest/resource/package inspection.
- No stale `.so` accepted by timestamp or build-manifest checks.

### L3 — Emulator runtime

- Process survival and native-crash scan.
- Render assertions against semantic IDs.
- Interaction and input.
- rotation/recreation, background/foreground, and process restart.
- CheckJNI and debug reference counters.
- screenshot and accessibility scans.

### L4 — Physical device

- Install, launch, interaction, keyboard, theme, and lifecycle.
- Device ABI/API recorded in evidence.
- Unplug/reconnect and clean reinstall path.

### L5 — Generated consumer

- Released CLI and released shards only.
- Clean generated hybrid app.
- AgentC reference migration.
- Build provenance, artifact checksum, and public documentation.

## Work packages and proposed commit sequence

Keep changes reviewable and avoid mixing the current unrelated dirty-tree work into Android commits.

1. **AP-AND-001: truthful Android toolchain and dependency builder**  
   Fix NDK tools, environment isolation, artifact validation, doctor output, and stale docs.
2. **AP-AND-002: Crystal embedded runtime bootstrap**  
   Call the current runtime initializer, add idempotence, and add the minimal runtime fixture.
3. **AP-AND-003: JNI thread/reference ownership**  
   Store `JavaVM`, attach/detach correctly, release global refs, and add debug counters.
4. **AP-AND-004: interactive host smoke**  
   Canonical activity, minimal screen, callback/input tests, emulator and phone evidence.
5. **AP-AND-005: Android core Tier A contract**  
   Density, theme, accessibility, lifecycle, supported component matrix, and instrumentation.
6. **AMBER-AND-001: native-safe Amber facade**  
   Split server imports from platform-neutral application code and add compile guards.
7. **AMBER-AND-002: hybrid application/capability contract**  
   Shared app layout, adapters, and manifest v2.
8. **CLI-AND-001: complete Android generator templates**  
   Generate the canonical host, resources, wrapper, bridge, and build tasks.
9. **CLI-AND-002: generated-project Android E2E**  
   Build/install/interact from a temporary generated app with no false skips.
10. **AGENTC-AND-001: three-screen hybrid reference**  
    Migrate shared application logic and prove the downstream template.
11. **REL-AND-001: matrix CI and release evidence**  
    ABI, emulator, generated-project, regression, symbols, bundle, and support matrix.

## Risks and controls

| Risk | Consequence | Control |
| --- | --- | --- |
| Crystal runtime startup changes between compiler versions | Native crash before first screen | Pin versions, mirror `Crystal.main` initialization, and run an embedded-runtime fixture for every upgrade |
| Boehm GC or Crystal is called from an unregistered thread | Intermittent corruption/crash | Explicit JVM/GC thread contract, debug checks, stress tests |
| JNI global refs/listeners leak | Activity and Crystal objects survive teardown | Single ownership model, explicit teardown, counters, rotation/relaunch stress |
| Full Amber server imports enter Android | OpenSSL/socket/link failures and excessive binary | Native-safe facade and compile-time server-only guards |
| Host macOS flags/tools contaminate NDK archives | Empty or wrong-architecture libraries | Sanitized environment and mandatory artifact inspection |
| Existing visitors look complete but are visual placeholders | Misleading support claim | Tier matrix and behavioral acceptance gate per component |
| Android Views renderer and Compose generator diverge | Generated project cannot mount the native result | Android Views canonical host; optional Compose adapter later |
| AgentC's HTML components are assumed reusable natively | Large hidden rewrite | Share domain/state first; explicitly author native presentation |
| Long-lived dirty branches mix unrelated changes | Difficult review and regression attribution | Targeted commits/worktrees and pre-commit diff review |
| Device absence is treated as test success | Broken runtime ships | Explicit skipped state locally; required device/emulator lane in CI |

## Physical-device onboarding checkpoint

The phone is not currently visible to ADB. Before the Phase 1 device gate:

1. Enable Developer options on the Android phone.
2. Enable USB debugging.
3. Unlock the phone and accept the computer's RSA debugging prompt.
4. Set the USB connection to file transfer/data if charging-only mode hides the device.
5. Reconnect the cable and verify the phone appears as `device`, not `unauthorized`.
6. Record its Android version, API level, ABI list, model, and serial alias in private test evidence.

No phone setting is needed to continue emulator development, so this does not block the first code fixes.

## Immediate first execution slice

The first implementation session should stay inside AssetPipeline and answer one question: **can today's source and compiler boot a real, interactive Android screen without borrowing an old binary?**

Execute in this order:

1. Fix and validate Android GC/PCRE dependency production.
2. Repair Crystal runtime initialization using the installed standard-library startup sequence.
3. Store `JavaVM` and make JNI reference/thread cleanup real.
4. Rebuild the current arm64 shared library and APK from clean outputs.
5. Add a button-plus-text-input instrumentation smoke test.
6. Run CheckJNI, rotation, relaunch, and leak counters on the emulator.
7. Complete phone ADB authorization and repeat the same APK/test on the device.
8. Capture a proof record containing source commit/diff, toolchain versions, artifact checksums, device facts, test output, and logcat crash scan.

Only after that slice passes should work move into Amber's module boundary or the CLI generator. Otherwise, framework and generator changes would be layered on an unproven runtime.

## Definition of complete

The Android compile target is complete only when all of these statements are true:

- A released AssetPipeline version documents a tested Tier A Android surface.
- A released Amber version exposes a native-safe application facade.
- A released Amber CLI creates a complete web/Android hybrid project.
- A clean generated project builds an arm64 and x86_64 native library, APK, and App Bundle.
- Its actual activity launches and a Crystal-owned state callback updates native UI.
- Emulator and physical-device lifecycle/input/accessibility tests pass.
- The AgentC open-source template demonstrates a real shared domain flow on Android while preserving its web app.
- CI contains no placeholder Android job and no test that hides device failures.
- Release documentation separates supported, preview, placeholder, and unsupported surfaces.

## Primary platform references

- [Android JNI tips](https://developer.android.com/ndk/guides/jni-tips) for `JavaVM`, thread-local `JNIEnv`, and native-thread attachment.
- [Android ABI guidance](https://developer.android.com/ndk/guides/abis) for ABI-specific native libraries and App Bundle/APK split guidance.
- [Android Gradle plugin compatibility](https://developer.android.com/build/releases/about-agp) and [Gradle compatibility](https://docs.gradle.org/current/userguide/compatibility.html) for pinning a supported AGP/Gradle/JDK matrix.
- [Crystal cross-compilation reference](https://crystal-lang.org/reference/syntax_and_semantics/cross-compilation.html) for the object-generation model used before the NDK link step.
