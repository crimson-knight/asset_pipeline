# Defines `UI::View`, the abstract base for every cross-platform view, plus the
# `RenderContext` and `RenderError` types used by the platform-visitor renderers.

module UI
  # Phase 6.11 iter-3 — Raised by a platform visitor when a child view
  # cannot be rendered to its native handle. The previous behavior emitted
  # a silent empty placeholder which masked bugs (notably the iOS
  # `SwipeActionRow` content path during the swipe-reveal refactor). The
  # explicit exception surfaces the failure immediately during development
  # and lets call sites that genuinely need a recoverable path opt in via
  # a `begin/rescue` of their own.
  class RenderError < Exception
  end

  # Phase 8A — Renderer-scoped per-request context threaded through
  # `UI::Web::Renderer#render(view, render_context:)`. Carries values
  # the web visit methods need but that don't belong on the view tree
  # itself (e.g. the CSRF token for `UI::Form`'s hidden-input
  # injection).
  #
  # Phase 10B.2c iter 2 — Now also carries the `UI::Environment` so
  # widgets that react to user preferences (e.g. `UI::Snackbar`'s
  # `effective_duration` honoring reduce-motion) can read the
  # environment at visit time from the renderer-side context. The
  # `ScreenContext`'s environment is copied here when the host builds
  # the render context (`compute_screen_html` does this); test paths
  # that construct a `RenderContext` directly pass `environment:`
  # explicitly or accept the conservative default.
  #
  # Lives in the core `UI` namespace (rather than the Amber integration
  # file) so the web renderer can read it without requiring the Amber
  # integration to be loaded. Apps not using Amber simply pass a fresh
  # `RenderContext.empty` or omit the argument.
  struct RenderContext
    getter csrf_token : String?
    getter environment : UI::Environment

    def initialize(@csrf_token : String? = nil, @environment : UI::Environment = UI::Environment.default)
    end

    def self.empty : RenderContext
      new(csrf_token: nil, environment: UI::Environment.default)
    end
  end

  # Alignment options for stack layouts
  enum Alignment
    Leading
    Center
    Trailing
    Top
    Bottom
    Fill
  end

  # Content mode for image display
  enum ContentMode
    Fit
    Fill
    Stretch
  end

  # Keyboard type hint for text fields
  enum KeyboardType
    Default
    EmailAddress
    NumberPad
    PhonePad
    URL
  end

  # Style for toggle/switch controls
  enum ToggleStyle
    Switch   # iOS-style toggle switch
    Checkbox # Standard checkbox
  end

  # Style for picker controls
  enum PickerStyle
    Wheel     # Spinning wheel picker
    Segmented # Segmented control inline
    Menu      # Dropdown/popup menu
    Inline    # Expanded inline
  end

  # Mode for date/time pickers
  enum DatePickerMode
    Date        # Date only
    Time        # Time only
    DateAndTime # Both date and time
  end

  # Visual style for date/time pickers.
  # Phase 10D-polish iter 2 (B-DATEPICKER-STYLE-PROPERTY).
  #
  # * `Automatic` — let the platform pick the HIG-correct style for the
  #   mode (`.date` → graphical on iOS; `.compact` on macOS).
  # * `Compact` — inline button that pops a wheel/calendar overlay when
  #   tapped. The asset_pipeline default for in-form usage.
  # * `Graphical` — full inline calendar / clock face. SwiftUI's
  #   `.graphical` (iOS) / `.field` (macOS) date picker style.
  # * `Wheels` — spinning wheel picker. SwiftUI `.wheel`.
  enum DatePickerStyle
    Automatic
    Compact
    Graphical
    Wheels
  end

  # Style for progress indicators
  enum ProgressStyle
    Linear   # Horizontal progress bar
    Circular # Spinning circular progress
  end

  # Style for list views
  enum ListStyle
    Plain        # No grouping, no separators between sections
    Inset        # Rounded group sections with insets
    Grouped      # Grouped with section headers
    InsetGrouped # Rounded grouped sections
    Sidebar      # macOS-style sidebar list
  end

  # Layout mode for list/collection views
  enum ListLayout
    List # Vertical row layout (default; maps to UITableView / NSTableView semantics)
    Grid # Multi-column grid layout (maps to UICollectionView / NSCollectionView semantics)
  end

  # Value type representing an RGBA color
  record Color,
    r : Float64,
    g : Float64,
    b : Float64,
    a : Float64 = 1.0

  # Value type representing a font specification
  record Font,
    family : String = "system",
    size : Float64 = 17.0,
    weight : Symbol = :regular,
    italic : Bool = false

  # Value type representing edge insets (padding/margins)
  record EdgeInsets,
    top : Float64 = 0.0,
    trailing : Float64 = 0.0,
    bottom : Float64 = 0.0,
    leading : Float64 = 0.0

  # Phase 10B.2b — Custom accessibility action surfaced to assistive tech
  # (VoiceOver / TalkBack / NSAccessibility). Each action carries a
  # human-readable `name` (announced by the screen reader as a verb
  # users invoke via the rotor / actions menu) plus a `callback` Proc
  # invoked when the user activates the action.
  #
  # Per-platform mapping:
  #   - UIKit  -> `UIAccessibilityCustomAction(name:target:selector:)`
  #              array passed to `setAccessibilityCustomActions:`.
  #   - AppKit -> `NSAccessibilityCustomAction(name:handler:)` array
  #              passed to `setAccessibilityCustomActions:`. Available
  #              on macOS 10.13+.
  #   - Web    -> emits `data-ax-actions="action1,action2"` plus a
  #              `data-ax-action-N-token="<n>"` attribute per action so
  #              a JS shim can dispatch keystroke-driven custom actions.
  #              The element is ensured focusable when actions exist.
  #   - Android -> best-effort `AccessibilityNodeInfo.addAction` via the
  #              accessibility delegate. JNI surface is documented as a
  #              deferred limitation when the bridge entry point is not
  #              wired (10B.2b iter 1 ships the Crystal-side data path
  #              and a stub log call).
  class AccessibilityAction
    getter name : String
    getter callback : Proc(Nil)

    def initialize(@name : String, &block : -> Nil)
      @callback = block
    end

    # Spec convenience — constructs an action that records its
    # invocation onto the given Channel/Array. Mostly used by tests
    # so the Crystal-side surface stays plain.
    def self.new(name : String, callback : Proc(Nil)) : AccessibilityAction
      new(name) { callback.call }
    end

    # Invoke the underlying callback. Renderers / dispatchers call this
    # from the native action trampoline.
    def call : Nil
      @callback.call
    end
  end

  # Phase 10B.2b — Keyboard shortcut binding for a view. The `key` is a
  # single character (or a special key name like `:return`, `:escape`,
  # `:tab`, `:up`, `:down`, `:left`, `:right`, `:space`, `:delete`,
  # `:backspace`, `:f1`...`:f12`). `modifiers` is a set of modifier
  # symbols: `:command`, `:control`, `:option` / `:alt`, `:shift`.
  #
  # Per-platform mapping:
  #   - Web    -> `accesskey` attribute (single character only) plus a
  #              `data-keyboard-shortcut` attribute carrying the full
  #              canonical string ("Cmd+Shift+P") for JS handlers that
  #              want richer dispatch.
  #   - UIKit  -> `UIKeyCommand` entries pushed onto the view's
  #              `keyCommands` (we maintain an Objective-C side list
  #              via `apsk_view_add_key_command`).
  #   - AppKit -> on `NSButton`-like controls we set `keyEquivalent` +
  #              `keyEquivalentModifierMask` directly. Non-control views
  #              fall through.
  #   - Android -> no first-class analog beyond `View.setOnKeyListener`;
  #              documented as a deferred limitation.
  struct KeyboardShortcut
    getter key : String
    getter modifiers : Array(Symbol)

    def initialize(key : String | Symbol, @modifiers : Array(Symbol) = [] of Symbol)
      @key = key.to_s
    end

    # Canonical "Cmd+Shift+P"-style label. Renderers / specs can use
    # this directly without re-implementing the join. Modifier ordering
    # matches macOS HIG: Control, Option, Shift, Command.
    def canonical : String
      parts = [] of String
      parts << "Control" if @modifiers.includes?(:control)
      parts << "Option" if @modifiers.includes?(:option) || @modifiers.includes?(:alt)
      parts << "Shift" if @modifiers.includes?(:shift)
      parts << "Command" if @modifiers.includes?(:command) || @modifiers.includes?(:cmd)
      parts << @key
      parts.join("+")
    end

    # Single-character "access key" used by HTML's `accesskey` attribute.
    # Returns the first character of `key` when `key` is a printable
    # single-character string; nil for named keys like `:return`.
    def accesskey_char : String?
      return nil if @key.size != 1
      @key
    end

    # UIKit `UIKeyModifierFlags` bitmask. Bit positions per the
    # UIKit public header:
    #   UIKeyModifierAlphaShift = 1 << 16
    #   UIKeyModifierShift      = 1 << 17
    #   UIKeyModifierControl    = 1 << 18
    #   UIKeyModifierAlternate  = 1 << 19
    #   UIKeyModifierCommand    = 1 << 20
    #   UIKeyModifierNumericPad = 1 << 21
    def uikit_modifier_mask : UInt64
      mask = 0_u64
      mask |= (1_u64 << 17) if @modifiers.includes?(:shift)
      mask |= (1_u64 << 18) if @modifiers.includes?(:control)
      mask |= (1_u64 << 19) if @modifiers.includes?(:option) || @modifiers.includes?(:alt)
      mask |= (1_u64 << 20) if @modifiers.includes?(:command) || @modifiers.includes?(:cmd)
      mask
    end

    # AppKit `NSEventModifierFlags`. Bit positions per AppKit header:
    #   NSEventModifierFlagShift   = 1 << 17
    #   NSEventModifierFlagControl = 1 << 18
    #   NSEventModifierFlagOption  = 1 << 19
    #   NSEventModifierFlagCommand = 1 << 20
    # (Same bit layout as UIKit for the four general modifiers.)
    def appkit_modifier_mask : UInt64
      uikit_modifier_mask
    end
  end

  # Abstract base class for all UI views.
  #
  # Crystal prohibits recursive structs, so View must be a class.
  # VStack/HStack/ZStack children arrays contain View references,
  # creating a recursive type relationship.
  abstract class View
    # Optional identifier for this view, used for lookup and testing
    property id : String? = nil

    # Accessibility label read by screen readers
    property accessibility_label : String? = nil

    # Phase 10B.2a — Supplemental hint announced after the label, used to
    # explain *what activating this element does* (e.g. "Double-tap to
    # open settings"). Web maps to `aria-describedby` (or `aria-description`
    # when the hint stands alone); UIKit maps to `accessibilityHint`;
    # AppKit maps to `setAccessibilityHelp:` (the closest AppKit equivalent
    # — AppKit lacks a first-class hint slot). Android concatenates the
    # hint onto `contentDescription` with a separator since Android's AX
    # API surfaces a single string per view.
    property accessibility_hint : String? = nil

    # Phase 10B.2a — Explicit semantic role for assistive tech. When `nil`
    # the View's `accessibility_role` getter falls back to the widget
    # subclass's `default_accessibility_role`. Set explicitly to override
    # the default (e.g. a `UI::Label` acting as a section header should set
    # `accessibility_role = :header`).
    #
    # Canonical role symbols (per-platform mapping table lives in the
    # phase 10B.2a close handoff):
    #   :button   :link        :text        :header     :image
    #   :tab      :tab_list    :tab_panel   :list       :list_item
    #   :checkbox :radio       :switch      :slider     :progress_bar
    #   :search   :dialog      :alert       :menu       :menu_item
    #   :none     — explicit "no role" (web emits `role="none"`).
    property accessibility_role : Symbol? = nil

    # Phase 10B.2a — UIKit-style traits surfaced to assistive tech as a
    # set of capability flags. Examples:
    #   :selected         — the element is in a selected state
    #   :not_enabled      — the element is non-interactive
    #   :plays_sound      — activating the element produces audio
    #   :starts_media     — activating begins media playback
    #   :causes_page_turn — activating navigates to a new screen
    #   :updates_frequently — value changes rapidly (announce sparingly)
    #
    # Per-platform mapping:
    #   UIKit  — bitwise OR of UIAccessibilityTraits values.
    #   AppKit — best-effort via `setAccessibilityCustomRole` /
    #            `setAccessibilitySelected:`; unmapped traits fall through.
    #   Web    — mapped to `aria-selected`, `aria-disabled`, etc. where
    #            an analog exists.
    #   Android — applied via `AccessibilityNodeInfo` flags where supported.
    property accessibility_traits : Array(Symbol) = [] of Symbol

    # Phase 10B.2a — Current value as a human-readable string. Used by
    # screen readers when the role implies a value (slider, progress,
    # toggle, segmented control). Examples: `"On"`, `"75%"`, `"3 of 7"`.
    # Web emits `aria-valuetext`; UIKit emits `accessibilityValue`;
    # AppKit emits `setAccessibilityValue:`; Android emits
    # `setStateDescription` (API 30+; older versions silently no-op).
    property accessibility_value : String? = nil

    # Phase 10B.2a — Stable identifier surfaced to platform AX trees for
    # automated UI testing. This is intentionally distinct from `test_id`:
    #   - `test_id` is the asset_pipeline / AXTest convention; the AppKit
    #     and UIKit renderers historically map it to `accessibilityIdentifier`.
    #   - `accessibility_identifier` is the explicit XCTest /
    #     Espresso-friendly slot. When both are set, the explicit
    #     `accessibility_identifier` wins on AppKit and UIKit.
    #   - Web emits both as `data-testid` (test_id) and
    #     `data-accessibility-id` (accessibility_identifier) so test
    #     drivers that already query the latter don't break.
    property accessibility_identifier : String? = nil

    # Phase 10B.2b — Custom accessibility actions surfaced to assistive
    # tech. Each action carries a human-readable name and a callback.
    # See `UI::AccessibilityAction`. Renderers walk this array and
    # emit per-platform custom actions (UIKit `UIAccessibilityCustomAction`,
    # AppKit `NSAccessibilityCustomAction`, web data-attribute hooks,
    # Android best-effort).
    property accessibility_actions : Array(AccessibilityAction) = [] of AccessibilityAction

    # Phase 10B.2b — Requests that the view receive focus on render. When
    # toggled true (e.g. via a controller reaction), the matching native
    # renderer calls `becomeFirstResponder` / `makeFirstResponder:` /
    # `requestFocus()` on the resolved native view. Web emits an
    # `autofocus` attribute on form controls and a `data-focused="true"`
    # hook for non-form elements that a JS shim can act on.
    property focused : Bool = false

    # Phase 10B.2b — Whether this view participates in keyboard focus
    # traversal. `nil` means "use the widget's default" (interactive
    # widgets default to focusable, layout primitives to non-focusable).
    # Set explicitly to override. Web emits `tabindex="0"` (focusable)
    # or `tabindex="-1"` (programmatic-focus-only). Native renderers
    # call `setIsAccessibilityElement:` / `setFocusable` to reflect the
    # choice.
    property focusable : Bool? = nil

    # Phase 10B.2b — Explicit tab order index. Web emits `tabindex="<n>"`.
    # On native platforms `tab_index` is advisory because keyboard
    # traversal order is determined by the platform's focus engine; we
    # surface the value in `accessibility_identifier` test attribute
    # form so XCUITest / Espresso can introspect intent.
    property tab_index : Int32? = nil

    # Phase 10B.2b — Keyboard shortcut binding. See `UI::KeyboardShortcut`.
    # Web emits an `accesskey` attribute plus a `data-keyboard-shortcut`
    # canonical string. UIKit and AppKit thread the modifier mask into
    # the platform's key command / key equivalent APIs.
    property keyboard_shortcut : KeyboardShortcut? = nil

    # Chainable convenience setter: `view.with_keyboard_shortcut("S",
    # modifiers: [:command])`. Returns `self`.
    def with_keyboard_shortcut(key : String | Symbol, modifiers : Array(Symbol) = [] of Symbol) : self
      @keyboard_shortcut = KeyboardShortcut.new(key, modifiers)
      self
    end

    # Phase 10B.2b — Per-widget default for `focusable` when the caller
    # leaves the property at `nil`. Interactive subclasses (`Button`,
    # `TextField`, `Toggle`, …) override this to return `true`; layout
    # primitives and decorative views return `false`. The
    # `effective_focusable` getter applies the precedence.
    def default_focusable : Bool
      false
    end

    # Phase 10B.2b — Resolved focusability: explicit `focusable` when
    # set, otherwise the subclass default. Renderers MUST call this
    # method rather than read `@focusable` directly so the default-
    # inference path runs.
    def effective_focusable : Bool
      f = @focusable
      f.nil? ? default_focusable : f
    end

    # Phase 10B.2b — Resolved tab-index emission. Returns the explicit
    # `tab_index` when the caller set one. When `focusable` was
    # explicitly set to `false` on a widget whose default is focusable,
    # returns `-1` so the renderer can opt the element out of tab
    # traversal. Otherwise returns `nil` and the renderer skips the
    # `tabindex` attribute — HTML form controls already have an
    # implicit tab order, so unconditional `tabindex="0"` emission
    # would just produce noise.
    def effective_tab_index : Int32?
      if t = @tab_index
        return t
      end
      # Explicit opt-out: focusable was set to false but the widget
      # default is true (or vice versa needs explicit override).
      if @focusable == false && default_focusable
        return -1
      end
      # Explicit opt-in on a widget whose default is non-focusable —
      # emit tabindex="0" so the browser puts it in the tab order.
      if @focusable == true && !default_focusable
        return 0
      end
      nil
    end

    # Phase 10B.2a — Per-widget default semantic role. Subclasses override
    # to return the role symbol that matches the widget's HIG semantics.
    # The base default is `nil`, which on web emits no `role=` attribute
    # (the HTML tag's intrinsic role wins). The `accessibility_role`
    # getter is overridden via `effective_accessibility_role` so callers
    # never need to pick between the explicit and default channels.
    def default_accessibility_role : Symbol?
      nil
    end

    # Phase 10B.2a — The resolved role: the explicitly set
    # `accessibility_role`, falling back to the subclass's
    # `default_accessibility_role`. Renderers MUST call this method
    # instead of reading the raw `accessibility_role` property so the
    # default-role inference path runs.
    def effective_accessibility_role : Symbol?
      @accessibility_role || default_accessibility_role
    end

    # Padding around the view content
    property padding : EdgeInsets = EdgeInsets.new

    # Background color, nil means transparent/inherited
    property background : Color? = nil

    # Whether the view is hidden from display
    property hidden : Bool = false

    # Opacity from 0.0 (fully transparent) to 1.0 (fully opaque)
    property opacity : Float64 = 1.0

    # Shape modifiers
    property corner_radius : Float64 = 0.0
    property clip_to_bounds : Bool = false

    # Shadow modifier
    property shadow_radius : Float64 = 0.0
    property shadow_color : Color? = nil
    property shadow_offset_x : Float64 = 0.0
    property shadow_offset_y : Float64 = 0.0

    # Border modifier
    property border_width : Float64 = 0.0
    property border_color : Color? = nil

    # Blur modifier
    property blur_radius : Float64 = 0.0

    # Size constraints
    property minimum_width : Float64? = nil
    property minimum_height : Float64? = nil
    property maximum_width : Float64? = nil
    property maximum_height : Float64? = nil

    # Fluid (responsive) size constraints. When set, the web renderer emits a
    # `width: clamp(min, ideal, max)` (resp. `height:`) declaration instead of
    # the literal `minimum_*` / `maximum_*` pair. Native renderers will adopt
    # platform-idiomatic size class translations in later phases.
    property fluid_width : UI::Fluid? = nil
    property fluid_height : UI::Fluid? = nil

    # Container query name. When set, the web renderer emits
    # `container-type: inline-size; container-name: <name>` on the element so
    # nested `@container <name> (...)` blocks resolve against this view's box
    # rather than the viewport.
    property container_query_name : String? = nil

    # Test identifier for automated UI testing, maps to native test attributes
    property test_id : String? = nil

    # Phase 6.10 Rem 4 (Item 2D) — root-fill flag.
    #
    # When `true`, the renderer treats this view as a full-screen root
    # and:
    #   - iOS / macOS: pins the view's width to the device screen width
    #     and lets its height grow to the screen height (or scroll if
    #     content exceeds it). Replaces the brittle hardcoded
    #     `content_width = 340.0` pattern.
    #   - Web: emits `min-height: 100dvh` + `width: 100%` (CSS dvh
    #     respects mobile address-bar resizing).
    #
    # Set via `view.root_fill = true` or the chainable shortcut
    # `view.fill_screen!` (returns self for chaining).
    #
    # The renderer-side honoring is best-effort — a `root_fill` view
    # nested deep inside another stack is still constrained by its
    # parent's bounds. The intent is the OUTER root of an iOS / macOS
    # screen.
    property root_fill : Bool = false

    # Chainable shortcut for `self.root_fill = true`. Returns self.
    def fill_screen! : self
      @root_fill = true
      self
    end

    # SwiftKit reactive-state opaque pointer (Phase 3 Remediation 4).
    #
    # Populated by the AppKit / UIKit renderer's visit method for views
    # that participate in the reactive surface (today: `UI::Label`,
    # `UI::Button`, `UI::Toggle`, `UI::Slider`). It mirrors the same
    # pointer held on the underlying `NativeHandle` so Crystal-side widget
    # mutators (e.g. `UI::Label#text=`) can dispatch through
    # `LibSwiftKitBridge.apsk_*_set_*` without having to thread the
    # `NativeHandle` back to user code. Nil for views that haven't been
    # rendered yet, weren't rendered by a SwiftKit renderer (Web /
    # Android), or aren't reactive widgets.
    #
    # Lifetime: the pointer is +1 retained on the Swift side. The
    # `NativeHandle.release!` path drops the retain via
    # `apsk_state_release`; the View doesn't need to participate.
    property swiftkit_state_handle : Pointer(Void)? = nil

    # Chainable setter: set a fluid horizontal size. Accepts CSS-compatible
    # strings (e.g. `"60vw"`, `"20rem"`) or numeric pixel values, which are
    # emitted as `Npx`. Returns `self` so calls can be chained.
    def fluid_width(min : String | Number, ideal : String | Number, max : String | Number) : self
      @fluid_width = UI::Fluid.new(
        min: coerce_fluid_size(min),
        ideal: coerce_fluid_size(ideal),
        max: coerce_fluid_size(max),
      )
      self
    end

    # Chainable setter: set a fluid vertical size. See `fluid_width`.
    def fluid_height(min : String | Number, ideal : String | Number, max : String | Number) : self
      @fluid_height = UI::Fluid.new(
        min: coerce_fluid_size(min),
        ideal: coerce_fluid_size(ideal),
        max: coerce_fluid_size(max),
      )
      self
    end

    # Chainable setter: mark this view as a container-query root. Renderers
    # that support container queries emit `container-type: inline-size` and
    # `container-name: <name>` on this element so descendant rules of the
    # form `@container <name> (min-width: ...)` resolve against this box.
    def container_query(name : String) : self
      @container_query_name = name
      self
    end

    # Accept a platform visitor for rendering dispatch.
    # Each concrete view type calls `visitor.visit(self)`.
    abstract def accept(visitor : PlatformVisitor)

    # Phase 10B.0 — declare which capabilities this view class supports
    # for a given Tier 2 intent. Used by `UI::WidgetRoute::Registry` to
    # validate overrides at registration time. Subclasses call this
    # exactly once per intent they claim to satisfy:
    #
    #     class UI::SwipeActionRow < UI::View
    #       declares_capabilities :swipe_actions, {
    #         supports_edge_trailing: true,
    #         supports_role_destructive: {ios: true, macos: false, web_wide: true},
    #         supports_role_default: true,
    #       }
    #     end
    #
    # # Capability value shapes (Phase 10B.1b)
    #
    # * `true` — full support on every platform the intent can resolve to.
    # * `false` — no support anywhere (declarative "I do not back this").
    # * `:partial` — fuzzy legacy "some platforms, unspecified." Accepted
    #   for back-compat but the 10B.1b audit prefers explicit Hash form
    #   below.
    # * `Hash(Symbol, Bool)` — platform-keyed support map. Keys are
    #   platform symbols (`:ios`, `:ipados`, `:macos`, `:web_wide`,
    #   `:web_narrow`, `:android`); the value is whether the renderer for
    #   that platform actually backs the capability. `UI::WidgetRoute::Registry`
    #   walks this hash at registration time to detect "claims iOS but
    #   rendered on macOS" mismatches, and again at resolve time when
    #   `capabilities_required:` is passed to `UI::WidgetRoute.resolve`.
    #
    # Both NamedTuple shorthand (`{ios: true, macos: false}`) and rocket-
    # style HashLiteral (`{:ios => true, :macos => false}`) are accepted
    # for the per-capability platform map. They produce the same
    # `Hash(Symbol, Bool)` at the cap site.
    #
    # The macro emits a class-level hook method
    # `_declare_capabilities_for_intent_<intent_id>` that runs the
    # `UI::WidgetRoute::Registry.declare_widget_capabilities` write. Like
    # `UI::App`'s `_bootstrap_screen_*` pattern, method definitions are
    # compile-time-emitted code, unaffected by the iOS class-init gap
    # (see [[project_crystal_ios_class_init_gap]]). The class-load side
    # effect of invoking the named method then writes the capability
    # bag into the registry.
    macro declares_capabilities(intent_id, capabilities)
      def self._declare_capabilities_for_intent_{{intent_id.id}} : Nil
        caps = {} of Symbol => ::UI::WidgetRoute::Registry::CapabilityValue
        {% for key, value in capabilities %}
          {% if value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
            _cap_h_{{intent_id.id}}_{{key.id}} = {} of Symbol => Bool
            {% for plat_key, plat_value in value %}
              {% if plat_key.is_a?(SymbolLiteral) %}
                # Rocket-style HashLiteral key (e.g. `:ios => true`) is
                # already a SymbolLiteral. Emit it directly — calling
                # `.symbolize` would wrap it as `:":ios"`, which then
                # never matches a `:ios` lookup downstream.
                _cap_h_{{intent_id.id}}_{{key.id}}[{{plat_key}}] = {{plat_value}}
              {% else %}
                # NamedTupleLiteral key (`ios: true`) arrives as a
                # MacroId; symbolize it into `:ios`.
                _cap_h_{{intent_id.id}}_{{key.id}}[{{plat_key.symbolize}}] = {{plat_value}}
              {% end %}
            {% end %}
            caps[{% if key.is_a?(SymbolLiteral) %}{{key}}{% else %}{{key.symbolize}}{% end %}] = _cap_h_{{intent_id.id}}_{{key.id}}
          {% else %}
            caps[{% if key.is_a?(SymbolLiteral) %}{{key}}{% else %}{{key.symbolize}}{% end %}] = {{value}}
          {% end %}
        {% end %}
        ::UI::WidgetRoute::Registry.declare_widget_capabilities(
          {{@type}},
          {{intent_id}},
          caps,
        )
        nil
      end

      # Class-load side effect: register the declaration eagerly. iOS
      # embedding may skip this write (class-init gap). The named
      # method above is the recovery hatch — re-running it from a
      # framework bootstrap routine restores the declaration.
      _declare_capabilities_for_intent_{{intent_id.id}}
    end

    # Coerce a fluid size argument into its CSS string form. Numbers are
    # treated as pixel values; strings pass through unchanged.
    private def coerce_fluid_size(value : String | Number) : String
      case value
      when Number then "#{value}px"
      else             value.to_s
      end
    end
  end
end
