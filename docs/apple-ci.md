# Apple native validation

`.github/workflows/apple-native.yml` is the continuous lane for the Apple
targets: the web specs on macOS, the macOS host built unsigned, and the iOS
host's behavior UI tests on a simulator. It runs on every relevant pull
request and push to `main`, nightly at 06:47 UTC, and on dispatch, on two
GitHub-hosted images that cost nothing on a public repository:

| Role | Runner | What it carries (2026-09-10) |
| --- | --- | --- |
| current | `macos-26` | macOS 26.6, Xcode 26.6 default, iOS 26.2 to 26.5 simulators |
| preview | `xcode-27` | macOS 26.5, Xcode 27 beta, iOS 27.0 simulator |

The preview image is why the lane exists now: iOS 27 ships within days of
this writing, and the bindings meet its Xcode and simulator every night
before it reaches phones. `macos-14` is deprecated and does not appear in
the lane. The pins live in `config/apple_toolchain.env`; the generated
`docs/support-matrix.md` reads them and this workflow.

## The compiler

Stock Crystal 1.21.0 cannot cross-compile for `arm64-apple-ios-simulator`:
its standard library has no C bindings for the iOS targets and falls to the
ELF loader path (`can't find file 'c/fcntl'`). The AgentC fork
(`crimson-knight/agent-crystal/agent-crystal`, `acrystal`) adds
`lib_c/aarch64-ios`, `lib_c/aarch64-ios-simulator` and the compiler's iOS
target, so the iOS and macOS hosts build with it. The fork's tap formula has
no bottle and builds from source (about half an hour on a runner), so the
lane caches the built keg (`/opt/homebrew/Cellar/agent-crystal`) by the
pinned fork version and the image, and relinks it on later runs; the web
specs keep stock Crystal, the version every lane installs.

## What the lane runs

1. `crystal spec spec/android_ci_spec.cr spec/apple_ci_spec.cr`: the
   declaration contracts of both workflows.
2. `make test-web`: the web specs, with stock Crystal, on macOS.
3. `make -C samples/cross_platform/macos_host build CODESIGN_IDENTITY=- CRYSTAL=acrystal`:
   the macOS HIG host links (ObjC bridges, SwiftKit, the Crystal binary)
   without a signing identity; nothing runs it, since its screenshot path
   needs Screen Recording consent no runner grants.
4. `make test-ios`, which is `scripts/test_ios_host.sh`: cross-compiles the
   C dependencies for the simulator when the cache has none, builds
   `libhighost.a` with the fork, generates the Xcode project, picks an
   iPhone Pro on the newest installed iOS runtime (a booted one first),
   and runs `CrystalHIGHostUITests/Phase03BehaviorTests` with signing
   disabled. It fails on a missing tool, a build error, a failed test or an
   empty run, and writes no tracked file; the visual tests, which rewrite
   the tracked screenshots, stay in `scripts/run_ios_hig_tests.sh`.
5. `git diff --exit-code`, then the evidence (`build/apple-ci/`: the
   toolchain record, the iOS log, summary and result bundle) is retained
   for 14 days, including on failure.

A `report` job after the matrix runs `scripts/ci/report_outcome.sh` with
`lane:apple-native` on every run that is not a pull request: one issue
tagging the maintainers when the lane fails, comments while it persists,
closed on recovery. `docs/android-ci.md` describes the reporter and its
`report_selftest` dispatch input; they are the same here.

## The first local run, 2026-09-10

The iOS host had not run since the 1.21 fork replaced the 1.20 one in
July, and it crashed at launch on the iOS 26.5 simulator: `SIGSEGV` at
`0x18` in `Thread::LinkedList#push` under `Fiber.current` under
`Crystal.once`, reading the first design-token constant. Crystal 1.21
leaves the thread registry, the fiber bookkeeping and the once mechanism
uninitialized until `Crystal.init_runtime`, which the generated `main`
calls and which the embedding hides; the bridge's init called `GC.init`
only. The happy_coach iOS shell had already learned this
(`GC.init`, `Crystal.init_runtime`, then its constants). The bridge now
calls `Crystal.init_runtime` after `GC.init`, and the ten behavior tests
pass on an iPhone 17 Pro under iOS 26.5 with Xcode 26.6 in 144 seconds
(evidence outside the repository, with the other proof directories). The
first run also showed that stock Crystal is not enough for iOS, above.
