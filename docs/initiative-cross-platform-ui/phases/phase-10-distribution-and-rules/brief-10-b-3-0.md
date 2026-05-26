# Phase 10B.3.0 — Class C native bridge substrate

**Branch:** `phase-10-b-3-0` from `phase-10` (tag `phase-10-batch-3-merged-2026-05-26`).
**Status:** v1.

## Context

Class C intents are cross-platform-bridged features: app features that have native implementations on each target platform (e.g. file picker, share sheet, haptic feedback, system notification, etc.). 10B.3.0 lays the substrate; 10B.3.x ships 8 individual Class C features afterwards.

## Deliverables

1. **`UI::Intent::ClassC` module** — namespace for Class C intent definitions. Each Class C feature is a Crystal class registering with the resolver.

2. **`UI::Intent::PlatformFeatureBinding`** — declarative shape for how a Class C feature maps to per-platform native APIs:
   ```crystal
   UI::Intent::PlatformFeatureBinding.new(
     intent_id: :share_link,
     api_capability_check: ->(env : UI::Environment) { ... },
     platforms: {
       ios: ->(args) { ... call into UIActivityViewController via JNI/objc ... },
       macos: ->(args) { ... call into NSSharingService ... },
       android: ->(args) { ... call into Intent.ACTION_SEND ... },
       web: ->(args) { ... use Web Share API or fallback ... },
     }
   )
   ```

3. **`UI::Intent.dispatch(:intent_id, **args)`** — fire-and-forget method that invokes the platform-appropriate binding. Returns `UI::Intent::DispatchResult` (success | unsupported | failed-with-reason).

4. **`UI::Intent::ClassCRegistry`** — central registry of Class C bindings (parallel to the widget registry for Class A intents).

5. **Hello-world Class C feature**: ship `:hello_world_alert` as a proof, with per-platform stubs that call:
   - Web: `console.log` or DOM `alert` (with capability check warning).
   - macOS: `NSAlert.runModal` via objc bridge.
   - iOS: `UIAlertController` via objc bridge.
   - Android: `Toast.makeText(...)` via JNI.

6. **`UI::Environment.feature_supported?(intent_id : Symbol) : Bool`** — extends Environment to surface platform feature availability (e.g. Web Share API on chrome, but not legacy browsers).

7. **Specs** — `spec/web/ui/intent_class_c_spec.cr`:
   - Dispatch :hello_world_alert on web context → returns success.
   - Dispatch :unknown_intent → returns DispatchResult.unsupported.
   - feature_supported? returns the right answer per platform.

8. **Close handoff** with the substrate API + the hello-world proof + the 8-feature 10B.3.x roadmap.

## Workflow

1. `git checkout -b phase-10-b-3-0 phase-10`.
2. Build `PlatformFeatureBinding` + `ClassCRegistry` + `Intent.dispatch`.
3. Wire the hello_world_alert proof on all 4 platforms.
4. Extend Environment with feature_supported?.
5. Specs.
6. Close handoff. List the 8 Class C features that 10B.3.x will ship (audit `:share_link`, `:open_url`, `:copy_to_clipboard`, `:haptic_feedback`, `:show_local_notification`, `:open_file_picker`, etc. — pick the right 8 per Phase 8 catalog).
7. Standard footer.

## Acceptance

- ✅ `UI::Intent.dispatch` API exists + tested.
- ✅ `ClassCRegistry` is process-global (class-scoped table).
- ✅ At least 1 Class C feature (hello_world_alert) wired end-to-end on at least web + 1 native platform.
- ✅ `Environment.feature_supported?` works.
- ✅ Specs pass.
- ✅ Codex APPROVE.

## Out of scope

- The 8 actual Class C features (those are 10B.3.x).
- Widget-side integration (Class A intents are 10B.0 territory).

— Architect (Claude Opus 4.7), 10B.3.0 brief v1
