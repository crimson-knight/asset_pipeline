# Android 16 and 16 KB readiness — September 6, 2026

Status: migration/proof in progress, not release-ready. Evidence root:
`/tmp/ap-android36-proof.R9f9EO`.

## Why this is a release gate

Google's current [target API requirement](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
requires new ordinary phone/tablet apps and updates to target Android 16/API 36
from August 31, 2026. The preserved equal-width checkpoint targets/compiles API 35;
the earlier emulator and generated-app results are useful development evidence,
not proof of this current submission requirement. No extension is assumed.

The [Android 16 setup guidance](https://developer.android.com/about/versions/16/setup-sdk)
requires an appropriate newer build plugin as well as compile/target SDK 36.
The migrated pin is AGP 8.13.2, which supports API 36.1 with JDK 17
and a minimum Gradle 8.13 according to its
[release notes](https://developer.android.com/build/releases/agp-8-13-0-release-notes).
Keep Kotlin 2.2.21, NDK 28.2.13676358, native/minimum API 31 and both existing
ABIs initially; verify the current Gradle 9.3.1 combination through actual builds
rather than treating the minimum-version table as complete compatibility proof.

## Installed and isolated

The SDK manager confirms the following newly installed packages alongside,
not in place of, existing SDKs (`sdk-installed.txt`):

- Android SDK Platform 36 revision 2.
- SDK Build Tools 36.0.0.
- `system-images;android-36;google_apis_ps16k;arm64-v8a`, revision 7.

No license-acceptance command was used; installation completed with standard
input closed under existing accepted licenses. The launcher's integer-expression
warning is retained in the log; the installer and subsequent inventory succeed.

The task-owned AVD is `ap_android36_16k_20260906`, data at
`api36-16k-device/`, with separate `avds/` and `android-user/` directories under
this evidence root. It uses Pixel 6 geometry (1080×2400, 420 dpi), the system
keyboard, two CPU cores and 2 GiB RAM, headless on port 5560. Existing AVDs and
their preferences are not changed. Its first boot took **161.804 seconds**;
an earlier bounded boot waiter expired without restarting the AVD. Subsequent
`device.txt` records API **36**, ABI **arm64-v8a** and actual page size **16384**,
fingerprint `google/sdk_gphone16k_arm64/emu64a16k:16/BE2A.250530.026.F3/13894323:userdebug/dev-keys`.
The emulator's own unqualified post-boot ADB preference commands report multiple
emulators; this task uses explicit serials and did not repeat those commands.

## Preliminary package checks

The preserved API-35-targeted equal-width sample APKs in `baseline-package/`
match the completed Android 15 checkpoint byte-for-byte:

- Debug: `d3642d6e7bac96ad84f11987bd144f27cd6b1dcfe1b12b01238e2293e8e843da`.
- Test: `dfc2881af41b1fd8958c730f9ebe06c1acaa6def540d433069680e37e7c5e9e8`.

Both ZIP integrity checks pass. The real packaged arm64 and x86_64 libraries
each have four LOAD segments aligned to `0x4000`; `zipalign -c -P 16 -v 4`
passes on the debug APK. This is alignment evidence, not a claim that the GC,
fiber stacks, native dependencies or application execute correctly on 16 KB
pages. Google's [native page-size guidance](https://developer.android.com/guide/practices/page-sizes)
also requires runtime testing; do not substitute binary inspection for it.

## Preserved target-35 compatibility probe

The frozen debug package cold-launches successfully in **10.455 seconds** as
process **2828**, mounts the real equal-width Crystal/native fixture and has a
visually reviewed screenshot (`baseline-launch.txt`, `baseline-ui.xml`,
`baseline.png`). No 16 KB compatibility dialog is visible. A delayed process-log
read lacks startup markers; that limited log is not claimed as initialization
proof. A subsequent startup-marker precheck stopped before instrumentation.

The actual focused run then uses continuous app-UID log capture:
**17 tests pass in 94.203 seconds**, with normal instrumentation completion and
no failed/skipped status. These cover all four layout contracts, text and
Storage/Secrets/Files. The logs confirm CheckJNI and Crystal initialization
(`probe=42`); no checked native/JVM/callback failure diagnostic is present.
Evidence: `baseline-focused-instrumentation.txt`,
`baseline-focused-live-logcat.txt`. This is real 16 KB execution of a
**target-35** package, not the complete native/failure matrix or target-36 proof.

## Canonical migration in progress

After the full API 31 equal-width gate passed and all 512 inputs were verified,
`config/android_toolchain.env` was changed to compile/target **36**, Build Tools
**36.0.0**, and AGP **8.13.2**. Native/minimum API 31, NDK, Kotlin, JDK, Gradle
and both ABIs are unchanged. The declared Linux CI matrix now includes
**31, 35 and 36**; remote execution remains unperformed. The first migrated
both-ABI/package/JVM build is recorded in `migrated-build.txt`; its outcome is
not yet claimed here.

## Required implementation and proof

1. Finish the in-flight API 31/35 equal-width regressions before changing their
   canonical input pins. Preserve those dated, frozen-package results.
2. Verify the new emulator's API, ABI, fingerprint, actual `getconf PAGESIZE`,
   normal native startup and calling-thread Crystal/GC behavior using the
   preserved baseline package. That remains a target-35 compatibility probe.
3. Update the single canonical toolchain file to compile/target 36, Build Tools
   36.0.0 and a supported AGP; keep native/minimum API 31. Update affected
   generator fixtures, environment/doctor contracts and declared CI matrix.
4. Run fresh both-ABI builds, package/ELF/ZIP alignment inspection, all host and
   native/failure checks, and a fresh actual-CLI consumer on the migrated pins.
   Validate on minimum API 31 and target API 36, preserving API 35 compatibility
   evidence where relevant. Do not patch generated applications manually.
5. Audit Android 16's [target-specific behavior changes](https://developer.android.com/about/versions/16/behavior-changes-16),
   especially mandatory edge-to-edge, predictive Back, large-screen resizing/
   orientation and text behavior. Exercise native windows, keyboard, navigation,
   lifecycle and accessibility; do not claim migration from compilation alone.
6. Make native page-size alignment a mandatory sample/generated artifact check
   and retain genuine 16 KB runtime evidence. Complete independent x86_64 CI,
   physical-phone and release gates separately; nothing here authorizes
   publishing or replaces those requirements.
