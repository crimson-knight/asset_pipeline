{% if flag?(:macos) %}
  # One-off motion-evidence capture (NOT a permanent _spec.cr): drives the
  # editor sheet present and captures a pixel triptych so a human/agent can SEE
  # the slide (AX cannot observe a SwiftUI present animation — guide §1.4). Run:
  #   crystal-alpha spec spec/native_macos/voyager/_sheet_motion_capture.cr -Dmacos \
  #     --link-flags="-framework ApplicationServices -framework CoreFoundation"
  require "./voyager_ax_support"

  describe "Sheet present — motion-evidence triptych" do
    it "captures baseline → early → mid → settled during the present" do
      VoyagerAX.with_app("voyager-todos") do |app|
        win = VoyagerAX.content_window(app).not_nil!
        add = VoyagerAX.find_in(win, identifier: "voyager-todos-add").not_nil!

        UI::AXTest::Screenshot.capture("/tmp/sheet_t0_baseline.png") # no sheet
        add.click
        UI::AXTest::Screenshot.capture("/tmp/sheet_t1_early.png")    # ~0-200ms into present
        sleep(0.18.seconds)
        UI::AXTest::Screenshot.capture("/tmp/sheet_t2_mid.png")      # ~mid present
        sleep(0.5.seconds)
        UI::AXTest::Screenshot.capture("/tmp/sheet_t3_settled.png")  # fully presented
        true.should be_true
      end
    end
  end
{% end %}
