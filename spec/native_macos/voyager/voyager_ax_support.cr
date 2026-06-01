{% if flag?(:macos) %}
  # Shared support for the Voyager macOS AX (accessibility + behavior) specs.
  #
  # These specs drive the EXTERNAL bin/voyager process over the accessibility
  # API (AXUIElement). The spec binary requires ONLY the AXTest lib (which
  # links just ApplicationServices + CoreFoundation), so it sidesteps the
  # full-UI / ObjC-collection-bridge link path that blocks `make test-macos`.
  #
  # IMPORTANT — display requirement: AX interaction + tree discovery require a
  # real on-screen window registered with the window server, which needs a
  # logged-in GUI (Aqua) session. In a headless / SSH / detached-spawn context
  # the host renders to an offscreen bitmap fine but its NSWindow is NOT
  # registered as an AXWindow (AXWindows reports only the self-referential
  # AXApplication; `invalid display identifier` is logged). The specs detect
  # that and PEND with guidance rather than false-fail, so they run for real
  # in a GUI session / display-enabled CI and pend everywhere else.
  require "spec"
  require "../../../src/ui/ax_test"

  module VoyagerAX
    extend self

    BIN = File.expand_path(
      "../../../samples/initiative-cross-platform-ui-voyager/macos/bin/voyager", __DIR__)

    NO_DISPLAY = "Voyager macOS AX needs a logged-in GUI session — no on-screen " \
                 "AXWindow in this context (offscreen-bitmap render works, but " \
                 "AX interaction/discovery does not). Run in a desktop session " \
                 "or display-enabled CI."

    def bin_present? : Bool
      File.exists?(BIN)
    end

    # Launch bin/voyager at `slug` with a live interactive window and connect
    # AXTest by PID. HIG_INTERACTIVE=1 keeps the NSApp run loop open + the host
    # activates as a regular app. Always terminates the host.
    def with_app(slug : String, *, settle : Float64 = 2.5, &)
      raise "bin/voyager missing at #{BIN} (run: make -C samples/initiative-cross-platform-ui-voyager macos)" unless bin_present?
      process = Process.new(
        BIN, [slug],
        env: {
          "VOYAGER_ROOT_SLUG"         => slug,
          "HIG_INTERACTIVE"           => "1",
          "VOYAGER_SKIP_NOTIF_PROMPT" => "1",
        },
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit,
      )
      begin
        sleep(settle.seconds)
        yield UI::AXTest::App.connect(process.pid.to_i32)
      ensure
        process.terminate rescue nil
        process.wait rescue nil
      end
    end

    # The app's on-screen content window, or nil if there's no real AXWindow
    # (headless/no-display). Fast — reads AXWindows once, no polling.
    def content_window(app : UI::AXTest::App) : UI::AXTest::Element?
      app.windows.find { |w| w.role == "AXWindow" }
    end

    # Recursively search `root` for a descendant matching identifier/role/label
    # (AXChildren walk, depth-bounded + cycle-guarded by depth). Used WITHIN a
    # real AXWindow (the app-level AXChildren self-cycles, so always search from
    # the window down, never from the app root).
    def find_in(root : UI::AXTest::Element, *, identifier : String? = nil,
                role : String? = nil, label : String? = nil, max_depth : Int32 = 12) : UI::AXTest::Element?
      return nil if max_depth <= 0
      root.children.each do |c|
        ok = true
        ok = false if identifier && c.identifier != identifier
        ok = false if role && c.role != role
        ok = false if label && c.label != label
        return c if ok
        if found = find_in(c, identifier: identifier, role: role, label: label, max_depth: max_depth - 1)
          return found
        end
      end
      nil
    end

    def display_text(elem : UI::AXTest::Element?) : String
      return "" unless e = elem
      v = e.value
      return v if v && !v.empty?
      l = e.label
      l && !l.empty? ? l : ""
    end
  end
{% end %}
