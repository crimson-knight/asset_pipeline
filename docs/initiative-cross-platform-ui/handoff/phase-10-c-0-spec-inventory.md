# Phase 10C.0 — Spec inventory + classification

**Date:** 2026-05-25
**Branch:** `phase-10-c-0`
**Source count:** 132 spec files (verified via `find spec -name '*.cr' | wc -l`)
**Files with relative `require`:** 129 (verified via `grep -lr "require_relative\|require \"\\.\\./" spec/`)

Classification rule (per `architecture-decisions.md` Decision 5): **deepest platform dependency**.
A spec is placed in `spec/native_<X>/` if it exercises a platform-gated view/renderer code path
under `-D<X>` AND the platform-specific assertions are the substantive payload of the file.
Multi-platform contract specs stay in `spec/web/` if they pass under plain `crystal spec`
without native link flags.

Platform-flag-gated specs (`{% if flag?(:macos) %}`, etc.) that yield 0 examples under web
AND only exercise meaningful assertions under the native flag are placed in the native
directory so `make test-macos` / `make test-ios` / `make test-android` actually run them.

Specs that use `pending` (placeholder bodies that never run) AND ship under default
`crystal spec` are classified as web — they document a future native probe without
requiring native link flags today.

`UI::AXTest` specs are unconditionally `spec/native_macos/` — they `require` ApplicationServices
runtime and only compile / link under `-Dmacos` with `-framework ApplicationServices`.

## Summary

| Target directory | Spec count | Notes |
|---|---:|---|
| `spec/web/` | 117 | Default `crystal spec` lane. |
| `spec/native_macos/` | 14 | Requires `-Dmacos` + `objc_bridge.o` + AppKit/ApplicationServices link flags. |
| `spec/native_ios/` | 0 | No iOS-only specs today; `views/action_sheet_*` exercises the `-Dios` compile gate via `Phase04CompileCheck` from a web spec. |
| `spec/native_android/` | 0 | No Android-only specs today; `spec/ui/native/collections_spec.cr` has android branches but is dominated by macOS branches and is placed in `spec/native_macos/`. |
| `spec/spec_helper.cr` | 1 | Stays at `spec/spec_helper.cr` (root helper). |
| **Total** | **132** | |

## spec/native_macos/ — 14 specs

All require `UI::AXTest` (which only compiles with `-Dmacos` + ApplicationServices link flags)
OR are HIG validation specs that drive a live NSApp host.

| Current path | Target path | Rationale |
|---|---|---|
| `spec/support/ax_test_patterns.cr` | `spec/native_macos/support/ax_test_patterns.cr` | AXTest helper module loaded by HIG specs. |
| `spec/ui/ax_test/ax_app_spec.cr` | `spec/native_macos/ax_test/ax_app_spec.cr` | AXTest app launch coverage. |
| `spec/ui/ax_test/ax_focus_spec.cr` | `spec/native_macos/ax_test/ax_focus_spec.cr` | AXTest focus coverage. |
| `spec/ui/ax_test/ax_geometry_spec.cr` | `spec/native_macos/ax_test/ax_geometry_spec.cr` | AXTest geometry coverage. |
| `spec/ui/ax_test/ax_identifier_spec.cr` | `spec/native_macos/ax_test/ax_identifier_spec.cr` | AXTest identifier coverage. |
| `spec/ui/ax_test/ax_keys_spec.cr` | `spec/native_macos/ax_test/ax_keys_spec.cr` | AXTest keystroke coverage. |
| `spec/ui/ax_test/ax_resize_spec.cr` | `spec/native_macos/ax_test/ax_resize_spec.cr` | AXTest window resize coverage. |
| `spec/ui/ax_test/ax_screenshot_element_spec.cr` | `spec/native_macos/ax_test/ax_screenshot_element_spec.cr` | AXTest screenshot path. |
| `spec/ui/ax_test/ax_value_writer_spec.cr` | `spec/native_macos/ax_test/ax_value_writer_spec.cr` | AXTest text-field value setter. |
| `spec/ui/hig_validation/macos_action_tap_probe_spec.cr` | `spec/native_macos/hig_validation/macos_action_tap_probe_spec.cr` | Requires AXTest patterns; drives macOS tap probe. |
| `spec/ui/hig_validation/macos_form_layout_spec.cr` | `spec/native_macos/hig_validation/macos_form_layout_spec.cr` | Requires AXTest patterns; drives macOS form layout host. |
| `spec/ui/hig_validation/macos_visual_spec.cr` | `spec/native_macos/hig_validation/macos_visual_spec.cr` | Requires AXTest patterns; drives macOS visual probe. |
| `spec/ui/menu_bar_spec.cr` | `spec/native_macos/menu_bar_spec.cr` | 100% `{% if flag?(:macos) %}` gated; yields 0 examples under web. |
| `spec/ui/native/collections_spec.cr` | `spec/native_macos/native/collections_spec.cr` | All examples gated `{% if flag?(:macos) || flag?(:ios) %}` / `{% if flag?(:android) %}`; yields 0 examples under web. macOS is the runnable lane today. |

## spec/web/ — 117 specs

All other specs. Verified to either run under default `crystal spec` (with examples > 0)
OR to be `pending`-only probes that compile under web.

Includes platform-flag-touching specs whose substantive content runs under web:
- `spec/asset_pipeline/platform_spec.cr` (Platform.has? branching — runs under all flags).
- `spec/ui/status_bar_spec.cr` (1 web example for `UI::StatusBarAppearance`; macOS-gated
  `UI::StatusBar` examples are minority and migrate with the spec when 10B.0/10A.0 splits land).
- `spec/ui/views_spec.cr` (3300 lines, vast majority web-runnable contract assertions;
  `{% if flag?(:macos) %}` and `{% if flag?(:ios) %}` islands are skipped under web build).
- `spec/ui/glass_material/*.cr` (all `pending` placeholders).
- `spec/ui/views/action_sheet_compile_error_spec.cr`,
  `context_menu_compile_error_spec.cr`, `path_control_compile_error_spec.cr` (validate
  macro raise via `Phase04CompileCheck` — runnable under default `crystal spec`).
- `spec/ui/views/action_sheet_spec.cr` (web fallback class; `{% if flag?(:ios) %}` islands
  are minority).

Full path listing (sorted):

<details>
<summary>spec/web/ files (117) — click to expand</summary>

```
spec/asset_pipeline_spec.cr                       → spec/web/asset_pipeline_spec.cr
spec/asset_pipeline/action_dispatcher_spec.cr     → spec/web/asset_pipeline/action_dispatcher_spec.cr
spec/asset_pipeline/action_result_spec.cr         → spec/web/asset_pipeline/action_result_spec.cr
spec/asset_pipeline/amber_integration_spec.cr     → spec/web/asset_pipeline/amber_integration_spec.cr
spec/asset_pipeline/cli/amber_generator_spec.cr   → spec/web/asset_pipeline/cli/amber_generator_spec.cr
spec/asset_pipeline/components/asset_pipeline_integration_test.cr → spec/web/asset_pipeline/components/asset_pipeline_integration_test.cr
spec/asset_pipeline/components/caching_test.cr    → spec/web/asset_pipeline/components/caching_test.cr
spec/asset_pipeline/components/components_test.cr → spec/web/asset_pipeline/components/components_test.cr
spec/asset_pipeline/components/javascript_integration_test.cr → spec/web/asset_pipeline/components/javascript_integration_test.cr
spec/asset_pipeline/dependency_analyzer_spec.cr   → spec/web/asset_pipeline/dependency_analyzer_spec.cr
spec/asset_pipeline/enhanced_front_loader_spec.cr → spec/web/asset_pipeline/enhanced_front_loader_spec.cr
spec/asset_pipeline/enhanced_script_renderer_spec.cr → spec/web/asset_pipeline/enhanced_script_renderer_spec.cr
spec/asset_pipeline/front_loader_script_integration_spec.cr → spec/web/asset_pipeline/front_loader_script_integration_spec.cr
spec/asset_pipeline/native_app_spec.cr            → spec/web/asset_pipeline/native_app_spec.cr
spec/asset_pipeline/native_context_spec.cr        → spec/web/asset_pipeline/native_context_spec.cr
spec/asset_pipeline/native_controller_spec.cr     → spec/web/asset_pipeline/native_controller_spec.cr
spec/asset_pipeline/phase_08c_routes_for_spec.cr  → spec/web/asset_pipeline/phase_08c_routes_for_spec.cr
spec/asset_pipeline/platform_spec.cr              → spec/web/asset_pipeline/platform_spec.cr
spec/asset_pipeline/script_renderer_spec.cr       → spec/web/asset_pipeline/script_renderer_spec.cr
spec/asset_pipeline/stimulus/stimulus_renderer_spec.cr → spec/web/asset_pipeline/stimulus/stimulus_renderer_spec.cr
spec/asset_pipeline/voyager_app_spec.cr           → spec/web/asset_pipeline/voyager_app_spec.cr
spec/asset_pipeline/voyager_controllers_spec.cr   → spec/web/asset_pipeline/voyager_controllers_spec.cr
spec/asset_pipeline/voyager_dispatcher_integration_spec.cr → spec/web/asset_pipeline/voyager_dispatcher_integration_spec.cr
spec/asset_pipeline/voyager_host_bootstrap_spec.cr → spec/web/asset_pipeline/voyager_host_bootstrap_spec.cr
spec/asset_pipeline/voyager_todo_editor_save_disabled_spec.cr → spec/web/asset_pipeline/voyager_todo_editor_save_disabled_spec.cr
spec/components/assets/font_asset_spec.cr         → spec/web/components/assets/font_asset_spec.cr
spec/components/base/component_spec.cr            → spec/web/components/base/component_spec.cr
spec/components/cache/cache_warmer_spec.cr        → spec/web/components/cache/cache_warmer_spec.cr
spec/components/cache/cacheable_spec.cr           → spec/web/components/cache/cacheable_spec.cr
spec/components/cache/memory_cache_store_spec.cr  → spec/web/components/cache/memory_cache_store_spec.cr
spec/components/css/amber_design_system_spec.cr   → spec/web/components/css/amber_design_system_spec.cr
spec/components/css/css_layer_structure_spec.cr   → spec/web/components/css/css_layer_structure_spec.cr
spec/components/css/css_phase2_wcag_spec.cr       → spec/web/components/css/css_phase2_wcag_spec.cr
spec/components/css/css_phase3_capabilities_spec.cr → spec/web/components/css/css_phase3_capabilities_spec.cr
spec/components/css/css_phase4_component_layer_spec.cr → spec/web/components/css/css_phase4_component_layer_spec.cr
spec/components/design_system/design_system_namespace_spec.cr → spec/web/components/design_system/design_system_namespace_spec.cr
spec/components/design_system/primitives_spec.cr  → spec/web/components/design_system/primitives_spec.cr
spec/components/design_system/runtime_alias_spec.cr → spec/web/components/design_system/runtime_alias_spec.cr
spec/components/elements/base/html_element_spec.cr → spec/web/components/elements/base/html_element_spec.cr
spec/components/elements/document/document_elements_spec.cr → spec/web/components/elements/document/document_elements_spec.cr
spec/components/elements/integration_spec.cr      → spec/web/components/elements/integration_spec.cr
spec/components/elements/simple_test_spec.cr      → spec/web/components/elements/simple_test_spec.cr
spec/components/examples/example_components_spec.cr → spec/web/components/examples/example_components_spec.cr
spec/components/phase1_verification_spec.cr       → spec/web/components/phase1_verification_spec.cr
spec/components/phase2_verification_spec.cr       → spec/web/components/phase2_verification_spec.cr
spec/components/phase3_verification_spec.cr       → spec/web/components/phase3_verification_spec.cr
spec/components/phase4_verification_spec.cr       → spec/web/components/phase4_verification_spec.cr
spec/components/phase6_final_verification_spec.cr → spec/web/components/phase6_final_verification_spec.cr
spec/components/reactive/reactive_handler_spec.cr → spec/web/components/reactive/reactive_handler_spec.cr
spec/components/view_generation_spec.cr           → spec/web/components/view_generation_spec.cr
spec/fixtures/phase_08c_macro_raise/native_plus_web_controller_no_routes.cr → spec/web/fixtures/phase_08c_macro_raise/native_plus_web_controller_no_routes.cr
spec/fixtures/phase_08c_macro_raise/no_side.cr    → spec/web/fixtures/phase_08c_macro_raise/no_side.cr
spec/fixtures/phase_08c_macro_raise/web_controller_no_routes.cr → spec/web/fixtures/phase_08c_macro_raise/web_controller_no_routes.cr
spec/fixtures/phase_08c_macro_raise/web_path_without_controller.cr → spec/web/fixtures/phase_08c_macro_raise/web_path_without_controller.cr
spec/import_map/import_map_spec.cr                → spec/web/import_map/import_map_spec.cr
spec/scripts/validate_design_system_manifest_spec.cr → spec/web/scripts/validate_design_system_manifest_spec.cr
spec/support/accessibility_matchers_spec.cr       → spec/web/support/accessibility_matchers_spec.cr
spec/support/accessibility_matchers.cr            → spec/web/support/accessibility_matchers.cr
spec/support/fake_lib_objc_bridge_spec.cr         → spec/web/support/fake_lib_objc_bridge_spec.cr
spec/support/fake_lib_objc_bridge.cr              → spec/web/support/fake_lib_objc_bridge.cr
spec/support/phase04_compile_check.cr             → spec/web/support/phase04_compile_check.cr
spec/ui/app_shortcuts_spec.cr                     → spec/web/ui/app_shortcuts_spec.cr
spec/ui/design_tokens_brand_spec.cr               → spec/web/ui/design_tokens_brand_spec.cr
spec/ui/design_tokens_cascade_spec.cr             → spec/web/ui/design_tokens_cascade_spec.cr
spec/ui/design_tokens_conversion_spec.cr          → spec/web/ui/design_tokens_conversion_spec.cr
spec/ui/design_tokens_default_accent_spec.cr      → spec/web/ui/design_tokens_default_accent_spec.cr
spec/ui/design_tokens_spec.cr                     → spec/web/ui/design_tokens_spec.cr
spec/ui/design_tokens/generators/apple_generator_spec.cr → spec/web/ui/design_tokens/generators/apple_generator_spec.cr
spec/ui/design_tokens/generators/web_generator_spec.cr → spec/web/ui/design_tokens/generators/web_generator_spec.cr
spec/ui/design_tokens/material_spec.cr            → spec/web/ui/design_tokens/material_spec.cr
spec/ui/device_metrics_spec.cr                    → spec/web/ui/device_metrics_spec.cr
spec/ui/fluid_spec.cr                             → spec/web/ui/fluid_spec.cr
spec/ui/form_state_spec.cr                        → spec/web/ui/form_state_spec.cr
spec/ui/glass_material/ios_glass_contrast_spec.cr → spec/web/ui/glass_material/ios_glass_contrast_spec.cr
spec/ui/glass_material/ios_glass_default_spec.cr  → spec/web/ui/glass_material/ios_glass_default_spec.cr
spec/ui/glass_material/ios_glass_env_response_spec.cr → spec/web/ui/glass_material/ios_glass_env_response_spec.cr
spec/ui/glass_material/macos_glass_contrast_spec.cr → spec/web/ui/glass_material/macos_glass_contrast_spec.cr
spec/ui/glass_material/macos_glass_default_spec.cr → spec/web/ui/glass_material/macos_glass_default_spec.cr
spec/ui/glass_material/macos_glass_env_response_spec.cr → spec/web/ui/glass_material/macos_glass_env_response_spec.cr
spec/ui/live_activities_spec.cr                   → spec/web/ui/live_activities_spec.cr
spec/ui/native/callback_registry_spec.cr          → spec/web/ui/native/callback_registry_spec.cr
spec/ui/native/native_handle_spec.cr              → spec/web/ui/native/native_handle_spec.cr
spec/ui/native/native_view_spec.cr                → spec/web/ui/native/native_view_spec.cr
spec/ui/native/reactive_state_spec.cr             → spec/web/ui/native/reactive_state_spec.cr
spec/ui/navigation_coordinator_spec.cr            → spec/web/ui/navigation_coordinator_spec.cr
spec/ui/notifications_spec.cr                     → spec/web/ui/notifications_spec.cr
spec/ui/quick_actions_spec.cr                     → spec/web/ui/quick_actions_spec.cr
spec/ui/renderers/container_query_spec.cr         → spec/web/ui/renderers/container_query_spec.cr
spec/ui/renderers/document_mode_spec.cr           → spec/web/ui/renderers/document_mode_spec.cr
spec/ui/renderers/fluid_emission_spec.cr          → spec/web/ui/renderers/fluid_emission_spec.cr
spec/ui/renderers/swiftkit/button_overrides_spec.cr → spec/web/ui/renderers/swiftkit/button_overrides_spec.cr
spec/ui/renderers/swiftkit/callback_registry_swiftkit_spec.cr → spec/web/ui/renderers/swiftkit/callback_registry_swiftkit_spec.cr
spec/ui/renderers/swiftkit/glass_background_overrides_spec.cr → spec/web/ui/renderers/swiftkit/glass_background_overrides_spec.cr
spec/ui/renderers/swiftkit/group1_overrides_spec.cr → spec/web/ui/renderers/swiftkit/group1_overrides_spec.cr
spec/ui/renderers/swiftkit/group3_overrides_spec.cr → spec/web/ui/renderers/swiftkit/group3_overrides_spec.cr
spec/ui/renderers/swiftkit/list_view_overrides_spec.cr → spec/web/ui/renderers/swiftkit/list_view_overrides_spec.cr
spec/ui/renderers/swiftkit/objc_setter_selector_spec.cr → spec/web/ui/renderers/swiftkit/objc_setter_selector_spec.cr
spec/ui/renderers/system_accent_integration_spec.cr → spec/web/ui/renderers/system_accent_integration_spec.cr
spec/ui/renderers/touch_target_spec.cr            → spec/web/ui/renderers/touch_target_spec.cr
spec/ui/renderers/web_glass_spec.cr               → spec/web/ui/renderers/web_glass_spec.cr
spec/ui/renderers/web_renderer_spec.cr            → spec/web/ui/renderers/web_renderer_spec.cr
spec/ui/state_spec.cr                             → spec/web/ui/state_spec.cr
spec/ui/status_bar_spec.cr                        → spec/web/ui/status_bar_spec.cr
spec/ui/swipe_action_row_spec.cr                  → spec/web/ui/swipe_action_row_spec.cr
spec/ui/view_adapter_spec.cr                      → spec/web/ui/view_adapter_spec.cr
spec/ui/views_spec.cr                             → spec/web/ui/views_spec.cr
spec/ui/views/action_sheet_compile_error_spec.cr  → spec/web/ui/views/action_sheet_compile_error_spec.cr
spec/ui/views/action_sheet_spec.cr                → spec/web/ui/views/action_sheet_spec.cr
spec/ui/views/action_sheet_with_web_fallback_spec.cr → spec/web/ui/views/action_sheet_with_web_fallback_spec.cr
spec/ui/views/context_menu_compile_error_spec.cr  → spec/web/ui/views/context_menu_compile_error_spec.cr
spec/ui/views/context_menu_with_web_fallback_spec.cr → spec/web/ui/views/context_menu_with_web_fallback_spec.cr
spec/ui/views/path_control_compile_error_spec.cr  → spec/web/ui/views/path_control_compile_error_spec.cr
spec/ui/views/path_control_with_web_fallback_spec.cr → spec/web/ui/views/path_control_with_web_fallback_spec.cr
spec/ui/voyager_state_propagation_spec.cr         → spec/web/ui/voyager_state_propagation_spec.cr
spec/ui/web_renderer_route_host_spec.cr           → spec/web/ui/web_renderer_route_host_spec.cr
spec/ui/widgets_spec.cr                           → spec/web/ui/widgets_spec.cr
spec/ui/windows_spec.cr                           → spec/web/ui/windows_spec.cr
```

</details>

## Acceptance gate (pre-move)

- Baseline: `crystal spec` reports 1723 examples, 4 failures, 0 errors, 66 pending (pre-existing).
- All 4 baseline failures are tracked outside Phase 10C.0's scope.
- Reorg must preserve example count.

## Plan

1. Create `spec/web/`, `spec/native_macos/` directory trees.
2. Move 14 native_macos specs.
3. Move 117 web specs.
4. `spec/spec_helper.cr` stays in place; relative-require paths inside specs are updated
   from `../spec_helper` / `../../spec_helper` / `../../../src/...` to the new depth.
5. After each batch: `crystal spec spec/web/` must pass with the same example count.

## Coordination

- 10A.0a and 10B.0 are running in parallel and may add specs under the *current* `spec/ui/`
  tree. When their branches merge, those new specs migrate into `spec/web/` or
  `spec/native_macos/` per this rule.
- 10A.0b (Family 2 view-spec pair rule) depends on this reorg landing.

— Implementer (Phase 10C.0), 2026-05-25
