# Overview — One UI Tree, Four Platforms

> **You are an agent (or a developer) who wants to ship one UI to web, iOS, macOS,
> and Android.** This guide is the install-and-ship path for `asset_pipeline`'s
> cross-platform UI system. Start here, then follow the numbered sections in order.

## What this is

`asset_pipeline` lets you write a UI **once**, as a tree of `UI::View` objects in
pure Crystal, and render it natively on four targets:

| Target | Renderer | Output | Compiler / flag |
|--------|----------|--------|-----------------|
| Web | `UI::Web::Renderer` | HTML + CSS | `crystal` (no flag) |
| macOS | `UI::AppKit::Renderer` | AppKit (`NSStackView`, `NSButton`, …) | `crystal-alpha -Dmacos` |
| iOS | `UI::UIKit::Renderer` | UIKit (`UIStackView`, `UIButton`, …) | `crystal-alpha -Dios` |
| Android | `UI::Android::Renderer` | JNI / Android Views | `crystal-alpha -Dandroid` |

There is no webview, no JavaScript framework bridge, and no custom drawing engine.
Each platform renders **real native widgets**. The same `UI::VStack` becomes a
`<div style="display:flex">` on web, an `NSStackView` on macOS, a `UIStackView` on
iOS, and a `LinearLayout` on Android.

```crystal
require "asset_pipeline/ui"

view = UI::VStack.new(spacing: 12.0)
view << UI::Label.new("Hello from one source tree")
view << UI::Button.new("Tap me") { puts "pressed" }
# `view` is platform-agnostic. The renderer you instantiate decides the output.
```

> **The consumer require is `require "asset_pipeline/ui"`** — *not* `require "ui"`.
> It resolves to `src/ui.cr` in the shard. See
> [01 — Install & Wire Up](01-install.md).

## Beauty-by-default philosophy

A `UI::View` must produce the **most beautiful Apple-native render possible with
zero configuration** on iOS / iPadOS / macOS — Liquid Glass materials, system
typography, semantic colors, correct hit targets, destructive/cancel role wiring,
SF Symbols, and section chrome. This is the library's North Star: a developer who
writes `UI::Sheet.new([...])` gets a HIG-authentic Apple sheet by default, in both
light and dark appearance.

When you want to impose a brand voice, you override explicit knobs on the view or
on the design-token theme. The defaults are beautiful; the overrides are yours.

- **Design tokens** (`src/ui/design_tokens.cr`) carry 23 semantic color roles in
  light + dark, a spacing scale, type / radius / shadow / motion scales, and
  `touch_target_minimum_px`. Override the brand by subclassing
  `UI::DesignTokens::Brand` — see [05 — Theming & Design Tokens](05-theming.md).
- **Accessibility is not optional.** Every interactive element MUST have an
  `accessibility_label`. WCAG 2.2 AA defaults (focus rings, motion preferences,
  ARIA/AX state) are built in. See [07 — Accessibility & Testing](07-accessibility-testing.md).

## The PlatformVisitor model

Platform dispatch uses the **visitor pattern**, resolved at compile time with
Crystal's `flag?()` — zero runtime overhead.

1. Your app code builds a tree of `UI::View` objects.
2. A `PlatformRenderer` (a subclass of `PlatformVisitor`) walks the tree.
3. The renderer is **selected at compile time** by the `-D` flag you pass.
   With no flag, the build uses the **web** renderer — *even on macOS*. You must
   pass `-Dmacos` / `-Dios` / `-Dandroid` to get a native renderer.

```
UI::View tree  ──►  PlatformVisitor (compile-time selected)  ──►  native widgets
   (your code)         AppKit / UIKit / Android / Web
```

Adding a new view type means adding **one method per renderer** — the visitor
guarantees every platform is forced to handle every view. There are currently
59 `UI::View` types. The canonical per-type mapping table lives in the project
`CLAUDE.md` and the `component-mapping-matrix` skill.

### Tier model (what's portable)

Every widget falls into one of three tiers (canonical:
`docs/initiative-cross-platform-ui/tier-matrix.md`):

- **Tier 1 — Brand-universal** (`VStack`, `HStack`, `Card`, `Circle`, …): renders
  identically everywhere. No gating.
- **Tier 2 — Platform default** (`Button`, `Slider`, `Sheet`, `Picker`, …): one
  API, mapped to the idiomatic native widget per platform. No gating.
- **Tier 3 — Platform-only** (`ActionSheet`, `ContextMenu`, …): no honest
  cross-platform analog. Gated behind a `flag?` macro; each ships a
  `*WithWebFallback` sibling. Naming a Tier 3 class without the right `-D` flag is
  a **compile-time error** that names the missing flag.

If you stay in Tier 1 + Tier 2 (the vast majority of UI), one source tree ships
to all four targets with no per-platform branching.

## When to reach for this

**Reach for it when:**

- You want **one UI codebase** for web + mobile + desktop, in Crystal, with no
  JavaScript SPA framework and no Node/npm/bundler toolchain.
- You have an **Amber web project** and want native iOS/macOS apps that share the
  same screens. `asset_pipeline` ships first-class Amber integration —
  `UI::AmberIntegration.routes_for(App)` wires a `UI::App` into a full Amber
  server. See [06 — Amber & Web Targets](06-amber-and-web.md).
- You want **Apple-native polish by default** (HIG-authentic chrome, Liquid Glass,
  dark mode) without hand-writing SwiftUI/UIKit.
- You're an **agent shipping a product end-to-end** and want a single, type-safe,
  zero-runtime-dependency front-end layer (`asset_pipeline` is one shard with no
  runtime deps; see `shard.yml`).

**Don't reach for it when:**

- You need a custom drawing/game engine or heavy GPU canvas work — this library
  renders native widgets, not a custom render surface (see the
  `graphics-rendering` skill for that survey).
- You only need server-rendered HTML with no native targets — you can still use
  the web pieces, but the cross-platform machinery is overkill.

## Two ways to author a UI

1. **View trees directly** — build `UI::View` objects and hand them to a renderer.
   Best for embedding into an existing host. See [02 — Build a View Tree](02-build-a-view-tree.md).
2. **`UI::App` (MVC-style app layer)** — declare routes with the `screen` macro,
   build screens from a shared `ScreenContext`, handle actions in a
   `UI::Controller` that returns a `UI::ActionResult` (Navigate / Pop / Rerender /
   ReplaceRoot / RenderInline), with `UI::FormState` carrying controlled input
   across renders. This is the recommended path for full apps. See
   [03 — The UI::App Layer](03-ui-app-layer.md) and the `ui-app` skill.

## Native builds need a compiled ObjC bridge

The AppKit and UIKit renderers call through a typed C bridge for ARM64-safe
`objc_msgSend`. **Native builds will not link without it.** The bridge source is
`src/ui/native/objc_bridge.m`. Compile it before linking:

```bash
clang -c src/ui/native/objc_bridge.m \
  -o src/ui/native/objc_bridge.o -fno-objc-arc
```

Then include the `.o` in your link flags (macOS example):

```bash
crystal-alpha build src/app.cr -o bin/app -Dmacos \
  --link-flags="src/ui/native/objc_bridge.o \
    -framework AppKit -framework Foundation -lobjc"
```

iOS cross-compilation additionally cross-builds the bridge against the iOS SDK,
hides `_main` to coexist with Swift `@main`, and packs everything into a static
library. The full sequence is in [04 — Building Native (macOS / iOS / Android)](04-building-native.md);
the working reference scripts are
`samples/initiative-cross-platform-ui-voyager/Makefile` and
`samples/initiative-cross-platform-ui-voyager/ios/build_crystal_lib.sh`.

> **Compiler matrix:** use `crystal` (vanilla) for the web target, and
> `crystal-alpha` (a.k.a. `acrystal`) for all native (`-Dmacos` / `-Dios` /
> `-Dandroid`) builds.

## Guide sections

| # | Section | Covers |
|---|---------|--------|
| 00 | **Overview** (this file) | What it is, philosophy, the PlatformVisitor model, when to use it |
| 01 | [Install & Wire Up](01-install.md) | Adding the shard, `require "asset_pipeline/ui"`, project layout |
| 02 | [Build a View Tree](02-build-a-view-tree.md) | `UI::View` composition, the 59 view types, renderer instantiation |
| 03 | [The UI::App Layer](03-ui-app-layer.md) | `UI::App`, `Screen`, `Controller`, `ActionDispatcher`, `FormState` |
| 04 | [Building Native (macOS / iOS / Android)](04-building-native.md) | Bridge compile, flags, link-flags, cross-compile, bundling |
| 05 | [Theming & Design Tokens](05-theming.md) | `UI::DesignTokens`, brand overrides, light/dark |
| 06 | [Amber & Web Targets](06-amber-and-web.md) | `UI::AmberIntegration.routes_for`, the static-site (Voyager) target |
| 07 | [Accessibility & Testing](07-accessibility-testing.md) | `accessibility_label` discipline, AXTest, WCAG 2.2 AA |

## Reference samples

- **Voyager** (`samples/initiative-cross-platform-ui-voyager/`) — the same four
  screens shipped to web (`make web`), macOS (`make macos`), and iOS (`make ios`).
  This is the canonical "one UI, every target" proof and the source of truth for
  the build commands in this guide.
