# Android navigation checkpoint — September 5, 2026

Status: **development progress; full Android compile-target goal remains active**.
See [the bounded navigation contract](android-navigation.md) for API ownership,
host integration and explicit limitations.

## Implementation

- Native `NavigationLink` now pushes onto its enclosing retained Crystal stack.
  `NavigationStack` renders a real Material toolbar and current screen. Toolbar
  Up is a tracked callback, with an Android-localized description and theme tint.
- Render-visible Crystal scopes choose nested Back priority and reject stale
  links/toolbar actions before the deferred refresh. No Activity, Context,
  JNIEnv or native view is retained by this navigation state.
- Canonical `NativeNavigation` installs a lifecycle-owned AndroidX Back callback,
  synchronized immediately after mutations and after each mount. It is disabled
  at root, so normal system exit/background behavior remains available.
- The new main-looper JNI query/commit uses checked GC entry and a contained
  Crystal failure status. Both canonical sample and generated hosts use it.
- The CLI counter now includes a native details screen reading its shared
  counter/name state. The generated test exercises both real toolbar Up and
  system Back. Both ABI artifact inspectors require the new navigation exports.

## Completed initial native proof (before predictive-Back manifest opt-in)

`/tmp/amber-android-navigation-proof/native-final`:

- **21 Crystal navigation examples**, including six new scope/ownership cases
  and the existing 15 NavigationCoordinator cases. The coordinator itself is
  not yet connected to Android; its tests are regression coverage only.
- **47 focused Crystal examples** when the existing callback registry suite is
  included; **eight image-compiler examples** and **58 JVM tests** also pass.
- **18 Android tests in 104.12 seconds**, all passing on API 35 ARM64. The new
  native navigation contract covers links, disabled links, nested Back priority,
  toolbar Up, shared state, retained drafts, recreation, repeated stack resets,
  root Back and same-process reopening.
- A real visible keyboard receives the first Back without popping the screen.
  AndroidX gesture start/progress/cancel leaves the stack unchanged. The latter
  tests dispatcher cancellation, not a recorded physical predictive gesture.
- Five repeated details/settings/reset loops return native references and
  callbacks to the exact root baseline; closing returns both counts to zero.
- Existing text/composition, image/theme/layout and storage/Keystore/files
  platform regressions pass. Host C backend and all **1,112,064 Unicode scalar**
  sanitizer round trips remain clean. No CheckJNI or app crash diagnostics.
- A separate ordinary process, PID **14241**, cold-launches the original native
  interaction screen after instrumentation. This is not navigation process-death
  restoration proof.

Final debug APK SHA-256:
`1acb7c4c457014865718c8b0c16defde4778a7ad168d6fd7e20ad7824765e34f`.
Final test APK SHA-256:
`d828c0f1ff39f90d6d8e02f48302a860ed68f9f811960a3b6b593535fd53e91c`.
Final release AAB SHA-256:
`ebc0bdacbd51af77c99c85a41ca8315c3bbfd3f6c4219301b0a4ca8d8b3d2a87`.
Source-ledger SHA-256:
`43fede7f6caca79c3df680b9c33265eb410f57bba9f51061869beb886b1492d4`.
Both ARM64 and x86_64 libraries are packaged; runtime proof is ARM64 only.

## Attempts retained

- `native-first` failed compilation because the fixture reused `UI::View`'s
  `@id` string field for a symbol screen identifier. Renamed to `@screen_id`.
- `native-second` failed compilation because NavigationLink has no Button-style
  `disabled=` property. The fixture now uses its existing `:not_enabled` trait.
- `native-third` passes **13 Android tests in 43.785 seconds** (navigation plus
  12 platform tests), before adding the keyboard/cancellation/hidden-scope cases.
  The full final run above supersedes this focused proof.
- `native-ime-verified` strengthens the first-Back assertion to require the
  keyboard to become hidden. That assertion passes, but the run fails later at
  toolbar Up: logcat explicitly reports `Overslept and turned a tap into a long
  press`, with a Tooltip window and no click callback. The canonical test now
  activates the real toolbar button through Android's accessibility click action.
- This inspection also found `OnBackInvokedCallback is not enabled` warnings.
  Both host manifests now explicitly opt in. Generated debug/release inspection
  requires the enabled flag in the actual compiled manifest, not only template text.
- `native-predictive-final` passes navigation/keyboard/toolbar behavior but fails
  an immediate lifecycle assertion after root Back. With predictive Back enabled,
  the live view disappears before the animation completes and `onStop` fires.
  The test now waits for the actual stopped/destroyed lifecycle state with a
  bounded deadline; it does not add a fixed animation sleep or accept STARTED.

## Final native proof with predictive Back enabled

`/tmp/amber-android-navigation-proof/native-predictive-verified` passes all
**18 Android tests in 104.793 seconds**, plus the same 58 JVM, 21 navigation,
eight asset-compiler and sanitizer-backed C checks. The keyboard visibility
assertion, native toolbar accessibility action, cancelled gesture, nested Back,
recreation, five reset cycles and bounded root-stop transition all pass. Native
references/callbacks clean up, and the app-specific log has no missing-opt-in,
CheckJNI or crash diagnostics. The ordinary post-test launch has PID **15853**.

Final native debug APK SHA-256:
`9ff298b9bd987f94af4eac2c377e6245c9a5432b15d2e132d8c5cea6bec46e11`.
Final native test APK SHA-256:
`37355568048e8f21b57255de872108a37eb8f3e56d279ee3aad4b311b0835b70`.
Final native release AAB SHA-256:
`760a402416e87e2993caa58d765e51e6801f2fed480d8c00d7ba331af0eca69e`.
Source-ledger SHA-256:
`544e6936acb3389108087c54c8c2c2671efdd21ac295ffb805aead49e10f308e`.
These follow-ups modify the sample test and host manifest, not the underlying
Crystal navigation implementation.

## Initial fresh consumers (before manifest opt-in)

The wording-corrected CLI is `/tmp/amber-android-navigation-proof/amber-final`, SHA-256
`f5c61220f8506b2673343824ae73da9931e0be1946074da71eeb77710e8d73b6`.
Its **159 generator/configuration examples** pass, including host installation
and emitted native stack/link assertions. Crystal formatting, targeted whitespace
and shell-syntax checks pass.

The first fresh runtime run passed at
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.2F4SB7`.
It used the preceding CLI `/tmp/amber-android-navigation-proof/amber` (SHA-256
`8358e9207b88eaa05033a64531347b55d84ab63f7649e2dfdaef2bc4dcc0ce61`).
Two shared examples, real web/validation/CSRF/escaping checks, 58 JVM tests,
13 Android tests (31.886 seconds) and a separate one-test restoration run
(4.853 seconds) pass. All 696 source entries remain unchanged: 36 generated,
242 Amber and 418 AssetPipeline. PID 14388 saved count 7 and the Unicode name;
PID 14516 read it exactly, and PID 14568 cold-launched the app. Its native
details screenshot was inspected. This is local-development resolution, not
released-consumer proof.

The subsequent final CLI changes only explanatory screen text to say that web
and Android share model code, not a synchronized database. Its completed fresh run is
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.ODQelx`.

- Two shared examples and actual web/validation/CSRF/escaping checks pass.
- **58 JVM tests**, **13 Android tests (33.054 seconds)** and the separate
  **one-test exact-state restoration run (5.153 seconds)** pass.
- All **696 source entries** are unchanged before/after: 36 generated, 242 Amber
  and 418 AssetPipeline. No generated-source repair was made. Explicit local
  Shards overrides are used; this remains the development lane.
- PID **14750** saves count **8** and `Android 雪 😀 é`; read-only PID **14873**
  verifies that exact state. A final cold launch (PID **14924**) restores it.
  The new details screen was subsequently opened and visually inspected, showing
  the same count/name and the corrected local-data explanation.
- Both ABI exports/debug symbols, image catalog and resource-table payloads,
  debug/release permission policy and CheckJNI/runtime diagnostics pass.

Final consumer debug APK SHA-256:
`060243b5e5c86d882dd77f03d4620e9893043c480d60acc3725cb294dd049801`.
Unsigned release APK SHA-256:
`a1698cea4720e072234fb0f5095c967e01b83ea1963f5d21b9ae864b9a75e01c`.
Release AAB SHA-256:
`4a8b48be39e4e6af5b3312deadbeac6de23bb404b462dcb67b36567362bbb5b4`.
The final inspected screenshot is
`/tmp/amber-android-navigation-proof/generated-details-final.png`.

## Final predictive-Back generated consumer

The final CLI is `/tmp/amber-android-navigation-proof/amber-predictive-final`,
SHA-256 `02cf5f861abe3c0f1798e6bbd463820268e8664e1f24bacdaffa68e9ca5c5242`.
All 159 generator/configuration examples pass, including explicit manifest
opt-in and required packaged-manifest checks. The native test uses the real
toolbar's accessibility click; links still use touch and Back uses the system.

Its completed fresh run is
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.kl4FDv`.

- **Two shared examples**, actual web/validation/CSRF/escaping checks,
  **58 JVM tests**, **13 Android tests (33.369 seconds)** and a separate
  **one-test exact-state restoration run (5.162 seconds)** all pass.
- All **696 source entries** are unchanged: 36 generated, 242 Amber and 418
  AssetPipeline. No generated-source edits or repairs were made.
- Both compiled APK manifests explicitly contain
  `enableOnBackInvokedCallback=true`; both ABI exports/debug symbols, image
  payloads and explicit permission gates pass.
- PID **16060** saves count **9** and `Android 雪 😀 é`; read-only PID **16194**
  verifies that exact saved text and count. Final cold-launch PID **16245**
  shows them with the bundled image and details link. Its screenshot was
  inspected and the generated app remains foreground on `emulator-5556`.
- This uses explicit local development Shards resolution. It does not satisfy
  the public-release/released-consumer gate. The physical phone is still absent
  from ADB; the existing visible `emulator-5554` was left intact.

Final predictive consumer debug APK SHA-256:
`66f58ad31078f001de21709647e3f531dcf36bda22927ce7dd75ae51b0f9b1e3`.
Unsigned release APK SHA-256:
`816b82e8070c4d0e9747a32056b9c6b391df020c3fb1595d3b8e5c0264b045df`.
Release AAB SHA-256:
`1142570c4dcc0b46a0ecbb674b54abc95bda98906b52ed09a72ba9c8f7d20b94`.
Final screenshot: the fresh run's `android-runtime/relaunch.png`.

## Remaining full-goal work

This is not full Tier A navigation certification or a public release. Route
process restoration, NavigationCoordinator integration, active-pane/hidden-
ancestor selection, accessibility/RTL/theme/tablet coverage, deep links and modal
priority remain explicit gaps. Broader renderer layout/reconciliation and JNI
exception/failure cleanup, CLI metadata workflows, AgentC's three reference
screens, API 31/x86_64 runtime, physical phone, CI/signing/public release and
released-consumer proof also remain open.

The AgentC checkout was inspected read-only during this milestone. It already
has unrelated changes in registration/settings/web tests. Its controller test
helper truncates user tables: establish an isolated test database before running
those tests, and preserve the existing changes during native migration.
