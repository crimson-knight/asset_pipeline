# Phase 10B.3.0 — Class C bootstrap: hello_world_alert.
#
# Installs the framework's Class C `PlatformFeatureBinding`s. This
# file is loaded by `src/ui.cr` AFTER the environment + registry are
# set up. Each future Class C feature (10B.3.x) adds its binding
# registration here OR ships its own bootstrap file required from
# this one.
#
# # Why a separate file from `intent_bootstrap.cr`?
#
# Class A bootstrap registers WIDGET defaults; Class C bootstrap
# registers FEATURE bindings. Keeping them in separate files makes
# the load-order story explicit (Class A bootstrap must run after
# `views/*`; Class C bootstrap has no view dependency). It also
# keeps each file legible — Class C will grow to ~8 binding
# registrations + per-platform lambdas, which would crowd the Class A
# bootstrap.
#
# # hello_world_alert proof
#
# The `:hello_world_alert` binding is a proof-of-substrate: it
# exercises every layer (registry → dispatch → environment lookup →
# platform lambda → native side-effect) without depending on a
# real feature. Subsequent Class C bindings (10B.3.x) replace this
# proof's call-sites with real share / clipboard / haptic features.
#
# Per-platform behaviour:
#
#   * Web (`:web_wide`, `:web_narrow`)  — emits an HTML/JS snippet
#     via the renderer surface. To keep the substrate testable in
#     pure-Crystal specs without a browser host, the web binding
#     writes the alert message to STDERR (acts as a `console.log`
#     stand-in). A future web renderer integration can route the
#     same dispatch through a JS bridge that calls `window.alert`.
#   * macOS                              — uses `NSAlert.runModal`
#     via the new `ap_alert_show` objc-bridge function.
#   * iOS / iPadOS                       — TODO 10B.3.x — the
#     `ap_alert_show` objc-bridge function needs an iOS branch
#     wrapping `UIAlertController`. Until then the binding registers
#     iOS/iPadOS in its `platforms` map with a stub that returns a
#     Failed result so `feature_supported?` still reports `true`
#     but dispatch surfaces the gap loudly. Documented for
#     follow-up.
#   * Android                            — TODO 10B.3.x — the
#     `android_toast_show` JNI bridge function needs to be added
#     to `android_bridge.c`. Until then the binding's Android proc
#     is a stub that returns a Failed result. Documented for
#     follow-up.
#
# # Bridge signatures for follow-up
#
#   * iOS:     `void ap_alert_show_ios(const char *title, const char *message);`
#              presents a `UIAlertController` on the top
#              `UIViewController` (use the same `ap_top_presenting_view_controller`
#              helper that `uiactivityview_present` uses).
#   * Android: `void ap_toast_show(void *env_ptr, void *context, const char *message);`
#              calls `Toast.makeText(context, message, Toast.LENGTH_SHORT).show()`
#              via JNI (same pattern as `android_context_start_share_chooser`).

require "./class_c_registry"
require "./platform_feature_binding"

{% if flag?(:macos) %}
  @[Link(framework: "AppKit")]
  lib LibAlertBridge
    fun ap_alert_show_macos = ap_alert_show_macos(title : LibC::Char*, message : LibC::Char*)
  end
{% end %}

module UI
  module Intent
    # Namespace for the framework-installed Class C bindings. The
    # `install` class method is called once from
    # `class_c_bootstrap.cr` at framework load. Specs that want to
    # reinstall a clean substrate after `reset_for_spec` call
    # `UI::Intent::ClassCBootstrap.install` directly.
    module ClassCBootstrap
      # Install every framework Class C binding. Idempotent —
      # `register` is last-wins, so calling `install` twice produces
      # the same final table.
      def self.install : Nil
        install_hello_world_alert
        nil
      end

      # The `:hello_world_alert` proof binding. Args:
      #   `message:` (String, required) — the body text.
      #   `title:`   (String, optional) — defaults to "Hello".
      def self.install_hello_world_alert : Nil
        UI::Intent::ClassCRegistry.register(
          UI::Intent::PlatformFeatureBinding.new(
            intent_id: :hello_world_alert,
            platforms: {
              :web_wide   => ->web_alert(UI::Intent::PlatformFeatureBinding::Args),
              :web_narrow => ->web_alert(UI::Intent::PlatformFeatureBinding::Args),
              :macos      => ->macos_alert(UI::Intent::PlatformFeatureBinding::Args),
              :ios        => ->ios_alert_stub(UI::Intent::PlatformFeatureBinding::Args),
              :ipados     => ->ios_alert_stub(UI::Intent::PlatformFeatureBinding::Args),
              :android    => ->android_toast_stub(UI::Intent::PlatformFeatureBinding::Args),
            } of Symbol => UI::Intent::PlatformFeatureBinding::PlatformProc,
          )
        )
        nil
      end

      # ------------------------------------------------------------------
      # Per-platform implementations for :hello_world_alert.
      # ------------------------------------------------------------------

      # Web — STDERR-as-console.log. Pure-Crystal so the substrate is
      # testable without a browser host. A future web renderer
      # integration can swap this for a JS bridge that calls
      # `window.alert` from a script tag the renderer emits.
      def self.web_alert(args : UI::Intent::PlatformFeatureBinding::Args) : Nil
        message = args[:message]? || ""
        title = args[:title]? || "Hello"
        STDERR.puts "[hello_world_alert/web] #{title}: #{message}"
        nil
      end

      # macOS — NSAlert.runModal via the ap_alert_show_macos C
      # function added to objc_bridge.m alongside this commit.
      # Builds without `-Dmacos` skip the LibAlertBridge `fun` decl
      # (the `lib` block is flag-gated above) and route through a
      # raise so the binding registers a clear failure mode.
      def self.macos_alert(args : UI::Intent::PlatformFeatureBinding::Args) : Nil
        title = args[:title]? || "Hello"
        message = args[:message]? || ""
        {% if flag?(:macos) %}
          LibAlertBridge.ap_alert_show_macos(title, message)
        {% else %}
          # Reaching here means the registry routed a :macos dispatch
          # on a build that wasn't compiled with `-Dmacos`. The
          # binding's `platforms` map should have made this
          # unreachable; raise so the gap shows up loudly.
          raise "macos_alert called from a non-macos build — substrate bug"
        {% end %}
        nil
      end

      # iOS / iPadOS stub. Follow-up 10B.3.x adds a real
      # `ap_alert_show_ios` C function wrapping UIAlertController +
      # `ap_top_presenting_view_controller`. Until then, dispatch
      # surfaces the gap as a Failed result so calling code knows
      # the platform branch is not yet wired.
      def self.ios_alert_stub(args : UI::Intent::PlatformFeatureBinding::Args) : Nil
        raise "hello_world_alert: iOS binding not yet implemented. " \
              "Add ap_alert_show_ios(const char *title, const char *message) to " \
              "src/ui/native/objc_bridge.m (presenting UIAlertController on the " \
              "top UIViewController) and wire LibAlertBridge to call it."
      end

      # Android stub. Follow-up 10B.3.x adds an `ap_toast_show` JNI
      # function to `android_bridge.c` calling Toast.makeText(...)
      # and wires LibAndroidBridge to call it.
      def self.android_toast_stub(args : UI::Intent::PlatformFeatureBinding::Args) : Nil
        raise "hello_world_alert: Android binding not yet implemented. " \
              "Add ap_toast_show(env, context, message) to " \
              "src/ui/native/android_bridge.c invoking Toast.makeText(...).show() " \
              "via JNI, and wire LibAndroidBridge to call it."
      end
    end
  end
end

# Install the framework's Class C bindings at load. Idempotent.
UI::Intent::ClassCBootstrap.install
