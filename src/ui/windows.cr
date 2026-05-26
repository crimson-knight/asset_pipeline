# Window configuration types (`WindowConfiguration`, `WindowSize`, titlebar style)
# describing top-level windows for macOS / iPadOS renderers to materialize.

module UI
  # macOS/iPadOS titlebar presentation. Maps to AppKit's `NSWindow.titlebarStyle`
  # and iPadOS scene-window equivalents.
  #
  # * `Automatic`      — system default for the host context.
  # * `Standard`       — chromed titlebar with title + traffic lights.
  # * `Unified`        — titlebar shares background with the toolbar.
  # * `UnifiedCompact` — narrow unified bar (Sidebar / Mail-style chrome).
  # * `Hidden`         — no titlebar; traffic lights are inset over content.
  enum WindowTitlebarStyle
    Automatic
    Standard
    Unified
    UnifiedCompact
    Hidden
  end

  # Width × height pair in logical points (1 pt == 1 px at 1x).
  #
  # Use `WindowSize#clamp` to bound a value against optional minimum
  # and/or maximum sizes — useful when the host wants to honor an
  # app-supplied `preferred_size` only within app-supplied bounds.
  record WindowSize,
    width : Float64,
    height : Float64 do
    # Returns a new `WindowSize` whose width/height fall within
    # `[minimum.width, maximum.width]` × `[minimum.height, maximum.height]`.
    # `nil` for either bound leaves that side unconstrained.
    def clamp(minimum : WindowSize? = nil, maximum : WindowSize? = nil) : WindowSize
      clamped_width = clamp_dimension(width, minimum.try(&.width), maximum.try(&.width))
      clamped_height = clamp_dimension(height, minimum.try(&.height), maximum.try(&.height))
      WindowSize.new(clamped_width, clamped_height)
    end

    private def clamp_dimension(value : Float64, minimum : Float64?, maximum : Float64?) : Float64
      clamped = value
      clamped = minimum if minimum && clamped < minimum
      clamped = maximum if maximum && clamped > maximum
      clamped
    end
  end

  # Declarative description of a top-level window the host App should
  # materialize. Apply via `Windows.apply(configuration)` (or
  # `configuration.apply`); the native bridge translates each property
  # to its AppKit `NSWindow` (or UIKit scene) equivalent.
  #
  # ```
  # config = UI::Windows.configure(
  #   title: "Notes",
  #   preferred_width: 1024.0,
  #   preferred_height: 768.0,
  #   minimum_width: 480.0,
  #   minimum_height: 320.0,
  #   titlebar_style: UI::WindowTitlebarStyle::Unified,
  # )
  # config.apply # true if the host bridge accepted it
  # ```
  class WindowConfiguration
    # Window title bar text.
    property title : String

    # Optional subtitle shown after an em dash in the title bar.
    property subtitle : String? = nil

    # Initial size on first present. Clamped to `minimum_size` /
    # `maximum_size` before the native call.
    property preferred_size : WindowSize? = nil

    # Lower bound on user-driven resize. nil = unconstrained.
    property minimum_size : WindowSize? = nil

    # Upper bound on user-driven resize. nil = unconstrained.
    property maximum_size : WindowSize? = nil

    # Titlebar presentation. See `WindowTitlebarStyle`.
    property titlebar_style : WindowTitlebarStyle = WindowTitlebarStyle::Standard

    # Whether the titlebar is visible at all. False ⇒ frameless window.
    property shows_titlebar : Bool = true

    # Whether the toolbar slot is reserved (NSToolbar-equivalent).
    property shows_toolbar : Bool = true

    # Whether full-screen mode is offered in the green traffic light.
    property allows_full_screen : Bool = true

    # Whether the user can resize the window from any edge.
    property resizable : Bool = true

    def initialize(
      @title : String,
      @subtitle : String? = nil,
      @preferred_size : WindowSize? = nil,
      @minimum_size : WindowSize? = nil,
      @maximum_size : WindowSize? = nil,
      @titlebar_style : WindowTitlebarStyle = WindowTitlebarStyle::Standard,
      @shows_titlebar : Bool = true,
      @shows_toolbar : Bool = true,
      @allows_full_screen : Bool = true,
      @resizable : Bool = true
    )
    end

    # Composed title + subtitle in the host's "Title — Subtitle" form.
    # When subtitle is nil/empty, returns the title alone.
    def display_title : String
      return title if subtitle.nil? || subtitle.not_nil!.empty?
      "#{title} — #{subtitle.not_nil!}"
    end

    # Returns the size the host should use for first-present, with
    # `preferred_size` clamped to the min/max bounds. Falls back to
    # `minimum_size` then `maximum_size` if no preferred is set.
    def normalized_preferred_size : WindowSize?
      size = preferred_size || minimum_size || maximum_size
      size ? size.clamp(minimum_size, maximum_size) : nil
    end

    # Convenience accessor — the clamped preferred width, or nil if no
    # size hints exist.
    def preferred_width : Float64?
      normalized_preferred_size.try(&.width)
    end

    # Convenience accessor — the clamped preferred height, or nil if no
    # size hints exist.
    def preferred_height : Float64?
      normalized_preferred_size.try(&.height)
    end

    # Human-readable "WxH" string for logs / debug overlays.
    # Returns nil if no preferred size hint was supplied.
    def size_summary : String?
      size = normalized_preferred_size
      return nil unless size
      "#{size.width.round(1)} x #{size.height.round(1)}"
    end

    # Apply this configuration to the host window. Returns `true` if the
    # native bridge accepted the call, `false` otherwise (e.g. on the
    # web target where window chrome is browser-controlled).
    def apply : Bool
      UI::Windows.apply(self)
    end
  end

  # Top-level window configuration entry points. Use `Windows.configure`
  # to build a `WindowConfiguration` from positional / keyword args, and
  # `Windows.apply` to invoke the native bridge.
  module Windows
    extend self

    {% if flag?(:macos) || flag?(:ios) %}
      lib LibObjCBridge
        fun ap_window_apply_configuration(title : UInt8*, subtitle : UInt8*, width : Float64, height : Float64, min_width : Float64, min_height : Float64, max_width : Float64, max_height : Float64, titlebar_style : Int64, shows_titlebar : Int32, shows_toolbar : Int32, allows_full_screen : Int32, resizable : Int32) : Int32
      end
    {% end %}

    # Build a `WindowConfiguration` from individual width/height knobs.
    # Each (width, height) pair must be passed together or both omitted
    # — passing only one raises `ArgumentError`.
    def configure(
      title : String,
      subtitle : String? = nil,
      preferred_width : Float64? = nil,
      preferred_height : Float64? = nil,
      minimum_width : Float64? = nil,
      minimum_height : Float64? = nil,
      maximum_width : Float64? = nil,
      maximum_height : Float64? = nil,
      titlebar_style : WindowTitlebarStyle = WindowTitlebarStyle::Standard,
      shows_titlebar : Bool = true,
      shows_toolbar : Bool = true,
      allows_full_screen : Bool = true,
      resizable : Bool = true
    ) : WindowConfiguration
      WindowConfiguration.new(
        title: title,
        subtitle: subtitle,
        preferred_size: build_size(preferred_width, preferred_height),
        minimum_size: build_size(minimum_width, minimum_height),
        maximum_size: build_size(maximum_width, maximum_height),
        titlebar_style: titlebar_style,
        shows_titlebar: shows_titlebar,
        shows_toolbar: shows_toolbar,
        allows_full_screen: allows_full_screen,
        resizable: resizable
      )
    end

    # Push a `WindowConfiguration` into the host's window. Returns
    # `true` on success. On non-Apple targets returns `false`
    # (the web target leaves window chrome to the browser).
    def apply(configuration : WindowConfiguration) : Bool
      {% if flag?(:macos) || flag?(:ios) %}
        subtitle_ptr = configuration.subtitle ? configuration.subtitle.not_nil!.to_unsafe : Pointer(UInt8).null
        preferred = configuration.normalized_preferred_size
        minimum = configuration.minimum_size
        maximum = configuration.maximum_size

        LibObjCBridge.ap_window_apply_configuration(
          configuration.title.to_unsafe,
          subtitle_ptr,
          preferred ? preferred.not_nil!.width : 0.0,
          preferred ? preferred.not_nil!.height : 0.0,
          minimum ? minimum.not_nil!.width : 0.0,
          minimum ? minimum.not_nil!.height : 0.0,
          maximum ? maximum.not_nil!.width : 0.0,
          maximum ? maximum.not_nil!.height : 0.0,
          configuration.titlebar_style.value,
          configuration.shows_titlebar ? 1 : 0,
          configuration.shows_toolbar ? 1 : 0,
          configuration.allows_full_screen ? 1 : 0,
          configuration.resizable ? 1 : 0
        ) == 1
      {% else %}
        false
      {% end %}
    end

    private def build_size(width : Float64?, height : Float64?) : WindowSize?
      return nil if width.nil? && height.nil?
      raise ArgumentError.new("window width and height must be provided together") if width.nil? || height.nil?
      WindowSize.new(width.not_nil!, height.not_nil!)
    end
  end
end
