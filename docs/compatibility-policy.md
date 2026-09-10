# Compatibility policy: what "supported" means

This is the policy behind `docs/support-matrix.md` (generated) for the four
targets AssetPipeline renders to: web, macOS, iOS and Android. It says which
versions are supported, what that claim rests on, how a new OS release enters
the matrix, and where an app that must run on an older version turns the
dials.

## The middleman

AssetPipeline is the middleman between one Crystal view tree and the
platforms, and the platforms change under it: Android ships a major release
a year and minor SDK releases in between (36.1, 37.0, 37.2), the Android
Gradle plugin, Gradle, the NDK and Kotlin each move on their own clocks, and
Apple ships Xcode and the OS betas every summer. The policy is that this
churn is absorbed **here**, once, with proof, and never spelled out in a
consumer:

- Every Android version is a pin in `config/android_toolchain.env`. The
  sample host, the Amber CLI's generated projects and the AgentC template
  read that file through their `settings.gradle.kts` and never carry a
  version of their own. A consumer moves to a new toolchain by moving its
  shard pin, not by editing Gradle.
- The Apple floors are the iOS deployment target in the iOS host's
  `project.yml` and the platform floors in `swift/AssetPipelineSwiftKit/Package.swift`.
- The Crystal compiler every lane installs is `CRYSTAL_ANDROID_VERSION`; the
  Apple lanes additionally install the fork named in `config/apple_toolchain.env`,
  the only compiler with the iOS targets (`docs/apple-ci.md`).

A consumer that overrides a pin (a lower `targetSdk` in its own
`android-app.properties`, say) is allowed to lag by one release and is on
its own nightly to prove it still builds.

## Three tiers of support

A version is one of:

1. **Proven**: it has a dated row in `config/support_proof.yml`, which means
   a real device or a real runner executed the full gate on it
   (`make test-android` with every device test and both failure lanes; the
   iOS host's UI tests on a simulator; the web specs).
2. **Exercised**: a CI lane runs it on every push and every night. Exercised
   lanes are the matrix in the workflow; the support matrix lists them with
   their role (the floor, the target, the newest release).
3. **Declared**: it lies between the floor and the newest exercised lane and
   nothing runs on it. It is supported by policy because the platform
   promises forward compatibility inside that range, and a report of a
   defect on such a version adds a lane, not an exception.

"Supported" without a qualifier means at least declared. A support claim in
a sales conversation should say proven.

## Android

- **Runtime range**: `ANDROID_MIN_SDK` (31, Android 12) through the newest
  exercised lane. The floor is a decision, not a drift: it moves only when
  a customer need or a platform requirement says so, and the change is a
  commit to the env file with the reason in its message.
- **Compile and target**: `ANDROID_COMPILE_SDK` and `ANDROID_TARGET_SDK`
  (36 today). A runtime above the compile floor (Android 17 today) is
  exercised on its own lane because a new runtime changes behavior even for
  apps that target the previous one; that lane passing is what allows the
  claim "runs on Android 17".
- **Native floor**: `ANDROID_NATIVE_API` (31) is what the Crystal libraries
  link against; it stays at the min SDK.
- **Platform APIs newer than the floor** are gated in the runtime by
  `Build.VERSION.SDK_INT` at the call site (see `android/runtime`), never by
  raising the floor. An app that must run on an older version than the
  floor is not a flag away: the floor is the oldest version the runtime is
  written for.

### How a new Android release enters

1. **The day a system image exists** (`sdkmanager --list` shows
   `system-images;android-<version>;google_apis;x86_64`): set
   `ANDROID_NEXT_RUNTIME` in the toolchain env to it. The nightly
   `android-next.yml` lane then says whether the new runtime, or its image,
   breaks the gate, with the release still weeks from phones, and without
   touching the pull-request check. When that lane has been green long
   enough, the version joins the matrix as a string (`'37.0'`) and the
   next release takes its place.
2. **When it is stable and the behavior changes are audited** the way Android
   16 was (`docs/android-36-readiness.md`, `docs/android-36-proof-2026-09-06.md`):
   bump `ANDROID_COMPILE_SDK` and `ANDROID_TARGET_SDK`, with the build tools
   and, when needed, the plugin, Gradle, NDK and Kotlin pins, in one commit
   that the matrix proves.
3. **Consumers** follow by moving their shard pin; the generated support
   matrix in each consumer's own lane shows the lag.

Minor SDK releases (36.1, 37.2) are lanes only when they carry behavior
changes an app can observe; the major release is the lane by default.

## Apple

- **Floors**: iOS 26.0 for the iOS host (it uses the iOS 26 SwiftUI
  hosting lifecycle); SwiftKit compiles for iOS 16, macOS 13, watchOS 10.
- **Runners**: the standard GitHub macOS runners are free on public
  repositories. `macos-26` is the current image (Xcode 26.6, iOS 26.5
  simulator); `xcode-27` is the preview image (Xcode 27 beta, iOS 27.0
  simulator). `macos-14` is deprecated and must not be used.
- **How a new Apple release enters**: the preview image gets a lane the day
  GitHub publishes it, so the bindings meet the next Xcode and OS before
  they ship; when the release is final the preview lane becomes the current
  one and the deployment target is raised only by decision.

## Web

- Crystal `>= 1.10.1` by the shard; the lanes install
  `CRYSTAL_ANDROID_VERSION` (1.21.0). The web specs run on `ubuntu-24.04`
  in the Android workflow's host-contracts step and are the Linux proof.

## When a lane fails

Every continuous workflow ends in a `report` job that runs
`scripts/ci/report_outcome.sh`: a failing lane opens one issue labeled
`ci-failure` and `lane:<lane>` that mentions and assigns the maintainers
(the repository variable `CI_MAINTAINERS`, or the repository owner), a
persisting failure comments on that issue, and the next passing run closes
it. Pull requests are excluded; they carry their own checks. A flaky lane is
a defect to name and fix, not to mute: no lane uses `continue-on-error`.

## Keeping the matrix honest

`docs/support-matrix.md` is generated from the pins, the workflows and the
proof ledger; CI fails when it is stale. A version that is not in the pins
is not declared; a lane that is not in a workflow is not exercised; a row
that is not in `config/support_proof.yml` is not proven.
