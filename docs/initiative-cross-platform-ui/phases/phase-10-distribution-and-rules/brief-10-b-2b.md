# Phase 10B.2b — Action + focus + keyboard accessibility

**Branch:** `phase-10-b-2b` from `phase-10` (tag `phase-10-batch-3-merged-2026-05-26`).
**Status:** v1. Predecessor: 10B.2a closed.

## Context

10B.2a shipped static AX metadata (label, hint, role, traits, value, identifier). 10B.2b adds dynamic accessibility semantics: keyboard interaction, focus management, custom AX actions.

## Deliverables

1. **`UI::View` action vocabulary:**
   - `accessibility_actions : Array(UI::AccessibilityAction)` — custom AX actions surfaced to AT users.
   - `UI::AccessibilityAction.new(name : String, &block)` value type.
   - Web: emits a custom widget actions map (Web Speech API patterns where applicable) + ensures the element is focusable.
   - UIKit: `accessibilityCustomActions = [UIAccessibilityCustomAction]`.
   - AppKit: `setAccessibilityCustomActions:`.
   - Android: `addAccessibilityAction` via AccessibilityNodeInfo (best-effort; document JNI gap if necessary).

2. **Focus management:**
   - `focused : Bool` property on `UI::View`.
   - `focusable : Bool` property (defaults to true for interactive widgets, false for static).
   - `tab_index : Int32?` — explicit tab order override.
   - Web: emits `tabindex="0|-1"`, focus ring CSS hook.
   - UIKit: `becomeFirstResponder` / `resignFirstResponder` calls on `focused` mutation.
   - AppKit: `makeFirstResponder:` via window.
   - Android: `requestFocus()` / `clearFocus()`.

3. **Keyboard shortcuts:**
   - `keyboard_shortcut : UI::KeyboardShortcut?` — `Cmd+S`, `Ctrl+Shift+P`, etc.
   - `UI::KeyboardShortcut` value type with modifier flags + key.
   - Web: `accesskey` attribute + JS keydown listener wired by the rendering surface.
   - UIKit: `UIKeyCommand` array.
   - AppKit: `keyEquivalent` + `keyEquivalentModifierMask`.

4. **Specs** — `spec/web/ui/accessibility_actions_spec.cr` + `accessibility_focus_spec.cr` + `accessibility_keyboard_spec.cr`. Each covers the web emission + cross-renderer threading via stub assertions.

5. **Close handoff** — per-property table + per-platform mapping + known gaps + Codex verdict.

## Workflow

1. `git checkout -b phase-10-b-2b phase-10`.
2. Extend `UI::View` properties.
3. Thread through web + native renderers.
4. Specs + close handoff.
5. Codex review.
6. Standard footer.

## Acceptance

- ✅ 3 property families shipped + 2 value types.
- ✅ All 4 renderers thread them.
- ✅ Specs pass.
- ✅ Lint + build green.
- ✅ Codex APPROVE.

## Out of scope

- VoiceOver / TalkBack runtime testing.
- Environment-driven contracts (motion preferences etc.) — 10B.2c.

— Architect (Claude Opus 4.7), 10B.2b brief v1
