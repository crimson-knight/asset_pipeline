{% if flag?(:macos) %}
  require "./voyager_ax_support"

  # macOS accessibility + behavior coverage for the Voyager UI, driven over
  # the AXUIElement accessibility tree (the macOS analog of the iOS XCUITest
  # suite). See voyager_ax_support.cr for the display requirement: these run
  # for real in a logged-in GUI session and PEND (with guidance) in a
  # headless/no-display context where the NSWindow isn't AX-registered.
  #
  # Run (in a desktop session, after `make -C samples/initiative-cross-platform-ui-voyager macos`):
  #   crystal-alpha spec spec/native_macos/voyager/ -Dmacos \
  #     --link-flags="-framework ApplicationServices -framework CoreFoundation"

  # Probe the display ONCE (launch sign-in, check for a real AXWindow). When
  # available, define real examples; otherwise a single pending example with
  # the reason — so the suite never false-fails in a headless context.
  DISPLAY_OK = VoyagerAX.bin_present? && (
    begin
      ok = false
      VoyagerAX.with_app("voyager-sign-in") { |app| ok = !VoyagerAX.content_window(app).nil? }
      ok
    rescue
      false
    end
  )

  describe "Voyager macOS — accessibility + behavior (AX tree)" do
    unless DISPLAY_OK
      pending "Sign-in + gallery accessibility & behavior — #{VoyagerAX.bin_present? ? VoyagerAX::NO_DISPLAY : "bin/voyager not built (make macos)"}"
    else
      # ---- Sign In ----------------------------------------------------------
      it "Sign In: interactive controls are AX-discoverable AND labeled" do
        VoyagerAX.with_app("voyager-sign-in") do |app|
          win = VoyagerAX.content_window(app).not_nil!

          submit = VoyagerAX.find_in(win, identifier: "voyager-sign-in-submit") ||
                   VoyagerAX.find_in(win, role: "AXButton", label: "Sign in")
          submit.should_not be_nil
          # Accessibility: VoiceOver needs a non-empty label/title.
          VoyagerAX.display_text(submit).empty?.should be_false

          email = VoyagerAX.find_in(win, identifier: "voyager-sign-in-email")
          email.should_not be_nil
          password = VoyagerAX.find_in(win, identifier: "voyager-sign-in-password")
          password.should_not be_nil
        end
      end

      it "Sign In: typed credentials reach Todos (behavior)" do
        VoyagerAX.with_app("voyager-sign-in") do |app|
          win = VoyagerAX.content_window(app).not_nil!

          email = VoyagerAX.find_in(win, identifier: "voyager-sign-in-email").not_nil!
          email.set_value("captain@voyager.app")
          password = VoyagerAX.find_in(win, identifier: "voyager-sign-in-password").not_nil!
          password.set_value("hunter2")
          submit = (VoyagerAX.find_in(win, identifier: "voyager-sign-in-submit") ||
                    VoyagerAX.find_in(win, role: "AXButton", label: "Sign in")).not_nil!
          submit.click
          sleep(0.6.seconds)

          # Post-sign-in the host rerenders to Todos; re-fetch the window and
          # assert the Todos "Add" control is now present (proves the typed
          # credentials reached the controller and ReplaceRoot(:todos) fired).
          todos_win = VoyagerAX.content_window(app).not_nil!
          add = VoyagerAX.find_in(todos_win, identifier: "voyager-todos-add") ||
                VoyagerAX.find_in(todos_win, role: "AXButton", label: "Add todo")
          add.should_not be_nil
        end
      end

      # ---- Component Gallery ------------------------------------------------
      it "Gallery: a representative interactive widget per family is labeled" do
        VoyagerAX.with_app("voyager-component-gallery") do |app|
          win = VoyagerAX.content_window(app).not_nil!
          # One representative per family (test_id -> AX identifier). Presence
          # in the AX tree proves the macOS renderer emitted a real native
          # control discoverable by assistive tech.
          %w[
            voyager-gallery-live-tap-button
            voyager-gallery-live-toggle
            voyager-gallery-live-segmented
            voyager-gallery-live-stepper
            voyager-gallery-live-tabview
            voyager-gallery-live-color
            voyager-gallery-textfield
            voyager-gallery-combobox
          ].each do |id|
            VoyagerAX.find_in(win, identifier: id).should_not(be_nil, "AX element '#{id}' not discoverable")
          end
        end
      end

      it "Gallery: tapping 'Tap me' increments the Taps readout (behavior)" do
        VoyagerAX.with_app("voyager-component-gallery") do |app|
          win = VoyagerAX.content_window(app).not_nil!
          readout = VoyagerAX.find_in(win, identifier: "voyager-gallery-live-taps").not_nil!
          VoyagerAX.display_text(readout).should eq("Taps: 0")

          button = VoyagerAX.find_in(win, identifier: "voyager-gallery-live-tap-button").not_nil!
          button.click
          sleep(0.4.seconds)

          readout2 = VoyagerAX.find_in(VoyagerAX.content_window(app).not_nil!,
            identifier: "voyager-gallery-live-taps").not_nil!
          VoyagerAX.display_text(readout2).should eq("Taps: 1")
        end
      end
    end
  end
{% end %}
