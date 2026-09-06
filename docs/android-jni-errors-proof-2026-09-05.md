# Checked JNI checkpoint — September 5, 2026

Status: **verified development progress, not full Android target completion**.
See [the implementation contract](android-jni-errors.md) for ownership, fallback,
diagnostic privacy and the explicit remaining safety scope.

## What changed

- The native View/collection bridges now use a common explicit checked JNI
  operation layer. **322 View bridge calls and 40 collection bridge calls** were
  mechanically converted; raw cleanup/exception operations remain direct.
- Crystal forwarding methods are generated from the existing lib declarations,
  with pending-error checks before/after non-cleanup calls. A pending Java
  exception unwinds Crystal-owned partial views, then reaches Android as the
  original Throwable rather than a replacement exception.
- Optional fallback paths now accept only the expected missing class/member or
  intent-handler error. Existing exceptions, constructor/setter failures and
  errors encountered while checking a fallback are preserved.
- Text conversion allocation/size failures now set an explicit Java error.
  Native collection creation/batch calls validate count/pointer relationships
  and stop iterating after a Java exception.
- Application render/lifecycle/service exception diagnostics now report only
  the error class, with a fixed guarded diagnostic fallback. Private app error
  messages and backtraces are not formatted into this logger.
- The normal native regression includes a sanitizer-backed checked-JNI host
  test and a gate against raw non-cleanup calls. Separate actual-Android tests
  cover eight Java failure types after partial native view construction.
- Generated APK inspection requires `android_exception_pending` in both ABIs.

## Final native proof

Evidence: `/tmp/amber-android-jni-proof/native-final`.

The clean lane at `crystal-failures/positive` passes **60 JVM tests, 18 Android
tests in 85.334 seconds, 30 Crystal callback/registry examples, 21 navigation
examples and eight asset-compiler examples**. Existing text, input, image/layout,
navigation, recreation and private storage/secrets/files checks remain green.
The C file-backend and all 1,112,064 Unicode scalar sanitizer round trips pass.

The new host sanitizer test passes **all 31 checked operation entrypoints**
against a mock JNI table, plus invalid throwing-result rejection, invalid null
receiver handling, expected-only fallback and original-error preservation when
fallback inspection itself fails. It compiles against the pinned NDK's isolated
JNI header; it is host evidence, not a substitute for the real VM tests.

The six isolated Crystal failures also pass, in processes **19426, 19488, 19542,
19597, 19652 and 19709**. Each performs 100 immediate partial-render cleanup
checks, followed by terminal-session/rejected-reuse and final zero-resource
assertions. Their durations are 6.061, 5.269, 6.255, 6.391, 6.625 and 5.375 seconds.

The actual Java test passes in **8.194 seconds**, process **19824**:

- **400 partial native render failures**: 50 each for missing View class,
  missing TextView method, throwing Java constructor, throwing text setter,
  missing collection element class, list index out of bounds, null required
  receiver and an existing exception entering optional fallback helpers.
- Every probe immediately restores the exact pre-probe global-reference and
  callback counts, without forcing a garbage collection.
- A final public `CrystalBridge.renderStudy` with a throwing Context preserves
  the original Throwable by identity, marks the session `FAILED`, rejects reuse
  and permits ordinary Activity cleanup/explicit close with zero references,
  callbacks and pending services.
- CheckJNI and runtime probe 42 are present. The only application error line is
  `Crystal application error: UI::Android::PendingJavaException`. There are no
  native/CheckJNI crashes, uncaught JVM exceptions or private Java message markers.

A separate normal process **19876** then mounts the ordinary native interaction
screen with clean diagnostics. Both ARM64 and x86_64 libraries are packaged;
runtime proof here is API 35 ARM64. A release DEX inspection also confirms that
the three deliberate throwing JVM fixture classes are absent from the release
bundle; they belong to the sample debug source set, not generated app runtime.

Debug APK SHA-256:
`a2ae0fec455b889b61c099291823aec785f643748b83f466a508249dbd58a492`.
Test APK SHA-256:
`789f921c18e623c551d9bcd0ea4d592a882950c495dda53aaa19399f934ff0da`.
Release AAB SHA-256:
`e47611e0e9ff63dbb05c0f41b935fe9bc306aef6bf8f5100c9c36d308d42dd41`.
Source-ledger SHA-256:
`46bd024ff6e6221567aeb71230eac9e557b5f6457f6a0329f4de9b78226a7ec7`.

## Retained earlier attempts

- `compile-first` fails because a nested Crystal macro was evaluated by the
  outer Android compile-flag macro. The macro body required deferred expansion.
- `compile-second.log` and `compile-third.log` expose that the attempted
  module-level missing-method forwarding does not supply the required module
  methods. It was replaced with explicit methods generated from lib declarations.
  A clipboard call-site rewrite initially used the wrong working directory and
  made no edit; the eight exact call sites were subsequently updated correctly.
- `compile-fourth.log` catches assigning a C `Void` result. Generated forwarding
  now treats void-returning calls separately. `compile-fifth.log` successfully
  builds both native libraries before the new Java fixtures are added.
- `native-first` passes the full clean/Crystal/Java runtime sequence, including
  the 400 Java probes in 7.299 seconds, process 18857. It predates adding the new
  host guard test to the normal runner and is superseded by `native-final`.
- The host guard test initially assumed the Android Studio runtime included JDK
  JNI headers. They are absent there. The final test uses only the pinned NDK's
  VM-neutral JNI header, preserving the host system's own standard headers.

## Fresh consumer proof

The rebuilt actual CLI is `/tmp/amber-android-jni-proof/amber`, SHA-256
`ad7168a117629dea7f72677d03e85aeac1cae60fa6b7e5d010e8b276d3183ec5`.
All **159 generator/configuration examples** pass.

Completed fresh consumer:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.qiah6X`.

- **Two shared examples**, actual web state/validation/CSRF/escaping checks,
  **60 JVM tests** and **13 Android tests in 29.508 seconds** pass.
- A separate read-only exact-state restoration test passes in **4.035 seconds**.
  Process **20018** saves count **11** and `Android 雪 😀 é` (the final accent
  remains decomposed); process **20146** verifies the exact state. A final normal
  cold launch, process **20197**, restores it and remains foreground on
  `emulator-5556`.
- All **703 source entries** are unchanged before/after: **36 generated,
  242 Amber and 425 AssetPipeline**. No generated source repairs were made.
- Both ABI exports, including the new checked-JNI status symbol, matching
  native debug symbols, bundled image resources, explicit permission policy and
  compiled predictive-Back manifest opt-in pass package inspection. Interaction,
  restoration and final-launch logs have no application/callback/CheckJNI errors.
- The final `android-runtime/relaunch.png` was visually inspected: the real
  native counter, image, Unicode name field, save action and details link render.

Consumer debug APK SHA-256:
`bf71b115cccafbc275bdc4ac5bc6920f831a84248399d3aad5f1681781df9482`.
Consumer unsigned release APK SHA-256:
`569f564a1443f9f4e1d4f470cca5187006ba42b95c607a56a089fc99a7a7beaf`.
Consumer release AAB SHA-256:
`158c23030a03c2460150f685fc990a1bd4cb060d966a9734251c82212cc1311b`.

This remains explicit local-development Shards resolution, not a public-release
or released-consumer gate. The deliberate Java failures run in the canonical
sample; the fresh consumer proves normal integration using those same runtime
sources. A fresh ADB inventory still shows only the two emulators, not the
physical phone. The original visible `emulator-5554` was left intact.

## Remaining full-goal work

This is not universal native error recovery or Tier A certification. Direct
platform-service/async completion policy, bootstrap/cleanup/allocation failure
coverage, renderer layout/reconciliation/focus/accessibility/themes/modals,
route process restoration, CLI metadata workflows and AgentC's three reference
screens remain open. Full API/ABI/phone/tablet matrices, the physical phone,
CI/public releases and a released-dependency consumer remain required by the
[complete implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md).
