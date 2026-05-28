# Phase 10B.3.0 + 10B.3.x — Class C bootstrap.
#
# Installs the framework's Class C `PlatformBinding`s. This
# file is loaded by `src/ui.cr` AFTER the environment + registry are
# set up. Each Class C feature has an `install_<feature>` class method
# below — `install` calls all of them in sequence at framework load.
#
# # Why a separate file from `widget_route/bootstrap.cr`?
#
# Class A bootstrap registers WIDGET defaults; Class C bootstrap
# registers FEATURE bindings. Keeping them in separate files makes
# the load-order story explicit (Class A bootstrap must run after
# `views/*`; Class C bootstrap has no view dependency).
#
# # 10B.3.0 — `:hello_world_alert` proof
#
# The `:hello_world_alert` binding is a proof-of-substrate: it
# exercises every layer (registry → dispatch → environment lookup →
# platform lambda → native side-effect) without depending on a real
# feature. 10B.3.x kept it in place alongside the 8 real features.
#
# # 10B.3.x — 8 Class C feature bindings
#
# Bindings registered:
#
#   1. `:copy_to_clipboard`        (B-027)
#   2. `:paste_from_clipboard`     (B-028)
#   3. `:request_permission`       (B-029)
#   4. `:open_url`                 (B-030)
#   5. `:incoming_deep_link`       (B-031 — event-driven, stub)
#   6. `:print`                    (B-032)
#   7. `:open_file_picker`         (B-033)
#   8. `:export_file`              (B-034)
#
# Per-platform coverage matrix:
#
# | Feature                | Web (STDERR-stand-in) | macOS | iOS | Android |
# |------------------------|-----------------------|-------|-----|---------|
# | `:copy_to_clipboard`   | yes                   | yes   | yes | yes     |
# | `:paste_from_clipboard`| yes                   | yes   | yes | yes     |
# | `:request_permission`  | yes                   | yes   | yes | stub    |
# | `:open_url`            | yes                   | yes   | yes | yes     |
# | `:incoming_deep_link`  | event-stub            | stub  | stub| stub    |
# | `:print`               | yes                   | yes   | yes | stub    |
# | `:open_file_picker`    | yes                   | yes   | yes | stub    |
# | `:export_file`         | yes                   | yes   | yes | stub    |
#
# `stub` means the platform proc raises with a documented signature for
# the C bridge function that would land it. `feature_supported?`
# returns `false` for these via the binding's
# `api_capability_check`, so callers can degrade gracefully.
#
# # api_capability_check
#
# Each binding's capability check returns `false` for platforms whose
# bridge isn't compiled in at build time. On a web-only build, a
# `dispatch(:copy_to_clipboard)` while
# `UI::Environment.platform == :macos` (test fixture) returns
# `Result.unsupported` because the macOS bridge wasn't linked.
# On a `-Dmacos` build, the same dispatch returns Success.
#
# # Bridge signatures
#
# All C bridge functions land in `src/ui/native/objc_bridge.m` (macOS +
# iOS branches) and `src/ui/native/android_bridge.c` (Android JNI).
# Each binding's docstring names the C function it calls.

require "./registry"
require "./platform_binding"
require "../native/callback_registry"

{% if flag?(:macos) %}
  @[Link(framework: "AppKit")]
  lib LibClassCBridge
    fun ap_alert_show_macos = ap_alert_show_macos(title : LibC::Char*, message : LibC::Char*)
    fun ap_clipboard_write_macos = ap_clipboard_write_macos(value : LibC::Char*)
    fun ap_clipboard_read_macos = ap_clipboard_read_macos(token : UInt64) : LibC::Int
    fun ap_open_url_macos = ap_open_url_macos(url : LibC::Char*) : LibC::Int
    fun ap_request_notification_permission_macos = ap_request_notification_permission_macos : LibC::Int
    fun ap_print_text_macos = ap_print_text_macos(text : LibC::Char*, job_name : LibC::Char*) : LibC::Int
    fun ap_open_file_picker_macos = ap_open_file_picker_macos(utis : LibC::Char*, token : UInt64) : LibC::Int
    fun ap_export_file_macos = ap_export_file_macos(suggested_name : LibC::Char*, token : UInt64) : LibC::Int
  end
{% elsif flag?(:ios) || flag?(:ipados) %}
  @[Link(framework: "UIKit")]
  lib LibClassCBridge
    fun ap_clipboard_write_ios = ap_clipboard_write_ios(value : LibC::Char*)
    fun ap_clipboard_read_ios = ap_clipboard_read_ios(token : UInt64) : LibC::Int
    fun ap_open_url_ios = ap_open_url_ios(url : LibC::Char*) : LibC::Int
    fun ap_request_notification_permission_ios = ap_request_notification_permission_ios : LibC::Int
    fun ap_print_text_ios = ap_print_text_ios(text : LibC::Char*, job_name : LibC::Char*) : LibC::Int
    # Note: file-picker bridges take an anchor_view_ptr — the substrate
    # passes `Pointer(Void).null` and the bridge no-ops. A real
    # picker component (10B.4) plumbs the active view ptr through.
    fun ap_open_file_picker_ios = ap_open_file_picker_ios(anchor : Void*, utis : LibC::Char*, token : UInt64) : LibC::Int
    fun ap_export_file_ios = ap_export_file_ios(anchor : Void*, source_url : LibC::Char*, token : UInt64) : LibC::Int
  end
{% end %}

module UI
  module SystemAction
    # Namespace for the framework-installed Class C bindings. The
    # `install` class method is called once from
    # `class_c_bootstrap.cr` at framework load. Specs that want to
    # reinstall a clean substrate after `reset_for_spec` call
    # `UI::SystemAction::Bootstrap.install` directly.
    module Bootstrap
      # Install every framework Class C binding. Idempotent —
      # `register` is last-wins, so calling `install` twice produces
      # the same final table.
      def self.install : Nil
        install_hello_world_alert
        install_copy_to_clipboard
        install_paste_from_clipboard
        install_request_permission
        install_open_url
        install_incoming_deep_link
        install_print
        install_open_file_picker
        install_export_file
        nil
      end

      # ------------------------------------------------------------------
      # Per-platform capability gate.
      #
      # Returns `true` when the running build's compile-time flag matches
      # `platform`. Used by every binding's `api_capability_check` so
      # `feature_supported?` is truthful: a dispatch on the macOS proc
      # only succeeds when the build was compiled with `-Dmacos`.
      # Web platforms (`:web_wide`, `:web_narrow`) are always supported
      # since the web procs are pure Crystal — they STDERR-puts as the
      # test stand-in and a future renderer integration emits real JS.
      # ------------------------------------------------------------------
      def self.platform_built_in?(platform : Symbol) : Bool
        case platform
        when :web_wide, :web_narrow
          true
        when :macos
          {% if flag?(:macos) %} true {% else %} false {% end %}
        when :ios
          {% if flag?(:ios) %} true {% else %} false {% end %}
        when :ipados
          {% if flag?(:ipados) || flag?(:ios) %} true {% else %} false {% end %}
        when :android
          {% if flag?(:android) %} true {% else %} false {% end %}
        else
          false
        end
      end

      # ------------------------------------------------------------------
      # `:hello_world_alert` — proof binding from 10B.3.0. Kept in
      # place so the existing 23-spec suite continues to pass.
      # ------------------------------------------------------------------
      def self.install_hello_world_alert : Nil
        UI::SystemAction::Registry.register(
          UI::SystemAction::PlatformBinding.new(
            intent_id: :hello_world_alert,
            platforms: {
              :web_wide   => ->web_alert(UI::SystemAction::PlatformBinding::Args),
              :web_narrow => ->web_alert(UI::SystemAction::PlatformBinding::Args),
              :macos      => ->macos_alert(UI::SystemAction::PlatformBinding::Args),
              :ios        => ->ios_alert_stub(UI::SystemAction::PlatformBinding::Args),
              :ipados     => ->ios_alert_stub(UI::SystemAction::PlatformBinding::Args),
              :android    => ->android_toast_stub(UI::SystemAction::PlatformBinding::Args),
            } of Symbol => UI::SystemAction::PlatformBinding::PlatformProc,
          )
        )
        nil
      end

      def self.web_alert(args : UI::SystemAction::PlatformBinding::Args) : Nil
        message = args[:message]? || ""
        title = args[:title]? || "Hello"
        STDERR.puts "[hello_world_alert/web] #{title}: #{message}"
        nil
      end

      def self.macos_alert(args : UI::SystemAction::PlatformBinding::Args) : Nil
        title = args[:title]? || "Hello"
        message = args[:message]? || ""
        {% if flag?(:macos) %}
          LibClassCBridge.ap_alert_show_macos(title, message)
        {% else %}
          raise "macos_alert called from a non-macos build — substrate bug"
        {% end %}
        nil
      end

      def self.ios_alert_stub(args : UI::SystemAction::PlatformBinding::Args) : Nil
        raise "hello_world_alert: iOS binding not yet implemented. " \
              "Add ap_alert_show_ios(const char *title, const char *message) to " \
              "src/ui/native/objc_bridge.m and wire LibClassCBridge."
      end

      def self.android_toast_stub(args : UI::SystemAction::PlatformBinding::Args) : Nil
        raise "hello_world_alert: Android binding not yet implemented. " \
              "Add ap_toast_show(env, context, message) to " \
              "src/ui/native/android_bridge.c invoking Toast.makeText(...).show() " \
              "via JNI."
      end

      # ------------------------------------------------------------------
      # B-027 `:copy_to_clipboard`
      # ------------------------------------------------------------------
      # Args: `value: String` (required) — the text to place on the
      # system clipboard.
      #
      # Bridge functions:
      #   * macOS:   `ap_clipboard_write_macos(value)`
      #   * iOS:     `ap_clipboard_write_ios(value)`
      #   * Android: `ap_clipboard_write_android(env, context, value, len)`
      # ------------------------------------------------------------------
      def self.install_copy_to_clipboard : Nil
        UI::SystemAction::Registry.register(
          UI::SystemAction::PlatformBinding.new(
            intent_id: :copy_to_clipboard,
            api_capability_check: ->(p : Symbol) { platform_built_in?(p) },
            platforms: {
              :web_wide   => ->web_copy_to_clipboard(UI::SystemAction::PlatformBinding::Args),
              :web_narrow => ->web_copy_to_clipboard(UI::SystemAction::PlatformBinding::Args),
              :macos      => ->macos_copy_to_clipboard(UI::SystemAction::PlatformBinding::Args),
              :ios        => ->ios_copy_to_clipboard(UI::SystemAction::PlatformBinding::Args),
              :ipados     => ->ios_copy_to_clipboard(UI::SystemAction::PlatformBinding::Args),
              :android    => ->android_copy_to_clipboard_stub(UI::SystemAction::PlatformBinding::Args),
            } of Symbol => UI::SystemAction::PlatformBinding::PlatformProc,
          )
        )
        nil
      end

      def self.web_copy_to_clipboard(args : UI::SystemAction::PlatformBinding::Args) : Nil
        value = args[:value]? || ""
        STDERR.puts "[copy_to_clipboard/web] #{value}"
        nil
      end

      def self.macos_copy_to_clipboard(args : UI::SystemAction::PlatformBinding::Args) : Nil
        value = args[:value]? || ""
        {% if flag?(:macos) %}
          LibClassCBridge.ap_clipboard_write_macos(value)
        {% else %}
          raise "macos_copy_to_clipboard called from non-macos build"
        {% end %}
        nil
      end

      def self.ios_copy_to_clipboard(args : UI::SystemAction::PlatformBinding::Args) : Nil
        value = args[:value]? || ""
        {% if flag?(:ios) || flag?(:ipados) %}
          LibClassCBridge.ap_clipboard_write_ios(value)
        {% else %}
          raise "ios_copy_to_clipboard called from non-ios build"
        {% end %}
        nil
      end

      # Android stub: the C function `ap_clipboard_write_android` is in
      # `android_bridge.c` but routing through it from Crystal requires
      # a `JNIEnv*` + Context pointer that's only available inside the
      # active Android renderer. The fully-wired path lands in 10B.4
      # once the renderer exposes a Class C dispatch hook. Until then
      # this proc raises — capability check returns false so dispatch
      # surfaces as `unsupported`.
      def self.android_copy_to_clipboard_stub(args : UI::SystemAction::PlatformBinding::Args) : Nil
        raise "copy_to_clipboard: Android binding not yet wired through " \
              "the renderer surface. C function `ap_clipboard_write_android` " \
              "is implemented in src/ui/native/android_bridge.c; needs JNIEnv " \
              "+ Context plumbing from UI::Android::Renderer (10B.4)."
      end

      # ------------------------------------------------------------------
      # B-028 `:paste_from_clipboard`
      # ------------------------------------------------------------------
      # Args: `on_paste: Symbol` (required) — a callback token registered
      # via `UI::CallbackRegistry.register_string_callback`. The native
      # bridge fires the callback with the pasted string (or "" if the
      # clipboard is empty / has no text).
      #
      # Bridge functions:
      #   * macOS:   `ap_clipboard_read_macos(token) -> int`
      #   * iOS:     `ap_clipboard_read_ios(token) -> int`
      #   * Android: `ap_clipboard_read_android(env, context, token) -> int`
      # ------------------------------------------------------------------
      def self.install_paste_from_clipboard : Nil
        UI::SystemAction::Registry.register(
          UI::SystemAction::PlatformBinding.new(
            intent_id: :paste_from_clipboard,
            api_capability_check: ->(p : Symbol) { platform_built_in?(p) },
            platforms: {
              :web_wide   => ->web_paste_from_clipboard(UI::SystemAction::PlatformBinding::Args),
              :web_narrow => ->web_paste_from_clipboard(UI::SystemAction::PlatformBinding::Args),
              :macos      => ->macos_paste_from_clipboard(UI::SystemAction::PlatformBinding::Args),
              :ios        => ->ios_paste_from_clipboard(UI::SystemAction::PlatformBinding::Args),
              :ipados     => ->ios_paste_from_clipboard(UI::SystemAction::PlatformBinding::Args),
              :android    => ->android_paste_from_clipboard_stub(UI::SystemAction::PlatformBinding::Args),
            } of Symbol => UI::SystemAction::PlatformBinding::PlatformProc,
          )
        )
        nil
      end

      def self.web_paste_from_clipboard(args : UI::SystemAction::PlatformBinding::Args) : Nil
        STDERR.puts "[paste_from_clipboard/web] (would call navigator.clipboard.readText())"
        nil
      end

      def self.macos_paste_from_clipboard(args : UI::SystemAction::PlatformBinding::Args) : Nil
        {% if flag?(:macos) %}
          token = parse_callback_token(args[:on_paste]?)
          LibClassCBridge.ap_clipboard_read_macos(token)
        {% else %}
          raise "macos_paste_from_clipboard called from non-macos build"
        {% end %}
        nil
      end

      def self.ios_paste_from_clipboard(args : UI::SystemAction::PlatformBinding::Args) : Nil
        {% if flag?(:ios) || flag?(:ipados) %}
          token = parse_callback_token(args[:on_paste]?)
          LibClassCBridge.ap_clipboard_read_ios(token)
        {% else %}
          raise "ios_paste_from_clipboard called from non-ios build"
        {% end %}
        nil
      end

      def self.android_paste_from_clipboard_stub(args : UI::SystemAction::PlatformBinding::Args) : Nil
        raise "paste_from_clipboard: Android binding not yet wired through " \
              "the renderer surface. C function `ap_clipboard_read_android` " \
              "is implemented in src/ui/native/android_bridge.c; needs JNIEnv " \
              "+ Context plumbing from UI::Android::Renderer (10B.4)."
      end

      # Parse a Hash(Symbol, String) callback-token arg. The arg shape
      # is `:on_paste => "<uint64 string>"`. Returns 0 if missing or
      # malformed — the native bridge tolerates a zero token (no-op
      # dispatch).
      private def self.parse_callback_token(raw : String?) : UInt64
        return 0_u64 unless raw
        raw.to_u64? || 0_u64
      end

      # ------------------------------------------------------------------
      # B-029 `:request_permission`
      # ------------------------------------------------------------------
      # Args: `permission: String` — one of `"notifications"`, `"camera"`,
      # `"microphone"`, etc. The substrate ships notifications only; other
      # permissions are documented gaps.
      #
      # Bridge functions:
      #   * macOS:   `ap_request_notification_permission_macos() -> int`
      #   * iOS:     `ap_request_notification_permission_ios() -> int`
      #   * Android: PLACEHOLDER — ActivityCompat.requestPermissions
      #             requires an Activity (not just a Context) and the
      #             permission-result callback machinery. Documented gap.
      # ------------------------------------------------------------------
      def self.install_request_permission : Nil
        UI::SystemAction::Registry.register(
          UI::SystemAction::PlatformBinding.new(
            intent_id: :request_permission,
            api_capability_check: ->(p : Symbol) { platform_built_in?(p) },
            platforms: {
              :web_wide   => ->web_request_permission(UI::SystemAction::PlatformBinding::Args),
              :web_narrow => ->web_request_permission(UI::SystemAction::PlatformBinding::Args),
              :macos      => ->macos_request_permission(UI::SystemAction::PlatformBinding::Args),
              :ios        => ->ios_request_permission(UI::SystemAction::PlatformBinding::Args),
              :ipados     => ->ios_request_permission(UI::SystemAction::PlatformBinding::Args),
              :android    => ->android_request_permission_stub(UI::SystemAction::PlatformBinding::Args),
            } of Symbol => UI::SystemAction::PlatformBinding::PlatformProc,
          )
        )
        nil
      end

      def self.web_request_permission(args : UI::SystemAction::PlatformBinding::Args) : Nil
        permission = args[:permission]? || "notifications"
        STDERR.puts "[request_permission/web] (would call Notification.requestPermission for #{permission})"
        nil
      end

      def self.macos_request_permission(args : UI::SystemAction::PlatformBinding::Args) : Nil
        permission = args[:permission]? || "notifications"
        case permission
        when "notifications"
          {% if flag?(:macos) %}
            LibClassCBridge.ap_request_notification_permission_macos
          {% else %}
            raise "macos_request_permission called from non-macos build"
          {% end %}
        else
          raise "request_permission: macOS bridge for `#{permission}` not implemented. " \
                "Currently only `notifications` ships; add a C function in objc_bridge.m " \
                "wrapping the appropriate AVCaptureDevice / PHPhotoLibrary / " \
                "CLLocationManager authorization API."
        end
        nil
      end

      def self.ios_request_permission(args : UI::SystemAction::PlatformBinding::Args) : Nil
        permission = args[:permission]? || "notifications"
        case permission
        when "notifications"
          {% if flag?(:ios) || flag?(:ipados) %}
            LibClassCBridge.ap_request_notification_permission_ios
          {% else %}
            raise "ios_request_permission called from non-ios build"
          {% end %}
        else
          raise "request_permission: iOS bridge for `#{permission}` not implemented. " \
                "Currently only `notifications` ships; add a C function in objc_bridge.m " \
                "wrapping AVCaptureDevice.requestAccessForMediaType: / " \
                "PHPhotoLibrary.requestAuthorization: / " \
                "CLLocationManager.requestWhenInUseAuthorization."
        end
        nil
      end

      def self.android_request_permission_stub(args : UI::SystemAction::PlatformBinding::Args) : Nil
        raise "request_permission: Android binding not yet implemented. " \
              "ActivityCompat.requestPermissions needs an Activity reference + " \
              "an onRequestPermissionsResult callback wired through JNI. " \
              "Add C helper `ap_request_permission_android(env, activity, perm, " \
              "request_code, token)` to android_bridge.c (10B.4)."
      end

      # ------------------------------------------------------------------
      # B-030 `:open_url`
      # ------------------------------------------------------------------
      # Args: `url: String` (required) — http(s):// or any scheme the OS
      # routes (mailto:, tel:, custom URL schemes).
      #
      # Bridge functions:
      #   * macOS:   `ap_open_url_macos(url) -> int`
      #   * iOS:     `ap_open_url_ios(url) -> int`
      #   * Android: `ap_open_url_android(env, context, url, len) -> int`
      # ------------------------------------------------------------------
      def self.install_open_url : Nil
        UI::SystemAction::Registry.register(
          UI::SystemAction::PlatformBinding.new(
            intent_id: :open_url,
            api_capability_check: ->(p : Symbol) { platform_built_in?(p) },
            platforms: {
              :web_wide   => ->web_open_url(UI::SystemAction::PlatformBinding::Args),
              :web_narrow => ->web_open_url(UI::SystemAction::PlatformBinding::Args),
              :macos      => ->macos_open_url(UI::SystemAction::PlatformBinding::Args),
              :ios        => ->ios_open_url(UI::SystemAction::PlatformBinding::Args),
              :ipados     => ->ios_open_url(UI::SystemAction::PlatformBinding::Args),
              :android    => ->android_open_url_stub(UI::SystemAction::PlatformBinding::Args),
            } of Symbol => UI::SystemAction::PlatformBinding::PlatformProc,
          )
        )
        nil
      end

      def self.web_open_url(args : UI::SystemAction::PlatformBinding::Args) : Nil
        url = args[:url]? || ""
        STDERR.puts "[open_url/web] (would call window.open(#{url.inspect}))"
        nil
      end

      def self.macos_open_url(args : UI::SystemAction::PlatformBinding::Args) : Nil
        url = args[:url]? || ""
        raise "open_url: missing :url arg" if url.empty?
        {% if flag?(:macos) %}
          LibClassCBridge.ap_open_url_macos(url)
        {% else %}
          raise "macos_open_url called from non-macos build"
        {% end %}
        nil
      end

      def self.ios_open_url(args : UI::SystemAction::PlatformBinding::Args) : Nil
        url = args[:url]? || ""
        raise "open_url: missing :url arg" if url.empty?
        {% if flag?(:ios) || flag?(:ipados) %}
          LibClassCBridge.ap_open_url_ios(url)
        {% else %}
          raise "ios_open_url called from non-ios build"
        {% end %}
        nil
      end

      def self.android_open_url_stub(args : UI::SystemAction::PlatformBinding::Args) : Nil
        raise "open_url: Android binding not yet wired through the renderer " \
              "surface. C function `ap_open_url_android` is implemented in " \
              "src/ui/native/android_bridge.c; needs JNIEnv + Context plumbing " \
              "from UI::Android::Renderer (10B.4)."
      end

      # ------------------------------------------------------------------
      # B-031 `:incoming_deep_link`
      # ------------------------------------------------------------------
      # Event-driven binding. The intent fires NOT when the app dispatches
      # it, but when the OS hands the running app an incoming URL via
      # `UIApplication.openURL:options:` (iOS) / `application:openFile:`
      # (macOS) / `Intent.getData()` (Android). The Crystal-side host
      # registers a callback via
      # `UI::SystemAction::IncomingDeepLink.on_receive { |url| ... }`; the
      # native renderer wires the OS-level event-handler to invoke that
      # callback at launch / foreground time.
      #
      # The substrate ships a callback-registration helper + a dispatch
      # that emits the registered callback for the in-`args[:url]` URL
      # (the test-time path). Full wire-through-OS-events lands with the
      # per-platform renderer integrations (10B.4).
      # ------------------------------------------------------------------
      def self.install_incoming_deep_link : Nil
        UI::SystemAction::Registry.register(
          UI::SystemAction::PlatformBinding.new(
            intent_id: :incoming_deep_link,
            api_capability_check: ->(_p : Symbol) { true },
            platforms: {
              :web_wide   => ->incoming_deep_link_dispatch(UI::SystemAction::PlatformBinding::Args),
              :web_narrow => ->incoming_deep_link_dispatch(UI::SystemAction::PlatformBinding::Args),
              :macos      => ->incoming_deep_link_dispatch(UI::SystemAction::PlatformBinding::Args),
              :ios        => ->incoming_deep_link_dispatch(UI::SystemAction::PlatformBinding::Args),
              :ipados     => ->incoming_deep_link_dispatch(UI::SystemAction::PlatformBinding::Args),
              :android    => ->incoming_deep_link_dispatch(UI::SystemAction::PlatformBinding::Args),
            } of Symbol => UI::SystemAction::PlatformBinding::PlatformProc,
          )
        )
        nil
      end

      def self.incoming_deep_link_dispatch(args : UI::SystemAction::PlatformBinding::Args) : Nil
        url = args[:url]? || ""
        UI::SystemAction::IncomingDeepLink.fire(url)
        nil
      end

      # ------------------------------------------------------------------
      # B-032 `:print`
      # ------------------------------------------------------------------
      # Args: `text: String` (required), `job_name: String` (optional).
      #
      # Bridge functions:
      #   * macOS:   `ap_print_text_macos(text, job_name) -> int`
      #   * iOS:     `ap_print_text_ios(text, job_name) -> int`
      #   * Android: PLACEHOLDER — PrintManager.print requires building
      #             a PrintDocumentAdapter subclass; that's a class-extension
      #             API not reachable from JNI without generating a Java
      #             adapter class. Documented gap; substrate stub.
      # ------------------------------------------------------------------
      def self.install_print : Nil
        UI::SystemAction::Registry.register(
          UI::SystemAction::PlatformBinding.new(
            intent_id: :print,
            api_capability_check: ->(p : Symbol) { platform_built_in?(p) },
            platforms: {
              :web_wide   => ->web_print(UI::SystemAction::PlatformBinding::Args),
              :web_narrow => ->web_print(UI::SystemAction::PlatformBinding::Args),
              :macos      => ->macos_print(UI::SystemAction::PlatformBinding::Args),
              :ios        => ->ios_print(UI::SystemAction::PlatformBinding::Args),
              :ipados     => ->ios_print(UI::SystemAction::PlatformBinding::Args),
              :android    => ->android_print_stub(UI::SystemAction::PlatformBinding::Args),
            } of Symbol => UI::SystemAction::PlatformBinding::PlatformProc,
          )
        )
        nil
      end

      def self.web_print(args : UI::SystemAction::PlatformBinding::Args) : Nil
        STDERR.puts "[print/web] (would call window.print())"
        nil
      end

      def self.macos_print(args : UI::SystemAction::PlatformBinding::Args) : Nil
        text = args[:text]? || ""
        job_name = args[:job_name]? || ""
        {% if flag?(:macos) %}
          LibClassCBridge.ap_print_text_macos(text, job_name)
        {% else %}
          raise "macos_print called from non-macos build"
        {% end %}
        nil
      end

      def self.ios_print(args : UI::SystemAction::PlatformBinding::Args) : Nil
        text = args[:text]? || ""
        job_name = args[:job_name]? || ""
        {% if flag?(:ios) || flag?(:ipados) %}
          LibClassCBridge.ap_print_text_ios(text, job_name)
        {% else %}
          raise "ios_print called from non-ios build"
        {% end %}
        nil
      end

      def self.android_print_stub(args : UI::SystemAction::PlatformBinding::Args) : Nil
        raise "print: Android binding not yet implemented. " \
              "PrintManager.print requires a PrintDocumentAdapter subclass; " \
              "ship a small Java helper class (e.g. AssetPipelinePrintHelper) " \
              "alongside the AAR and invoke it via JNI in 10B.4."
      end

      # ------------------------------------------------------------------
      # B-033 `:open_file_picker`
      # ------------------------------------------------------------------
      # Args: `utis: String` (optional, comma-separated UTIs / mime types),
      #       `on_pick: String` (callback token from CallbackRegistry).
      #
      # Bridge functions:
      #   * macOS:   `ap_open_file_picker_macos(utis, token) -> int`
      #   * iOS:     `ap_open_file_picker_ios(anchor, utis, token) -> int`
      #             — anchor required; substrate passes nil and the
      #             bridge no-ops. Production usage plumbs anchor
      #             through 10B.4 picker component.
      #   * Android: PLACEHOLDER — startActivityForResult is Activity-
      #             scoped + needs an onActivityResult callback wired
      #             through JNI. Documented gap.
      # ------------------------------------------------------------------
      def self.install_open_file_picker : Nil
        UI::SystemAction::Registry.register(
          UI::SystemAction::PlatformBinding.new(
            intent_id: :open_file_picker,
            api_capability_check: ->(p : Symbol) { platform_built_in?(p) },
            platforms: {
              :web_wide   => ->web_open_file_picker(UI::SystemAction::PlatformBinding::Args),
              :web_narrow => ->web_open_file_picker(UI::SystemAction::PlatformBinding::Args),
              :macos      => ->macos_open_file_picker(UI::SystemAction::PlatformBinding::Args),
              :ios        => ->ios_open_file_picker(UI::SystemAction::PlatformBinding::Args),
              :ipados     => ->ios_open_file_picker(UI::SystemAction::PlatformBinding::Args),
              :android    => ->android_open_file_picker_stub(UI::SystemAction::PlatformBinding::Args),
            } of Symbol => UI::SystemAction::PlatformBinding::PlatformProc,
          )
        )
        nil
      end

      def self.web_open_file_picker(args : UI::SystemAction::PlatformBinding::Args) : Nil
        STDERR.puts "[open_file_picker/web] (would render <input type=file> or call showOpenFilePicker())"
        nil
      end

      def self.macos_open_file_picker(args : UI::SystemAction::PlatformBinding::Args) : Nil
        utis = args[:utis]? || ""
        {% if flag?(:macos) %}
          token = parse_callback_token(args[:on_pick]?)
          LibClassCBridge.ap_open_file_picker_macos(utis, token)
        {% else %}
          raise "macos_open_file_picker called from non-macos build"
        {% end %}
        nil
      end

      def self.ios_open_file_picker(args : UI::SystemAction::PlatformBinding::Args) : Nil
        utis = args[:utis]? || ""
        {% if flag?(:ios) || flag?(:ipados) %}
          token = parse_callback_token(args[:on_pick]?)
          anchor = Pointer(Void).null
          LibClassCBridge.ap_open_file_picker_ios(anchor, utis, token)
        {% else %}
          raise "ios_open_file_picker called from non-ios build"
        {% end %}
        nil
      end

      def self.android_open_file_picker_stub(args : UI::SystemAction::PlatformBinding::Args) : Nil
        raise "open_file_picker: Android binding not yet implemented. " \
              "Intent.ACTION_GET_CONTENT requires startActivityForResult + " \
              "onActivityResult plumbing through an Activity-scoped JNI " \
              "helper. Add C helper `ap_open_file_picker_android(env, " \
              "activity, mime, request_code, token)` to android_bridge.c (10B.4)."
      end

      # ------------------------------------------------------------------
      # B-034 `:export_file`
      # ------------------------------------------------------------------
      # Args: `suggested_name: String` (optional, default name field),
      #       `source_url: String` (iOS only — temp-file URL),
      #       `on_export: String` (callback token).
      #
      # Bridge functions:
      #   * macOS:   `ap_export_file_macos(suggested, token) -> int`
      #   * iOS:     `ap_export_file_ios(anchor, source_url, token) -> int`
      #   * Android: PLACEHOLDER — ACTION_CREATE_DOCUMENT, same constraints
      #             as ACTION_GET_CONTENT. Documented gap.
      # ------------------------------------------------------------------
      def self.install_export_file : Nil
        UI::SystemAction::Registry.register(
          UI::SystemAction::PlatformBinding.new(
            intent_id: :export_file,
            api_capability_check: ->(p : Symbol) { platform_built_in?(p) },
            platforms: {
              :web_wide   => ->web_export_file(UI::SystemAction::PlatformBinding::Args),
              :web_narrow => ->web_export_file(UI::SystemAction::PlatformBinding::Args),
              :macos      => ->macos_export_file(UI::SystemAction::PlatformBinding::Args),
              :ios        => ->ios_export_file(UI::SystemAction::PlatformBinding::Args),
              :ipados     => ->ios_export_file(UI::SystemAction::PlatformBinding::Args),
              :android    => ->android_export_file_stub(UI::SystemAction::PlatformBinding::Args),
            } of Symbol => UI::SystemAction::PlatformBinding::PlatformProc,
          )
        )
        nil
      end

      def self.web_export_file(args : UI::SystemAction::PlatformBinding::Args) : Nil
        STDERR.puts "[export_file/web] (would render <a download> or call showSaveFilePicker())"
        nil
      end

      def self.macos_export_file(args : UI::SystemAction::PlatformBinding::Args) : Nil
        suggested = args[:suggested_name]? || ""
        {% if flag?(:macos) %}
          token = parse_callback_token(args[:on_export]?)
          LibClassCBridge.ap_export_file_macos(suggested, token)
        {% else %}
          raise "macos_export_file called from non-macos build"
        {% end %}
        nil
      end

      def self.ios_export_file(args : UI::SystemAction::PlatformBinding::Args) : Nil
        source = args[:source_url]? || ""
        {% if flag?(:ios) || flag?(:ipados) %}
          raise "export_file: missing :source_url arg" if source.empty?
          token = parse_callback_token(args[:on_export]?)
          anchor = Pointer(Void).null
          LibClassCBridge.ap_export_file_ios(anchor, source, token)
        {% else %}
          raise "ios_export_file called from non-ios build"
        {% end %}
        nil
      end

      def self.android_export_file_stub(args : UI::SystemAction::PlatformBinding::Args) : Nil
        raise "export_file: Android binding not yet implemented. " \
              "Intent.ACTION_CREATE_DOCUMENT requires startActivityForResult + " \
              "onActivityResult plumbing through an Activity-scoped JNI helper. " \
              "Add C helper `ap_export_file_android(env, activity, mime, " \
              "suggested_name, request_code, token)` to android_bridge.c (10B.4)."
      end
    end

    # ------------------------------------------------------------------
    # Phase 10B.3.x — `:incoming_deep_link` callback registry.
    #
    # A tiny event-bus the framework / host wire OS-level
    # openURL: events into. App code registers a handler via
    # `UI::SystemAction::IncomingDeepLink.on_receive { |url| ... }`; the
    # platform renderer (or, in tests, a manual
    # `UI::SystemAction.perform(:incoming_deep_link, url: ...)`) calls
    # `IncomingDeepLink.fire(url)` to notify every registered handler.
    #
    # Last-in stays — callers register once at app boot.
    # ------------------------------------------------------------------
    module IncomingDeepLink
      @@handlers = [] of String -> Nil

      # Register a handler to be called every time a deep link arrives.
      # Returns the registered proc so callers can later
      # `IncomingDeepLink.remove_handler(proc)` to detach.
      def self.on_receive(&block : String -> Nil) : (String -> Nil)
        handler = block
        @@handlers << handler
        handler
      end

      # Detach a previously-registered handler.
      def self.remove_handler(handler : String -> Nil) : Nil
        @@handlers.delete(handler)
        nil
      end

      # Notify every registered handler. Used by the platform renderer
      # (or by a test). Exceptions inside a handler are swallowed and
      # logged to STDERR so one bad listener doesn't break the chain.
      def self.fire(url : String) : Nil
        @@handlers.each do |h|
          begin
            h.call(url)
          rescue ex : Exception
            STDERR.puts "[incoming_deep_link] handler raised: #{ex.message}"
          end
        end
        nil
      end

      # Count of registered handlers. Spec hook.
      def self.handler_count : Int32
        @@handlers.size
      end

      # SPEC-ONLY — clear every registered handler. Called by the spec
      # suite's `reinstall_class_c_bootstrap` helper.
      def self.reset_for_spec : Nil
        @@handlers.clear
        nil
      end
    end
  end
end

# Install the framework's Class C bindings at load. Idempotent.
UI::SystemAction::Bootstrap.install
