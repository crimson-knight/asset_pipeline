require "spec"
require "../../../src/ui"

# ==========================================================================
# ZStack alignment — AppKit Auto Layout geometry specs
#
# Regression gate for the kit bug where the AppKit renderer's visit(UI::ZStack)
# unconditionally pinned EVERY child to all four superview edges (required
# priority), IGNORING ZStack#alignment. A fixed-size child was therefore
# force-stretched to fill the whole container, so an aligned, fixed-size overlay
# child (slide-in drawer panel, toast, badge, FAB) was impossible.
#
# These build a real NSView hierarchy through the ObjC bridge, run a layout
# pass, and assert resolved child frames:
#   • Leading + fixed width  → child keeps its width, pinned to the LEFT (the fix)
#   • Leading + no width      → child still FILLS (soft fill edge beats hugging)
#   • Center (legacy edges)   → child fills even with a fixed width (unchanged)
#
# Native-only: the AppKit renderer + Auto Layout are macOS-runtime; the bridge
# symbols are linked by the `make test-macos` lane (objc_bridge.o + frameworks).
# ==========================================================================

{% if flag?(:macos) %}
  @[Link("objc")]
  lib LibObjCRaw
    fun objc_getClass(name : UInt8*) : Void*
    fun sel_registerName(name : UInt8*) : Void*
  end

  private def new_nsview : Void*
    cls = LibObjCRaw.objc_getClass("NSView")
    allocated = UI::AppKit::LibObjCBridge.objc_send(cls, LibObjCRaw.sel_registerName("alloc"))
    UI::AppKit::LibObjCBridge.objc_send(allocated, LibObjCRaw.sel_registerName("init"))
  end

  private def make_rect(x : Float64, y : Float64, w : Float64, h : Float64) : UI::AppKit::LibObjCBridge::CGRect
    r = UI::AppKit::LibObjCBridge::CGRect.new
    r.x = x; r.y = y; r.width = w; r.height = h
    r
  end

  # Build a 480x800 parent NSView with one child pinned via `pin`, run layout,
  # and return the child's resolved frame. `width` (if > 0) fixes the child width.
  private def child_frame_after_layout(width : Float64, &pin : Void*, Void* ->) : UI::AppKit::LibObjCBridge::CGRect
    parent = new_nsview
    UI::AppKit::LibObjCBridge.objc_set_frame(parent, make_rect(0.0, 0.0, 480.0, 800.0))
    child = new_nsview
    UI::AppKit::LibObjCBridge.objc_add_subview(parent, child)
    UI::AppKit::LibObjCBridge.objc_constrain_width(child, width) if width > 0.0
    pin.call(parent, child)
    UI::AppKit::LibObjCBridge.objc_layout_now(parent)
    UI::AppKit::LibObjCBridge.objc_get_frame(child)
  end

  describe "ZStack alignment (AppKit Auto Layout)" do
    it "Leading + fixed width: child keeps its width and pins to the left (the fix)" do
      fr = child_frame_after_layout(360.0) do |parent, child|
        UI::AppKit::LibObjCBridge.objc_pin_child_aligned(parent, child, 0) # leading
      end
      fr.width.should be_close(360.0, 1.0) # NOT stretched to 480
      fr.x.should be_close(0.0, 1.0)        # pinned to the leading (left) edge
      fr.height.should be_close(800.0, 1.0) # cross-axis still fills
    end

    it "Trailing + fixed width: child keeps its width and pins to the right" do
      fr = child_frame_after_layout(360.0) do |parent, child|
        UI::AppKit::LibObjCBridge.objc_pin_child_aligned(parent, child, 1) # trailing
      end
      fr.width.should be_close(360.0, 1.0)
      fr.x.should be_close(120.0, 1.0) # 480 - 360, pinned to the trailing edge
    end

    it "Leading + no width constraint: child still FILLS (soft fill beats hugging)" do
      fr = child_frame_after_layout(0.0) do |parent, child|
        UI::AppKit::LibObjCBridge.objc_pin_child_aligned(parent, child, 0) # leading
      end
      fr.width.should be_close(480.0, 1.0)
      fr.x.should be_close(0.0, 1.0)
    end

    it "Center (legacy edges pin): unconstrained child fills both axes (zero-regression)" do
      fr = child_frame_after_layout(0.0) do |parent, child|
        UI::AppKit::LibObjCBridge.objc_pin_child_to_superview_edges(parent, child)
      end
      # Center keeps the legacy all-edges-required pin on purpose: every existing
      # full-bleed hero (meditation backgrounds etc.) is an unconstrained ZStack
      # child that depends on this fill. The alignment fix leaves it untouched.
      fr.width.should be_close(480.0, 1.0)
      fr.height.should be_close(800.0, 1.0)
      fr.x.should be_close(0.0, 1.0)
    end
  end
{% end %}
