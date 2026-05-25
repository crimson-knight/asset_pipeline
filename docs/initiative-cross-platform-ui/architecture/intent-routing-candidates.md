# Intent Routing Candidates — Class A Only

**Companion to:** `intent-catalog.md`.

This document lists every Class A intent (widget-routing intents) with its full capabilities block, per-platform default translation, and rationale. Class A intents get the four-part contract per `tier-2-translation-contract.md`; Class D intents do not.

Codex co-plan §1 predicted 1-3 Class A intents in the entire framework. The final count is **1**.

---

## `:swipe_actions`

### Identity
- **intent_identifier_crystal:** `:swipe_actions`
- **primary_apple_name:** `swipeActions`
- **catalog entry:** `intent-catalog.md` §"Class A — Widget-routing intents"

### Capabilities

```crystal
intent :swipe_actions do
  capabilities do
    # SwiftUI/UIKit API surface (directly backed by swipeActions / UISwipeActionsConfiguration):
    supports_edge :leading                            # swipeActions(edge: .leading, ...)
    supports_edge :trailing                           # swipeActions(edge: .trailing, ...)
    supports_role :destructive                        # SwiftUI Button.role
    supports_role :default                            # SwiftUI Button (no role)
    supports_disabled_actions true                    # Button.disabled() modifier
    requires_row_identity_dispatch true               # callbacks need to know which row

    # HIG-mandated invariants (gestures.md:23,31 + accessibility.md:134):
    requires_visible_or_keyboard_alternative true     # HIG gestures.md:23 — gesture cannot be sole path
    requires_accessibility_custom_actions true        # HIG accessibility.md:134 — non-gesture path via custom actions
    supports_voiceover_actions true                   # accessibilityAction modifier honored
    supports_switch_control_activation true           # focus + activation via Switch Control
    supports_voice_control_labels true                # action labels match what Voice Control matches on
    does_not_conflict_with_system_gestures true       # edge-swipes don't fight system back-gesture
  end

  defaults do
    ios        UI::SwipeActionRow
    ipados     UI::SwipeActionRow
    macos      UI::InlineActionRow      # MISSING — see intent-backlog.md B-001
    android    UI::SwipeActionRow       # STUB — android_renderer.cr:3148; see B-035
    web_wide   UI::InlineActionRow      # MISSING — see intent-backlog.md B-002
    web_narrow UI::SwipeActionRow
  end
end
```

**Removed from earlier drafts (no source backing):**
- `supports_full_swipe` / `full_swipe_destructive_safe` — `allowsFullSwipe` exists in SwiftUI's `swipeActions(edge:allowsFullSwipe:content:)` but the "destructive-safe" semantic is a design opinion, not a HIG rule. If the framework wants to encode that opinion, it belongs in a separate `framework_opinion` block, not in `capabilities`.
- `supports_role :cancel` — SwiftUI `Button.role` accepts `.cancel` but the cancel role is meant for dismissal-style actions, not swipe-row actions. Removed pending a use case.
- `requires_confirmation_for_destructive_full_swipe` — UX recommendation, not a HIG or API requirement. Apps that want this discipline implement it via `:confirmation_dialog` after the swipe action; not a property of `:swipe_actions` itself.
- `preserves_focus_after_action` — desirable but not specified by SwiftUI or HIG.

These were architect opinions that hadn't been validated against the cited sources. The capability block now reflects only what's backed by SwiftUI's API + HIG's accessibility rules.

### Per-platform default rationale

| Platform | Default widget | Reasoning |
|---|---|---|
| iOS | `UI::SwipeActionRow` | Native swipe gesture is the idiomatic affordance. UIKit `UISwipeActionsConfiguration` backs this. |
| iPadOS | `UI::SwipeActionRow` | Same as iOS; iPadOS list rows support swipe. |
| macOS | `UI::InlineActionRow` (missing) | macOS has no swipe gesture on lists. Idiomatic AppKit equivalent is visible trailing buttons. The current `UI::SwipeActionRow` renderer already emits inline buttons on AppKit (`appkit_renderer.cr:3801`), so this is partially shipped — but it's masquerading under the wrong type name. Phase 10 introduces `UI::InlineActionRow` as the named default. |
| Android | `UI::SwipeActionRow` (STUB) | Android renderer is explicitly a stub at `android_renderer.cr:3148` — defers proper Material `SwipeToDismissBox` integration. Backlog item B-035. |
| web_wide | `UI::InlineActionRow` (missing) | Desktop web has no native swipe gesture. Hover/right-click affordances + visible trailing buttons are idiomatic. |
| web_narrow | `UI::SwipeActionRow` | Mobile web honors touch gestures; CSS+JS libraries provide swipe-reveal. |

### Why this is Class A (and not Class D)

Class A vs Class D boils down to whether the framework picks a **materially different concrete widget** per platform. For `:swipe_actions`:

- iOS uses a row that listens for swipe gesture and reveals hidden actions on edge-reveal.
- macOS/web-wide uses a row with visible trailing buttons — no hidden state, no gesture.

These are structurally different views. A single `UI::SwipeActionRow` class with a `mobile_breakpoint_px` property today fudges this by branching internally, but the renderer-side abstraction is brittle: AppKit's renderer ignores most swipe-action properties and just lays out the trailing buttons. Class A formalizes the split.

`:context_menu` is Class D, not Class A, because while the gesture differs per platform (long-press vs right-click), the conceptual widget is the same — a popover menu. The framework doesn't pick a different concrete class per platform; it picks a different trigger gesture, which is renderer-internal.

### Override examples

```crystal
# App-wide override: on macOS-wide, use the new DragHandleRow class instead.
class VoyagerApp < UI::App
  override_intent :swipe_actions, with: UI::DragHandleRow, on: [:macos, :web_wide]
end

# Screen-scoped override: SettingsScreen always uses InlineActionRow regardless of platform.
class SettingsScreen < UI::Screen
  override_intent :swipe_actions, with: UI::InlineActionRow, on: :all
end
```

### Capability validation

If an override declares a widget that doesn't satisfy `:swipe_actions`'s capability set, the framework raises with a specific message at registration time:

```
UI::Intent::CapabilityMismatchError:
  Override for :swipe_actions with UI::DragHandleRow on platforms [:macos, :web_wide]
  does NOT declare capability `requires_accessibility_custom_actions`.

  :swipe_actions requires this per HIG accessibility.md:134 (gesture must not be the sole path).
  UI::DragHandleRow should declare `provides :accessibility_custom_actions` in its widget capabilities,
  OR a different override widget should be chosen.
```

This is the guardrail Codex's antagonist pass identified as missing in scoping v2.

---

## Why only one Class A intent?

The Codex co-plan predicted "5-10 widget-routing intents total"; the actual scoping work produced one. Why?

1. **Most cross-platform interaction differences are renderer-internal.** When SwiftUI's `Menu` and Android's `DropdownMenu` are visually different but functionally identical — same API, same callbacks, same options — that's renderer-internal. One Crystal class, different `visit(view)` implementations. Class D.

2. **The materially-different-widget bar is high.** For Class A to apply, the framework needs to swap *entire* concrete classes per platform — not just style values. `:swipe_actions` qualifies because iOS swipes (hidden state revealed by gesture) and macOS inline buttons (always-visible state) really are different widgets, not the same widget with different styling.

3. **Routing has a cost.** Override registries + capability validation + resolver patterns are real complexity. Most apps don't need to override widget choice per platform; they just want the framework's default to be sensible. Class D's direct-modifier shape gets there without the contract overhead.

If a future phase identifies a new Class A candidate (e.g., `:reorder_list_items` if the drag-handle vs up-down-button divergence proves to be a different widget rather than the same widget with different rendering), it gets added here.

— Architect (Claude Opus 4.7)
