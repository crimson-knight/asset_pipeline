# Phase 10B.3.x close — 8 Class C feature implementations

**Branch:** `phase-10-b-3-x` (cut from `phase-10` @ `97217ad3`).
**Brief:** `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-b-3-x.md` (v1).
**Status:** Forward-only commits; ready for architect review.

---

## What shipped

On top of the 10B.3.0 Class C substrate, 10B.3.x ships **8 framework Class C feature bindings** — one per backlog item B-027 through B-034 — plus their per-platform C bridge functions and a 32-spec coverage suite.

### Surface added

| File | Change |
|---|---|
| `src/ui/intent/class_c_bootstrap.cr` | 8 new `install_<feature>` registrations + per-platform procs + `IncomingDeepLink` callback-bus module. |
| `src/ui/native/objc_bridge.m` | 13 new C entry points (7 macOS, 6 iOS) covering clipboard / open_url / permissions / print / file picker / export. |
| `src/ui/native/android_bridge.c` | 3 new JNI entry points (`ap_clipboard_write_android`, `ap_clipboard_read_android`, `ap_open_url_android`). |
| `spec/web/ui/intent_class_c_features_spec.cr` | 32 new specs — registration + dispatch + capability check + IncomingDeepLink event-bus + registry health. |

### Per-feature × per-platform status

| Feature | Backlog | Web | macOS | iOS / iPadOS | Android |
|---|---|---|---|---|---|
| `:copy_to_clipboard` | B-027 | STDERR stand-in | `ap_clipboard_write_macos` (NSPasteboard) | `ap_clipboard_write_ios` (UIPasteboard) | C function shipped (`ap_clipboard_write_android`); Crystal proc is a documented stub awaiting renderer-side JNIEnv+Context plumbing (10B.4) |
| `:paste_from_clipboard` | B-028 | STDERR stand-in | `ap_clipboard_read_macos` (sync + callback) | `ap_clipboard_read_ios` (sync + callback) | C function shipped (`ap_clipboard_read_android`); Crystal proc stub (same gap as above) |
| `:request_permission` | B-029 | STDERR stand-in | `ap_request_notification_permission_macos` (UNUserNotificationCenter, notifications-only) | `ap_request_notification_permission_ios` (notifications-only) | Stub — `ActivityCompat.requestPermissions` needs an Activity + result-callback wiring; signature documented |
| `:open_url` | B-030 | STDERR stand-in | `ap_open_url_macos` (NSWorkspace.openURL) | `ap_open_url_ios` (UIApplication.openURL) | C function shipped (`ap_open_url_android`); Crystal proc stub (renderer plumbing) |
| `:incoming_deep_link` | B-031 | event-bus dispatch (fires `IncomingDeepLink.on_receive` handlers) | event-bus | event-bus | event-bus |
| `:print` | B-032 | STDERR stand-in | `ap_print_text_macos` (NSPrintOperation + NSTextView) | `ap_print_text_ios` (UIPrintInteractionController + UISimpleTextPrintFormatter) | Stub — PrintManager.print requires a PrintDocumentAdapter Java subclass; signature documented |
| `:open_file_picker` | B-033 | STDERR stand-in | `ap_open_file_picker_macos` (NSOpenPanel, sync runModal) | `ap_open_file_picker_ios` (UIDocumentPickerViewController, modal + delegate) | Stub — ACTION_GET_CONTENT requires startActivityForResult + onActivityResult plumbing; signature documented |
| `:export_file` | B-034 | STDERR stand-in | `ap_export_file_macos` (NSSavePanel) | `ap_export_file_ios` (UIDocumentPickerViewController, export mode) | Stub — ACTION_CREATE_DOCUMENT, same constraints as ACTION_GET_CONTENT; signature documented |

**Honesty:** every "stub" row above is the platform proc raising with a documented message naming the C function signature that would land it. Each binding's `api_capability_check` consults `ClassCBootstrap.platform_built_in?` so `feature_supported?` returns `false` on platforms whose bridge isn't compiled in — meaning a dispatch from the registry returns `DispatchResult.unsupported`, not `failed`. Callers can rely on `feature_supported?` to gate UI.

### C bridge entry points added

**macOS (`src/ui/native/objc_bridge.m`, AppKit branch):**

```c
void ap_clipboard_write_macos(const char *value);
int  ap_clipboard_read_macos(unsigned long long token);
int  ap_open_url_macos(const char *url);
int  ap_request_notification_permission_macos(void);
int  ap_print_text_macos(const char *text, const char *job_name);
int  ap_open_file_picker_macos(const char *utis, unsigned long long token);
int  ap_export_file_macos(const char *suggested_name, unsigned long long token);
```

**iOS (`src/ui/native/objc_bridge.m`, UIKit branch):**

```c
void ap_clipboard_write_ios(const char *value);
int  ap_clipboard_read_ios(unsigned long long token);
int  ap_open_url_ios(const char *url);
int  ap_request_notification_permission_ios(void);
int  ap_print_text_ios(const char *text, const char *job_name);
int  ap_open_file_picker_ios(void *anchor_view, const char *utis, unsigned long long token);
int  ap_export_file_ios(void *anchor_view, const char *source_url, unsigned long long token);
```

The iOS picker functions take an anchor view ptr; the substrate currently
passes `nullptr` and the C function early-returns. A real picker
component lands in 10B.4 with anchor plumbing.

**Android (`src/ui/native/android_bridge.c`):**

```c
void ap_clipboard_write_android(JNIEnv *env, jobject context,
                                uint8_t *text, int32_t text_len);
int  ap_clipboard_read_android(JNIEnv *env, jobject context,
                               unsigned long long token);
int  ap_open_url_android(JNIEnv *env, jobject context,
                         uint8_t *url, int32_t url_len);
```

### `:incoming_deep_link` event-bus

Class C dispatch is fire-and-forget by contract, but deep-link receipt
is event-driven from the OS. To reconcile, the substrate ships
`UI::Intent::IncomingDeepLink`:

```crystal
# In app boot:
UI::Intent::IncomingDeepLink.on_receive do |url|
  puts "deep link arrived: #{url}"
end

# In tests / from a native renderer's openURL: hook:
UI::Intent.dispatch(:incoming_deep_link, url: "myapp://session/42")
# -> calls every registered handler with "myapp://session/42"
```

Per-platform OS-event wiring (UIApplication.openURL: / application:openFile: / Intent.getData) lands with the renderer integrations in 10B.4.

### Compile-time gating

The Lib block in `class_c_bootstrap.cr` is `flag?(:macos)` vs `flag?(:ios) || flag?(:ipados)` so a single binding source compiles against the right bridge symbols for the active build. The capability-check helper `platform_built_in?` mirrors the same flag set so dispatch and `feature_supported?` agree.

The web build (no flag) compiles without any `LibClassCBridge` block — the macos_*/ios_*/android_* procs raise inside `{% else %}` branches that the platform-built-in check filters out before they're invoked.

## Specs

* `spec/web/ui/intent_class_c_spec.cr` — 23 examples, all passing (pre-existing, unchanged).
* `spec/web/ui/intent_class_c_features_spec.cr` — 32 examples, all passing (new).

Combined: **55 Class C specs green**.

Per-feature coverage in the new spec:
- registration after install
- `dispatch` returns Success on web
- `dispatch` returns Unsupported on non-built-in native platforms
- `feature_supported?` matches the platform-built-in check
- `:incoming_deep_link` handler-bus: fire / multi-listen / exception isolation
- registry health: all 9 bindings present (1 proof + 8 features)

## Build + lint

* `crystal build src/asset_pipeline.cr` → green.
* `crystal tool format --check` on touched files → green.
* `crystal run scripts/lint_conventions.cr` → `OK (469 files, 14 rules, 0 diagnostics)`.
* `clang -c src/ui/native/objc_bridge.m -fno-objc-arc` for macOS → green (3 pre-existing deprecation warnings, no new errors).
* `clang -c src/ui/native/objc_bridge.m -target arm64-apple-ios-simulator` for iOS → green (73 pre-existing warnings, no new errors).
* Android JNI compilation deferred per `native-compile-matrix.md` (lane blocked on Linux-targeted Crystal compiler).

## Acceptance checklist

- [x] All 8 features registered as `PlatformFeatureBinding`.
- [x] Each feature has at minimum web + 1 native impl. macOS + iOS land for 7/8 (deep_link is event-bus on every platform). Android C functions shipped for 3/8; remaining 5 are documented gaps with C signatures named.
- [x] Specs cover each feature's dispatch path.
- [x] Lint green.
- [x] `crystal build src/asset_pipeline.cr` passes.
- [ ] Codex content review APPROVE — pending architect dispatch.

## Out of scope (per brief)

- Native widget wrappers (10B.4 / 10B.5).
- Public usage docs for the new APIs (10A.final).
- HIG validation.
- Android renderer-side JNIEnv+Context plumbing for clipboard / open_url stubs.
- Activity-scoped Android startActivityForResult + onActivityResult wiring for picker / export.
- PrintDocumentAdapter Java helper class.
- Per-permission Android RequestPermissions JNI helper.

— Implementer (Claude Opus 4.7), 10B.3.x close v1.
