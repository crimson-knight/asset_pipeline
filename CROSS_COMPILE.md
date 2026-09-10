# Cross-Compilation Guide: Crystal for iOS and Android

This guide covers building Crystal shared libraries (`.dylib` / `.so`) for
iOS and Android using the scripts in `scripts/`. The resulting libraries embed
into Swift/Kotlin host applications via the C-level FFI.

---

## Prerequisites

### All platforms

| Tool | Version | Install |
|------|---------|---------|
| Crystal compiler | Android: pinned 1.21.0; iOS: use its separately tested toolchain | Android requires the reviewed embedded startup contract |
| git | Any | `brew install git` |
| cmake | 3.20+ | `brew install cmake` |
| make | Any | Included with Xcode CLT |

### iOS targets

| Tool | Required for | Install |
|------|-------------|---------|
| Xcode | All iOS builds | Mac App Store |
| Xcode Command Line Tools | `xcrun`, SDK headers | `sudo xcode-select --install` |
| iOS 17 SDK | Device + simulator | Bundled with Xcode 15+ |

Verify your SDK path:

```bash
xcrun --sdk iphoneos --show-sdk-path
xcrun --sdk iphonesimulator --show-sdk-path
```

### Android targets

| Tool | Required for | Install |
|------|-------------|---------|
| Android NDK 28.2.13676358 | All Android builds | Android Studio SDK Manager or `sdkmanager "ndk;28.2.13676358"` |

`config/android_toolchain.env` is the canonical Android version contract.
Run `./scripts/doctor_android.sh` to validate SDK, NDK, Java, Crystal and ADB.
The installed macOS Crystal compiler can emit Android objects when given the
actual `--target` triple; a Linux compiler host is not required. `-Dandroid`
alone does not change the object architecture or libc bindings.

Set the `ANDROID_NDK_HOME` environment variable:

```bash
export ANDROID_NDK_HOME=/opt/homebrew/share/android-commandlinetools/ndk/28.2.13676358
# or for Android Studio:
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/28.2.13676358
```

---

## Quick Start

Three commands to build and integrate Crystal for all targets:

```bash
# 1. Build cross-compiled dependencies (libgc + libpcre2) — one-time setup
./scripts/cross_compile_deps.sh all

# 2. Build for iOS device
./scripts/build_ios.sh src/my_app.cr device

# 3. Build for Android
./scripts/build_android.sh src/my_app.cr
```

For iOS Simulator:

```bash
./scripts/build_ios.sh src/my_app.cr simulator
```

---

## Full Dependency Build

`cross_compile_deps.sh` builds BoehmGC and PCRE2 for each target. These are
Crystal's only non-system dependencies for mobile targets.

```
BUILD_DIR/
  ios-device/lib/
    libgc.a
    libpcre2-8.a
  ios-simulator/lib/
    libgc.a
    libpcre2-8.a
  android/<arm64-v8a|x86_64>/api-<minimum-api>/<contract-sha256>/
    android-deps.manifest
    files.sha256
    include/
    licenses/
    lib/
      libgc.a
      libcord.a
      libpcre2-8.a
      libpcre2-posix.a
```

Android bundles are keyed by ABI, native API, pinned source commits/checksums,
NDK tool hashes, build-tool versions and recipe identity. Both the dependency
builder and native linker validate the contract and complete library/header
payload. The old flat Android cache is retained but no longer accepted; rebuild
with the current script instead of moving old archives into the new layout.
The iOS layout and iOS builder are unchanged by this Android migration.

Android builds also require Autoconf, Automake and GNU libtoolize (named
`glibtoolize` on Homebrew). `doctor_android.sh` checks these prerequisites.
GC is explicitly configured for POSIX threads and Clang's built-in atomics;
it does not discover a host libatomic_ops installation. The atomic_ops source
revision/checksum is retained as provenance, but no separate atomic_ops object
is linked in this recipe.

For independent-build and negative-cache regression proof:

```bash
JOBS=4 bash scripts/tests/android_dependency_reproducibility.sh
```

This creates two empty cache roots, fetches pinned sources independently,
compares all published files and manifests, and checks wrong API/ABI/toolchain,
modified headers, invalid archives and corrupt source-download rejection.
It tests repeatability on the selected host/toolchain, not byte identity across
different operating systems or compiler versions.

### Building individual targets

```bash
# iOS only (device + simulator)
./scripts/cross_compile_deps.sh ios

# Android only
./scripts/cross_compile_deps.sh android

# All targets
./scripts/cross_compile_deps.sh all
```

### Custom build directory

```bash
export BUILD_DIR=/path/to/my-deps
./scripts/cross_compile_deps.sh all
export CRYSTAL_CROSS_DEPS=$BUILD_DIR
./scripts/build_ios.sh src/my_app.cr device
```

### Dependency versions

Override via environment variables:

```bash
BDWGC_VERSION=8.2.6 PCRE2_VERSION=10.44 ./scripts/cross_compile_deps.sh all
```

---

## iOS Build Details

### Build flow

```
Crystal source (.cr)
    |
    | crystal build --cross-compile --target aarch64-apple-ios17.0 --shared
    v
Object file (.o)
    |
    | xcrun --sdk iphoneos clang -dynamiclib
    |   libgc.a libpcre2-8.a
    |   -framework UIKit -framework Foundation
    v
Shared library (.dylib)
```

### Output files

| File | Description |
|------|-------------|
| `build/ios-device/lib<name>.dylib` | Shared library for physical devices |
| `build/ios-simulator/lib<name>.dylib` | Shared library for the simulator |
| `build/ios-device/CrystalBridge.h` | C header for Swift bridging |

### Recommended `-D` flags for iOS

| Flag | Effect |
|------|--------|
| `-Dwithout_openssl` | Disable Crystal's OpenSSL bindings (not in iOS SDK) |
| `-Dwithout_xml` | Disable LibXML2 bindings (not needed for UI layer) |
| `-Dwithout_iconv` | Disable libiconv (iOS uses CoreFoundation for encoding) |

Do **not** use `--prelude=empty`. The full standard library is available once
`libgc` and `libpcre2` are cross-compiled. This gives you `String`, `Array`,
`Hash`, `IO`, `Fiber`, `Channel`, `JSON`, `Log`, `Time`, and the UI layer.

### Xcode integration

1. Drag `lib<name>.dylib` into your Xcode project.
2. Under the target's "General" tab, confirm the dylib appears in "Frameworks,
   Libraries, and Embedded Content" with "Embed & Sign".
3. Set "Build Settings > Objective-C Bridging Header" to `CrystalBridge.h`
   (or add `#import "CrystalBridge.h"` to your own bridging header).
4. Add the library directory to "Build Settings > Library Search Paths".

**App Sandbox entitlement:** The standard iOS App Sandbox does not require
any special entitlements for a Crystal dylib. BoehmGC is compiled with
`--disable-threads` (single-threaded GC) and does not use `mmap(PROT_EXEC)`.

### Calling Crystal from Swift

```swift
// Bridging header (CrystalBridge.h)
// void crystal_init(void);
// void crystal_cleanup(void);
// int32_t crystal_add(int32_t a, int32_t b);

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        crystal_init()
        print("crystal_add(17, 25) =", crystal_add(17, 25))
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        crystal_cleanup()
    }
}
```

---

## Android Build Details

### Build flow

```
Crystal source (.cr)
    |
    | crystal build --cross-compile --target aarch64-linux-android31
    v
Object file (.o)
    |
    | $NDK_CLANG --target=aarch64-linux-android31 -shared -fPIC
    |   libgc.a libpcre2-8.a -llog -lc -lm -ldl
    v
Shared library (.so)
```

### Output files

| File | Description |
|------|-------------|
| `build/android-arm64/lib<name>.so` | Shared library for arm64-v8a devices |
| `build/android-x86_64/lib<name>.so` | Shared library for x86_64 emulators/devices |

Select the second architecture with `ANDROID_ABI=x86_64`. The canonical sample
builds both. Crystal 1.21.0 does not bundle x86_64 Android libc bindings; the
build creates a local overlay from the bundled ARM64 bionic bindings, replaces
the architecture-specific `stat`, `va_list` and syscall definitions, and
checks their layouts against NDK headers. It does not modify the installed
Crystal standard library. Cross-link success is not x86_64 runtime proof.

### Recommended `-D` flags for Android

| Flag | Effect |
|------|--------|
| `-Dwithout_openssl` | Disable Crystal OpenSSL imports; TLS requires a separate platform adapter or bundled library |
| `-Dwithout_xml` | Disable LibXML2 |

### Android Studio integration

1. Copy `lib<name>.so` to `app/src/main/jniLibs/arm64-v8a/`.
2. In your `build.gradle`:

```groovy
android {
    defaultConfig {
        ndk {
            abiFilters "arm64-v8a"
        }
    }
}
```

3. Load the library from Kotlin:

```kotlin
companion object {
    init {
        System.loadLibrary("myapp")  // loads libmyapp.so
    }
}

external fun crystalCleanup()
external fun crystalAdd(a: Int, b: Int): Int
```

4. Implement the JNI bridge (see `samples/cross_platform/android_host/android_host_jni.c`):

```c
#include <jni.h>
#include <android/log.h>

extern void crystal_init(void);
extern int crystal_add(int a, int b);

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    crystal_init();
    return JNI_VERSION_1_6;
}

JNIEXPORT jint JNICALL
Java_com_example_myapp_MainActivity_crystalAdd(JNIEnv *env, jclass cls, jint a, jint b) {
    return crystal_add(a, b);
}
```

Compile the JNI bridge together with the Crystal object file by adding both
to your CMakeLists.txt `add_library` sources list, or by linking the Crystal
`.o` directly in the NDK clang invocation (the `build_android.sh` script
handles this for you).

---

## Initialisation: `crystal_init()` and `crystal_cleanup()`

When Crystal runs as a shared library, there is no automatic runtime
initialisation. The host application must call `crystal_init()` before any
Crystal function is used.

Android builds link `scripts/crystal_init.cr` and the C runtime wrapper
`scripts/crystal_gc_threads.c`. The C `pthread_once` gate performs GC setup,
Crystal runtime setup, and `Crystal.main_user_code` exactly once. The last step
initializes eager globals and the scheduler, including the application source's
top-level statements. Do not put a web-server boot loop in an embedded entrypoint.
Android owns process lifetime; the bridge does not call `Crystal.exit`.

The Android embedding exports these functions:

| Function | Signature | Purpose |
|----------|-----------|---------|
| `crystal_init` | `() -> void` | Initialise BoehmGC and Crystal runtime |
| `crystal_cleanup` | `() -> void` | Final GC collection and cleanup |
| `crystal_runtime_is_ready` | `() -> int32` | Verify initialization succeeded before entry |
| `crystal_gc_register_thread` | `() -> int32` | 1: registered here; 0: already registered; negative: failure |
| `crystal_gc_unregister_thread` | `() -> int32` | Release a registration owned by this C bridge |

Require the initialization support at the top of your source file:

```crystal
require "../scripts/crystal_init"

fun my_feature_function : Int32
  42
end
```

### Multi-threaded use

The canonical Android host renders and dispatches UI callbacks on the main
looper. Its C entrypoints register a foreign JVM stack with Boehm before
entering Crystal, check failure, and unregister only when that invocation owns
the registration. GC registration alone does not make application state or
Android Views safe to use from arbitrary worker threads. Native-created threads
also need JVM attachment before JNI calls; reference deletion uses the stored
JavaVM to obtain a valid thread-local JNIEnv. Do not retain a JNIEnv across
threads. See the canonical host's `android_host_jni.c` for the complete contract.

---

## Known Issues and Workarounds

### `Process.fork` crashes on iOS

The iOS App Sandbox disallows `fork()`. Any Crystal code that calls
`Process.fork` or `Process.run` with `shell: true` will crash with
`SIGABRT` at runtime.

**Workaround:** Guard process spawning with a compile-time flag:

```crystal
{% unless flag?(:ios) %}
  Process.run("ls", shell: true)
{% end %}
```

For background work on iOS, use `Fiber` / `Channel` within a single process.

### TLS on Android

Android's NDK does not bundle OpenSSL. Compile with `-Dwithout_openssl`.
For HTTPS from Crystal on Android, either:

- Use Android's system `HttpURLConnection` via JNI from Kotlin, passing
  results back to Crystal as strings.
- Bundle a static libssl/libcrypto built for `aarch64-linux-android31`
  (see OpenSSL's Android build guide) and remove `-Dwithout_openssl`.

### PCRE2 JIT disabled on iOS

`mmap(PROT_EXEC)` is forbidden in the iOS App Sandbox for non-text pages.
PCRE2's JIT compiler requires executable memory. `cross_compile_deps.sh`
builds libpcre2 with `-DPCRE2_SUPPORT_JIT=OFF` for all iOS targets.

Impact: Regular expressions are slightly slower (interpreted PCRE2 vs JIT).
This is not measurable for typical UI workloads. String matching and
substitution still work correctly.

### Thread-local storage on older Android

Android Bionic does not support `__thread` on API < 21. Crystal falls back
to `pthread_key_create` / `pthread_getspecific` automatically when targeting
Android (this is already handled in Crystal's libc bindings at
`src/lib_c/aarch64-linux-android/`).

The `ANDROID_API=31` default in these scripts avoids this issue entirely.

### `arm64-apple-ios` vs `aarch64-apple-ios`

Crystal's `--target` flag accepts both `arm64-apple-ios17.0` and
`aarch64-apple-ios17.0`. They are synonymous. The scripts use
`aarch64-apple-ios${IOS_DEPLOYMENT_TARGET}` internally (matching LLVM triple
convention) but accept `arm64` from the user for familiarity.

### Universal (fat) binaries / XCFramework

The scripts produce a single-arch `arm64` dylib. To distribute via
XCFramework (which Xcode requires for mixed device + simulator frameworks):

```bash
xcodebuild -create-xcframework \
    -library build/ios-device/libmyapp.dylib \
    -headers build/ios-device/ \
    -library build/ios-simulator/libmyapp.dylib \
    -headers build/ios-simulator/ \
    -output MyApp.xcframework
```

### Bitcode

Bitcode is no longer required by Apple as of Xcode 14. The scripts do not
pass `-fembed-bitcode`. If you target older Xcode versions, add
`EXTRA_LINK_FLAGS=-fembed-bitcode` when running `build_ios.sh`.

---

## Script Reference

### `cross_compile_deps.sh`

```
Usage: ./scripts/cross_compile_deps.sh [ios|android|all]

Environment:
  BUILD_DIR              Output root   (default: /tmp/crystal-cross-deps)
  BDWGC_VERSION          BoehmGC tag   (default: 8.2.6)
  PCRE2_VERSION          PCRE2 tag     (default: 10.44)
  IOS_DEPLOYMENT_TARGET  Min iOS ver   (default: 17.0)
  ANDROID_API            Min API level (default: 31)
  ANDROID_NDK_HOME       NDK path
  JOBS                   Make -j       (default: CPU count)
```

### `build_ios.sh`

```
Usage: ./scripts/build_ios.sh <source.cr> [device|simulator] [output_name]

Environment:
  CRYSTAL              Crystal binary          (default: crystal)
  CRYSTAL_CROSS_DEPS   Deps root directory     (default: /tmp/crystal-cross-deps)
  IOS_DEPLOYMENT_TARGET                        (default: 17.0)
  CRYSTAL_FLAGS        Extra -D flags          (default: -Dwithout_openssl -Dwithout_xml)
  EXTRA_C_SOURCES      Extra C bridge sources  (default: none)
  EXTRA_CFLAGS         Extra C compiler flags  (default: none)
  EXTRA_LINK_FLAGS     Extra clang link flags  (default: target-specific)
  BUILD_DIR            Output directory        (default: <repo>/build)
```

### `build_android.sh`

```
Usage: ./scripts/build_android.sh <source.cr> [output_name]

Environment:
  CRYSTAL              Crystal binary          (default: crystal)
  CRYSTAL_CROSS_DEPS   Deps root directory     (default: /tmp/crystal-cross-deps)
  ANDROID_API          Min API level           (default: 31)
  ANDROID_ABI          Target ABI              (default: arm64-v8a; also x86_64)
  ANDROID_NDK_HOME     NDK path
  CRYSTAL_FLAGS        Extra -D flags          (default: -Dwithout_openssl -Dwithout_xml)
  EXTRA_C_SOURCES      Extra C bridge sources  (default: none)
  EXTRA_CFLAGS         Extra C compiler flags  (default: none)
  EXTRA_LINK_FLAGS     Extra NDK link flags    (default: -llog -lz)
  STRIP                Set to 1 for release    (default: 0)
  BUILD_DIR            Output directory        (default: <repo>/build)
```

---

## Architecture Reference

The cross-compilation targets align with the Crystal compiler's 7 supported
build targets on the `incremental-compilation` branch:

| Target triple | `flag?()` | Notes |
|---------------|-----------|-------|
| `aarch64-apple-ios17.0` | `:ios`, `:apple`, `:darwin` | Physical device |
| `aarch64-apple-ios17.0-simulator` | `:ios`, `:apple`, `:darwin` | Apple Silicon simulator |
| `aarch64-linux-android31` | `:android`, `:linux`, `:unix` | arm64-v8a, API 31+ |
| `wasm32-wasi` | `:wasm32` | See WASM_ROADMAP.md |
| Native macOS | `:macos`, `:apple`, `:darwin` | Development machine |
| `x86_64-linux-gnu` | `:linux`, `:unix` | CI / server |
| `aarch64-linux-gnu` | `:linux`, `:unix` | Linux arm64 |

Use `flag?()` in Crystal source to gate platform-specific code at compile
time with zero runtime overhead:

```crystal
{% if flag?(:ios) %}
  # UIKit-specific code here — not compiled on other targets
{% elsif flag?(:android) %}
  # Android-specific code here
{% elsif flag?(:macos) %}
  # AppKit-specific code here
{% end %}
```
