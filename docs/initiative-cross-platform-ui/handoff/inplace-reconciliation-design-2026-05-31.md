# In-place reconciliation design (Rerender focus preservation)

Author: Codex gpt-5.5 (xhigh), 2026-05-31. Staged design for replacing the
iOS `.id()` teardown with in-place native reconciliation so reactive text
editing preserves keyboard focus. See memory project_reactive_text_focus_loss.

Status: Stage 1 in progress. Stages 2-3 are follow-ons.

codex
Below is a staged design only. I did not edit files.

**Current Anchors**

The destructive behavior is in [ContentView.swift](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/Sources/ContentView.swift:71): `VoyagerHost(slug:renderVersion:)` is keyed by `.id("\(slug)#\(renderVersion)")` at lines 71-77, and every `VoyagerBridge.routeChanged` bumps `renderVersion` at lines 83-91. That was deliberate for Save→pop stale state, documented at lines 18-35. `updateUIView` also destructively calls `VoyagerBridge.render`, removes old subviews, and pins the new root at lines 192-241.

The bridge currently only publishes a slug: [VoyagerBridge.swift](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/Sources/VoyagerBridge.swift:16) defines `routeChanged = PassthroughSubject<String, Never>()`, and the C thunk sends only `slug` at lines 31-38. On the Crystal side, `NavigationCoordinator#republish` is indistinguishable from push/pop to Swift because it just calls `notify` at [navigation_coordinator.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/src/ui/navigation_coordinator.cr:111), while `ActionDispatcher` maps `Rerender` to `mount_screen(current_route)` then `republish` at [action_dispatcher.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/src/asset_pipeline/action_dispatcher.cr:270).

The existing safe lifecycle pieces must stay: bridge presentation reuse is built from `@@last_native` at [bridge.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/bridge.cr:289), the fresh renderer rule guarding iOS layout inversion is at lines 304-325, and double-release prevention is `detach_reused!` plus presentation sweep at lines 369-388. `NativeView#detach_reused!` is the ownership escape hatch at [native_view.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/src/ui/native/native_view.cr:253). Text controls currently always allocate new SwiftUI-hosted controls: `TextField` at [uikit_renderer.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/src/ui/renderers/uikit_renderer.cr:576), `SecureField` at line 1555, `SearchField` at line 1704, `TextArea` at line 1730, and `TextEditor` at line 2745.

**Stage 1: Focused TextField Leaf Reconciliation**

Ship the smallest useful subset: same-route `Rerender` gets a new event kind; Swift does not bump `.id` for that event; Crystal performs a conservative in-place leaf update only when a focused, identity-stable text input exists and the native tree shape has not changed. If unsupported, return `false` and let Swift run the existing destructive safety net. This preserves Save→pop and sheets because navigation and structural rerenders still use the current path.

Change [navigation_coordinator.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/src/ui/navigation_coordinator.cr:33):

```crystal
enum ChangeKind
  Navigation
  Rerender
end
record Change, route : Route, kind : ChangeKind

@on_change_event_callbacks : Array(Proc(Change, Nil))

def initialize(root : Route)
  @routes = [root] of Route
  @on_change_callbacks = [] of Proc(Route, Nil)
  @on_change_event_callbacks = [] of Proc(Change, Nil)
end

def push(route : Route) : Nil
  @routes << route
  notify(ChangeKind::Navigation)
end

def pop : Route?
  return nil if @routes.size <= 1
  popped = @routes.pop
  notify(ChangeKind::Navigation)
  popped
end

def replace_root(route : Route) : Nil
  @routes = [route]
  notify(ChangeKind::Navigation)
end

def republish : Nil
  notify(ChangeKind::Rerender)
end

def on_change_event(&block : Change ->) : Nil
  @on_change_event_callbacks << block
end

private def notify(kind : ChangeKind) : Nil
  change = Change.new(current, kind)
  @on_change_callbacks.each { |cb| cb.call(change.route) }
  @on_change_event_callbacks.each { |cb| cb.call(change) }
end
```

Add C ABI beside [Voyager-Bridging-Header.h](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/Sources/Voyager-Bridging-Header.h:10):

```c
int voyager_reconcile(const char* slug);
void voyager_register_route_event_callback(void (*cb)(const char*, int));
```

Update Swift route handling around [VoyagerBridge.swift](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/Sources/VoyagerBridge.swift:13):

```swift
enum RouteChangeKind: Int32 { case navigation = 0, rerender = 1 }
struct RouteEvent { let slug: String; let kind: RouteChangeKind }

static let routeEvents = PassthroughSubject<RouteEvent, Never>()
static let routeChanged = PassthroughSubject<String, Never>()

static func initialize() {
    guard !didInit else { return }
    voyager_init()
    voyager_register_route_event_callback(VoyagerBridge.routeEventThunk)
    didInit = true
}

private static let routeEventThunk: @convention(c) (UnsafePointer<CChar>?, Int32) -> Void = { ptr, rawKind in
    guard let ptr = ptr else { return }
    let slug = String(cString: ptr)
    let kind = RouteChangeKind(rawValue: rawKind) ?? .navigation
    DispatchQueue.main.async {
        VoyagerBridge.routeEvents.send(RouteEvent(slug: slug, kind: kind))
        VoyagerBridge.routeChanged.send(slug)
    }
}

static func reconcile(slug: String) -> Bool {
    initialize()
    return slug.withCString { voyager_reconcile($0) != 0 }
}
```

Update [ContentView.swift](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/Sources/ContentView.swift:48) so navigation still bumps identity, but rerender does not:

```swift
@State private var navigationVersion: Int = 0
@State private var reconcileVersion: Int = 0

VoyagerHost(slug: slug, navigationVersion: navigationVersion, reconcileVersion: reconcileVersion)
    .id("\(slug)#\(navigationVersion)")
    ...
.onReceive(VoyagerBridge.routeEvents) { event in
    if event.kind == .rerender && event.slug == slug {
        reconcileVersion &+= 1
    } else {
        navigationVersion &+= 1
        if event.slug != slug { slug = event.slug }
    }
}
```

Refactor `VoyagerHost.updateUIView` at [ContentView.swift](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/Sources/ContentView.swift:192) into: rerender calls `VoyagerBridge.reconcile`; fallback calls the existing remove-and-repin code unchanged.

Text sync rule in SwiftKit: associate `TextStorage` with the hosted view, make `token` mutable, and add a C-callable updater. On update: always replace the callback token; if any descendant is first responder, do not write `storage.text`; otherwise write model text without firing the binding callback.

```swift
final class TextStorage: ObservableObject {
    @Published var text: String
    @Published var placeholder: String
    var token: UInt64

    init(initial: String, placeholder: String = "", token: UInt64) {
        self.text = initial
        self.placeholder = placeholder
        self.token = token
    }
}

private var kAPSKTextStorageKey: UInt8 = 0

enum APSKTextInputStorage {
    static func attach(_ storage: TextStorage, to view: APSKPlatformView) {
        objc_setAssociatedObject(view, &kAPSKTextStorageKey, storage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    static func storage(for view: APSKPlatformView) -> TextStorage? {
        objc_getAssociatedObject(view, &kAPSKTextStorageKey) as? TextStorage
    }
}

@objc(updateTextInputWithPlatformView:placeholder:text:actionToken:)
public static func updateTextInput(platformView: APSKPlatformView, placeholder: String, text: String, actionToken: UInt64) -> Bool {
    guard let storage = APSKTextInputStorage.storage(for: platformView) else { return false }
    storage.token = actionToken
    storage.placeholder = placeholder
    #if canImport(UIKit)
    if !platformView.apskContainsFirstResponder && storage.text != text { storage.text = text }
    #else
    if storage.text != text { storage.text = text }
    #endif
    return true
}
```

Add C trampolines in [swiftkit_bridge.m](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/src/ui/native/swiftkit_bridge.m:614) and bindings in [swiftkit_bridge.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/src/ui/native/swiftkit_bridge.cr:170):

```c
int apsk_text_input_update(void *view, const char *placeholder, const char *text, unsigned long long token);
int apsk_text_input_is_focused(void *view);
```

Renderer changes at [uikit_renderer.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/src/ui/renderers/uikit_renderer.cr:221): add a reconciliation registry separate from presentation reuse. Match key priority: `accessibility_identifier`, then `test_id`, then no structural fallback in Stage 1. Reuse only `:label` and `:text_field`. Label updates call `apsk_label_set_text`; TextField updates call `apsk_text_input_update`, replaces callback IDs, and returns the existing `NativeView`.

Bridge `voyager_reconcile` in [bridge.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/bridge.cr:401):

```crystal
fun voyager_reconcile(slug_ptr : LibC::Char*) : Int32
  VoyagerBridge.initialize_runtime
  VoyagerBridge.reconcile_slug(String.new(slug_ptr)) ? 1 : 0
end

fun voyager_register_route_event_callback(cb : LibC::Char*, Int32 -> Void) : Void
  VoyagerBridge.register_route_event(cb)
end
```

`reconcile_slug` must create a fresh renderer per call, preserving the line 304-325 layout-inversion guard. It must not assign `@@last_native`. On success: sweep presentations against the fresh tree, detach reused nodes from the throwaway fresh tree, then `fresh.teardown!`. On fallback: detach reused nodes from the throwaway fresh tree, `fresh.teardown!`, return `false`.

Stage 1 XCUITest: add a gallery stress field whose `on_change` stores text and dispatches `Rerender` per keystroke, plus a keyed echo label. Test:

```swift
func testReactiveTextFieldKeepsKeyboardFocusAcrossPerKeystrokeRerender() throws {
    let app = launchGallery()
    let field = input(app, "voyager-gallery-rerender-textfield")
    XCTAssertTrue(scroll(app, to: field, up: false))
    field.tap()
    for ch in Array("voyager") {
        field.typeText(String(ch))
        let focused = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND hasKeyboardFocus == true", "voyager-gallery-rerender-textfield"))
            .firstMatch
        XCTAssertTrue(focused.waitForExistence(timeout: 1))
    }
    XCTAssertEqual(field.value as? String, "voyager")
    XCTAssertTrue(app.staticTexts["Echo: voyager"].waitForExistence(timeout: 3))
}
```

**Stage 2: Complete Text Inputs + Prop Updates**

Extend Stage 1 reuse to `SecureField`, `SearchField`, `TextArea`, and `TextEditor` at [uikit_renderer.cr](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/src/ui/renderers/uikit_renderer.cr:1555), lines 1704, 1730, and 2745. Move all Swift text facades to the same associated `TextStorage`. `SearchFieldFacade` should use `storage.placeholder` instead of a captured literal. Add XCUITests matching Stage 1 for secure/search/area/editor, typing full words while asserting `hasKeyboardFocus == true`.

**Stage 3: Structural Fallback + Child Reconciliation**

Add `NativeHandle#reconciliation_path` and compute fallback keys as `kind:path` when no explicit ID exists. Then add a UIKit child reconciler:

- Same key and kind: update props, recurse.
- Added child: insert native view at index.
- Removed child: remove from superview or arrangedSubviews, then `teardown!`.
- Reordered keyed child: move without recreating.
- Kind mismatch: replace.

This is where unmatched/added/removed/reordered nodes become truly in-place. Until this stage, Stage 1 intentionally falls back to destructive render on structural signature changes.

Stage 3 tests: row delete updates list without navigation; hide-completed toggle updates rows; presentation tests [V1ContractTests.swift](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/UITests/V1ContractTests.swift:35) and [ShareActionSheetTests.swift](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/UITests/ShareActionSheetTests.swift:72) still pass; Save→pop [VoyagerVisualTests.swift](/Users/crimsonknight/open_source_coding_projects/asset_pipeline/samples/initiative-cross-platform-ui-voyager/ios/UITests/VoyagerVisualTests.swift:347) still passes.

**Risk Guards**

- Save→pop: navigation events still bump `.id`; same-route rerender does not. If reconcile returns false, existing destructive `updateUIView` path runs.
- Sheets/dialogs: existing presentation registry and `dismiss_reactive_presentations!` stay; Stage 1 falls back for structural presentation opens.
- Layout inversion: every render/reconcile still uses a fresh `UI::UIKit::Renderer`.
- Double release: destructive render keeps `prior.detach_reused!`; in-place reconcile detaches reused nodes from only the throwaway fresh tree and never swaps `@@last_native`.
- Stale text clobber: focused text input live buffer wins; model text sync only happens when not first responder.


