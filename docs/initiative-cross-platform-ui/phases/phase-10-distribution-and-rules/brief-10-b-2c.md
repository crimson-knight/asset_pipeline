# Phase 10B.2c — Environment-driven accessibility contracts

**Branch:** `phase-10-b-2c` from `phase-10` (tag `phase-10-batch-3-merged-2026-05-26`).
**Status:** v1. Concurrent-eligible with 10B.2b.

## Context

System-level user preferences (reduced motion, increased contrast, larger text) MUST be respected by views. 10B.2c adds the `UI::Environment` surface that views read at render time + the per-platform sources.

## Deliverables

1. **`UI::Environment`** class — a context object exposed via `ScreenContext.environment`:
   ```crystal
   class UI::Environment
     getter reduce_motion : Bool
     getter increase_contrast : Bool
     getter dynamic_type_size : Symbol  # :xsmall .. :xxxlarge
     getter color_scheme : Symbol  # :light, :dark, :high_contrast
     getter accessibility_enabled : Bool  # VoiceOver / TalkBack active
   end
   ```

2. **Per-platform sources:**
   - Web: read from `prefers-reduced-motion`, `prefers-contrast`, `prefers-color-scheme` media queries at render time (server-side rendering passes `Request`-derived hints; client-side JS layer for subsequent updates).
   - UIKit: `UIAccessibility.isReduceMotionEnabled`, `UITraitCollection.accessibilityContrast`, `UIContentSizeCategory`, `UITraitCollection.userInterfaceStyle`.
   - AppKit: `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`, `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast`, system appearance.
   - Android: `Settings.Global.ANIMATOR_DURATION_SCALE == 0`, `AccessibilityManager.isHighTextContrastEnabled`, font scale.

3. **`UI::View` reactive hooks**:
   - `def render_with(env : Environment)` overridable on every view (or per-view if needed).
   - Components query environment when their rendering depends on it (e.g. `Animation.duration_with_environment(env)` returns 0 when `reduce_motion`).
   - Convention: rendering remains correct + visually meaningful when ALL environment flags are at their accessibility-conservative defaults.

4. **`ScreenContext.environment` field** — defaults to a "no preferences set" Environment; populated by host (Amber integration / native dispatcher) at request/render time.

5. **Specs** — `spec/web/ui/environment_spec.cr`:
   - Environment construction + getters.
   - Web renderer reads from a stubbed Request and surfaces the Environment to the context.
   - Reactivity: changing environment between renders produces different output (e.g., an animation widget renders with `duration: 0` when reduce_motion=true).

6. **Close handoff** — per-platform source map + integration notes (where consumer apps need to wire the source vs. what asset_pipeline provides out of the box).

## Workflow

1. `git checkout -b phase-10-b-2c phase-10`.
2. Build `UI::Environment` class.
3. Extend `ScreenContext` with `environment` field.
4. Wire per-platform sources (Amber integration reads request headers / accept hints; native dispatchers query OS).
5. Add at least one widget that reacts to environment (animation duration hook).
6. Specs + close handoff.
7. Standard footer.

## Acceptance

- ✅ `UI::Environment` class + 5 getters.
- ✅ `ScreenContext.environment` integration.
- ✅ 4 per-platform sources documented (and at least the web + macOS / iOS implementations sketched in code).
- ✅ Reactivity proof: same view + different environment → different render output.
- ✅ Specs pass.
- ✅ Codex APPROVE.

## Out of scope

- Runtime AT testing.
- Action + focus + keyboard (10B.2b).

— Architect (Claude Opus 4.7), 10B.2c brief v1
