
# Phase 1 — Validation Rubric: Design Token Foundation

**Audience:** Validator agent.
**Companion docs:** `../../rubric/validation_criteria.md` (universal standards; how to run a check, capture evidence, format the GATE_REPORT), `../../rubric/gate_report_schema.md`, `README.md` (phase orientation). Do **not** read `implementation.md` before forming your expectations from this rubric.

---

## Scope reminder

Verify that this repo now has one unified `UI::DesignTokens` source of truth, three deterministic generators (web/Apple/Android), a working `Brand` override surface, and that every renderer reads tokens through accessor calls rather than hard-coded literals. Evidence lives under `handoff/phase-01-evidence-{YYYY-MM-DD}/`. Default tolerance for color round-trip: ΔL ≤ 0.001, Δc ≤ 0.001, Δh ≤ 0.5°, ΔRGB per channel ≤ 1/255 unless a check overrides it.

---

## Pre-reading checklist

Before running checks:

1. `git log --oneline phase-01-design-token-foundation` — the phase branch where the implementer committed. Note the commits the implementer's handoff lists.
2. `src/ui/design_tokens.cr` — what types exist.
3. `src/ui/design_tokens/generators/` directory — confirm three generators present.
4. `src/ui/design_tokens/dist/` — confirm dist files exist.
5. `spec/ui/design_tokens*` — confirm spec coverage exists.
6. The implementer's handoff message (Deviations and Known concerns sections only).

Do **not** read commit messages beyond the one-line subject. Do not read `implementation.md`.

---

## Checks

Each check below produces one entry in `GATE_REPORT.checks`, in this order.

### 1. `tokens.types-defined`  (required)

- **Verify:** `src/ui/design_tokens.cr` defines `UI::DesignTokens::Color`, `ColorPalette`, `SpacingScale`, `TypeScale`, `TypeStep`, `RadiusScale`, `ShadowScale`, `ShadowLevel`, `MotionScale`, `Breakpoints`, and a `Tokens` aggregate with `getter`s for `colors_light`, `colors_dark`, `spacing`, `type`, `radius`, `shadow`, `motion`, `breakpoints`, and `touch_target_minimum_px : Float64` (default `44.0`).
- **How:** `grep -nE '^\s*(struct|record|class)\s+(Color|ColorPalette|SpacingScale|TypeScale|TypeStep|RadiusScale|ShadowScale|ShadowLevel|MotionScale|Breakpoints|Tokens)\b' src/ui/design_tokens.cr`. Then `grep -nE 'touch_target_minimum_px' src/ui/design_tokens.cr` and confirm a `getter` declaration with `Float64` type and a default of `44.0` somewhere in `Tokens.default`.
- **Pass:** every type listed above appears exactly once; `touch_target_minimum_px` getter present on the `Tokens` aggregate with the correct type and default.
- **Evidence:** `inspections/tokens.types-defined.log` (the grep output).

### 2. `tokens.color-roundtrip`  (required)

- **Verify:** OKLCH ↔ sRGB conversion is implemented and round-trip-stable for every default color.
- **How:** `crystal spec spec/ui/design_tokens_conversion_spec.cr 2>&1 | tee test_output/tokens.color-roundtrip.log`.
- **Pass:** `0 failures, 0 errors, 0 pending`.
- **Evidence:** `test_output/tokens.color-roundtrip.log`.

### 3. `tokens.default-matches-amber`  (required)

- **Verify:** `Tokens.default` reproduces the legacy Amber palette within tolerance. Pick five canonical colors: `brand-primary`, `surface-canvas`, `text-primary`, `border-default`, `danger-indicator`. For each, compare `Tokens.default.colors_light.<role>` to the OKLCH string that was in `amber_theme.cr` before this phase (use `git show <pre-phase-commit>:src/components/css/tokens/amber_theme.cr` to recover the original strings).
- **How:** run a one-off inspection script or a spec under `spec/ui/design_tokens_default_match_spec.cr` if the implementer added one. Otherwise inline: `crystal eval` with a script that prints the five colors and diff against the captured pre-phase values.
- **Pass:** every comparison within ΔL ≤ 0.001, Δc ≤ 0.001, Δh ≤ 0.5°.
- **Evidence:** `inspections/tokens.default-matches-amber.diff`.

### 4. `tokens.brand-override-merge`  (required)

- **Verify:** A `Brand` subclass that overrides only `brand_primary` leaves every other field equal to the default.
- **How:** `crystal spec spec/ui/design_tokens_brand_spec.cr 2>&1 | tee test_output/tokens.brand-override-merge.log`.
- **Pass:** `0 failures`.
- **Evidence:** `test_output/tokens.brand-override-merge.log`.

### 5. `generator.web-deterministic`  (required)

- **Verify:** `WebGenerator.generate(Tokens.default)` is byte-stable across two consecutive calls and matches the checked-in dist file.
- **How:**
  ```
  crystal run scripts/regenerate_design_tokens.cr -- --stdout-web > /tmp/web1.css
  crystal run scripts/regenerate_design_tokens.cr -- --stdout-web > /tmp/web2.css
  diff /tmp/web1.css /tmp/web2.css
  diff /tmp/web1.css src/ui/design_tokens/dist/web_tokens.css
  ```
- **Pass:** both diffs empty.
- **Evidence:** `inspections/generator.web-deterministic.diff` (empty file is fine; include it anyway).

### 6. `generator.web-content`  (required)

- **Verify:** Generated CSS contains every required variable family: `--ap-color-brand-primary`, `--ap-space-1`, `--ap-radius-md`, `--ap-shadow-raised`, `--ap-motion-duration-fast`, `--ap-type-body-size`, `--ap-bp-md`. Light and dark blocks both present. **No `--amber-*` aliases are emitted** — the prefix change to `--ap-*` is total across the initiative.
- **How:** `grep -E '^\s*--ap-' src/ui/design_tokens/dist/web_tokens.css | sort -u` to confirm the seven sample variables are present. Then `grep -E '^\s*--amber-' src/ui/design_tokens/dist/web_tokens.css` and confirm **zero matches** (the `--amber-*` alias block has been removed; any remaining match is a regression).
- **Pass:** all seven variables present, both schemes present, **no `--amber-*` aliases present**.
- **Evidence:** `inspections/generator.web-content.log`.

### 7. `generator.apple-deterministic`  (required)

- **Verify:** Same as #5 for Swift output.
- **How:**
  ```
  crystal run scripts/regenerate_design_tokens.cr -- --stdout-apple > /tmp/a1.swift
  crystal run scripts/regenerate_design_tokens.cr -- --stdout-apple > /tmp/a2.swift
  diff /tmp/a1.swift /tmp/a2.swift
  diff /tmp/a1.swift src/ui/design_tokens/dist/AssetPipelineTokens.swift
  ```
- **Pass:** both diffs empty.
- **Evidence:** `inspections/generator.apple-deterministic.diff`.

### 8. `generator.apple-content`  (required)

- **Verify:** Swift output defines `AssetPipelineTokens.Color.brandPrimary`, `.Spacing.x4`, `.Radius.md`, `.Typography.body`, `.Motion.durationFast`, and a `.Color.Dark.brandPrimary`. Every `SwiftUI.Color(.sRGB, red: …)` triple is within 1/255 of the value computed from the corresponding `Tokens.default.colors_*.<role>`.
- **How:** inspect file contents; sample 5 colors and reconcile against `Tokens.default`. Capture the sample table.
- **Pass:** every sampled color matches within tolerance.
- **Evidence:** `inspections/generator.apple-content.log`.

### 9. `generator.android-deterministic`  (required)

- **Verify:** Same as #5 for the four XML files.
- **How:** regenerate via the script; diff against the checked-in dist for `values/colors.xml`, `values-night/colors.xml`, `values/dimens.xml`, `values/themes.xml`.
- **Pass:** all four diffs empty.
- **Evidence:** `inspections/generator.android-deterministic.diff`.

### 10. `generator.android-well-formed`  (required)

- **Verify:** Each of the four XML files parses cleanly.
- **How:** `crystal eval 'require "xml"; %w[values/colors.xml values-night/colors.xml values/dimens.xml values/themes.xml].each { |p| XML.parse(File.read("src/ui/design_tokens/dist/android/#{p}")) }'`.
- **Pass:** no exception raised.
- **Evidence:** `test_output/generator.android-well-formed.log`.

### 11. `renderer.web-no-hardcoded`  (required)

- **Verify:** No hard-coded brand colors, hex literals, or scalar literals for radius/font-size/spacing in `web_renderer.cr` visit methods. Allowed: `to_rgb_int` calls that originate from a user-set `view.background` `UI::Color` value (these come from the user, not the brand); literal `display: inline-block` and similar non-token CSS.
- **How:** `grep -nE '"#[0-9A-Fa-f]{3,8}"|rgba\([0-9]+,|9999px|cornerRadius.*[0-9]+\.[0-9]' src/ui/renderers/web_renderer.cr | grep -v '^[0-9]*:\s*#'`. Then manually inspect each remaining hit and classify.
- **Pass:** every remaining hit is either (a) from a user-supplied `UI::Color` attribute or (b) annotated with `# Tier 2` within 3 lines.
- **Evidence:** `inspections/renderer.web-no-hardcoded.log` with classification notes per hit.

### 12. `renderer.appkit-no-hardcoded`  (required)

- **Verify:** Same as #11 for `appkit_renderer.cr`. Specifically confirm: `amber_brand_gold` is **deleted** (or now calls `token_color(:brand_primary, ...)`); every `LibObjCBridge.nsfont_system(<float>)` literal in a visit method derives that float from a token; every `setCornerRadius:` numeric arg derives from `token_radius(:...)`.
- **How:** `grep -nE 'amber_brand_gold|nsfont_system\([0-9]+\.[0-9]|nscolor_rgba\([0-9]+\.[0-9]' src/ui/renderers/appkit_renderer.cr`. Classify each.
- **Pass:** `amber_brand_gold` absent. Every numeric-literal hit is in a token helper (lower portion of the file) or annotated `# Tier 2`.
- **Evidence:** `inspections/renderer.appkit-no-hardcoded.log`.

### 13. `renderer.uikit-no-hardcoded`  (required)

- **Verify:** Same as #12 for `uikit_renderer.cr`.
- **How:** mirror #12 with `uicolor_rgba`, `systemFontOfSize:`, etc.
- **Pass:** same as #12.
- **Evidence:** `inspections/renderer.uikit-no-hardcoded.log`.

### 14. `renderer.android-no-hardcoded`  (required)

- **Verify:** No literal `0xFF......_u32` ARGB or `setTextSize(..., <float>)` literal arguments in `android_renderer.cr` visit methods.
- **How:** `grep -nE '0xFF[0-9A-Fa-f]{6}_u32|0xFF[0-9A-Fa-f]{6}\.to_i32|setTextSize.*[0-9]+\.[0-9]|android_textview_set_text_color.*0x' src/ui/renderers/android_renderer.cr`. Classify.
- **Pass:** every hit is either annotated `# Tier 2` (platform-system color like `0xFF8E8E93` for iOS-like secondary label) or is in the glass-strength block (lines 2167–2172 in the pre-phase file — that block is owned by phase 5).
- **Evidence:** `inspections/renderer.android-no-hardcoded.log`.

### 15. `specs.suite-green`  (required)

- **Verify:** Full Crystal test suite passes.
- **How:** `cd /Users/crimsonknight/open_source_coding_projects/asset_pipeline && crystal spec 2>&1 | tee test_output/specs.suite-green.log`.
- **Pass:** `0 errors, 0 failures, 0 pending`. Pending tests appearing here that did not exist before this phase are a fail.
- **Evidence:** `test_output/specs.suite-green.log`.

### 16. `build.web-cleanly`  (required)

- **Verify:** Web entry compiles with no new warnings.
- **How:** `crystal build --no-codegen src/asset_pipeline.cr 2>&1 | tee test_output/build.web-cleanly.log`.
- **Pass:** exit 0, no warnings referencing files under `src/ui/design_tokens/` or the migrated renderer files.
- **Evidence:** `test_output/build.web-cleanly.log`.

### 17. `build.platform-samples-compile`  (required)

- **Verify:** macOS / iOS / Android sample entry points still compile (`--no-codegen`).
- **How:** for each documented sample in `samples/cross_platform/`, run the build command with `--no-codegen` and the platform `-D` flag. Capture each output.
- **Pass:** every sample build exits 0.
- **Evidence:** `test_output/build.platform-samples-compile-{macos,ios,android}.log`. If a sample is documented as out-of-scope for this phase in the implementer's handoff Deviations, mark this check `blocked: true` and explain.

### 18. `cascade.web-changes-on-brand-override`  (required, behavioral + conformance)

- **Bar:** behavior (cascade actually flows) + conformance (rendered pixel matches the override, not just the CSS variable).
- **Verify:** Defining a `Brand` subclass that sets `brand_primary` to `#ff00ff` (sentinel magenta) and re-rendering the brand-cascade demo page actually paints magenta on the rendered widget.
- **How:**
  1. Apply a temporary edit to `samples/cross_platform/web/brand_cascade_demo.cr` (created in Phase 1 Step 12) so its `SentinelBrand` returns `Color.hex("#ff00ff")` for `brand_primary`. The demo source must contain at least one Button (or a div with `data-testid="brand-primary-sample"`) whose background is bound to `brand_primary`.
  2. Build the page: `crystal run samples/cross_platform/web/brand_cascade_demo.cr`.
  3. Drive Chrome via CDP per `../../rubric/behavior-simulation-toolkit.md` §3.2; set the viewport to 1280×800 light scheme via `Emulation.setDeviceMetricsOverride` + `Emulation.setEmulatedMedia`.
  4. Capture the rendered page: `Page.navigate` to the `file://` URL, poll `document.readyState === "complete"`, then `Page.captureScreenshot` (`captureBeyondViewport: true`).
  5. Evaluate via `Runtime.evaluate` (use the `DevTools#evaluate` helper from the canonical script):
     ```js
     const el = document.querySelector('[data-testid="brand-primary-sample"]');
     const rect = el.getBoundingClientRect();
     const cs = getComputedStyle(el);
     ({
       computed_background: cs.backgroundColor,
       computed_var: cs.getPropertyValue('--ap-color-brand-primary'),
       bbox: {x: rect.x, y: rect.y, w: rect.width, h: rect.height}
     })
     ```
  6. Sample the center pixel of the bounding box from the captured PNG; convert to sRGB; assert distance to `(255, 0, 255)` is within ΔE 76 ≤ 8 (allows for anti-aliasing).
  7. Revert the edit. Verify `git status --short` is clean.
- **Pass:**
  - `computed_background` is `rgb(255, 0, 255)` (or equivalent — anti-alias-free CSS color).
  - The sampled center pixel from the captured PNG is within ΔE ≤ 8 of magenta.
  - `computed_var` is `#ff00ff` or `rgb(255, 0, 255)` or the equivalent OKLCH triple resolving to magenta.
- **Evidence:** `screenshots/cascade.web-changes-on-brand-override.png`, `inspections/cascade.web-changes-on-brand-override-computed-style.json` (with the evaluation result above), `inspections/cascade.web-changes-on-brand-override-pixel-sample.log` (the center-pixel RGB + ΔE), plus a `notes` entry confirming revert.

### 19. `cascade.macos-changes-on-brand-override`  (required, behavioral)

- **Verify:** Same as #18 for the macOS sample. Apply the same `SentinelBrand` to `samples/cross_platform/web/brand_cascade_demo.cr` (or the macOS counterpart if one is documented in the implementer's handoff), build the macOS sample with the screenshot harness in `samples/cross_platform/macos_host/` (if present), capture in light scheme.
- **How:** temporary edit to the cascade demo source + build + `xcrun simctl` or whatever harness exists. Revert.
- **Pass:** the captured PNG shows sentinel magenta on the same element family as in #18.
- **Evidence:** `screenshots/cascade.macos-changes-on-brand-override.png`, plus revert confirmation in `notes`.
- **Note:** if the macOS sample harness is not present (the implementer's handoff says it lands later), mark this check `blocked: true` with that explanation.

### 20. `cascade.android-or-ios-changes-on-brand-override`  (required, behavioral)

- **Verify:** Same as #18 for at least one of iOS or Android — whichever sample is buildable in the current environment.
- **How:** mirror #18/#19 on the chosen platform, editing `samples/cross_platform/web/brand_cascade_demo.cr` as the cascade entry point. iOS via `xcrun simctl io booted screenshot`; Android via the existing emulator harness if present.
- **Pass:** sentinel magenta visible on the brand-primary element.
- **Evidence:** `screenshots/cascade.{ios|android}-changes-on-brand-override.png`.
- **Note:** if neither environment is available, mark `blocked: true`. The team lead will decide whether to unblock or to send back. Do not skip silently.

### 21. `docs.regen-script-runs`  (required)

- **Verify:** `scripts/regenerate_design_tokens.cr` runs end-to-end and produces the three dist artifacts.
- **How:** `crystal run scripts/regenerate_design_tokens.cr 2>&1 | tee test_output/docs.regen-script-runs.log`. Confirm dist files updated on disk; then `git diff --stat src/ui/design_tokens/dist/` to confirm no unintended drift.
- **Pass:** script exits 0; no diff against checked-in dist after running.
- **Evidence:** `test_output/docs.regen-script-runs.log`, `inspections/docs.regen-script-runs-diff.log`.

### 22. `docs.public-api-documented`  (optional)

- **Verify:** `UI::DesignTokens::Tokens`, `Brand`, and the three generator classes have doc comments stating their contract.
- **How:** `grep -B1 '^\s*class\s\+\(Tokens\|Brand\|WebGenerator\|AppleGenerator\|AndroidGenerator\)' src/ui/design_tokens.cr src/ui/design_tokens/generators/*.cr`.
- **Pass:** every match has a `#`-prefixed comment line directly above.
- **Evidence:** `inspections/docs.public-api-documented.log`.

---

## Verdict computation

`PASS` if every `required: true` check has `passed: true`. `blocked: true` counts as a failure for verdict purposes.

If checks 19 or 20 are `blocked` purely because of environment unavailability (no macOS / no emulator on the validation machine), record them as blocked with a clear explanation. The team lead will adjudicate whether to unblock the environment and re-run, or to send the phase back to the implementer.

Return your single-message report per `../../rubric/validation_criteria.md` "Returning the report".
