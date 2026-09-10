# Android dependency provenance and reproducibility — 2026-09-04

**Development dependency milestone passed on the current Mac toolchain. Full
Android goal remains active.**

This advances the dependency gates in the
[implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md), following
the [generated consumer milestone](android-generated-consumer-proof-2026-09-04.md).
It does not establish public releases, physical-device/x86_64 runtime support,
the full core UI, native services or AgentC template completion.

## Correctness gap fixed

The previous Android cache used only `android-arm64`/`android-x86_64` directory
names. Existing archives were skipped, then the manifest was rewritten using
the requested API/toolchain. That could relabel old binaries without rebuilding
them. Native linking inspected architecture/symbols but did not enforce the
manifest's provenance.

The new builder publishes:

```text
<cache>/android/<abi>/api-<native-api>/<contract-sha256>/
  android-deps.manifest
  files.sha256
  lib/                  # GC, CORD, PCRE2-8 and PCRE2 POSIX archives
  include/
  licenses/
```

The key covers ABI/API, pinned source commits and archive SHA-256, NDK tool
hashes/revision/host, build-tool versions, fixed build environment/options and
recipe file hashes. Both the builder and linker validate it. Headers, libraries
and license texts have a complete independently regenerated checksum inventory;
manifest paths are never evaluated as shell code. Non-regular headers and
symlinks are rejected.

Old flat caches remain on disk but are not accepted. A corrupted bundle is
retained with a failure diagnostic, not silently relabeled or trusted. A new
recipe/API gets a separate entry. A per-entry lock and same-filesystem rename
keep partially built bundles out of the usable cache, with a second existence
check after acquiring the lock to handle concurrent publication safely.

## Source and build contract

Upstream tag targets were verified read-only:

| Source | Version | Commit |
| --- | --- | --- |
| [Boehm GC](https://github.com/ivmai/bdwgc/tree/v8.2.6) | 8.2.6 | `e340b2e869e02718de9c9d7fa440ef4b35785388` |
| [libatomic_ops](https://github.com/ivmai/libatomic_ops/tree/v7.8.2) | 7.8.2 | `4c00f978cbafe4eb76929dace4ba8f456e800fec` |
| [PCRE2](https://github.com/PCRE2Project/pcre2/releases/tag/pcre2-10.44) | 10.44 | `6ae58beca071f13ccfed31d03b3f479ab520639b` |

The checked-in SHA-256 values identify
`git -c tar.umask=0022 archive --format=tar <commit>` with no prefix. A mutable
tag must still match the pinned commit and source checksum. Builds extract
those verified archives, not a possibly dirty source checkout. Cached source
archives are verified before use.

The native build runs with a clean environment, fixed locale/timezone/epoch,
explicit NDK C/C++/archive tools, and normalized source/build paths. Injected
host include/library/configuration settings cannot enter configure or CMake.
The library/header payload is relocatable; generated CMake/Libtool metadata
containing temporary install paths is not published as part of that payload.
Native bridge compilation/linking also clears inherited host include/link flags.

The API suffix is explicitly part of the target compiler selection, following
the [NDK other-build-systems contract](https://developer.android.com/ndk/guides/other_build_systems).
An explicit NDK override must still match the pinned revision.

GC uses POSIX threads and compiler built-in atomics explicitly. The atomic_ops
source/license pin is retained, but no separate atomic_ops object is linked in
this recipe. This is recorded rather than pretending it is a compiled archive.
The current pins are a tested development baseline, not a dependency security
audit or recommendation to skip release-time vulnerability/version review.

## Independent-build evidence

Runner: `scripts/tests/android_dependency_reproducibility.sh`.

Evidence: `/tmp/ap-android-dependency-proof.bTzNdZ`.

The runner created two empty roots and fetched sources independently. The second
build deliberately inherited invalid host CFLAGS/CPPFLAGS/LDFLAGS, CPATH,
LIBRARY_PATH, CMAKE_PREFIX_PATH and CONFIG_SITE. Both complete published
payloads and their manifests were byte-identical for ARM64 and x86_64.
Recipe hashes matched before/after the run.

| ABI / native API | Contract SHA-256 | Manifest SHA-256 |
| --- | --- | --- |
| ARM64 / 31 | `b925f55e82d22fab1283622f7c72f3a410742de644ca551404877b7afeb00bc5` | `42beab3111c1403b9065ab8039ef0ff16c50b75f048dd1424e6d734a7985da9f` |
| x86_64 / 31 | `20293085a0f2b639caccaadd937462ae03d3e38c7f279091613e7690eea7905c` | `0f4bb7bc657c5cfe5876927a17aebae7853a739f1cced667615c2acfe9bc9dd4` |

Recipe-manifest SHA-256:
`1cf1814b4475914dfa4c85af839083f144da7bfe2ff6640a74b2e878bccab358`.

Validation included 18 negative cases: altered headers, empty archives, stale
manifests, incomplete bundles, symlinks/non-regular headers, legacy flat caches,
wrong API and ABI, changed source and recipe, unpinned versions, wrong NDK,
invalid/below-baseline APIs, unsupported ABI and corrupt source downloads.
The real native linker was required to reject a missing API-specific bundle
before creating its output directory. The original valid cache stayed unchanged.

Separate archive tests passed for valid, empty, mixed-architecture, exact-symbol
and missing-file cases. All four archives are validated for their actual target
architecture and required exported symbol before publication and linking.

Observed host tools: NDK 28.2.13676358, CMake 4.1.2, GNU Make 3.81, Autoconf
2.72, Automake 1.18.1, GNU Libtool 2.6.2, Crystal 1.21.0. The byte-identity claim
is for this host/toolchain, not arbitrary machines, different NDKs or APIs.

## Runtime regression and keyboard finding

The current dependencies were linked into the real Android host, not tested
only as archive files. Final host evidence:
`/tmp/ap-android-dependency-proof.bTzNdZ/runtime-adjust-resize`.

The full three-test ARM64/API 35 suite passed in 27.952 seconds, including
runtime/fiber startup, eight worker initialization attempts, character-by-
character input, same-editor identity/focus, callbacks, five recreation cycles,
reference cleanup, theme/system bars, logical density and text scaling. CheckJNI
and a separate process launch also passed (observed relaunch PID 9189).

One prior final-candidate run failed while typing the first character because
the focused editor's visible rectangle was empty during keyboard opening.
That failed result is retained under `runtime` in the same evidence root.
The host and generator now explicitly request `adjustResize`. The host test
waits for the actual IME and asserts the entire focused editor is above it
before sending real keystrokes; it does not substitute programmatic text setting.
This follows [Android's keyboard/insets guidance](https://developer.android.com/develop/ui/views/layout/sw-keyboard).
This is not full Unicode/composition or keyboard-navigation support.

## Fresh generated consumer with the final dependencies

The latest actual CLI binary generated another empty-directory hybrid app and
passed the complete development E2E runner:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.ydiGP5`.

Its web state/validation/CSRF/escaping checks, shared Crystal spec, debug and
unsigned release APKs, App Bundle and Android interaction/recreation test passed
(`OK (1 test)`, 9.852 seconds). The artifact inspector now retains and checks
per-ABI dependency receipts. Their manifest hashes exactly match the independent
builds above. All 644 generated/Amber/AssetPipeline source entries matched
before/after the run. The final CLI regression suite passed 156 examples.

| Fresh consumer artifact | SHA-256 |
| --- | --- |
| CLI binary | `ae3a3e0822d44fa15511dcf981647a5df85379fb90ffff8113c192ad07e7a9b7` |
| Debug APK | `34775566d6fada230a4898b33fa3d367c3330a1e72a7e3ad1b6ecc050e7b0157` |
| Unsigned release APK | `e422969a58d8af7e1e43a42bc8460ad8c7b764c7191d4f497968abbba6d2d3e3` |
| App Bundle | `d2b1821164afc45b7fe1f5b9cf8c4dd657be7adc115ca8e8f88dd381184ded0c` |

CounterApp was left open in the emulator after a separate launch (observed PID
9436). No build/test process remains running at this checkpoint. The SDK tools
still list no physical phone; x86_64 is built/inspected but not executed.

## Reproduce and resume

```bash
JOBS=4 bash scripts/tests/android_dependency_reproducibility.sh

CRYSTAL_CROSS_DEPS=/tmp/ap-android-dependency-proof.bTzNdZ/first \
CRYSTAL_CACHE_DIR=/tmp/ap-android-crystal-cache \
bash scripts/run_android_smoke.sh emulator-5554
```

Use the newly printed cache path from a new proof run; temporary directories may
be removed by the OS. Work/source directories and logs are retained, not cleaned
automatically. Do not delete a live build lock; inspect the reported builder
process first, or choose a new cache root.

The remaining goal includes safe CLI target/metadata management, Android
lifecycle/service adapters, complete Tier A renderer/IME/accessibility behavior,
AgentC migration, CI/other-platform regressions, physical phone and x86_64/API
runtime matrices, signing, security/version review, public releases and clean
released-consumer proof. None is waived by this dependency milestone.
