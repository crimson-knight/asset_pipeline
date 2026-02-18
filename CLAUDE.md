# Asset Pipeline

A front-end library written in pure Crystal that provides type-safe HTML generation, utility-first CSS, JavaScript/Stimulus management, and reactive server-side components. Ships as a single shard with zero runtime dependencies.

## Architecture

```
src/components/
  elements/          94 HTML element classes (Div, Input, Table, etc.)
  base/              Component base classes (Stateless, Stateful, Reactive)
  css/               CSS engine (ClassBuilder, Config, Generator, Parser)
  reactive/          WebSocket-based real-time component updates
  examples/          6 reference components (Button, Card, Counter, Form, Chat, LiveSearch)
  integration.cr     Amber framework helpers and view macros

src/asset_pipeline.cr  FrontLoader — import maps and script rendering
src/asset_pipeline/
  stimulus/          StimulusRenderer — auto-detects controllers from import maps
  import_map/        ESM import map management
```

## Key Entry Points

- `Components::Elements::*` — 94 type-safe HTML element classes matching HTML tags
- `Components::StatelessComponent` — cacheable, pure-render components
- `Components::StatefulComponent` — components with internal JSON state
- `Components::Reactive::ReactiveComponent` — WebSocket-enabled real-time components
- `Components::CSS::ClassBuilder` — fluent DSL for building CSS class strings
- `Components::CSS::Config` — design token configuration (OKLCH colors, spacing, typography)
- `Components::CSS::Engine::Generator` — generates utility CSS with @layer structure
- `AssetPipeline::FrontLoader` — JavaScript import map and Stimulus management

## Naming Conventions

- Element classes match HTML tag names: `Div`, `Article`, `Input`, `Th`, `Dialog`
- Factory methods on `Input`: `.text()`, `.email()`, `.radio()`, `.search()`, `.range()`, `.color()`, etc.
- Factory methods on `Meta`: `.charset()`, `.viewport()`, `.description()`
- Factory methods on `Link`: `.stylesheet()`, `.preload()`, `.preconnect()`
- Component CSS registered via `component_css <<-CSS ... CSS` macro
- Utility classes follow Tailwind naming: `bg-blue-500`, `hover:text-white`, `sm:flex`

## Design Philosophy

- No templates — all HTML generated from Crystal classes with compile-time type safety
- Utility-first CSS with OKLCH color space and `@layer` cascade structure
- WCAG 2.2 AA accessibility built into defaults (focus rings, motion preferences, ARIA states)
- Stimulus-only JavaScript — no frameworks, ESM import maps, automatic controller detection
- Components render to strings via `.render()` for server-side rendering

## Quick Reference

| Topic | Skill |
|-------|-------|
| Building UIs with elements and components | `build-ui` |
| CSS styling, ClassBuilder, design tokens | `css-styling` |
| JavaScript, Stimulus, reactive components | `javascript` |
| WCAG 2.2 AA accessibility | `accessibility` |

## Build & Test

```bash
crystal spec                    # Run tests
crystal tool format --check     # Check formatting
crystal run src/generators/brand_kit.cr  # Generate style guide
```
