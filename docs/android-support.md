# Android support policy — development preview

Status: **development preview**, not a public release. This document is the
release-facing statement the plan's Phase 7 requires: what is supported, what
is preview, what is a placeholder, what is unsupported, and how a consumer is
expected to build and test. Every claim below points at evidence in this
repository or in the dated proof reports.

## Toolchain contract

The single source of truth is `config/android_toolchain.env`. Current pins:

| Component | Pin |
| --- | --- |
| Crystal | 1.21.0 (official) |
| NDK | 28.2.13676358 |
| Native and minimum API | 31 |
| Compile and target SDK | 36 (Android 16) |
| Build Tools | 36.0.0 |
| AGP / Gradle / Kotlin | 8.13.2 / 9.3.1 / 2.2.21 |
| JDK | 17 |
| ABIs | arm64-v8a, x86_64 |
| Native dependencies | bdwgc 8.2.6, libatomic_ops 7.8.2, PCRE2 10.44, pinned by commit and source checksum |

Dependency bundles are identity-keyed by this contract and verified at link
time; a bundle built under a different pin cannot be reused silently
(`scripts/android_deps.sh`). Native libraries are 16 KB page-aligned.

## Validation ladder and what has passed

| Level | Meaning | Status |
| --- | --- | --- |
| L0 host | Crystal structure specs, Kotlin JVM contracts, script contracts | pass (1,461 shared UI examples, 93 JVM tests, 20 entrypoint contracts) |
| L1 cross-compile and link | fresh Crystal object per ABI, verified dependency bundles, ELF inspection | pass on macOS arm64 and Linux x86_64 |
| L2 package | debug APK, test APK, release bundle, symbol and permission checks | pass |
| L3 emulator | 56 instrumentation tests, isolated Crystal, Java and Sheet failure lanes, CheckJNI, tracked-source check | pass on API 31, 35 and 36 (16 KB) arm64 locally; API 31 and 36 x86_64 on GitHub runners; API 35 x86_64 at 54/56 (landscape sheet window focus on that image) |
| L4 physical device | same driver against an authorized phone | **not run**: no phone has appeared in ADB |
| L5 generated consumer | `amber new --type hybrid --targets web,android` from an empty directory, dependencies resolved from GitHub only | pass on API 35 and API 36 from commit pins; **not yet from tagged releases** |

## Surface tiers

See `docs/android-renderer-tiers.md` for the per-view table. In summary:

- **Supported (A core, 34 views)**: text fields, secure fields, text areas
  and editors, buttons, icon, toggle and link buttons, toggles, checkboxes,
  radio groups, sliders, pickers, segmented controls, steppers, combo boxes,
  progress views and activity indicators, dividers, stacks, scroll views,
  spacers, cards, images, navigation stack and links, toolbar, alerts,
  confirmation dialogs, sheets. Each has a native contract suite that runs on
  every API level in the ladder.
- **Preview (B, 8 views)**: activity view, chart, color picker, map, popover,
  snackbar, video player, web view. They render natively in the study fixtures
  and have no behavioral contract; their platform dependencies are not yet split
  from the core target.
- **Unverified (36 views)**: a renderer handler exists but no Android fixture or
  test exercises it. Not a support claim. Promote through a fixture and contract
  suite before naming any of them in release notes.
- **Unsupported (D, 17 views)**: no handler; the renderer raises
  `AndroidRendererNotImplemented` with the view name.

## Platform services

Storage (key/value), protected secrets (Keystore-backed), app-private binary
files, HTTP with platform TLS, local notifications and bundled images are
implemented behind Amber's optional adapters and covered by JVM contracts and
Android tests. Streaming transfers, external documents, cameras, location and
background work are not implemented.

## How a consumer builds and tests

1. Generate or attach: `amber new my_app --type hybrid --targets web,android`
   or `amber target add android` in an existing Amber V2 app.
2. Install the pinned toolchain from `config/android_toolchain.env` and run
   `mobile/android/android.sh doctor`. The doctor names the missing piece; a
   no-device warning is not a device pass.
3. Build with `mobile/android/android.sh build`; test with
   `amber test android --device <serial>`. A missing, unauthorized or offline
   device fails; nothing is skipped silently.

## Physical-device onboarding

Enable Developer options, USB debugging, turn Samsung Auto Blocker off if
present, accept the computer's debugging prompt, and confirm the phone shows as
`device` in `adb devices -l`. Then run the same driver with
`ANDROID_SERIAL=<phone serial>`. Record model, Android version, API level, ABI
list and `getconf PAGESIZE` in the evidence directory.

## Known limits and open gates

- No tagged releases yet: generated apps pin Amber and AssetPipeline to
  commits on the `android-target` branches. Tagging those commits and replacing
  the pins with version constraints is the remaining release step.
- The Linux x86_64 lane depends on emulator speed; the sheet and keyboard
  tests carry ten-second waits for real state and the driver retains a
  screenshot and focus dump when instrumentation fails.
- One host spec crashed once on Linux when raw threads contended on a
  fiber-aware mutex; the identity counter is now lock-free, and the same
  pattern must be avoided anywhere a JVM thread enters Crystal.
- `emulator-5554` on the development Mac has a stalled ADB transport and is
  excluded from every driver.
