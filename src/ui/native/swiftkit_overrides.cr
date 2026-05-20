require "../view"
require "../views/button"
require "../views/label"
require "../views/image"
require "../views/text_field"
require "../views/secure_field"
require "../views/search_field"
require "../views/text_area"
require "../views/text_editor"
require "../views/link_button"
require "../views/icon_button"
require "../views/divider"
require "../views/spacer"
require "../views/toggle"
require "../views/checkbox"
require "../views/radio_group"
require "../views/slider"
require "../views/stepper"
require "../views/segmented_control"
require "../views/picker"
require "../views/date_picker"
require "../views/time_picker"
require "../views/color_picker"
require "./swiftkit_bridge"

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

      # Populate the common `APSKViewOverrides` fields from any `UI::View`.
      #
      # Every per-widget populator calls this helper first, then layers
      # widget-specific setters on top. Keeps each per-widget populator to
      # the minimal "what is unique about THIS widget?" surface.
      #
      # All setters are skipped when the matching property is at its type
      # default — that is the default-detection invariant in §11.
      def self.populate_view_common(target : String, view : UI::View, sender : Sender)
        sender.set_color(target, :setBackgroundColor, view.background)

        cr = view.corner_radius
        sender.set_number(target, :setCornerRadius, cr == 0.0 ? nil : cr)

        pad = view.padding
        sender.set_number(target, :setPaddingTop, pad.top == 0.0 ? nil : pad.top)
        sender.set_number(target, :setPaddingLeading, pad.leading == 0.0 ? nil : pad.leading)
        sender.set_number(target, :setPaddingBottom, pad.bottom == 0.0 ? nil : pad.bottom)
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

        sender.set_number(target, :setMinWidth, view.minimum_width)
        sender.set_number(target, :setMinHeight, view.minimum_height)
        sender.set_number(target, :setMaxWidth, view.maximum_width)
        sender.set_number(target, :setMaxHeight, view.maximum_height)

        sender.set_string(target, :setAccessibilityIdentifier, view.test_id)
        sender.set_string(target, :setAccessibilityLabel, view.accessibility_label)
      end

      # Populate an `APSKButtonOverrides` instance from a `UI::Button`.
      #
      # The `target` parameter is the Crystal-side identifier for the
      # overrides object (in production it's a stringified pointer; in
      # specs it's the sentinel from `FakeLibObjCBridge.next_sentinel_pointer`).
      def self.populate_button(target : String, view : UI::Button, sender : Sender)
        populate_view_common(target, view, sender)

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

      # ---------------------------------------------------------------
      # Group 1 — value display and simple input widgets.
      # ---------------------------------------------------------------

      def self.populate_label(target : String, view : UI::Label, sender : Sender)
        populate_view_common(target, view, sender)
        # Label uses LabelRole::Primary as the type default; only emit when
        # the developer explicitly overrode the role or set a brand colour.
        if view.text_color_role.nil?
          # Brand RGBA path — the Swift facade reads textColor only when
          # textColorRole is nil. Roles are mutually exclusive with raw RGBA.
          c = view.text_color
          sender.set_color(target, :setForegroundColor, c)
        else
          role = view.text_color_role
          unless role == UI::LabelRole::Primary
            sender.set_string(target, :setLabelRole, role.to_s.downcase)
          end
        end

        align = view.text_alignment
        unless align == UI::Alignment::Leading
          sender.set_string(target, :setTextAlignment, align.to_s.downcase)
        end

        nl = view.number_of_lines
        sender.set_number(target, :setNumberOfLines, nl == 0 ? nil : nl.to_f64)
      end

      def self.populate_image(target : String, view : UI::Image, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_color(target, :setForegroundColor, view.tint_color)
        mode = view.content_mode
        unless mode == UI::ContentMode::Fit
          sender.set_string(target, :setContentMode, mode.to_s.downcase)
        end
      end

      def self.populate_text_field(target : String, view : UI::TextField, sender : Sender)
        populate_view_common(target, view, sender)
        # Placeholder + text are positional args on apsk_make_text_field;
        # only secure-entry needs to flow through overrides.
        sender.set_bool(target, :setSecureEntry, view.secure_entry ? true : nil)
        kt = view.keyboard_type
        unless kt == UI::KeyboardType::Default
          sender.set_string(target, :setKeyboardType, kt.to_s.downcase)
        end
      end

      def self.populate_secure_field(target : String, view : UI::SecureField, sender : Sender)
        populate_view_common(target, view, sender)
        # No widget-specific overrides today; the SwiftUI SecureField default
        # already handles obscured entry + accessibility traits.
      end

      def self.populate_search_field(target : String, view : UI::SearchField, sender : Sender)
        populate_view_common(target, view, sender)
        # Default placeholder is "Search"; the Swift facade falls back to
        # localizedSystemSearchLabel when no override surfaces.
        unless view.shows_cancel_button
          sender.set_bool(target, :setShowsCancelButton, false)
        end
      end

      def self.populate_text_area(target : String, view : UI::TextArea, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_bool(target, :setEditable, view.is_editable ? nil : false)
        sender.set_bool(target, :setScrollable, view.is_scrollable ? nil : false)
        if ll = view.line_limit
          sender.set_number(target, :setLineLimit, ll.to_f64)
        end
      end

      def self.populate_text_editor(target : String, view : UI::TextEditor, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_bool(target, :setEditable, view.is_editable ? nil : false)
        if sh = view.syntax_highlighting
          sender.set_string(target, :setSyntaxHighlighting, sh.to_s)
        end
      end

      def self.populate_link_button(target : String, view : UI::LinkButton, sender : Sender)
        populate_view_common(target, view, sender)
        # No widget-specific overrides — label + url are positional.
      end

      def self.populate_icon_button(target : String, view : UI::IconButton, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_color(target, :setForegroundColor, view.tint_color)
        sender.set_number(target, :setIconSize, view.icon_size == 24.0 ? nil : view.icon_size)
        sender.set_bool(target, :setDisabled, view.disabled ? true : nil)
        sender.set_string(target, :setLabel, view.label)
      end

      def self.populate_divider(target : String, view : UI::Divider, sender : Sender)
        populate_view_common(target, view, sender)
        # Divider's tint default is hard-coded grey; only surface a colour
        # when it has been explicitly set (cannot detect — emit always).
        sender.set_color(target, :setForegroundColor, view.color)
        sender.set_number(target, :setThickness, view.thickness == 1.0 ? nil : view.thickness)
        # orientation is :horizontal by default.
        unless view.orientation == :horizontal
          sender.set_string(target, :setOrientation, view.orientation.to_s)
        end
      end

      def self.populate_spacer(target : String, view : UI::Spacer, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_number(target, :setMinLength, view.min_length == 0.0 ? nil : view.min_length)
      end

      # ---------------------------------------------------------------
      # Group 2 — selection and form controls.
      # ---------------------------------------------------------------

      def self.populate_toggle(target : String, view : UI::Toggle, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_color(target, :setForegroundColor, view.tint_color)
        sender.set_bool(target, :setDisabled, view.disabled ? true : nil)
        unless view.style == UI::ToggleStyle::Switch
          sender.set_string(target, :setToggleStyle, view.style.to_s.downcase)
        end
      end

      def self.populate_checkbox(target : String, view : UI::Checkbox, sender : Sender)
        populate_view_common(target, view, sender)
      end

      def self.populate_radio_group(target : String, view : UI::RadioGroup, sender : Sender)
        populate_view_common(target, view, sender)
      end

      def self.populate_slider(target : String, view : UI::Slider, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_color(target, :setForegroundColor, view.tint_color)
        sender.set_number(target, :setStep, view.step == 0.0 ? nil : view.step)
      end

      def self.populate_stepper(target : String, view : UI::Stepper, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_number(target, :setStep, view.step_value == 1.0 ? nil : view.step_value)
        sender.set_bool(target, :setWraps, view.wraps ? true : nil)
      end

      def self.populate_segmented_control(target : String, view : UI::SegmentedControl, sender : Sender)
        populate_view_common(target, view, sender)
      end

      def self.populate_picker(target : String, view : UI::Picker, sender : Sender)
        populate_view_common(target, view, sender)
        unless view.style == UI::PickerStyle::Menu
          sender.set_string(target, :setPickerStyle, view.style.to_s.downcase)
        end
      end

      def self.populate_date_picker(target : String, view : UI::DatePicker, sender : Sender)
        populate_view_common(target, view, sender)
        unless view.mode == UI::DatePickerMode::Date
          sender.set_string(target, :setDatePickerMode, view.mode.to_s.downcase)
        end
      end

      def self.populate_time_picker(target : String, view : UI::TimePicker, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_bool(target, :setShows24Hour, view.shows_24_hour ? true : nil)
        sender.set_number(target, :setMinuteInterval, view.minute_interval == 1 ? nil : view.minute_interval.to_f64)
      end

      def self.populate_color_picker(target : String, view : UI::ColorPicker, sender : Sender)
        populate_view_common(target, view, sender)
        sender.set_bool(target, :setSupportsOpacity, view.supports_alpha ? true : nil)
      end

      # Symbol-to-ObjC-selector helper. The Populator emits setter
      # symbols without a trailing colon (`:setStyle`,
      # `:setBackgroundColor`) because that's the shape the spec
      # recording sender asserts against. ObjC selectors for single-
      # argument setters need the colon; the production
      # `SwiftKitObjCSender` routes through this helper at the boundary
      # so the populator contract and the spec recording remain
      # symmetric.
      #
      # Idempotent: passing a Symbol that already ends in `:` returns
      # its String form unchanged so a future caller that knows the
      # ObjC convention can pass the canonical Symbol directly.
      def self.objc_setter_selector(setter : Symbol) : String
        name = setter.to_s
        name.ends_with?(':') ? name : "#{name}:"
      end
    end

    # ---------------------------------------------------------------------
    # Production `Sender` backed by `LibSwiftKitBridge`.
    #
    # This is the sender the AppKit / UIKit renderer's `visit(UI::Button)`
    # constructs. It holds the raw `APSK*Overrides` pointer the C
    # trampoline returned and forwards every `set_*` invocation to the
    # matching `apsk_overrides_set_*` `fun`. The `target : String`
    # argument the abstract contract passes is ignored — the production
    # sender already knows which overrides object it is populating from
    # the pointer captured at construction time. Symbol setter names are
    # stringified once at the C boundary via `to_s.to_unsafe`.
    #
    # The sender is gated on `flag?(:macos) || flag?(:ios)` because
    # `LibSwiftKitBridge` only resolves under those builds. The web /
    # Android renderers never reach this code path.
    # ---------------------------------------------------------------------
    {% if flag?(:macos) || flag?(:ios) %}
      class SwiftKitObjCSender < Populator::Sender
        # The `APSK*Overrides` pointer returned by `apsk_*_overrides_new`.
        # Lives at least as long as the sender; the renderer drops the
        # sender immediately after the matching `apsk_make_*` call, which
        # is the next ObjC autorelease-pool drain at the latest.
        getter overrides_ptr : Void*

        def initialize(@overrides_ptr : Void*)
        end

        def set_color(target : String, setter : Symbol, color : UI::Color?)
          return if color.nil?
          LibSwiftKitBridge.apsk_overrides_set_color(
            @overrides_ptr, Populator.objc_setter_selector(setter).to_unsafe,
            color.r, color.g, color.b, color.a,
          )
        end

        def set_number(target : String, setter : Symbol, value : Float64?)
          return if value.nil?
          LibSwiftKitBridge.apsk_overrides_set_number(
            @overrides_ptr, Populator.objc_setter_selector(setter).to_unsafe, value,
          )
        end

        def set_bool(target : String, setter : Symbol, value : Bool?)
          return if value.nil?
          LibSwiftKitBridge.apsk_overrides_set_bool(
            @overrides_ptr, Populator.objc_setter_selector(setter).to_unsafe, value ? 1 : 0,
          )
        end

        def set_string(target : String, setter : Symbol, value : String?)
          return if value.nil?
          LibSwiftKitBridge.apsk_overrides_set_string(
            @overrides_ptr, Populator.objc_setter_selector(setter).to_unsafe, value.to_unsafe,
          )
        end
      end
    {% end %}
  end
end
