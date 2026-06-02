# watchOS Crystal cross-compile blocker — exact diagnosis + fix (2026-06-02)

Phase D, Track 1. The SwiftKit watch catalog is ready (23/40 facades reachable —
see `watch-facade-bucket-audit.md`), so the next step is the Crystal-side
`UI::WatchKit::Renderer`. But the renderer cannot be **proven** until the Crystal
compiler can target watchOS. This note pins the blocker to an exact, ~10-line
compiler patch, all claims verified by probes/source reads this session — not
assumed.

## Symptom (proven)

```
$ acrystal build --cross-compile --target arm64-apple-watchos10.0 wprobe.cr
Error: can't find file 'c/dlfcn'    # from src/exception/call_stack/libunwind.cr
```

`-Ddarwin -Dunix` does not help (same failure). Toolchain:
`agent-crystal 1.20.0-dev (2026-02-18)`, LLVM 21.1.8.

## Root cause (proven by source read)

The lib_c bindings dir is selected in `src/compiler/crystal/crystal_path.cr:80-84`:

```crystal
private def add_target_path(codegen_target)
  target = "#{codegen_target.architecture}-#{codegen_target.os_name}"   # line 81
  @entries.each do |path|
    path = File.join(path, "lib_c", target)                            # line 84
    ...
```

`Target#os_name` (`src/compiler/crystal/codegen/target.cr:88-109`) has cases for
`macos? → "darwin"`, `ios? → "ios"`, the BSDs, solaris, android — but **no
`watchos` case**, so it falls to `else → environment`. For target
`arm64-apple-watchos10.0` the environment is `"watchos10.0"`, so the derived dir is:

```
aarch64-watchos10.0      ← does NOT exist
```

while the **actual lib_c dir is `aarch64-watchos`** (and
`aarch64-watchos-simulator`), both present and complete — verified
`.../src/lib_c/aarch64-watchos/c/dlfcn.cr` EXISTS. So the bindings are there; only
the triple→dir derivation misses. There is also no `watchos?` predicate, and
`apple?`/`unix?` (`target.cr:163-165,187-189`) exclude watchOS, so platform-flag
derivation would be wrong even once the path resolves.

## The fix (compiler repo: crimson-knight/crystal, `src/compiler/crystal/codegen/target.cr`)

Add the predicates and the `os_name` cases. Note `aarch64-watchos` (device) and
`aarch64-watchos-simulator` (sim) are SEPARATE dirs — unlike iOS, which has one —
so `os_name` must distinguish the simulator, and `watchos_simulator?` must be
matched BEFORE `watchos?` (a simulator triple is also `watchos?`).

```crystal
def os_name
  case self
  when .macos?              then "darwin"
  when .ios?                then "ios"
  when .watchos_simulator?  then "watchos-simulator"   # NEW (before watchos?)
  when .watchos?            then "watchos"             # NEW
  when .freebsd?            then "freebsd"
  # ... unchanged ...
  end
end

def watchos?                                            # NEW
  @environment.starts_with?("watchos")
end

def watchos_simulator?                                  # NEW
  watchos? && environment_parts.any?(&.starts_with?("simulator"))
end

def apple?
  macos? || ios? || watchos?                            # + watchos?
end

def unix?
  macos? || ios? || watchos? || bsd? || linux? || wasi? || solaris?   # + watchos?
end
```

This is the source-repo task the program already lists ("watchOS lib_c dirs + flag
derivation so `-Ddarwin -Dunix` becomes unnecessary"). The lib_c dirs half is
DONE (they exist); this is the derivation half.

**Caveat — requires a compiler rebuild.** `target.cr` is compiled INTO the
`acrystal` binary; editing the Homebrew Cellar copy does nothing. The fix must land
in the `crimson-knight/crystal` checkout and the compiler must be rebuilt + the
new binary installed. The local checkout
(`/Users/crimsonknight/open_source_coding_projects/crystal`) is currently on
`fix/union-type-codegen-mismatch` with unrelated uncommitted WIP — do NOT graft
this onto that branch; cut a clean `watchos-target-derivation` branch off the
intended base first.

## asset_pipeline-side prerequisite (independent of the compiler)

`src/ui/native/swiftkit_bridge.cr:20` gates the whole bridge on
`flag?(:macos) || flag?(:ios)`. The WatchKit renderer calls these facades, so the
gate must become `flag?(:macos) || flag?(:ios) || flag?(:watchos)` (likewise
`swiftkit_overrides.cr` if similarly gated). This change is safe to stage but
cannot be COMPILE-PROVEN on watch until the toolchain fix lands — so it should be
made together with the renderer, in one verifiable step, once the compiler can
target watchOS.

## Net

- ✅ SwiftKit watch catalog ready (23/40, incl. TextField/ListView/Sheet/SecureField/TabView).
- ✅ watchOS boundary node (`APSKWatchHostView`) contract-complete.
- ⛔ **Gating item:** Crystal compiler watchOS target derivation (the ~10-line
  `target.cr` patch above) — until it lands, the `UI::WatchKit::Renderer` cannot be
  compiled or proven, so writing it now would violate the "never mark done
  unproven" bar.
- Recommended order once unblocked: compiler patch + rebuild → `swiftkit_bridge`
  gate += `:watchos` → `UI::WatchKit::Renderer` (Bucket-1 leaves first) → one-screen
  watch render proof (XCUITest on the watch simulator).
