# Phase 10B.1c — Close handoff (Android Material3 swipe integration)

**Branch:** `phase-10-b-1c` (from `phase-10`, tag `phase-10-batch-2-merged-2026-05-26`).
**Predecessors:** 10B.0 (intent resolver + capability registry), 10B.1a (`UI::InlineActionRow` for macOS / web_wide).
**Status:** v1 — implementation complete; lint + web spec green; Material3 SwipeToDismiss **blocked** by missing Compose-host JNI surface; LinearLayout fallback shipped + documented.

---

## What shipped

1. **`UI::AndroidSwipeActionRow`** (`src/ui/views/android_swipe_action_row.cr`).
   - Reuses the `UI::SwipeAction` value type from `src/ui/views/swipe_action_row.cr` so action lists are portable between `UI::SwipeActionRow`, `UI::InlineActionRow`, and `UI::AndroidSwipeActionRow` without rewrite.
   - `declares_capabilities :swipe_actions, { supports_edge_trailing: true, supports_role_default: true, supports_role_destructive: :partial }` — capabilities reflect the LinearLayout fallback reality, not the aspirational `SwipeToDismissBox` contract. When the Compose bridge lands, flip `supports_role_destructive` to `true`.
2. **`PlatformVisitor#visit(view : AndroidSwipeActionRow)`** abstract declaration (`src/ui/platform_visitor.cr`).
3. **Renderer dispatch (all 4 renderers wired per `[[audit-scope-discipline]]`):**
   - **Android** (`src/ui/renderers/android_renderer.cr`): horizontal `LinearLayout` of (leading buttons, content, trailing buttons) using `MaterialButton` siblings dispatched through `UI::Button`. Same shape as the 10B.1a `visit(InlineActionRow)` path. The visit body documents the M3 SwipeToDismissBox target + the Compose-bridge blocker inline.
   - **Web** (`src/ui/renderers/web_renderer.cr`): inline-row chrome reusing the `.ap-inline-action-row` CSS already emitted by `InlineActionRow`, with a distinguishing `data-component="android-swipe-action-row"` marker for E2E / introspection.
   - **AppKit** (`src/ui/renderers/appkit_renderer.cr`): horizontal `NSStackView` mirroring `visit(InlineActionRow)` — produces HIG-correct macOS chrome when an app overrides to `UI::AndroidSwipeActionRow` on macOS.
   - **UIKit** (`src/ui/renderers/uikit_renderer.cr`): horizontal `UIStackView` mirroring `visit(InlineActionRow)` — same intent for iOS overrides.
4. **`src/ui/intent_bootstrap.cr`**: `register_default(:swipe_actions, :android, UI::AndroidSwipeActionRow)`. The `:android` line in the bootstrap no longer reads "NO default; 10B.1c will install it" — it now installs it.
5. **Specs:**
   - `spec/web/ui/views/android_swipe_action_row_spec.cr` — 9 examples covering construction, sibling-value-type sharing, leading + trailing actions, visitor dispatch, web fallback chrome (content + roles + aria-labels + `on_tap_route`), reactivity contract (mutate-and-re-render), and intent resolution (`:android` → `UI::AndroidSwipeActionRow`).
   - `spec/web/ui/intent_spec.cr` — replaced the `UnresolvableDefault for :android` assertion with the new positive resolution assertion. The "skips app tier when context.app_class is nil" spec now uses a synthetic `:spec_no_default_platform` symbol (every real platform now has a `:swipe_actions` default after 10B.1c).
   - Updated `TestVisitor` stub lists in `spec/web/ui/swipe_action_row_spec.cr`, `spec/web/ui/views/inline_action_row_spec.cr`, and `spec/web/ui/views_spec.cr` to cover the new abstract method.

## Verification

| Check | Command | Result |
|---|---|---|
| New widget spec | `crystal spec spec/web/ui/views/android_swipe_action_row_spec.cr` | **9 examples, 0 failures** |
| Adjacent specs | `crystal spec spec/web/ui/intent_spec.cr spec/web/ui/views/inline_action_row_spec.cr spec/web/ui/swipe_action_row_spec.cr spec/web/ui/views_spec.cr` | **366 examples, 1 pre-existing failure** (`views_spec.cr:3287` — Theme inject_theme_css, unrelated; reproduces on clean phase-10) |
| Full web suite | `crystal spec spec/web/` | **1822 examples, 4 pre-existing failures** (Theme + 3 Phase 2 component specs, all unrelated; reproduce on clean phase-10) |
| Convention lint | `crystal run scripts/lint_conventions.cr` | **OK — 454 files, 14 rules, 0 diagnostics** |
| Web type-check | `crystal build --no-codegen src/ui.cr` | **clean** |
| macOS type-check | `crystal-alpha build --no-codegen src/ui.cr -Dmacos` | **clean** |
| iOS type-check | `crystal-alpha build --no-codegen src/ui.cr -Dios` | **clean** |
| Android type-check | `crystal-alpha build --no-codegen src/ui.cr -Dandroid` | **architect-precedent-blocked** — pre-existing `c/sys/epoll` host limitation per Phase 1 #17 / Phase 10C.0 (`docs/initiative-cross-platform-ui/native-compile-matrix.md`). Not a 10B.1c regression. |

## Resolver gap closure

Before 10B.1c:

```crystal
UI::Intent.resolve(:swipe_actions, native_ctx(:android))
# => raises UI::Intent::UnresolvableDefault
```

After 10B.1c:

```crystal
UI::Intent.resolve(:swipe_actions, native_ctx(:android))
# => UI::AndroidSwipeActionRow
```

The `:swipe_actions` intent now resolves to a concrete default widget on **every** known platform: `:ios` + `:ipados` + `:web_narrow` → `UI::SwipeActionRow`; `:macos` + `:web_wide` → `UI::InlineActionRow`; `:android` → `UI::AndroidSwipeActionRow`. The `UnresolvableDefault` branch is now reachable only on synthetic / unregistered platforms.

## Material3 SwipeToDismiss status: **blocked by Compose-bridge gap**

**Target API:** `androidx.compose.material3.SwipeToDismissBox`. This is the HIG-correct Android idiom for Mail-style row actions; the swipe-reveal-and-confirm flow is exactly what `UI::SwipeAction` value types are designed to drive.

**Why it's not wired today:** the current JNI bridge (`src/ui/native/android_bridge.c`) exposes only the Android *View* system — `LinearLayout`, `MaterialButton`, `MaterialCardView`, `TextView`, `EditText`, etc., constructed via `android_view_new` / `android_view_new_themed`. `SwipeToDismissBox` is a Jetpack Compose API; reaching it requires:

1. A `ComposeView` factory in the bridge that returns an `android.view.View` host.
2. A `setContent { ... }` plumbing surface that lets the renderer feed a Compose `@Composable` lambda from Crystal.
3. A `MutableState`-bridge so the dismiss callback can fire a Crystal `Proc` via `CallbackRegistry`.

None of those exist in the bridge today. Per `[[plan-what-to-understand-not-just-what-to-build]]`, ratcheting in a half-bridge would invite the same audit-scope-discipline failure mode that 10B.0 ran into. The honest call: ship the LinearLayout fallback now, declare capabilities to match the fallback, and leave a one-line follow-up for the Compose-host phase.

**Fallback rationale:** the LinearLayout-of-MaterialButtons shape is the same shape `UI::InlineActionRow` already uses on Android (see `visit(view : UI::InlineActionRow)` in `android_renderer.cr` shipped in 10B.1a). It is a working, HIG-aware fallback that produces a visible Material 3 row chrome — destructive role tints the button, leading and trailing actions are laid out side-by-side, and `on_tap` callbacks fire through the standard `UI::Button` path. The downgrade vs. `SwipeToDismissBox` is the loss of the swipe-reveal gesture and the role-driven confirm flow; that downgrade is encoded honestly in `supports_role_destructive: :partial`.

**Follow-up owner:** the Phase 10D / cross-platform CI follow-up that owns the Linux+NDK build environment is the natural home for the Compose-host bridge. When it lands:

1. Add a `Compose_view_new(...)` + `Compose_view_set_content(...)` pair to `src/ui/native/android_bridge.c`.
2. Replace the `LinearLayout` body in `visit(view : UI::AndroidSwipeActionRow)` with a `ComposeView` + `SwipeToDismissBox` content lambda.
3. Flip `UI::AndroidSwipeActionRow#declares_capabilities` so `supports_role_destructive` becomes `true`.
4. Update this handoff's status from "blocked" to "wired".

## Memories applied

- **`[[codex-as-architect-antagonist]]`** — implementation reflected on the brief's "ship Material3 if reachable" instruction, audited the bridge surface, and reported the honest blocker rather than synthesizing a half-Compose path that the audit would reject.
- **`[[audit-scope-discipline]]`** — all 4 renderers wired (`PlatformVisitor` declares the abstract method; each of web / appkit / uikit / android renderer implements it). The original brief audit could have missed the renderer-side fan-out; explicit per-renderer dispatch + per-renderer stub in test visitors guarantees coverage.
- **`[[reactivity-is-table-stakes]]`** — the spec includes an explicit `mutate-and-re-render` test that mutates `trailing_actions` after construction and asserts the post-mutation HTML contains the new action. Renderer paths re-read `view.leading_actions` / `view.trailing_actions` on every visit, so the contract holds for all 4 targets.
- **`[[plan-what-to-understand-not-just-what-to-build]]`** — the brief said "if Material3 is reachable, wire it." The honest answer required understanding the bridge layer, not just the widget layer. The handoff documents the bridge gap explicitly so the follow-up phase has a precise target.

## Out of scope (per brief)

- Per-widget HIG validation (deferred).
- Other intent capabilities (10B.2 owns the next batch).

---

— Implementer (Claude Opus 4.7), 10B.1c close v1, 2026-05-26
