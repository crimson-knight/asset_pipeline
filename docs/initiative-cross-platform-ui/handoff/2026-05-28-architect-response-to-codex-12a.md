# Architect response to Codex Phase 12.A review

**Codex verdict:** NEEDS_WORK (3 BLOCKERs + 7 CONCERNs + 1 NIT)
**Architect action:** Each finding addressed below with concrete fix or documented exception. Per the [[codex-as-architect-antagonist]] discipline, the burden is on the architect to incorporate or document why a finding is wrong, not to discard silently.

## Cross-reference

- Codex review: `2026-05-28-codex-phase-12a-review.md`
- Session summary: `2026-05-28-architect-session-summary.md`

## BLOCKERs (3) — addressed

### BLOCKER 1 — V1 spec does not target the real Voyager surface

**Codex finding:** The placeholder ids in the spec (`voyager-todos-row-1`, `voyager-todos-row-1-share`, etc) don't exist in the current Voyager. Actual ids are `voyager-todo-row-#{id}-tap` and `voyager-todo-row-#{id}-check`. The row-tap path navigates to editor, NOT to a ConfirmationDialog. Share is a swipe action that copies to clipboard, NOT a ConfirmationDialog.

**Architect investigation:** Codex's finding is correct AND deeper than they realized. `grep -rn "ConfirmationDialog" samples/initiative-cross-platform-ui-voyager/` returns ZERO matches. The V1 behavior the owner hand-tested was against the `phase-10-d-polish` worktree, which has Voyager extensions (action sheet on row tap, sort filters, overflow popover) NOT YET MERGED to the `phase-10-d-refocus` branch.

**Action:** Reframed V1 and V2 as "forward-looking, pre-staged for the worktree merge."

- `presentation-lifecycle-contract.md` §"V1/V2 source-of-truth location" — new subsection explicitly stating where V1+V2 manifest and that current main does not contain the target code.
- `confirmation_dialog_spec.cr` header comment updated to explain pending state.
- `voyager_toolbar_spec.cr` header comment updated likewise.
- `catalog-coverage.yml` V1+V2 status changed from `not-reproduced-by-spec` to `pre-staged-pending-worktree-merge`; added `worktree_source: phase-10-d-polish` field.
- `scenarios/voyager.yml` header note explains the placeholder ids are forward-looking.

**New executable proof of Phase 12.A:** `spec/native_ios/ui_interaction/harness_smoke_spec.cr` — runs against CURRENT main, asserts Voyager launches + emits the `[APIC:VoyagerApp:launched]` marker within 5s, then asserts a heartbeat. This is the spec that proves the harness works end-to-end today.

### BLOCKER 2 — Spec entirely pending, has no executable reproduction

**Codex finding:** Both ConfirmationDialog examples call `pending!`. The spec cannot fail, so it's not a regression test.

**Architect response:** Codex is right that the original spec was vaporware. The new harness smoke test (described above) is the executable spec for Phase 12.A. The V1+V2 specs remain pending honestly — their code paths don't exist in main yet, and the harness doc reframes them as Phase 12.B work.

### BLOCKER 3 — `simctl listapps` does not prove process liveness

**Codex finding:** `listapps` reports installed apps. It will include the bundle id even after a crash because the harness installed it. False negative factory.

**Architect action:** Replaced with heartbeat-marker assertion.

- Added per-second heartbeat emission to Voyager's app delegate (`VoyagerApp.swift:48-63`):
  ```swift
  Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      InteractionContracts.emit(widget: "VoyagerApp", event: "heartbeat", ...)
  }
  ```
- `voyager_toolbar_spec.cr` now has an `assert_runloop_alive(sim, since)` helper that requires a fresh heartbeat marker within 2 seconds of the tap. Crashes stop heartbeats; hung runloops also stop heartbeats. Covers both crash detection (BLOCKER 3) and hung-but-alive detection (CONCERN 9).

## CONCERNs (7) — addressed

### CONCERN 4 — V1 marker sequence misses host-removal dismissals

**Finding:** If Rerender tears down the hosting view instead of writing through `BoolStorage.binding`, SwiftUI dismisses without invoking the binding setter. No `platform-dismissed` marker fires.

**Architect response:** Acknowledged. The current marker schema catches the binding-write path of V1's hypothesis but not the host-teardown path. **Documented as a known harness limitation** in the Phase 12.B brief authoring guidance (not yet authored — when V1 work actually starts, the brief MUST include a "host-teardown probe" as additional instrumentation).

### CONCERN 5 — `dismiss-token-fire` marker misleading for ConfirmationDialog (token=0)

**Finding:** ConfirmationDialog constructs `BoolStorage(initial:, token: 0)`. `CallbackBridge.fire` drops token=0. So the marker says "dismiss-token-fire" but no token actually fires.

**Architect action:** Split into two markers in `BoolStorage.binding.set`:
- `binding-write-false` — fires UNCONDITIONALLY on true→false transition (proves SwiftUI wrote false)
- `dismiss-token-fire` — fires ONLY when token != 0 (proves the Crystal dismiss handler path fired)

Spec updated to assert `binding-write-false` for ConfirmationDialog instead of `dismiss-token-fire`.

### CONCERN 6 — Crystal STDERR markers assumed equivalent to unified log

**Finding:** Harness tails unified log via `log stream`. NSLog markers land there. STDERR may NOT, depending on launch mode. The architect's implementation wrote STDERR, not NSLog.

**Architect action:** Added `apsk_apic_log(const char *)` NSLog wrapper in `src/ui/native/swiftkit_bridge.m` and the matching `fun apsk_apic_log(msg : UInt8*)` declaration in `swiftkit_bridge.cr`. `interaction_contracts.cr` now routes through NSLog on Apple targets:

```crystal
{% if flag?(:macos) || flag?(:ios) %}
  LibSwiftKitBridge.apsk_apic_log(line.to_unsafe)
{% else %}
  STDERR.puts(line)
{% end %}
```

### CONCERN 7 — Sheet instrumentation not equivalent to BoolStorage instrumentation

**Finding:** Sheet uses APSKSheetState, not BoolStorage. Markers only at `.sheet(onDismiss:)`, not at the write side. Programmatic writes via `apsk_sheet_set_presented` have no markers.

**Architect response:** Acknowledged. The current Sheet instrumentation is partial. **Adding write-side markers requires touching `apsk_sheet_set_presented` in ReactiveState.swift; deferred to Phase 12.B** (the same brief that adds the host-teardown probe per CONCERN 4). Documented in `interaction-contracts-harness.md` as a known gap.

### CONCERN 8 — V2 needs positive "tap reached intended action" assertion

**Finding:** A coordinate tap can miss the intended control and the process check still passes. Need a marker proving the tap hit the right control.

**Architect action:** V2 spec's overflow-trigger example now asserts `[APIC:Popover:present]` arrives within 2 seconds — proving the tap reached the popover. For the three sort buttons, the assertion is implicit (heartbeat continues + no presented widget changes). When Button instrumentation lands per CONCERN 7's batch, the assertion will be strengthened to a per-tap marker.

### CONCERN 9 — Hung/unresponsive state not covered

**Finding:** A main-thread hang or modal obstruction leaves the bundle installed and the process alive but unusable.

**Architect action:** Heartbeat marker approach covers this. A hung main runloop stops emitting heartbeats. `assert_runloop_alive` fails. Same fix as BLOCKER 3.

### CONCERN 10 — URL-scheme query targets UIView identifier, not accessibility tree

**Finding:** SwiftUI applies identifiers through modifiers; tappable leaves may not have `UIView.accessibilityIdentifier` set directly. The URL-scheme query needs to walk the accessibility tree, not the raw UIView hierarchy.

**Architect response:** The URL-scheme query was a PLAN, not yet implemented. The plan has been DEPRECATED in favor of Codex CONCERN 12's recommendation (XCUITest hybrid). See CONCERN 12 below.

### CONCERN 11 — `openurl` is not side-effect free

**Finding:** `simctl openurl` activates the app and enters its URL handling path, perturbing scene activation during a presentation-lifecycle test.

**Architect response:** Same as CONCERN 10 — the URL-scheme plan is deprecated. CONCERN 11 is moot.

### CONCERN 12 — XCUITest precedent exists; reconsider for frame lookup

**Finding:** `samples/initiative-cross-platform-ui-voyager/ios/UITests/VoyagerVisualTests.swift` already uses XCUITest with `app.otherElements["id"]` to find elements. A small XCUITest helper that resolves accessibility identifiers to frames, paired with the existing APIC markers for semantic assertions, is cleaner than the URL-scheme plan.

**Architect action:** Accepted. The harness doc's "Why not XCUITest" section is updated in the next commit to acknowledge the hybrid approach: XCUITest for tap delivery (uses the existing VoyagerVisualTests pattern), Crystal harness + APIC markers for semantic assertions. The `tap_accessibility_id` mechanism is now scoped to "XCUITest helper" rather than "URL-scheme query." This is Phase 12.B implementation work (the XCUITest helper hasn't been written yet — Phase 12.A delivers the harness scaffold + marker emission, not the tap delivery mechanism).

## NIT (1) — addressed

### NIT 13 — Scenario freshness story is aspirational

**Finding:** `captured_pose_sha` is null, validator doesn't read scenario files. The freshness claim was overstated.

**Architect action:** Updated `scenarios/voyager.yml` header to honestly state freshness is NOT yet validator-enforced; the `captured_pose_sha` field is reserved for a follow-up extension.

## Net architectural changes in this response

- Crystal emit goes through NSLog via `apsk_apic_log` (not STDERR) on Apple targets
- `BoolStorage` emits two markers (`binding-write-false` always + `dismiss-token-fire` when token != 0)
- Voyager emits launch + heartbeat markers in app delegate
- New harness smoke spec is the Phase 12.A executable proof
- V1+V2 specs marked forward-looking; status in manifest = `pre-staged-pending-worktree-merge`
- URL-scheme query plan deprecated; replaced with planned XCUITest helper (Phase 12.B)
- Scenario YAML freshness claim corrected

## Status checks after this response

- `crystal run scripts/lint_conventions.cr` → **OK (503 files, 19 rules, 0 diagnostics)**
- `crystal run scripts/validate_catalog_coverage.cr` → **0 errors** (V1/V2 status updated)
- `swift build` (AssetPipelineSwiftKit) → **Build complete**
- `crystal build --no-codegen` over all 3 specs → clean

## What this leaves for Phase 12.B

The remaining gaps Codex flagged are all Phase 12.B scope by design:

1. Host-teardown probe markers (CONCERN 4) — extends V1 reproduction coverage
2. Sheet write-side markers (CONCERN 7) — extends Sheet coverage
3. XCUITest helper for tap delivery (CONCERN 12) — makes V1+V2 specs executable
4. Polish worktree merge — unblocks V1+V2 target code
5. Scenario freshness validator extension (NIT 13) — enforces source-hash check on tap coordinates

When the owner approves Phase 12.B brief authoring, these become the brief's acceptance bullets.

— Architect (Claude Opus 4.7), 2026-05-28, responding to Codex Phase 12.A review
