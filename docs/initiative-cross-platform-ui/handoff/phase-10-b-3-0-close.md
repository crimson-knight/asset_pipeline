# Phase 10B.3.0 close — Class C native bridge substrate

**Branch:** `phase-10-b-3-0` (cut from `phase-10` @ tag `phase-10-batch-3-merged-2026-05-26`; the brief commit `04736877` was cherry-picked onto the branch).
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-3-0.md` (v1).
**Status:** Forward-only commits; ready for architect review.

---

## What shipped

The substrate that 10B.3.x will populate with 8 real Class C features. Class A intent routing (resolver → widget) and Class C feature dispatch (intent → native side-effect) now sit side-by-side as parallel mechanisms with disjoint registries and disjoint use cases.

### New surface

| File | Purpose |
|---|---|
| `src/ui/intent/dispatch_result.cr` | `UI::Intent::DispatchResult` tagged union: `Success` / `Unsupported(detail)` / `Failed(reason)`. |
| `src/ui/intent/platform_feature_binding.cr` | `UI::Intent::PlatformFeatureBinding` — immutable struct binding an `intent_id` to per-platform `Args -> Nil` lambdas plus an optional `api_capability_check`. |
| `src/ui/intent/class_c_registry.cr` | `UI::Intent::ClassCRegistry` — process-global flat registry (no override tiers). `register`, `binding_for`, `supports?`, `registered_intents`, `reset_for_spec`. |
| `src/ui/intent/class_c_bootstrap.cr` | `UI::Intent::ClassCBootstrap.install` — installs framework bindings (currently `:hello_world_alert`). Loaded by `src/ui.cr` after the registry. |
| `src/ui/environment.cr` | `UI::Environment.platform` / `.set_platform` / `.reset_platform_for_spec` / `.feature_supported?` — process-level platform + capability surface, sourced from `flag?(...)`. |
| `src/ui/intent.cr` (added) | `UI::Intent.dispatch(intent_id, args)` + kwarg overload. Looks up binding, picks platform proc, returns `DispatchResult`. |
| `src/ui/native/objc_bridge.m` (added) | `ap_alert_show_macos(title, message)` — NSAlert.runModal on main thread (macOS, `TARGET_OS_OSX`). |
| `spec/web/ui/intent_class_c_spec.cr` | 23 specs covering registry + dispatch + environment + DispatchResult. All passing. |

### `UI::Intent.dispatch` contract

```crystal
result = UI::Intent.dispatch(:hello_world_alert, message: "hi")
# or:
result = UI::Intent.dispatch(:hello_world_alert, {:message => "hi"})

case result
when .success?     then nothing
when .unsupported? then log result.reason  # platform not covered, or capability check failed
when .failed?      then log result.reason  # platform proc raised
end
```

Three returns:

1. `DispatchResult.success` — platform proc completed without raising.
2. `DispatchResult.unsupported(detail)` — no binding, OR binding doesn't cover the current platform, OR `api_capability_check` returned false.
3. `DispatchResult.failed(reason)` — platform proc raised; reason carries `"ExceptionClass: message"`.

### `UI::Environment` contract

```crystal
UI::Environment.platform              # => :web_wide (default), or :macos/:ios/... per flag?()
UI::Environment.set_platform(:web_narrow)   # tests + viewport-aware web hosts
UI::Environment.feature_supported?(:hello_world_alert)  # => true/false
```

The platform default is read from compile-time `flag?(:macos | :ios | :ipados | :android)` at class-var init. Web (no flag) defaults to `:web_wide`. `set_platform` lets a web host narrow after viewport detection, and lets tests exercise multiple branches.

### `PlatformFeatureBinding` shape

```crystal
UI::Intent::PlatformFeatureBinding.new(
  intent_id: :share_link,
  api_capability_check: ->(platform : Symbol) { ... },
  platforms: {
    :ios        => ->(args : PlatformFeatureBinding::Args) { ... },
    :ipados     => ->(args : PlatformFeatureBinding::Args) { ... },
    :macos      => ->(args : PlatformFeatureBinding::Args) { ... },
    :android    => ->(args : PlatformFeatureBinding::Args) { ... },
    :web_wide   => ->(args : PlatformFeatureBinding::Args) { ... },
    :web_narrow => ->(args : PlatformFeatureBinding::Args) { ... },
  } of Symbol => PlatformFeatureBinding::PlatformProc,
)
```

`api_capability_check` defaults to `->(_p) { true }` (no extra gate beyond platform-in-map). Bindings that gate on a runtime feature (browser API, framework availability) opt in.

`Args = Hash(Symbol, String)` — the lowest-common-denominator shape that crosses JNI / objc bridge boundaries without bridge code rebuilding typed payloads. Bindings parse / coerce inside the platform lambda.

## hello_world_alert proof status

| Platform | Implementation | Status |
|---|---|---|
| `:web_wide` | STDERR-as-console.log (`STDERR.puts "[hello_world_alert/web] #{title}: #{message}"`). | Shipped + spec-tested. |
| `:web_narrow` | Same STDERR sink. | Shipped + spec-tested. |
| `:macos` | `LibAlertBridge.ap_alert_show_macos(title, message)` → NSAlert.runModal on main queue. | Shipped (gated on `flag?(:macos)`). C side compiled into `objc_bridge.m` at `ap_alert_show_macos` (line ~3027). |
| `:ios` | Stub raising "iOS binding not yet implemented." Documents the required C signature `void ap_alert_show_ios(const char *title, const char *message);` to wrap `UIAlertController` on the top `UIViewController` (use `ap_top_presenting_view_controller` from objc_bridge.m). | Follow-up. |
| `:ipados` | Same iOS stub. | Follow-up. |
| `:android` | Stub raising "Android binding not yet implemented." Documents the required JNI signature `void ap_toast_show(void *env_ptr, void *context, const char *message);` in `android_bridge.c` calling `Toast.makeText(context, message, Toast.LENGTH_SHORT).show()`. | Follow-up. |

Web + macOS cover the brief's "ship at least 2 implementations" bar. The iOS / iPadOS / Android stubs intentionally remain in the binding's `platforms` map so `feature_supported?` returns `true` on those targets — when an architect dispatches 10B.3.x for iOS and Android implementations, the bindings simply replace the stub procs.

## Why no override tiers in `ClassCRegistry`?

Class A intents (widget routing) need app- and screen-scoped overrides because brand designers swap default widgets out for branded variants. Class C intents bridge to native system APIs; the "implementation" IS the framework's mapping to UIActivityViewController / NSSharingService / `navigator.share` / Intent.ACTION_SEND. If a consumer app needs a different behaviour (log every share before dispatching), they wrap the `UI::Intent.dispatch` call-site, not the binding. The substrate stays flat and predictable.

## Spec + lint + build results

```
$ crystal spec spec/web/ui/intent_class_c_spec.cr spec/web/ui/intent_spec.cr
48 examples, 0 failures, 0 errors, 0 pending

$ crystal run scripts/lint_conventions.cr
lint_conventions: OK (463 files, 14 rules, 0 diagnostics)

$ crystal build --no-codegen src/ui.cr
(clean — no warnings, no errors)

$ crystal tool format --check src/ui/intent.cr src/ui/intent/ src/ui/environment.cr src/ui.cr spec/web/ui/intent_class_c_spec.cr
(clean — passes after `crystal tool format src/ui/environment.cr`)
```

Full suite: 1902 examples / 4 failures / 2 errors / 66 pending — the 4 failures + 2 errors are pre-existing baseline failures (confirmed by stashing my changes and re-running: 1879 examples / same 4 failures / same 2 errors). My 23 added specs all pass.

## 10B.3.x roadmap — the 8 Class C features

Audit source: `docs/initiative-cross-platform-ui/architecture/intent-catalog.md` Class C section (9 catalog entries) + the brief's suggested list. The 8 priorities for 10B.3.x in dispatch order:

| # | intent_id | Catalog row | Native APIs | Notes |
|---|---|---|---|---|
| 1 | `:share_link` | catalog Class C #1 | iOS `UIActivityViewController`, macOS `NSSharingServicePicker`, Android `Intent.ACTION_SEND`, Web `navigator.share` (fallback: copy-to-clipboard + `<a target=_blank>`) | Already wired through `UI::ActivityView` widget on every platform — 10B.3.x's job is to expose it as a direct dispatch for screens that want to share without rendering an explicit view. |
| 2 | `:open_url` | catalog Class C `:open_url` | iOS / iPadOS `UIApplication.openURL`, macOS `NSWorkspace.openURL`, Android `Intent.ACTION_VIEW`, Web `window.open` / `<a>` | Universal. `args[:url]`. |
| 3 | `:copy_to_clipboard` | catalog Class C `:copyable` | iOS / iPadOS `UIPasteboard.general.string`, macOS `NSPasteboard.general writeObjects`, Android `ClipboardManager.setPrimaryClip`, Web `navigator.clipboard.writeText` (`document.execCommand('copy')` fallback) | Universal. `args[:text]`. |
| 4 | `:paste_from_clipboard` | catalog Class C `:paste_button` | Same APIs as `:copy_to_clipboard`, read side. Returns the pasted string via callback. | Demonstrates the callback pattern (a feature that needs a return value uses `args[:on_paste_callback_id]` + `UI::Intent::CallbackRegistry` follow-up). |
| 5 | `:haptic_feedback` | NOT in catalog; new for 10B.3.x | iOS / iPadOS `UIImpactFeedbackGenerator` + `UINotificationFeedbackGenerator` + `UISelectionFeedbackGenerator`, macOS `NSHapticFeedbackManager`, Android `View.performHapticFeedback`, Web `navigator.vibrate` (where supported) | `args[:style]` ∈ `light`/`medium`/`heavy`/`success`/`warning`/`error`/`selection`. |
| 6 | `:request_permission` | catalog Class C `:authorization_request` | iOS / iPadOS `requestAuthorization` per framework (Notifications, Camera, Location, Photos, …), macOS same, Android `ActivityCompat.requestPermissions`, Web `Notification.requestPermission` (limited) | `args[:capability]` ∈ `notifications`/`camera`/`location`/`photos`/`microphone`. Returns granted/denied via callback. |
| 7 | `:open_file_picker` | catalog Class C `:file_importer` | iOS / iPadOS `UIDocumentPickerViewController`, macOS `NSOpenPanel`, Android `Intent.ACTION_GET_CONTENT`, Web `<input type=file>` + `showOpenFilePicker` (Chrome) | `args[:content_types]`, `args[:on_pick_callback_id]`. Returns selected URL(s) via callback. |
| 8 | `:show_local_notification` | catalog row near `:authorization_request` | iOS / iPadOS `UNUserNotificationCenter.add`, macOS same, Android `NotificationManagerCompat.notify`, Web `new Notification(...)` | `args[:title]`, `args[:body]`, `args[:identifier]`. Requires `:request_permission` first on every platform. |

### Why not `:file_exporter` (catalog #9)?

Defer to a later slice — file export is a less common need than file import, and the Phase 8 `UI::ShareSheet` already covers the dominant "save to filesystem" use case via the share affordance. 10B.3.x can revisit.

### Dispatch shape for 10B.3.x slices

Each Class C feature ships as a `10B.3.N` slice (N = 1..8) with:

* A bootstrap file (`src/ui/intent/bindings/<feature>.cr`) installing the `PlatformFeatureBinding`.
* Per-platform native functions: typically a new `ap_<feature>_*` C function in `objc_bridge.m` for Apple targets and a new `android_<feature>_*` JNI function in `android_bridge.c` for Android.
* `LibIntent<Feature>Bridge` Crystal `lib` block gated on `flag?(:macos | :ios | :android)` matching each function.
* Specs in `spec/web/ui/intent_<feature>_spec.cr` exercising the registry + the platform-detection branches with a fake bridge.

A 10B.3.x feature is "shipped" when web + at least 1 native platform are wired end-to-end and the other native platforms either have working bindings OR documented follow-ups (matching this slice's pattern).

## Substrate API cheat-sheet for 10B.3.x authors

```crystal
# 1. Author a binding file.
require "../platform_feature_binding"
require "../class_c_registry"

module UI::Intent
  module ClassCBindings
    module ShareLink
      def self.install : Nil
        UI::Intent::ClassCRegistry.register(
          UI::Intent::PlatformFeatureBinding.new(
            intent_id: :share_link,
            api_capability_check: ->(_p : Symbol) { true },
            platforms: {
              :ios        => ->ios_share(UI::Intent::PlatformFeatureBinding::Args),
              :macos      => ->macos_share(UI::Intent::PlatformFeatureBinding::Args),
              :android    => ->android_share(UI::Intent::PlatformFeatureBinding::Args),
              :web_wide   => ->web_share(UI::Intent::PlatformFeatureBinding::Args),
              :web_narrow => ->web_share(UI::Intent::PlatformFeatureBinding::Args),
            } of Symbol => UI::Intent::PlatformFeatureBinding::PlatformProc,
          )
        )
      end

      def self.ios_share(args : UI::Intent::PlatformFeatureBinding::Args) : Nil
        # Pull args[:text], args[:url], args[:subject].
        # Call LibIntentShareBridge.ap_share_link_ios(...).
      end
      # ... macos_share, android_share, web_share ...
    end
  end
end

# 2. Hook it into the bootstrap.
# In class_c_bootstrap.cr:
#   ClassCBindings::ShareLink.install

# 3. Call from a screen.
UI::Intent.dispatch(:share_link, text: "Hello", url: "https://...")
```

## Follow-ups owned by 10B.3.0

- (none — substrate is complete)

## Follow-ups handed off to 10B.3.x

- Wire `ap_alert_show_ios` for `:hello_world_alert` (proof binding's iOS branch is currently a stub). Optional — 10B.3.x slices can replace the proof entirely.
- Wire `ap_toast_show` for `:hello_world_alert` Android branch. Optional — same reasoning.
- Ship the 8 features above as 10B.3.1 through 10B.3.8 (dispatch in the order listed).

## Files touched

```
modified:   src/ui.cr
modified:   src/ui/intent.cr
modified:   src/ui/native/objc_bridge.m
added:      src/ui/environment.cr
added:      src/ui/intent/dispatch_result.cr
added:      src/ui/intent/platform_feature_binding.cr
added:      src/ui/intent/class_c_registry.cr
added:      src/ui/intent/class_c_bootstrap.cr
added:      spec/web/ui/intent_class_c_spec.cr
added:      docs/initiative-cross-platform-ui/handoff/phase-10-b-3-0-close.md
```

— Implementer (Claude Opus 4.7), phase-10-b-3-0 close v1, 2026-05-26
