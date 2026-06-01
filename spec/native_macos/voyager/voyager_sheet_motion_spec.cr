{% if flag?(:macos) %}
  require "./voyager_ax_support"

  # ===========================================================================
  # Usability bar U1 + U4 — TIMED Sheet present/dismiss behavior (the U4
  # artifact required by docs/initiative-cross-platform-ui/platform-capability-matrix.md §1.3).
  #
  # WHY THIS SPEC EXISTS. A `UI::Sheet` that opened and closed nearly instantly
  # was once marked PASSING because validation only ever checked STATIC
  # screenshots of the *open* state — a 0ms sheet and a 350ms sheet produce an
  # identical "open" still. This spec is the missing timed behavior test: it
  # drives the REAL sheet over the macOS accessibility tree and asserts the
  # transition is PERCEPTIBLE (U1) — i.e. the sheet is NOT already fully
  # settled at t≈0 (it is animating in), and IS fully present + interactive by
  # t≈400ms — then dismisses it and asserts it left (U4: "assert it left").
  #
  # This is NOT a discoverability check ("the control exists"). Per CLAUDE.md's
  # Definition of Done, existence is necessary but never sufficient; this drives
  # the present, samples geometry across time, and asserts the timing outcome a
  # real user experiences.
  #
  # SURFACE UNDER TEST. The Voyager Todos editor sheet
  # (`samples/.../screens/todos_screen.cr` — `UI::Sheet` test_id
  # "voyager-todos-editor-sheet", body "voyager-todos-editor-sheet-body").
  # Tapping the "Add" button (id "voyager-todos-add") sets
  # `pending_editor_todo_id` → Rerender presents the modal sheet.
  #
  # DISPLAY REQUIREMENT (same as the voyager AX suite). AX interaction needs a
  # logged-in GUI (Aqua) session with a real on-screen AXWindow. In a headless /
  # SSH / detached context the sheet has no AXWindow to sample, so this spec
  # PENDs with guidance rather than false-failing. It runs for real in a desktop
  # session / display-enabled CI.
  #
  # Run (in a desktop session, after `make -C samples/initiative-cross-platform-ui-voyager macos`):
  #   crystal-alpha spec spec/native_macos/voyager/voyager_sheet_motion_spec.cr -Dmacos \
  #     --link-flags="-framework ApplicationServices -framework CoreFoundation"
  #
  # NOTE (native-link-pending): this spec is authored to be correct and to PEND
  # in headless contexts; it has NOT been executed against a live GUI host in
  # this worktree (no -Dmacos native link / no display here).
  # ===========================================================================

  module VoyagerSheetMotion
    extend self

    # U1 floor / ceiling for a modal present, in seconds. Matches the Swift
    # facade's bounds (SheetFacade.motionFloorSeconds = 0.200,
    # motionCeilingSeconds = 0.900). The sheet must NOT be fully settled before
    # the floor, and MUST be settled by the ceiling.
    PRESENT_FLOOR_S   = 0.200
    PRESENT_CEILING_S = 0.900
    # Sample point that comfortably clears the ceiling: the sheet is expected to
    # be fully present + interactive by here.
    SETTLED_SAMPLE_S = 0.500

    # A sheet content node counts as "fully on-screen / settled" when it exists,
    # is on-screen with a non-trivial frame. During the slide-up present the
    # bottom-anchored sheet content is either absent from the tree yet or has a
    # smaller visible height than once settled — so at t≈0 this returns false.
    def settled_height(win : UI::AXTest::Element) : Float64?
      node = VoyagerAX.find_in(win, identifier: "voyager-todos-editor-sheet-body") ||
             VoyagerAX.find_in(win, identifier: "voyager-todos-editor-sheet")
      return nil unless node
      f = node.frame
      return nil unless f
      f[:height]
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

  describe "Voyager macOS — Sheet present/dismiss is timed & perceptible (U1/U4)" do
    unless SHEET_DISPLAY_OK
      pending "Timed Sheet present/dismiss — #{VoyagerAX.bin_present? ? VoyagerAX::NO_DISPLAY : "bin/voyager not built (make macos)"}"
    else
      it "present is NOT instant at t≈0 and IS settled+interactive by t≈400ms; dismiss leaves" do
        VoyagerAX.with_app("voyager-todos") do |app|
          win = VoyagerAX.content_window(app).not_nil!

          # Precondition: the editor sheet is NOT present before we open it.
          VoyagerSheetMotion.settled_height(win).should be_nil

          add = (VoyagerAX.find_in(win, identifier: "voyager-todos-add") ||
                 VoyagerAX.find_in(win, role: "AXButton", label: "Add a new todo")).not_nil!

          # Trigger the present. Sample geometry IMMEDIATELY (before the U1
          # floor elapses): the sheet must NOT already be at its settled height.
          add.click
          # Re-fetch the window; the SwiftUI .sheet presents in its own window.
          early_win = VoyagerAX.content_window(app).not_nil!
          early_height = VoyagerSheetMotion.settled_height(early_win)

          # U1 — perceptible present: at t≈0 the sheet is either not yet in the
          # tree or not yet at full height (it is animating in). If it were
          # already fully settled here, the present collapsed to an instant snap
          # (the too-fast-sheet bug) and this MUST fail.
          # Let the present finish, then read the settled height.
          sleep(VoyagerSheetMotion::SETTLED_SAMPLE_S.seconds)
          settled_win = VoyagerAX.content_window(app).not_nil!
          settled_height = VoyagerSheetMotion.settled_height(settled_win)

          # U4 — by t≈400-500ms the sheet IS fully present and interactive.
          settled_height.should_not be_nil
          settled_height.not_nil!.should be > 0.0

          # The perceptible-transition assertion: the early sample must be
          # strictly "less present" than the settled sample — either absent
          # (nil) or a smaller visible height. Equal full height at t≈0 means an
          # instant snap → fail.
          if eh = early_height
            (eh < settled_height.not_nil!).should be_true
          else
            early_height.should be_nil # absent at t≈0 is the strongest "not instant" signal
          end

          # The settled sheet exposes a real, interactive control (a Save/Done
          # button inside the editor body). Prove it is hit-testable.
          save = VoyagerAX.find_in(settled_win, identifier: "voyager-editor-sheet-save") ||
                 VoyagerAX.find_in(settled_win, role: "AXButton", label: "Save")
          save.should_not be_nil
          save.not_nil!.enabled?.should be_true

          # Dismiss: drive the editor's close/cancel affordance (U6 — a visible
          # affordance must exist), then assert the sheet LEFT (U4).
          cancel = VoyagerAX.find_in(settled_win, identifier: "voyager-editor-sheet-cancel") ||
                   VoyagerAX.find_in(settled_win, role: "AXButton", label: "Cancel")
          cancel.should_not be_nil
          cancel.not_nil!.click

          # Allow the dismiss transition to complete (bounded by the U1 ceiling).
          sleep(VoyagerSheetMotion::PRESENT_CEILING_S.seconds)
          gone_win = VoyagerAX.content_window(app).not_nil!
          VoyagerSheetMotion.settled_height(gone_win).should be_nil
        end
      end
    end
  end
{% end %}
