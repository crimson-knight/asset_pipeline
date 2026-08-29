# watchOS WatchKit renderer — brick 4b plan (on-device render)

Bricks 1–4a are done and compile-verified: the patched `acrystal` targets watchOS,
the UI lib + `UI::WatchKit::Renderer` + the watch `bridge.cr` (`voyager_watch_render`)
all cross-compile to a watch `.o`. Brick 4b is the native build pipeline + watch-app
linking that turns that into a Crystal-authored screen rendering on the watch sim.

## UPDATE 2026-06-02 — the GC dep is SOLVED (recipe below)

The feared hard blocker (bdwgc's stop-the-world uses `thread_suspend`/`thread_resume`,
unavailable on watchOS) is sidestepped: the Crystal watch program is **single-threaded**
(cross-compiled without `-Dpreview_mt`), so it needs only the basic GC API — no
stop-the-world thread suspension. Build bdwgc **with threads OFF**:

```sh
git clone --depth 1 --branch v8.2.8 https://github.com/ivmai/bdwgc /tmp/bdwgc-watch
SDK=$(xcrun --sdk watchsimulator --show-sdk-path)
cmake -S /tmp/bdwgc-watch -B /tmp/bdwgc-watch/build-wsim-nt \
  -DCMAKE_SYSTEM_NAME=watchOS -DCMAKE_OSX_SYSROOT="$SDK" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=10.0 \
  -Denable_threads=OFF -DBUILD_SHARED_LIBS=OFF -Denable_cplusplus=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/bdwgc-watch/build-wsim-nt --config Release   # -> libgc.a (arm64 watchOS)
```

PROVEN: the watch bridge needs exactly 14 `GC_*` symbols (GC_malloc/init/free/realloc/
finalizer/stackbottom/push_other_roots/…) and the no-threads `libgc.a` provides ALL of
them (`comm -23` of needed-vs-provided is empty). Staged at
`/tmp/crystal-cross-deps/watchos-simulator/lib/libgc.a` (ephemeral; the watch
build_crystal_lib.sh should build it). Caveat: keep the watch program single-threaded
(no `-Dpreview_mt`); a threaded build would require porting bdwgc's stop-the-world to
watchOS (a real upstream effort).

## The blocker: Crystal runtime deps for watchOS-simulator

The watch bridge's cross-compile prints link flags `-lgc -liconv -lz -lssl -lcrypto`.
- `iconv`, `z` — provided by the watchOS SDK; fine.
- **`libgc` (bdwgc) — must be cross-built for `arm64-apple-watchos-simulator`.** The
  iOS build links a cross-built `/tmp/crystal-cross-deps/ios-simulator/lib/libgc.a`;
  there is no watchOS equivalent (and `/tmp` is ephemeral — the iOS build dirs are gone).
- `ssl`/`crypto` (OpenSSL) — only needed if the Crystal code actually USES them. Verify
  whether `src/ui`'s require graph pulls OpenSSL (reactive/HTTP). If unused, the linker
  drops them; if used, OpenSSL must also be cross-built for watchOS (avoid by trimming
  the bridge's requires to the UI subset it needs).

## Steps (in order)

1. **Cross-build bdwgc → `libgc.a` for `arm64-apple-watchos10.0-simulator`.**
   Get the bdwgc source (the agent-crystal `make deps` builds it; or clone
   github.com/ivmai/bdwgc). CMake cross-build:
   `-DCMAKE_OSX_SYSROOT=$(xcrun --sdk watchsimulator --show-sdk-path)`
   `-DCMAKE_OSX_ARCHITECTURES=arm64` + watchOS deployment min + `-Denable_threads`.
   Stage to `/tmp/crystal-cross-deps/watchos-simulator/lib/libgc.a` (mirror the iOS dir).
2. **Build the watch lib:** mirror `ios/build_crystal_lib.sh` as `watchos/build_crystal_lib.sh`:
   - compile `objc_bridge.m` + `swiftkit_bridge.m` for watchOS (`-arch arm64 -isysroot
     <watchsimulator sdk> -mwatchos-simulator-version-min=10.0`, `-fno-objc-arc`).
   - cross-compile `watchos/bridge.cr` (`acrystal build --cross-compile
     --target=arm64-apple-watchos10.0-simulator -Dwatchos`), then `ld -r
     -unexported_symbol _main` on the `.o` (Swift @main).
   - `ar rcs libvoyagerwatch.a` the bridge `.o` + the two `.m` objects.
3. **Link into the watch app** (`watchos/project.yml` OTHER_LDFLAGS): `-lvoyagerwatch
   -lgc -liconv` + `-L` the watchos-simulator dep dir + the SwiftKit `.a` (or keep the
   SwiftKit Sources compiled in, as now). Add a bridging header declaring
   `void* voyager_watch_render(void);`.
4. **Swift integration:** `ContentView` calls `voyager_watch_render()`, wraps the
   returned `APSKWatchHostView*` via `Unmanaged.fromOpaque(...).takeRetainedValue()`,
   reads `.content`, embeds it. Call `VoyagerWatchBridge.initialize_runtime` is implicit
   (the render entry calls it).
5. **Run + screenshot** on the watch sim → ON-DEVICE proof of a Crystal-authored screen.

## After 4b
Upgrade the renderer's remaining fallback visits (Card/Toggle/Slider/Sheet/List/…)
to their real facades — most are already watch-ported (23/40 catalog).

This is a focused, toolchain-heavy effort (the bdwgc cross-build is the long pole and
may need iteration) — best done deliberately, not in a timed loop slot.
