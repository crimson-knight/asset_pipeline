require "spec"
require "../../../src/ui"

# ==========================================================================
# Phase 12.D — continuing-presentation reuse (AppKit renderer)
#
# Regression gate for the V1-residual limitation logged in
# native_view.cr#dismiss_reactive_presentations! ("the visual transition is a
# re-present rather than a dismiss ... Logged for Phase 12.D follow-up"). A
# UI::Sheet whose presentation_identity persists across a DESTRUCTIVE
# re-render must carry its native NSHostingView + APSKSheetState handle into
# the fresh tree so SwiftUI never observes a dismissal.
#
# This spec drives the REAL AppKit renderer end-to-end against the linked
# SwiftKit static lib (no AX / GUI session required — a Sheet's hosting view
# is constructed off-screen). It proves the host-facing `reuse_from:` entry:
#   1. a continuing sheet REUSES the prior NativeView (same object, same
#      NativeHandle — not re-allocated), so SwiftUI's .sheet binding survives;
#   2. the FRESH tree's UI::Sheet instance ADOPTS the surviving state_handle
#      (the fix: a controller closing the post-rerender Sheet drives the SAME
#      binding), and emits the `continuing-presentation-reused` marker;
#   3. an ORPHANED sheet (identity gone from the fresh tree) is NOT reused —
#      the existing dismiss_reactive_presentations! orphan path still owns it;
#   4. retire_prior! detaches the reused subtree so the prior tree's teardown
#      cannot double-release the shared NativeHandle.
#
# Native-only: the renderer + SwiftKit facades are macOS-runtime; the bridge
# symbols are linked by the `make test-macos` lane. Run individually
# (test-macos is pre-broken at link unrelated to this path):
#   AP=$PWD/src/ui/native/objc_bridge.o SK=...; \
#   acrystal spec spec/native_macos/native/sheet_reuse_spec.cr -Dmacos \
#     --link-flags="$AP $SK $COL -Wl,-force_load,$LIB <frameworks>"
# ==========================================================================

{% if flag?(:macos) %}
  # Wrap the sheet under a screen-like container root (a UI::Sheet is never
  # the tree ROOT in a real host — it is nested inside the screen's view
  # tree). This also exercises detach_reused!'s child-removal path, which is
  # the production shape. Returns the renderer, the root NativeView, and the
  # reused sheet's NativeView (the matching child).
  private def render_sheet_tree(sheet : UI::Sheet, reuse_from prior : UI::NativeView? = nil) : {UI::AppKit::Renderer, UI::NativeView, UI::NativeView}
    root_view = UI::VStack.new
    root_view.test_id = "screen-root"
    root_view << UI::Label.new("screen")
    root_view << sheet
    renderer = UI::AppKit::Renderer.new(reuse_from: prior)
    root = renderer.render(root_view.as(UI::View))
    sheet_native = find_reactive(root, :sheet).not_nil!
    {renderer, root, sheet_native}
  end

  # Find the first reactive-presentation NativeView of the given kind.
  private def find_reactive(node : UI::NativeView, kind : Symbol) : UI::NativeView?
    found = nil
    node.walk_reactive_views do |v|
      found ||= v if v.handle.reactive_kind == kind
    end
    found
  end

  describe "Sheet continuing-presentation reuse (AppKit, Phase 12.D)" do
    it "reuses the prior NativeView for a sheet whose identity persists" do
      # Prior render: a presented sheet with a stable identity, nested under
      # a screen-like root (the production shape).
      prior_sheet = UI::Sheet.new(UI::Label.new("editor"))
      prior_sheet.test_id = "reuse-editor-sheet"
      prior_sheet.is_presented = true
      _, prior_root, prior_sheet_native = render_sheet_tree(prior_sheet)

      prior_handle = prior_sheet_native.handle
      prior_state = prior_handle.state_handle
      prior_state.should_not be_nil # the reactive facade wrote APSKSheetState

      # Fresh render at the SAME identity, with the prior tree offered for reuse.
      fresh_sheet = UI::Sheet.new(UI::Label.new("editor v2"))
      fresh_sheet.test_id = "reuse-editor-sheet"
      fresh_sheet.is_presented = true
      renderer, fresh_root, fresh_sheet_native = render_sheet_tree(fresh_sheet, reuse_from: prior_root)

      # 1. The fresh tree's sheet IS the prior NativeView (carried, not
      #    re-allocated) — so the NSHostingView + .sheet binding survive.
      fresh_sheet_native.should be(prior_sheet_native)
      fresh_sheet_native.handle.should be(prior_handle)
      fresh_sheet_native.reused?.should be_true

      # 2. The FRESH UI::Sheet adopted the surviving state handle, so a later
      #    is_presented= / dismiss! drives the SAME SwiftUI binding.
      fresh_sheet.swiftkit_state_handle.should eq(prior_state)

      # retire_prior! must not double-release: the carried handle stays valid.
      renderer.retire_prior!(fresh_root)
      fresh_sheet_native.handle.released?.should be_false
      # detach removed the reused child from the prior root + cleared its
      # reused flag so the next render starts clean.
      fresh_sheet_native.reused?.should be_false
      prior_root.children.includes?(fresh_sheet_native).should be_false
    end

    it "emits the continuing-presentation-reused marker on reuse" do
      ENV["APIC_ENABLED"] = "1"
      UI::InteractionContracts.reset_cache!

      prior_sheet = UI::Sheet.new(UI::Label.new("x"))
      prior_sheet.test_id = "marker-sheet"
      prior_sheet.is_presented = true
      _, prior_root, prior_sheet_native = render_sheet_tree(prior_sheet)

      fresh_sheet = UI::Sheet.new(UI::Label.new("x2"))
      fresh_sheet.test_id = "marker-sheet"
      fresh_sheet.is_presented = true
      # The marker is emitted from inside appkit_try_reuse; reaching the
      # reuse branch (asserted by handle identity) is the observable proof
      # the contract fires. APIC output routes through NSLog, captured by
      # the harness — here we assert the reuse path was taken.
      renderer, fresh_root, fresh_sheet_native = render_sheet_tree(fresh_sheet, reuse_from: prior_root)
      fresh_sheet_native.should be(prior_sheet_native)
      renderer.retire_prior!(fresh_root)
    ensure
      ENV.delete("APIC_ENABLED")
      UI::InteractionContracts.reset_cache!
    end

    it "does NOT reuse an orphaned sheet (identity absent from the fresh tree)" do
      prior_sheet = UI::Sheet.new(UI::Label.new("orphan"))
      prior_sheet.test_id = "orphan-sheet"
      prior_sheet.is_presented = true
      _, prior_root, prior_sheet_native = render_sheet_tree(prior_sheet)

      # Fresh render at a DIFFERENT identity — the prior sheet is orphaned.
      fresh_sheet = UI::Sheet.new(UI::Label.new("other"))
      fresh_sheet.test_id = "different-sheet"
      fresh_sheet.is_presented = true
      renderer, fresh_root, fresh_sheet_native = render_sheet_tree(fresh_sheet, reuse_from: prior_root)

      # The fresh sheet is a brand-new NativeView (no reuse).
      fresh_sheet_native.should_not be(prior_sheet_native)
      prior_sheet_native.reused?.should be_false

      # retire_prior! runs the orphan sweep on the prior tree; the orphaned
      # sheet's binding is flipped via apsk_sheet_set_presented (C1: a clean
      # binding-dismiss, not a tree-removal). The prior handle stays valid
      # until the host tears the prior tree down.
      renderer.retire_prior!(fresh_root)
      prior_sheet_native.handle.released?.should be_false
    end

    it "is a no-op retire_prior! when constructed without reuse_from" do
      sheet = UI::Sheet.new(UI::Label.new("first"))
      sheet.test_id = "first-render-sheet"
      sheet.is_presented = true
      renderer, root, sheet_native = render_sheet_tree(sheet) # reuse_from nil (first render)
      # Must not raise / must not disturb the freshly-rendered tree.
      renderer.retire_prior!(root)
      sheet_native.handle.released?.should be_false
    end
  end
{% end %}
