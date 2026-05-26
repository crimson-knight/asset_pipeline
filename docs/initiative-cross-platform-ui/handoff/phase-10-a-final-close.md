# Phase 10A.final — Close handoff

**Date:** 2026-05-26.
**Branch:** `phase-10-a-final` cut from `phase-10` (after 10A.0a/b/c, 10B.0–10B.5, 10C.0 all merged).
**Status:** Deliverables 1–3 complete. Acceptance gate met.

---

## Deliverables status

| # | Deliverable | Status | Artifact |
|---|---|---|---|
| 1 | Public-API doc enrichment | DONE (targeted) | 4 files: `action_result.cr`, `state.cr`, `windows.cr`, `notifications.cr` |
| 2 | Family 4 — test_id hygiene rules | DONE (3 rules) | `src/lsp_rules/family_4_test_id_hygiene/` + 11 fixtures + spec |
| 3 | Family 5 — deep partial rules | DONE (2 new rules + backfill spec for the 10C.0 directory rule) | `src/lsp_rules/family_5_partial/{native_spec_has_platform_flag,cross_target_spec_purity}_rule.cr` + 14 fixtures + spec |

---

## Deliverable 1 — Public-API docs

The iter 5/6 doc sweep from Phase 10A.0a already landed file headers and
per-class summaries across ~90 files. Per
[[reflection-over-shotgun]], 10A.final's pragmatic pass focused on
files where per-method content was thin OR the public-API contract was
worth documenting in usage example form:

| File | Surface enriched |
|---|---|
| `src/asset_pipeline/action_result.cr` | All 5 `ActionResult` subclasses now carry usage snippets (`Navigate`, `Pop`, `Rerender`, `ReplaceRoot`, `RenderInline`), per-getter descriptions, and a note on the dispatcher's "mount-before-publish" invariant. |
| `src/ui/state.cr` | `UI::State(T)#value=` documents the equality-skip semantic; `on_change` documents listener ordering / exception behavior; `remove_listeners` documents the GC use-case. Added a selection-state example. |
| `src/ui/windows.cr` | `WindowTitlebarStyle` enum gained per-variant docs (Automatic / Standard / Unified / UnifiedCompact / Hidden). `WindowSize` clamping documented. `WindowConfiguration` properties + helper methods (`display_title`, `normalized_preferred_size`, `apply`) documented. `Windows.configure` + `Windows.apply` documented with example. |
| `src/ui/notifications.cr` | `NotificationAuthorizationStatus` enum, `NotificationRequest` properties + `effective_delay_seconds` floor logic, `NotificationAction` purpose. |

Total: 4 files, ~50 incremental doc blocks added. The remaining
~80 `src/ui/views/*.cr` files were audited and already carry adequate
class-level docs from iter 5/6 (skipped per "skip trivial getters,
return-the-X self-doc, override boilerplate" guidance in the brief).

Files that the brief listed as priority 1–3 (`view.cr`, `intent.cr`,
`app.cr`, `screen.cr`, `controller.cr`, `action_dispatcher.cr`,
`form_state.cr`, `screen_context.cr`, `environment.cr`,
`design_tokens.cr`) were ALREADY documented per-method by prior phases;
the audit confirmed coverage and no further enrichment was needed.

---

## Deliverable 2 — Family 4 test_id hygiene

3 narrow regex-based rules in `src/lsp_rules/family_4_test_id_hygiene/`:

| Rule | Catches |
|---|---|
| `family_4/interactive_widget_test_id` | `samples/<file>.cr` instantiates an interactive widget (Button, TextField, Toggle, Picker, etc.) into a variable but no `<var>.test_id =` appears within 15 lines. |
| `family_4/spec_test_id_reference` | `*_spec.cr` references a test_id via `find_by_test_id("foo")` / `with_test_id("foo")` / `test_id: "foo"` / `data-testid="foo"` but no `<receiver>.test_id = "foo"` setter exists in the same file. |
| `family_4/unique_test_id_per_screen` | Two views within a single `class FooScreen < UI::Screen`'s `build` body declare the same string-literal `test_id`. Dynamic / interpolated ids are skipped (uncheckable at lint time). |

**Catalog of interactive widgets** in
`InteractiveWidgetTestIdRule::INTERACTIVE_WIDGETS` (21 entries —
Button, IconButton, LinkButton, MenuButton, ToggleButton, TextField,
SecureField, SearchField, TextArea, TextEditor, Toggle, Checkbox,
RadioGroup, Slider, Stepper, SegmentedControl, Picker, DatePicker,
TimePicker, ColorPicker, ComboBox). Decorative views (Label, Image,
Card, Spacer, Divider, etc.) are intentionally excluded.

**Fixture coverage:** 11 fixtures (3 rules × {pass + fail + 2+
false-positive guards}) under
`spec/web/lint_conventions/fixtures/family_4_test_id_hygiene/`.

**Pre-existing widget catalog hosts** (`hig_showcase.cr`,
`ios_host/hig_bridge.cr`, `android_material_bridge.cr`,
`macos_app.cr`, `brand_cascade_demo.cr`,
`phase-08b-native-spike/src/spike_app.cr`) carry
`# lint:disable=family_4/interactive_widget_test_id` rationales — they
identify widgets by HIG slug or by accessibility_label rather than by
test_id.

---

## Deliverable 3 — Family 5 deep partial rules

2 new rules in `src/lsp_rules/family_5_partial/` extend Phase 10C.0's
`spec_platform_directory_rule`:

| Rule | Catches |
|---|---|
| `family_5_partial/native_spec_has_platform_flag` | Spec under `spec/native_<platform>/` has no `{% if flag?(:<platform>) %}` guard (raw or in an `\|\|` OR-combination including the platform) AND no recognized native spec_helper require. |
| `family_5_partial/cross_target_spec_purity` | Spec references a renderer / bridge belonging to a different platform tree (e.g. `spec/web/` references `UI::AppKit::Renderer` or `LibAndroidBridge`). Uses identifier-aware left-boundary matching so `LibObjCBridge` does NOT match `FakeLibObjCBridge` (the test double in the web renderer specs). |

**Forbidden-token map** (per-tree, in `cross_target_spec_purity_rule.cr`):

| Tree | Forbidden |
|---|---|
| `spec/web/` | AppKit + UIKit + Android renderers/bridges |
| `spec/native_macos/` | UIKit + Android |
| `spec/native_ios/` | AppKit + Android |
| `spec/native_android/` | AppKit + UIKit |

**Fixture coverage:** 14 fixtures (covering all 3 Family 5 rules
including 2 backfill fixtures for the previously-untested
`spec_platform_directory_rule`) under
`spec/web/lint_conventions/fixtures/family_5_partial/`.

---

## Acceptance gate

| Check | Status |
|---|---|
| `crystal run scripts/lint_conventions.cr` | OK (484 files, **19 rules**, 0 diagnostics) |
| `crystal spec spec/web/lint_conventions/` | 83 examples, 0 failures (53 baseline + 14 Family 4 + 16 Family 5) |
| `crystal build --no-codegen src/ui.cr` | Compiles cleanly |
| `crystal spec spec/web/` (full) | 2085 examples, 4 failures, 2 errors — identical to pre-10A.final baseline (failures in `views_spec.cr` / `intent_spec.cr` / `android_swipe_action_row_spec.cr` pre-date this sub-phase) |

**Rule count progression:**

| Phase | Rules |
|---|---:|
| 10A.0a (Family 1) | 5 |
| 10A.0b (Family 2) | 3 |
| 10A.0c (Family 3) | 5 |
| 10C.0 (Family 5 partial) | 1 |
| 10A.final (Family 4 + Family 5 deep) | **+5** (3 F4 + 2 F5) |
| **Total** | **19** |

---

## Commits

| SHA | Subject |
|---|---|
| `0a44e9a2` | Family 4 test_id hygiene rules |
| `430b2536` | Family 5 deep partial rules |
| `7c1911fc` | Doc-pass: ActionResult / State / Windows |
| `5f0d03b8` | Doc-pass: Notifications |

---

## Phase 10 status after 10A.final

With 10A.final closed, the Phase 10 distribution-and-rules arc is
complete except for owner hands-on validation (10D, out of scope):

| Sub-phase | Status |
|---|---|
| 10A.0a (Family 1 — naming) | CLOSED |
| 10A.0b (Family 2 — view-spec pair) | CLOSED |
| 10A.0c (Family 3 — architectural) | CLOSED |
| 10A.final (Family 4 + Family 5 deep + public docs) | **CLOSED (this handoff)** |
| 10B.0 — Intent resolver substrate | CLOSED |
| 10B.1a/b/c — SwipeActions + InlineActionRow + Android | CLOSED |
| 10B.2a/b/c — Accessibility properties | CLOSED |
| 10B.3.0 — Class C bridge substrate | CLOSED |
| 10B.3.x — Class C feature implementations | CLOSED |
| 10B.4 — Missing widgets (4 ships) | CLOSED |
| 10B.5 — Class D implementations | (per 10-b-5 brief) |
| 10C.0 — Spec inventory + directory rule | CLOSED |
| 10D — Owner hands-on | OUT OF SCOPE per brief |

— Implementer (Claude Opus 4.7), Phase 10A.final close
