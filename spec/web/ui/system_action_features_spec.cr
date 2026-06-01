require "../spec_helper"
require "../../../src/ui/widget_route"
require "../../../src/ui/system_action/bootstrap"
require "../../../src/ui/environment"

# Phase 10B.3.x — 8 Class C feature spec.
#
# Each describe block exercises:
#   * the binding is registered after `install`
#   * `feature_supported?` is truthful on web. NOTE (false-success fix,
#     platform-capability-matrix §11.1): the web procs for clipboard /
#     paste / open_url / print / file-picker / export / request_permission
#     only STDERR-puts — they perform NO real browser effect — so they are
#     now reported `unsupported` on web rather than fake `success`. The
#     dispatch path has no web-renderer handle to emit real JS, so honesty
#     (unsupported) beats fake success until that seam is threaded.
#     `:incoming_deep_link` remains genuinely web-supported (pure Crystal).
#   * `feature_supported?` is falsy on non-built-in native platforms
#     (e.g. `:macos` on a web-only build returns false because the
#     binding's `api_capability_check` consults `platform_built_in?`)
#   * `dispatch` returns Success on web
#   * `dispatch` returns Unsupported when the running build doesn't
#     include the targeted native platform
#
# Reuses the same reinstall pattern as `intent_class_c_spec.cr`.

private def reinstall_class_c_bootstrap : Nil
  UI::SystemAction::Registry.reset_for_spec
  UI::Environment.reset_platform_for_spec
  UI::SystemAction::IncomingDeepLink.reset_for_spec
  UI::SystemAction::Bootstrap.install
  nil
end

describe "Phase 10B.3.x — Class C feature bindings" do
  before_each { reinstall_class_c_bootstrap }

  describe ":copy_to_clipboard" do
    it "is registered after install" do
      UI::SystemAction::Registry.binding_for(:copy_to_clipboard).should_not be_nil
    end

    it "is NOT supported on web (STDERR stand-in performs no real effect)" do
      # False-success fix: the web proc only STDERR-puts; nothing reaches
      # the clipboard. Honest answer is unsupported, not fake success.
      UI::SystemAction::Registry.supports?(:copy_to_clipboard, :web_wide).should be_false
      UI::SystemAction::Registry.supports?(:copy_to_clipboard, :web_narrow).should be_false
    end

    it "is NOT supported on :macos in a web-only build" do
      # The capability check returns false for :macos when the build
      # isn't compiled with -Dmacos. The web spec suite runs without
      # any -D flag so this is the production path.
      UI::SystemAction::Registry.supports?(:copy_to_clipboard, :macos).should be_false
    end

    it "returns Unsupported on web (no real clipboard effect wired)" do
      UI::Environment.set_platform(:web_wide)
      result = UI::SystemAction.perform(:copy_to_clipboard, value: "hello")
      result.unsupported?.should be_true
    end

    it "returns Unsupported when dispatching on :macos in a web build" do
      UI::Environment.set_platform(:macos)
      result = UI::SystemAction.perform(:copy_to_clipboard, value: "hello")
      result.unsupported?.should be_true
    end
  end

  describe ":paste_from_clipboard" do
    it "is registered after install" do
      UI::SystemAction::Registry.binding_for(:paste_from_clipboard).should_not be_nil
    end

    it "returns Unsupported on web (no real clipboard read wired)" do
      UI::Environment.set_platform(:web_wide)
      result = UI::SystemAction.perform(:paste_from_clipboard)
      result.unsupported?.should be_true
    end

    it "returns Unsupported on :ios in a web build" do
      UI::Environment.set_platform(:ios)
      result = UI::SystemAction.perform(:paste_from_clipboard)
      result.unsupported?.should be_true
    end
  end

  describe ":request_permission" do
    it "is registered after install" do
      UI::SystemAction::Registry.binding_for(:request_permission).should_not be_nil
    end

    it "returns Unsupported on web (no real Notification.requestPermission wired)" do
      UI::Environment.set_platform(:web_wide)
      result = UI::SystemAction.perform(:request_permission, permission: "notifications")
      result.unsupported?.should be_true
    end

    it "returns Unsupported on :android in a web build" do
      UI::Environment.set_platform(:android)
      result = UI::SystemAction.perform(:request_permission, permission: "notifications")
      result.unsupported?.should be_true
    end
  end

  describe ":open_url" do
    it "is registered after install" do
      UI::SystemAction::Registry.binding_for(:open_url).should_not be_nil
    end

    it "returns Unsupported on web (no real window.open wired)" do
      UI::Environment.set_platform(:web_wide)
      result = UI::SystemAction.perform(:open_url, url: "https://example.com")
      result.unsupported?.should be_true
    end

    it "returns Unsupported on :macos in a web build" do
      UI::Environment.set_platform(:macos)
      result = UI::SystemAction.perform(:open_url, url: "https://example.com")
      result.unsupported?.should be_true
    end
  end

  describe ":incoming_deep_link" do
    it "is registered after install" do
      UI::SystemAction::Registry.binding_for(:incoming_deep_link).should_not be_nil
    end

    it "fires registered handlers when dispatched with a url" do
      captured = [] of String
      UI::SystemAction::IncomingDeepLink.on_receive do |url|
        captured << url
      end
      UI::Environment.set_platform(:web_wide)
      result = UI::SystemAction.perform(:incoming_deep_link, url: "myapp://session/42")
      result.success?.should be_true
      captured.should eq(["myapp://session/42"])
    end

    it "supports multiple handlers" do
      counter = 0
      UI::SystemAction::IncomingDeepLink.on_receive { |_| counter += 1; nil }
      UI::SystemAction::IncomingDeepLink.on_receive { |_| counter += 10; nil }
      UI::Environment.set_platform(:web_wide)
      UI::SystemAction.perform(:incoming_deep_link, url: "myapp://x")
      counter.should eq(11)
    end

    it "swallows handler exceptions so the chain keeps going" do
      survivor = 0
      UI::SystemAction::IncomingDeepLink.on_receive { |_| raise "first handler boom" }
      UI::SystemAction::IncomingDeepLink.on_receive { |_| survivor += 1; nil }
      UI::Environment.set_platform(:web_wide)
      UI::SystemAction.perform(:incoming_deep_link, url: "myapp://x")
      survivor.should eq(1)
    end

    it "is supported on every platform (callback-based, no API gate)" do
      UI::SystemAction::Registry.supports?(:incoming_deep_link, :web_wide).should be_true
      UI::SystemAction::Registry.supports?(:incoming_deep_link, :macos).should be_true
      UI::SystemAction::Registry.supports?(:incoming_deep_link, :ios).should be_true
      UI::SystemAction::Registry.supports?(:incoming_deep_link, :android).should be_true
    end
  end

  describe ":print" do
    it "is registered after install" do
      UI::SystemAction::Registry.binding_for(:print).should_not be_nil
    end

    it "returns Unsupported on web (no real window.print wired)" do
      UI::Environment.set_platform(:web_wide)
      result = UI::SystemAction.perform(:print, text: "hello", job_name: "Test Job")
      result.unsupported?.should be_true
    end

    it "returns Unsupported on :ios in a web build" do
      UI::Environment.set_platform(:ios)
      result = UI::SystemAction.perform(:print, text: "hello")
      result.unsupported?.should be_true
    end
  end

  describe ":open_file_picker" do
    it "is registered after install" do
      UI::SystemAction::Registry.binding_for(:open_file_picker).should_not be_nil
    end

    it "returns Unsupported on web (no real file picker wired)" do
      UI::Environment.set_platform(:web_wide)
      result = UI::SystemAction.perform(:open_file_picker, utis: "public.data")
      result.unsupported?.should be_true
    end

    it "returns Unsupported on :android in a web build" do
      UI::Environment.set_platform(:android)
      result = UI::SystemAction.perform(:open_file_picker)
      result.unsupported?.should be_true
    end
  end

  describe ":export_file" do
    it "is registered after install" do
      UI::SystemAction::Registry.binding_for(:export_file).should_not be_nil
    end

    it "returns Unsupported on web (no real download/save wired)" do
      UI::Environment.set_platform(:web_wide)
      result = UI::SystemAction.perform(:export_file, suggested_name: "draft.txt")
      result.unsupported?.should be_true
    end

    it "returns Unsupported on :macos in a web build" do
      UI::Environment.set_platform(:macos)
      result = UI::SystemAction.perform(:export_file, suggested_name: "x.txt")
      result.unsupported?.should be_true
    end
  end

  describe "registry health" do
    it "has all 9 Class C bindings after install (hello_world_alert + 8 features)" do
      intents = UI::SystemAction::Registry.registered_intents
      [
        :hello_world_alert,
        :copy_to_clipboard,
        :paste_from_clipboard,
        :request_permission,
        :open_url,
        :incoming_deep_link,
        :print,
        :open_file_picker,
        :export_file,
      ].each do |intent|
        intents.should contain(intent)
      end
    end
  end

  describe "Environment.feature_supported?" do
    it "returns false for STDERR-stand-in features on web platform" do
      # False-success fix: these web procs perform no real browser effect,
      # so feature_supported? is honestly false on web (was incorrectly
      # true when the stand-ins faked success).
      UI::Environment.set_platform(:web_wide)
      UI::Environment.feature_supported?(:copy_to_clipboard).should be_false
      UI::Environment.feature_supported?(:open_url).should be_false
      UI::Environment.feature_supported?(:print).should be_false
    end

    it "returns false for native-only features on web platform" do
      # Switch to :macos and expect false on builds without -Dmacos.
      UI::Environment.set_platform(:macos)
      UI::Environment.feature_supported?(:copy_to_clipboard).should be_false
      UI::Environment.feature_supported?(:open_url).should be_false
    end

    it "returns true for :incoming_deep_link on every platform" do
      [:web_wide, :web_narrow, :macos, :ios, :ipados, :android].each do |p|
        UI::Environment.set_platform(p)
        UI::Environment.feature_supported?(:incoming_deep_link).should be_true
      end
    end
  end
end
