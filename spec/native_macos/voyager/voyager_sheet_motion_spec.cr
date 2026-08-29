{% if flag?(:macos) %}
  require "./voyager_ax_support"

  # ===========================================================================
  # Usability bar U4/U6 + value-fidelity — Sheet present → gated Save → dismiss.
  #
  # WHY THIS SPEC EXISTS. A `UI::Sheet` that opened/closed nearly instantly was
  # once marked PASSING because validation only checked STATIC screenshots of the
  # *open* state. This spec is the missing BEHAVIOR test: it drives the REAL
  # editor sheet over the macOS accessibility tree and asserts the user-observable
  # outcomes — the sheet presents, its primary action is correctly GATED on real
  # input (a value-fidelity check, per the SecureField Definition-of-Done lesson),
  # and a visible affordance dismisses it (U6) leaving the sheet gone (U4).
  #
  # WHAT THIS SPEC DELIBERATELY DOES NOT DO: assert the present *animation timing*
  # by sampling AX geometry over time. That approach was tried and proven
  # unreliable — the macOS AX tree does NOT expose a SwiftUI `.sheet`'s transient
  # present frames (the sheet body reports a degenerate ~1pt frame at both t≈0 and
  # t≈500ms). The motion PERCEPTIBILITY guarantee (U1: present ≥0.2s floor, never
  # an instant snap; reduce-motion → crossfade) is therefore enforced + proven at
  # the SwiftUI layer (SheetFacade.resolvePresentationAnimation, swift-build-
  # verified) and via the recorded motion-evidence-class artifact reviewed by a
  # human/agent (audit_evidence.py §1.3) — NOT by this AX spec. Asserting only
  # what AX can honestly observe keeps this test from becoming the next false-pass.
  #
  # SURFACE UNDER TEST. The Voyager Todos editor sheet
  # (`samples/.../screens/todos_screen.cr`): tapping "Add" (voyager-todos-add)
  # sets `pending_editor_todo_id` → the screen rebuilds with a presented
  # `UI::Sheet` (test_id voyager-todos-editor-sheet, body
  # voyager-todos-editor-sheet-body) containing the editor form. The "Save" button
  # (voyager-editor-sheet-save) starts DISABLED for a new todo
  # (`save_btn.disabled = seed_title.strip.empty?`) and is re-enabled by the title
  # field's on_change — that gate is exactly the value-fidelity behavior we prove.
  #
  # DISPLAY REQUIREMENT (same as the voyager AX suite). AX interaction needs a
  # logged-in GUI (Aqua) session with a real on-screen AXWindow; in a headless
  # context this PENDs with guidance rather than false-failing.
  #
  # Run (in a desktop session, after `make -C samples/initiative-cross-platform-ui-voyager macos`):
  #   crystal-alpha spec spec/native_macos/voyager/voyager_sheet_motion_spec.cr -Dmacos \
  #     --link-flags="-framework ApplicationServices -framework CoreFoundation"
  # ===========================================================================

  module VoyagerSheetMotion
    extend self

    # The editor sheet body node, present only while the sheet is shown.
    def sheet_body(win : UI::AXTest::Element) : UI::AXTest::Element?
      VoyagerAX.find_in(win, identifier: "voyager-todos-editor-sheet-body") ||
        VoyagerAX.find_in(win, identifier: "voyager-todos-editor-sheet")
    end
  end

  # Probe the display ONCE — launch todos, confirm a real AXWindow exists.
  SHEET_DISPLAY_OK = VoyagerAX.bin_present? && (
    begin
      ok = false
      VoyagerAX.with_app("voyager-todos") { |app| ok = !VoyagerAX.content_window(app).nil? }
      ok
    rescue
      false
    end
  )

  describe "Voyager macOS — editor Sheet present / gated Save / dismiss (U4/U6 + value-fidelity)" do
    unless SHEET_DISPLAY_OK
      pending "Editor sheet behavior — #{VoyagerAX.bin_present? ? VoyagerAX::NO_DISPLAY : "bin/voyager not built (make macos)"}"
    else
      it "presents on Add; Save enables only after a real title is typed; Cancel dismisses" do
        VoyagerAX.with_app("voyager-todos") do |app|
          win = VoyagerAX.content_window(app).not_nil!

          # Precondition: the editor sheet is NOT present before we open it.
          VoyagerSheetMotion.sheet_body(win).should be_nil

          add = (VoyagerAX.find_in(win, identifier: "voyager-todos-add") ||
                 VoyagerAX.find_in(win, role: "AXButton", label: "Add a new todo")).not_nil!
          add.click
          sleep(0.6.seconds) # let the present settle (bounded by the Swift U1 ceiling)

          # PRESENT (U4): the sheet body + its controls are now discoverable.
          win2 = VoyagerAX.content_window(app).not_nil!
          VoyagerSheetMotion.sheet_body(win2).should_not be_nil

          save = (VoyagerAX.find_in(win2, identifier: "voyager-editor-sheet-save") ||
                  VoyagerAX.find_in(win2, role: "AXButton", label: "Save")).not_nil!
          title = (VoyagerAX.find_in(win2, identifier: "voyager-editor-sheet-title") ||
                   VoyagerAX.find_in(win2, role: "AXTextField")).not_nil!

          # VALUE-FIDELITY GATE: Save starts DISABLED for a new todo (empty title)
          # and must enable ONLY after a real title is typed. set_value writes the
          # displayed text without firing the change binding, so use REAL
          # keystrokes (the SecureField lesson) — that is what re-enables Save.
          save.enabled?.should be_false
          title.click
          sleep(0.2.seconds)
          UI::AXTest::Keys.type("Buy milk")
          sleep(0.4.seconds)

          save_after = (VoyagerAX.find_in(VoyagerAX.content_window(app).not_nil!,
            identifier: "voyager-editor-sheet-save") ||
                        VoyagerAX.find_in(win2, role: "AXButton", label: "Save")).not_nil!
          save_after.enabled?.should be_true # the typed title reached the gate

          # DISMISS (U6: a visible affordance must exist; U4: assert it left).
          cancel = (VoyagerAX.find_in(VoyagerAX.content_window(app).not_nil!,
            identifier: "voyager-editor-sheet-cancel") ||
                    VoyagerAX.find_in(win2, role: "AXButton", label: "Cancel")).not_nil!
          cancel.click
          sleep(0.6.seconds)
          gone_win = VoyagerAX.content_window(app).not_nil!
          VoyagerSheetMotion.sheet_body(gone_win).should be_nil
        end
      end
    end
  end
{% end %}
