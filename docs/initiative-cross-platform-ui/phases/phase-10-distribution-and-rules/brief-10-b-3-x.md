# Phase 10B.3.x — Class C feature implementations (8 features)

**Branch:** `phase-10-b-3-x` from `phase-10` (tag `phase-10-batch-4-merged-2026-05-26`).
**Status:** v1. Predecessor: 10B.3.0 closed.

## Context

10B.3.0 shipped the Class C substrate (`UI::Intent.dispatch`, `PlatformFeatureBinding`, `ClassCRegistry`, `Environment.feature_supported?`, `:hello_world_alert` proof). 10B.3.x ships the 8 actual Class C features per the canonical list in `docs/initiative-cross-platform-ui/architecture/intent-backlog.md` items B-027 through B-034.

## The 8 features

Per intent-backlog.md (verify the list when you start; if it differs adjust):

1. **`:copy_to_clipboard`** — `UIPasteboard` / `NSPasteboard` / `ClipboardManager` / `navigator.clipboard.writeText`.
2. **`:paste_from_clipboard`** — same APIs (read side). Demonstrates the callback pattern when the dispatch returns a value.
3. **`:request_permission`** — `requestAuthorization` / `ActivityCompat.requestPermissions` / `Notification.requestPermission`.
4. **`:open_url`** — `UIApplication.openURL` / `NSWorkspace.openURL` / `Intent.ACTION_VIEW` / `window.open`.
5. **`:incoming_deep_link`** — registration of a handler that fires on app-launch deep link receipt. Event-driven (callback registered via `UI::Intent.on_dispatch(:incoming_deep_link) { |url| ... }`).
6. **`:print`** — `UIPrintInteractionController` / `NSPrintOperation` / `PrintManager.print` / `window.print`.
7. **`:open_file_picker`** — `UIDocumentPickerViewController` / `NSOpenPanel` / `Intent.ACTION_GET_CONTENT` / `<input type=file>` + `showOpenFilePicker`.
8. **`:export_file`** — `UIDocumentPickerViewController` (save mode) / `NSSavePanel` / `Intent.ACTION_CREATE_DOCUMENT` / `showSaveFilePicker`.

## Deliverables

For each of the 8 features:

1. **Crystal-side `PlatformFeatureBinding`** registration in `src/ui/intent/class_c_bootstrap.cr`.
2. **Per-platform implementation**:
   - Web: vanilla JS path (or no-op with capability_check returning false on browsers lacking the API).
   - macOS: objc_bridge.m function calling the NSAlert / NSPasteboard / NSWorkspace / etc. API.
   - iOS: objc_bridge.m function (or new file) calling the UIKit equivalent. May need a `#if TARGET_OS_IPHONE` guard if not already.
   - Android: android_bridge.c function via JNI. If the JNI surface needs new entry points, add them with documented signatures (best-effort; missing JNI is a documented gap, not a blocker).
3. **`Environment.feature_supported?` capability checks** — each binding's `api_capability_check` actually checks whether the platform API is reachable (Web Share API present, iOS file picker available, etc.).
4. **Spec** — `spec/web/ui/intent_class_c_<feature>_spec.cr` per feature, or one combined `spec/web/ui/intent_class_c_features_spec.cr`. Each:
   - dispatch returns Success on supported platform.
   - dispatch returns Unsupported on unsupported platform / browser.
   - the binding ACTUALLY does something (web emits a script tag, native calls the bridge function — verifiable via stderr print or mock for native).
5. **Close handoff** with per-feature status table + per-platform bridge function names + Codex verdict.

## Constraints

- Forward commits only on `phase-10-b-3-x`.
- Don't break existing 23-spec intent_class_c_spec.cr.
- Best-effort per platform: if iOS or Android needs new JNI/bridge work that's too heavy, ship a documented stub that returns `Unsupported`. The spec just confirms the substrate's behavior.
- `[[codex-as-architect-antagonist]]` applies.

## Workflow

1. `git checkout -b phase-10-b-3-x phase-10`.
2. Read `intent-backlog.md` to confirm the 8 features. Adjust if list has changed.
3. Implement features in order (clipboard first since it's the simplest cross-platform).
4. For each: Crystal binding + 4-platform impl + spec + brief close-handoff entry.
5. After all 8: full close handoff with table + codex content review verdict.
6. Standard footer.

## Acceptance

- ✅ All 8 features registered as `PlatformFeatureBinding`.
- ✅ Each feature has at minimum web + 1 native impl (the other native stubs return Unsupported).
- ✅ Specs cover each feature's dispatch path.
- ✅ Lint green.
- ✅ `crystal build src/asset_pipeline.cr` passes.
- ✅ Codex content review APPROVE.

## Out of scope

- Native platform widget wrappers (10B.4 / 10B.5).
- Public docs for the new APIs (10A.final).
- HIG validation.

— Architect (Claude Opus 4.7), 10B.3.x brief v1
