# Native compile matrix (Phase 10C.0)

**Date:** 2026-05-25
**Branch:** `phase-10-c-0`
**Discovery scope:** best-effort attempt per `architecture-decisions.md` Decision 5.
**Android update (2026-09-04):** The Android host-only conclusion below is
superseded by the [current runtime proof](../android-runtime-proof-2026-09-04.md).
The macOS/iOS entries remain historical and were not reverified by that work.
**Android CI update (2026-09-06):** The former ignored Android placeholder has
been replaced by the real [native validation entrypoint and declared CI lane](../android-ci.md).
Local workflow/host checks are not evidence of an executed remote CI matrix.
Each platform is tested with the canonical command from CLAUDE.md Build & Test +
Native App Development Workflow sections. Outcome is one of three statuses:

- `verified` — command runs end-to-end; documented command is canonical.
- `attempted-blocked` — first actionable error + remediation owner documented.
- `deferred-not-attempted` — explicit "not run; deferred to <phase>" rationale.

## Toolchain probed

| Tool | Version | Path |
|---|---|---|
| `crystal` (release) | 1.20.0 (2026-04-16), LLVM 22.1.3 | `/opt/homebrew/bin/crystal` |
| `acrystal` / `crystal-alpha` | 1.20.0-dev (2026-02-18), LLVM 21.1.8 | `/opt/homebrew/bin/acrystal` (same binary as `/opt/homebrew/bin/crystal-alpha`) |
| `clang` (Xcode) | Xcode 26.5 build 17F42 | `/usr/bin/clang` |
| `swift` (Xcode) | Xcode 26.5 | `/usr/bin/swift` |
| iOS SDK | iPhoneOS26.5.sdk | `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk` |
| Android NDK | NOT INSTALLED | `$ANDROID_HOME` unset |

`acrystal` is the binary name per `[[reference_agent_crystal]]`. The legacy
`crystal-alpha` name is still aliased at `/opt/homebrew/bin/crystal-alpha` on
this host (verified — same SHA on Homebrew tap `crimson-knight/agent-crystal`).
CI workflows reference `crystal-alpha`; downstream rename to `acrystal` is a
cosmetic follow-up.

## Status summary

| Platform | Status | First-error / next remediation |
|---|---|---|
| web (default `crystal`) | `verified` | `crystal spec spec/web/` runs the 117-spec lane. |
| macOS (`acrystal -Dmacos`) | `attempted-blocked` (two distinct blockers) | (1) Spec-entry require: AX specs need `require "../../src/ui"` ahead of `require "../../src/ui/ax_test"` so `callback_registry.cr` `fun crystal_ui_*_callback_dispatch` defs are linked into the binary (objc_bridge.o references them). Probe verified; applied to the 14 native_macos specs during migration. (2) C collection bridge: `src/ui/native/objc_collections.cr` declares `lib LibCollectionBridge { fun nsstring_to_utf8(...); fun objc_add_subviews_batch(...); ... }` but the implementing C/Obj-C source (`collection_bridge.c` / `.m`) is NOT in the repo. `make test-macos` link step fails with ~40 undefined symbols. Sample apps under `samples/cross_platform/macos_host/` link successfully today, implying the bridge .m lives outside `src/ui/native/` or is implemented by a downstream sample. Remediation: locate or stub the C trampolines. Deferred to a follow-up native-runner phase. |
| iOS (`acrystal -Dios`) | `attempted-blocked` (cross-compile libgc missing) | Linker pulls `/opt/homebrew/Cellar/bdw-gc/8.2.12/lib/libgc.dylib` which is macOS-built. iOS path needs cross-compiled `libcascade.a` flow per `samples/initiative-cross-platform-ui-demo/ios/build_crystal_lib.sh` — not a single-binary `acrystal spec` flow. Remediation deferred to 10C.1 or a follow-up runner phase. |
| Android (Crystal 1.21.0 + explicit Android target + NDK) | `verified` for dual-ABI cross-build/package and ARM64 emulator smoke | Use `scripts/run_android_smoke.sh <serial>`. Physical-device proof, x86_64 runtime, the complete component surface and CI remain open. |

## macOS — `attempted-blocked` (one-line spec fix path)

### Command attempted

```bash
# 1. Compile the ObjC bridge.
clang -c src/ui/native/objc_bridge.m -o src/ui/native/objc_bridge.o -fno-objc-arc
clang -c src/ui/native/swiftkit_bridge.m -o src/ui/native/swiftkit_bridge.o -fno-objc-arc

# 2. Build the SwiftKit static lib for macOS.
swift build -c release --package-path swift/AssetPipelineSwiftKit

# 3. Build the spec with full link flags.
SWIFTKIT_LIB="$PWD/swift/AssetPipelineSwiftKit/.build/release/libAssetPipelineSwiftKit.a"
acrystal build spec/ui/ax_test/ax_app_spec.cr -Dmacos \
  -o bin/ax_app_spec \
  --link-flags="$PWD/src/ui/native/objc_bridge.o $PWD/src/ui/native/swiftkit_bridge.o \
    -Wl,-force_load,$SWIFTKIT_LIB \
    -framework AppKit -framework Foundation -framework SwiftUI -framework Combine \
    -framework ApplicationServices -framework CoreFoundation \
    -framework CoreGraphics -framework ImageIO -framework QuartzCore \
    -framework UserNotifications -framework WebKit -framework MapKit -framework CoreLocation \
    -framework AVKit -framework AVFoundation \
    -lobjc -Wl,-rpath,/usr/lib/swift"
```

### First actionable error

`spec/ui/ax_test/ax_app_spec.cr` requires only `../../../src/ui/ax_test` — it does
not transitively pull in `src/ui` (where `callback_registry.cr`'s `fun crystal_ui_*_callback_dispatch`
definitions live). The ObjC bridge object references those symbols.

```
"_crystal_ui_callback_dispatch", referenced from:
    _crystal_action_dispatcher_dispatch in objc_bridge.o
"_crystal_ui_string_bool_callback_dispatch", referenced from:
    _ap_web_delegate_should_allow in objc_bridge.o
"_crystal_ui_string_callback_dispatch", referenced from:
    _ap_web_delegate_dispatch_string in objc_bridge.o
ld: symbol(s) not found for architecture arm64
```

### Verified workaround

Adding `require "../../src/ui"` ahead of `require "../../src/ui/ax_test"` in the
spec entry resolves the link (probe verified):

```crystal
# spec/native_macos/ax_test/ax_app_spec.cr
require "../../src/ui"       # ensures callback_registry.cr fun defs are in the binary
require "../../src/ui/ax_test"
```

Probe: `tmp_ax_smoke.cr` containing both requires + a trivial `describe` block
linked successfully with the full flag set (`-rwxr-xr-x 5518408 May 25 19:01 /tmp/ax_smoke`).

This adjustment will be applied during the Deliverable 2 batch moves to the 14
`spec/native_macos/` specs. The Makefile `test-macos` target uses these link
flags verbatim.

### Next remediation owner

Implementer (Phase 10C.0, Deliverable 2 — spec moves). Each AX spec gets the
`src/ui` require prepended during migration.

### CI feasibility

`macos-14` runner already supported in `.github/workflows/initiative-cross-platform-ui.yml`.
SwiftKit cache wired. `make test-macos` integrates cleanly.

## iOS — `attempted-blocked` (cross-compile libgc missing)

### Command attempted

```bash
acrystal build tmp_ios_smoke.cr --target=arm64-apple-ios18.0 -Dios -o /tmp/ios_smoke
```

Where `tmp_ios_smoke.cr` is `puts "hello"`.

### First actionable error

```
ld: building for 'iOS', but linking in dylib
  (/opt/homebrew/Cellar/bdw-gc/8.2.12/lib/libgc.1.5.6.dylib) built for 'macOS'
clang: error: linker command failed with exit code 1
```

Without `--target`, the default cross-compile produces an `aarch64-apple-darwin25.5.0`
mismatch (object file built for `darwin`, not `iOS`).

### Existing remediation path (NOT in 10C.0 scope)

The repo's iOS sample build at `samples/initiative-cross-platform-ui-demo/ios/build_crystal_lib.sh`
uses Crystal's `--cross-compile` to emit a static `libcascade.a`, then links via
Xcode (`xcodegen` + `xcodebuild`). That model expects a host iOS app project,
not standalone `acrystal spec` invocation. Mapping that flow to `make test-ios`
is a Phase 10C.1 / 10D scope item.

### Next remediation owner

Deferred. iOS runner phase TBD. Tracked under Phase 10D (Voyager + intent
exerciser + owner test) per `architecture-decisions.md` updated dependency graph.

### CI feasibility

Existing `.github/workflows/initiative-cross-platform-ui.yml` `build-ios` job
already runs an iOS-simulator artifact build via xcodebuild. That path
continues to work; the `make test-ios` lane is the *spec* runner gap.

## Android — historical failed host-target command

The May command below did not select an Android target triple. It is retained
as diagnostic history, not a current requirement for a Linux build host.
The September toolchain uses `--cross-compile --target aarch64-linux-android31`
and `--target x86_64-linux-android31` with the local x86 bionic overlay.

### Command attempted

```bash
acrystal build tmp_android_smoke.cr -Dandroid -o /tmp/android_smoke
```

### First actionable error

```
Error: can't find file 'c/sys/epoll'

If you're trying to require a shard:
- Did you remember to run `shards install`?
- Did you make sure you're running the compiler in the same directory as your shard.yml?
```

Crystal's stdlib resolves `require "c/sys/epoll"` from a Linux-only `src/c/sys/epoll.cr`
file. The `agent-crystal` Homebrew tap installs the macOS-targeted stdlib only.

### Next remediation owner

The compiler/NDK/JNI build and ARM64 emulator interaction are now proven. The
remaining scope is tracked in `docs/ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md`.

### CI feasibility

The original `continue-on-error` placeholder is historical. The September 6
`android-native.yml` declaration uses explicit Ubuntu 24.04, API 31/35 x86_64
emulators and the complete `make test-android` driver without ignored failures.
See [the validation runbook](../android-ci.md) and
[the local checkpoint](../android-ci-entrypoint-proof-2026-09-06.md) for the
verified scope and outstanding independent-runner/runtime gates. No remote CI
run is implied by the declaration.

## Open questions

1. **macOS one-line require fix vs. bridge split.** Adding `require "../../src/ui"`
   to AX specs works but pulls the entire `src/ui` graph into every AX-test
   binary. A long-term clean alternative is to split `objc_bridge.m` into
   `ax_bridge.m` (no Crystal callbacks) + `renderer_bridge.m` (the rest). 10C.0
   ships the one-line fix; the split is a Phase 10A.final / refactor task.

2. **`acrystal` vs. `crystal-alpha` naming.** The Homebrew tap installs both
   names pointing at the same binary. `[[reference_agent_crystal]]` prefers
   `acrystal`; the Makefile target uses `acrystal` but CI workflows reference
   `crystal-alpha` (working as installed). Cosmetic rename is a follow-up.

3. **iOS spec runner.** No precedent in the repo for `acrystal spec -Dios`.
   Sample iOS apps use `--cross-compile` + Xcode. A `make test-ios` lane that
   actually runs specs in an iOS simulator is a Phase 10D scope item.

— Implementer (Phase 10C.0), 2026-05-25
