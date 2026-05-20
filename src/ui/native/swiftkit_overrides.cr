require "../view"
require "../views/button"

module UI
  module Native
    # SwiftKit override populator.
    #
    # Phase 3's renderer migration moves overrides population OUT of each
    # visit method and INTO this module so the populator can be exercised
    # in plain `crystal spec` runs (no `-Dmacos` / `-Dios` flag, no
    # AppKit / UIKit / SwiftKit frameworks linked).
    #
    # The contract:
    #
    #   `Populator.populate_button(overrides_ptr, view)` walks the
    #   `UI::Button`'s common-view properties (background, corner_radius,
    #   padding, opacity, hidden, border_*, shadow_*, min/max_*,
    #   accessibility_label, test_id) PLUS the button-specific properties
    #   (role, style, disabled, symbol) and ONLY sends the setter when
    #   the property differs from its type default. This is the
    #   "default-detection" invariant — implementation.md §11 calls it
    #   "the single most important behavioral invariant of phase 3."
    #
    #   The populator does not call `objc_msgSend` directly. It calls
    #   into an injected `Sender` interface. In production builds the
    #   sender is `LibObjCBridge`-backed (renderer integration); in spec
    #   builds it is `FakeLibObjCBridge`-backed and merely records each
    #   setter invocation.
    #
    # This indirection lets the renderer's visit method shrink from
    # ~230 lines to ~5: `populate_button(ovr, view); make_button(...)`.
    module Populator
      # Setter sender interface. The renderer supplies a `LibObjCBridge`-
      # backed implementation; specs supply a `FakeLibObjCBridge`-backed
      # one. Methods are deliberately String-typed for the spec side —
      # the production sender stringifies its args once at the boundary
      # and passes the real `Void*` / `Float64` / `String` through.
      abstract class Sender
        # Set an `NSColor?`/`UIColor?` field. `nil` means leave unset.
        abstract def set_color(target : String, setter : Symbol, color : UI::Color?)
        # Set an `NSNumber?` field from a `Float64?`. `nil` skips.
        abstract def set_number(target : String, setter : Symbol, value : Float64?)
        # Set an `NSNumber?` field from a `Bool?`. `nil` skips.
        abstract def set_bool(target : String, setter : Symbol, value : Bool?)
        # Set an `NSString?` field. `nil` skips.
        abstract def set_string(target : String, setter : Symbol, value : String?)
      end

      # Populate an `APSKButtonOverrides` instance from a `UI::Button`.
      #
      # The `target` parameter is the Crystal-side identifier for the
      # overrides object (in production it's a stringified pointer; in
      # specs it's the sentinel from `FakeLibObjCBridge.next_sentinel_pointer`).
      def self.populate_button(target : String, view : UI::Button, sender : Sender)
        # ---- common ViewOverrides fields ---------------------------------
        sender.set_color(target, :setBackgroundColor, view.background)

        cr = view.corner_radius
        sender.set_number(target, :setCornerRadius, cr == 0.0 ? nil : cr)

        pad = view.padding
        sender.set_number(target, :setPaddingTop,      pad.top      == 0.0 ? nil : pad.top)
        sender.set_number(target, :setPaddingLeading,  pad.leading  == 0.0 ? nil : pad.leading)
        sender.set_number(target, :setPaddingBottom,   pad.bottom   == 0.0 ? nil : pad.bottom)
        sender.set_number(target, :setPaddingTrailing, pad.trailing == 0.0 ? nil : pad.trailing)

        op = view.opacity
        sender.set_number(target, :setOpacity, op == 1.0 ? nil : op)

        sender.set_bool(target, :setHidden, view.hidden ? true : nil)

        bw = view.border_width
        sender.set_number(target, :setBorderWidth, bw == 0.0 ? nil : bw)
        sender.set_color(target, :setBorderColor, view.border_color)

        sr = view.shadow_radius
        sender.set_number(target, :setShadowRadius, sr == 0.0 ? nil : sr)
        sender.set_color(target, :setShadowColor, view.shadow_color)
        ox = view.shadow_offset_x
        oy = view.shadow_offset_y
        sender.set_number(target, :setShadowOffsetX, ox == 0.0 ? nil : ox)
        sender.set_number(target, :setShadowOffsetY, oy == 0.0 ? nil : oy)

        sender.set_number(target, :setMinWidth,  view.minimum_width)
        sender.set_number(target, :setMinHeight, view.minimum_height)
        sender.set_number(target, :setMaxWidth,  view.maximum_width)
        sender.set_number(target, :setMaxHeight, view.maximum_height)

        sender.set_string(target, :setAccessibilityIdentifier, view.test_id)
        sender.set_string(target, :setAccessibilityLabel,      view.accessibility_label)

        # ---- Button-specific overrides -----------------------------------
        # Role: :default is the type default; anything else surfaces a
        # role string the Swift facade switches on.
        role_str = view.role == :default ? nil : view.role.to_s
        sender.set_string(target, :setRole, role_str)

        # Style: only emit when non-Default. The Swift facade falls back
        # to SwiftUI's `.automatic` style when role is nil.
        style_str = case view.style
                    when UI::ButtonStyle::Prominent  then "prominent"
                    when UI::ButtonStyle::Tinted     then "tinted"
                    when UI::ButtonStyle::Bordered   then "bordered"
                    when UI::ButtonStyle::Borderless then "borderless"
                    else                                  nil
                    end
        sender.set_string(target, :setStyle, style_str)

        # Disabled: false is the type default.
        sender.set_bool(target, :setDisabled, view.disabled ? true : nil)

        # SF Symbol leading glyph.
        sender.set_string(target, :setSymbolName, view.symbol)
      end
    end
  end
end
