require "./design_tokens/conversion"

module UI
  # Unified design-token model. This is the single source of truth for all
  # Tier 1 brand decisions in the asset_pipeline cross-platform UI system.
  #
  # The model is platform-agnostic: scalars are stored in `Float64`
  # rem-equivalent units (1 rem = 16 logical points) and colors are stored
  # with both an OKLCH triple (the canonical source) and a precomputed RGBA
  # bake (used by native renderers that have no OKLCH support).
  #
  # Three generators consume this model:
  #   - `UI::DesignTokens::WebGenerator`   → `dist/web_tokens.css`
  #   - `UI::DesignTokens::AppleGenerator` → `dist/AssetPipelineTokens.swift`
  #   - `UI::DesignTokens::AndroidGenerator` (deferred, see Architect handoff
  #     `docs/initiative-cross-platform-ui/handoff/phase-01-architect-scope-deferral-2026-05-20.md`)
  #
  # ## `copy_with` policy
  #
  # All `record`-based aggregate types in this module rely on the Crystal
  # `record` macro's auto-generated `copy_with` method. This was verified on
  # the pinned compiler version (Crystal 1.20.0) — the brand override surface
  # in `Brand#apply` and any consumer-side `palette.copy_with(brand_primary: …)`
  # call paths depend on it. If a future compiler upgrade drops `copy_with`
  # from `record`, hand-roll one per type — `ColorPalette`, `SpacingScale`,
  # `TypeScale`, `TypeStep`, `RadiusScale`, `ShadowScale`, `ShadowLevel`,
  # `MotionScale`, `Breakpoints` — taking keyword arguments matching the
  # record fields. `Tokens` itself is a class with its own `copy_with`.
  module DesignTokens
    # Canonical color.
    #
    # The OKLCH triple is the source of truth; the sRGB triple is the
    # deterministic bake used by native renderers. Constructors taking OKLCH
    # compute the sRGB; constructors taking sRGB store sRGB verbatim and
    # leave OKLCH nil — that nil case is reserved for platform-system color
    # references that must not round-trip (e.g., a sentinel `NSColor.labelColor`
    # which the AppKit renderer resolves separately).
    struct Color
      getter l : Float64?
      getter c : Float64?
      getter h : Float64?
      getter alpha : Float64
      getter r : Float64
      getter g : Float64
      getter b : Float64

      def initialize(
        @l : Float64?,
        @c : Float64?,
        @h : Float64?,
        @r : Float64,
        @g : Float64,
        @b : Float64,
        @alpha : Float64 = 1.0,
      )
      end

      # Construct from an OKLCH triple. Lightness on [0, 1], chroma typically
      # on [0, 0.4], hue in degrees on [0, 360). Alpha on [0, 1].
      #
      # If the triple is out of gamut, chroma is reduced until the result lies
      # within sRGB — the hue and lightness are preserved exactly.
      def self.oklch(l : Float64, c : Float64, h : Float64, alpha : Float64 = 1.0) : Color
        r, g, b = Conversion.oklch_to_srgb(l, c, h)
        new(l: l, c: c, h: h, r: r, g: g, b: b, alpha: alpha)
      end

      # Construct from an sRGB triple on [0, 1]. The OKLCH counterpart is
      # computed and stored too, so `to_oklch_css` is meaningful.
      def self.rgb(r : Float64, g : Float64, b : Float64, alpha : Float64 = 1.0) : Color
        l, c, h = Conversion.srgb_to_oklch(r, g, b)
        new(l: l, c: c, h: h, r: r, g: g, b: b, alpha: alpha)
      end

      # Construct from a "#rrggbb" or "#rrggbbaa" hex string.
      def self.hex(value : String) : Color
        s = value.starts_with?('#') ? value[1..] : value
        raise ArgumentError.new("Invalid hex color: #{value}") unless s.size == 6 || s.size == 8
        r = s[0, 2].to_i(16) / 255.0
        g = s[2, 2].to_i(16) / 255.0
        b = s[4, 2].to_i(16) / 255.0
        alpha = s.size == 8 ? (s[6, 2].to_i(16) / 255.0) : 1.0
        rgb(r, g, b, alpha)
      end

      # Construct from a CSS-style oklch() string: "oklch(0.52 0.16 50)" or
      # "oklch(0.66 0.15 50 / 0.58)". Whitespace-tolerant.
      def self.parse_oklch(css : String) : Color
        text = css.strip
        inner = text.sub(/^oklch\(/i, "").sub(/\)$/, "").strip
        alpha = 1.0
        if slash_index = inner.index('/')
          alpha = inner[(slash_index + 1)..].strip.to_f
          inner = inner[0...slash_index].strip
        end
        parts = inner.split(/\s+/).map(&.to_f)
        raise ArgumentError.new("Invalid oklch() literal: #{css}") unless parts.size == 3
        oklch(parts[0], parts[1], parts[2], alpha)
      end

      # CSS `oklch(L C H / alpha)` string. Component digits are formatted with
      # 3 decimal places for L/C and 2 for H so the generator output is
      # deterministic regardless of float printing quirks.
      def to_oklch_css : String
        if (lv = @l) && (cv = @c) && (hv = @h)
          base = "%.3f %.3f %.2f" % {lv, cv, hv}
          @alpha < 1.0 ? "oklch(#{base} / #{format_alpha})" : "oklch(#{base})"
        else
          to_rgba_css
        end
      end

      # CSS `rgba(r, g, b, alpha)` string with integer 0..255 channels.
      def to_rgba_css : String
        ri = (@r * 255).round.to_i.clamp(0, 255)
        gi = (@g * 255).round.to_i.clamp(0, 255)
        bi = (@b * 255).round.to_i.clamp(0, 255)
        if @alpha < 1.0
          "rgba(#{ri}, #{gi}, #{bi}, #{format_alpha})"
        else
          "rgba(#{ri}, #{gi}, #{bi}, 1)"
        end
      end

      # Generator-friendly "r g b" triple (space-separated 0..255 ints) for
      # use inside CSS `rgb()` / `oklch()` paired tokens.
      def to_rgb_triple_css : String
        ri = (@r * 255).round.to_i.clamp(0, 255)
        gi = (@g * 255).round.to_i.clamp(0, 255)
        bi = (@b * 255).round.to_i.clamp(0, 255)
        "#{ri} #{gi} #{bi}"
      end

      # "#rrggbb" or "#rrggbbaa" hex string.
      def to_hex : String
        ri = (@r * 255).round.to_i.clamp(0, 255)
        gi = (@g * 255).round.to_i.clamp(0, 255)
        bi = (@b * 255).round.to_i.clamp(0, 255)
        base = "#%02x%02x%02x" % {ri, gi, bi}
        if @alpha < 1.0
          ai = (@alpha * 255).round.to_i.clamp(0, 255)
          "#{base}%02x" % {ai}
        else
          base
        end
      end

      # SwiftUI Color literal source.
      def to_swift_color : String
        "Color(.sRGB, red: %.3f, green: %.3f, blue: %.3f, opacity: %.3f)" % {@r, @g, @b, @alpha}
      end

      # Packed 0xAARRGGBB ARGB int for Android (the deferred Android generator
      # consumes this through the Crystal model rather than computing it again).
      def to_android_argb : Int32
        ri = (@r * 255).round.to_i.clamp(0, 255)
        gi = (@g * 255).round.to_i.clamp(0, 255)
        bi = (@b * 255).round.to_i.clamp(0, 255)
        ai = (@alpha * 255).round.to_i.clamp(0, 255)
        ((ai.to_u32 << 24) | (ri.to_u32 << 16) | (gi.to_u32 << 8) | bi.to_u32).to_i32!
      end

      # Returns a new Color with the given fields replaced (manual copy_with
      # because Color is a struct, not a record).
      def copy_with(
        l : Float64? = @l,
        c : Float64? = @c,
        h : Float64? = @h,
        r : Float64 = @r,
        g : Float64 = @g,
        b : Float64 = @b,
        alpha : Float64 = @alpha,
      ) : Color
        Color.new(l: l, c: c, h: h, r: r, g: g, b: b, alpha: alpha)
      end

      private def format_alpha : String
        # Trim trailing zeros and a trailing dot so "0.58" stays "0.58" but
        # "1.000" becomes "1".
        s = "%.3f" % @alpha
        s = s.rstrip('0').rstrip('.')
        s.empty? ? "0" : s
      end
    end

    # 23 semantic color roles. The set is the union of the Material 3 roles
    # already in `UI::Theme` and the surface/text/border/state set in the
    # `Components::CSS::Tokens::Theme` web token bag. Names use library-generic
    # vocabulary, not platform vocabulary.
    record ColorPalette,
      brand_primary : Color,
      brand_primary_hover : Color,
      brand_primary_active : Color,
      brand_secondary : Color,
      brand_accent : Color,
      surface_canvas : Color,
      surface_panel : Color,
      surface_elevated : Color,
      surface_sunken : Color,
      surface_inverse : Color,
      text_primary : Color,
      text_secondary : Color,
      text_muted : Color,
      text_inverse : Color,
      text_link : Color,
      border_subtle : Color,
      border_default : Color,
      border_strong : Color,
      border_focus : Color,
      success : Color,
      warning : Color,
      danger : Color,
      info : Color do
      # Iterating accessor used by generators and `lookup`. Keys use the same
      # kebab vocabulary that ships in the CSS output (`brand-primary`, etc.).
      def to_h : Hash(String, Color)
        {
          "brand-primary"        => brand_primary,
          "brand-primary-hover"  => brand_primary_hover,
          "brand-primary-active" => brand_primary_active,
          "brand-secondary"      => brand_secondary,
          "brand-accent"         => brand_accent,
          "surface-canvas"       => surface_canvas,
          "surface-panel"        => surface_panel,
          "surface-elevated"     => surface_elevated,
          "surface-sunken"       => surface_sunken,
          "surface-inverse"      => surface_inverse,
          "text-primary"         => text_primary,
          "text-secondary"       => text_secondary,
          "text-muted"           => text_muted,
          "text-inverse"         => text_inverse,
          "text-link"            => text_link,
          "border-subtle"        => border_subtle,
          "border-default"       => border_default,
          "border-strong"        => border_strong,
          "border-focus"         => border_focus,
          "success"              => success,
          "warning"              => warning,
          "danger"               => danger,
          "info"                 => info,
        }
      end

      # Lookup by symbol (used by renderer token helpers).
      def lookup(role : Symbol) : Color?
        case role
        when :brand_primary        then brand_primary
        when :brand_primary_hover  then brand_primary_hover
        when :brand_primary_active then brand_primary_active
        when :brand_secondary      then brand_secondary
        when :brand_accent         then brand_accent
        when :surface_canvas       then surface_canvas
        when :surface_panel        then surface_panel
        when :surface_elevated     then surface_elevated
        when :surface_sunken       then surface_sunken
        when :surface_inverse      then surface_inverse
        when :text_primary         then text_primary
        when :text_secondary       then text_secondary
        when :text_muted           then text_muted
        when :text_inverse         then text_inverse
        when :text_link            then text_link
        when :border_subtle        then border_subtle
        when :border_default       then border_default
        when :border_strong        then border_strong
        when :border_focus         then border_focus
        when :success              then success
        when :warning              then warning
        when :danger               then danger
        when :info                 then info
        else                            nil
        end
      end
    end

    # Storage is rem-equivalent `Float64` (1 rem = 16 logical points). Names
    # mirror the Tailwind-flavored keys in `Components::CSS::Config` so the
    # generators can lower to `rem` for web, `CGFloat` for Apple, `dp/sp` for
    # Android without re-encoding.
    record SpacingScale,
      px : Float64,
      x0 : Float64, x0_5 : Float64,
      x1 : Float64, x1_5 : Float64, x2 : Float64, x2_5 : Float64,
      x3 : Float64, x3_5 : Float64, x4 : Float64,
      x5 : Float64, x6 : Float64, x7 : Float64, x8 : Float64,
      x9 : Float64, x10 : Float64, x11 : Float64, x12 : Float64,
      x14 : Float64, x16 : Float64, x20 : Float64, x24 : Float64,
      x28 : Float64, x32 : Float64, x36 : Float64, x40 : Float64,
      x44 : Float64, x48 : Float64, x52 : Float64, x56 : Float64,
      x60 : Float64, x64 : Float64, x72 : Float64, x80 : Float64,
      x96 : Float64 do
      # Tailwind/css_config-style key ("0.5", "1", "1.5", …) → field value.
      def by_key(key : String) : Float64?
        case key
        when "px"  then px
        when "0"   then x0
        when "0.5" then x0_5
        when "1"   then x1
        when "1.5" then x1_5
        when "2"   then x2
        when "2.5" then x2_5
        when "3"   then x3
        when "3.5" then x3_5
        when "4"   then x4
        when "5"   then x5
        when "6"   then x6
        when "7"   then x7
        when "8"   then x8
        when "9"   then x9
        when "10"  then x10
        when "11"  then x11
        when "12"  then x12
        when "14"  then x14
        when "16"  then x16
        when "20"  then x20
        when "24"  then x24
        when "28"  then x28
        when "32"  then x32
        when "36"  then x36
        when "40"  then x40
        when "44"  then x44
        when "48"  then x48
        when "52"  then x52
        when "56"  then x56
        when "60"  then x60
        when "64"  then x64
        when "72"  then x72
        when "80"  then x80
        when "96"  then x96
        else            nil
        end
      end

      # Iterating accessor in CSS-emit order.
      def to_h : Hash(String, Float64)
        {
          "px"  => px,
          "0"   => x0,
          "0_5" => x0_5,
          "1"   => x1,
          "1_5" => x1_5,
          "2"   => x2,
          "2_5" => x2_5,
          "3"   => x3,
          "3_5" => x3_5,
          "4"   => x4,
          "5"   => x5,
          "6"   => x6,
          "7"   => x7,
          "8"   => x8,
          "9"   => x9,
          "10"  => x10,
          "11"  => x11,
          "12"  => x12,
          "14"  => x14,
          "16"  => x16,
          "20"  => x20,
          "24"  => x24,
          "28"  => x28,
          "32"  => x32,
          "36"  => x36,
          "40"  => x40,
          "44"  => x44,
          "48"  => x48,
          "52"  => x52,
          "56"  => x56,
          "60"  => x60,
          "64"  => x64,
          "72"  => x72,
          "80"  => x80,
          "96"  => x96,
        }
      end
    end

    record TypeStep,
      size : Float64,
      line_height : Float64,
      weight : Int32,
      tracking : Float64

    record TypeScale,
      family_sans : String,
      family_display : String,
      family_mono : String,
      caption : TypeStep,
      body : TypeStep,
      body_emph : TypeStep,
      title : TypeStep,
      headline : TypeStep,
      display : TypeStep do
      def lookup(step : Symbol) : TypeStep?
        case step
        when :caption   then caption
        when :body      then body
        when :body_emph then body_emph
        when :title     then title
        when :headline  then headline
        when :display   then display
        else                 nil
        end
      end
    end

    # Role-based radius scale. Phase 1 added `xs`, `card`, `sheet`, `avatar`,
    # and `avatar_lg` to cover concrete renderer use cases (4pt bar corners,
    # 10pt grouped-card / popover / snackbar corners, 14pt sheet corners,
    # 30pt circular action icons, 60pt circular hero icons). These are
    # role-named rather than t-shirt-sized so consuming brands can override
    # them semantically.
    record RadiusScale,
      none : Float64,
      xs : Float64,
      sm : Float64,
      md : Float64,
      lg : Float64,
      xl : Float64,
      x2l : Float64,
      card : Float64,
      sheet : Float64,
      avatar : Float64,
      avatar_lg : Float64,
      pill : Float64 do
      def lookup(key : Symbol) : Float64?
        case key
        when :none      then none
        when :xs        then xs
        when :sm        then sm
        when :md        then md
        when :lg        then lg
        when :xl        then xl
        when :x2l       then x2l
        when :card      then card
        when :sheet     then sheet
        when :avatar    then avatar
        when :avatar_lg then avatar_lg
        when :pill      then pill
        else                 nil
        end
      end
    end

    record ShadowLevel,
      offset_x : Float64,
      offset_y : Float64,
      blur : Float64,
      spread : Float64,
      color : Color

    record ShadowScale,
      flat : Array(ShadowLevel),
      raised : Array(ShadowLevel),
      floating : Array(ShadowLevel),
      overlay : Array(ShadowLevel) do
      def lookup(key : Symbol) : Array(ShadowLevel)?
        case key
        when :flat     then flat
        when :raised   then raised
        when :floating then floating
        when :overlay  then overlay
        else                nil
        end
      end
    end

    record MotionScale,
      duration_instant_ms : Int32,
      duration_fast_ms : Int32,
      duration_base_ms : Int32,
      duration_slow_ms : Int32,
      ease_standard : String,
      ease_emphasized : String,
      spring : String

    record Breakpoints,
      sm : Float64,
      md : Float64,
      lg : Float64,
      xl : Float64,
      x2l : Float64

    # Top-level token aggregate. Held immutable: `with_brand` returns a new
    # `Tokens` rather than mutating self.
    class Tokens
      getter colors_light : ColorPalette
      getter colors_dark : ColorPalette
      getter spacing : SpacingScale
      getter type : TypeScale
      getter radius : RadiusScale
      getter shadow : ShadowScale
      getter motion : MotionScale
      getter breakpoints : Breakpoints

      # Minimum interactive target size in CSS pixels. Phase 2 consumes this
      # to enforce WCAG 2.2 AA touch targets and to derive the lower bound
      # of `clamp()` expressions for tappable controls. Default 44.0 per
      # WCAG / Apple HIG.
      getter touch_target_minimum_px : Float64

      def initialize(
        @colors_light : ColorPalette,
        @colors_dark : ColorPalette,
        @spacing : SpacingScale,
        @type : TypeScale,
        @radius : RadiusScale,
        @shadow : ShadowScale,
        @motion : MotionScale,
        @breakpoints : Breakpoints,
        @touch_target_minimum_px : Float64 = 44.0,
      )
      end

      # Returns a new `Tokens` with the given fields replaced; everything else
      # is shared by reference (all referenced types are records, so sharing is
      # safe).
      def copy_with(
        colors_light : ColorPalette = @colors_light,
        colors_dark : ColorPalette = @colors_dark,
        spacing : SpacingScale = @spacing,
        type : TypeScale = @type,
        radius : RadiusScale = @radius,
        shadow : ShadowScale = @shadow,
        motion : MotionScale = @motion,
        breakpoints : Breakpoints = @breakpoints,
        touch_target_minimum_px : Float64 = @touch_target_minimum_px,
      ) : Tokens
        Tokens.new(
          colors_light: colors_light,
          colors_dark: colors_dark,
          spacing: spacing,
          type: type,
          radius: radius,
          shadow: shadow,
          motion: motion,
          breakpoints: breakpoints,
          touch_target_minimum_px: touch_target_minimum_px,
        )
      end

      # Apply a `Brand` override on top of self. Returns a NEW `Tokens` — never
      # mutates self. Phase 6's consumer-side override path lands here.
      def with_brand(brand : Brand) : Tokens
        brand.apply(self)
      end

      # Look up a single token by dotted path. Used by debug tooling. Unknown
      # paths return nil.
      #
      # Examples:
      #   tokens.lookup("colors.light.brand_primary") # => Color
      #   tokens.lookup("spacing.x4")                 # => Float64
      #   tokens.lookup("radius.md")                  # => Float64
      #   tokens.lookup("type.body.size")             # => Float64
      def lookup(path : String) : (Color | Float64 | Int32 | String | TypeStep)?
        parts = path.split('.')
        case parts.first?
        when "colors"
          return nil unless parts.size >= 3
          palette = parts[1] == "dark" ? @colors_dark : @colors_light
          lookup_color_role(palette, parts[2])
        when "spacing"
          return nil unless parts.size == 2
          # Accept both "spacing.x4" (field-name form) and "spacing.4" (key form).
          key = parts[1].to_s
          key = key[1..] if key.starts_with?('x')
          @spacing.by_key(key.gsub('_', '.'))
        when "radius"
          return nil unless parts.size == 2
          lookup_radius_key(parts[1])
        when "type"
          return nil unless parts.size >= 2
          step = lookup_type_step(parts[1])
          return step if parts.size == 2
          return nil unless step && parts.size == 3
          case parts[2]
          when "size"        then step.size
          when "line_height" then step.line_height
          when "weight"      then step.weight
          when "tracking"    then step.tracking
          else                    nil
          end
        when "motion"
          return nil unless parts.size == 2
          case parts[1]
          when "duration_instant_ms" then @motion.duration_instant_ms
          when "duration_fast_ms"    then @motion.duration_fast_ms
          when "duration_base_ms"    then @motion.duration_base_ms
          when "duration_slow_ms"    then @motion.duration_slow_ms
          when "ease_standard"       then @motion.ease_standard
          when "ease_emphasized"     then @motion.ease_emphasized
          when "spring"              then @motion.spring
          else                            nil
          end
        when "breakpoints"
          return nil unless parts.size == 2
          case parts[1]
          when "sm"  then @breakpoints.sm
          when "md"  then @breakpoints.md
          when "lg"  then @breakpoints.lg
          when "xl"  then @breakpoints.xl
          when "x2l" then @breakpoints.x2l
          else            nil
          end
        when "touch_target_minimum_px"
          @touch_target_minimum_px
        else
          nil
        end
      end

      private def lookup_color_role(palette : ColorPalette, role : String) : Color?
        case role
        when "brand_primary"        then palette.brand_primary
        when "brand_primary_hover"  then palette.brand_primary_hover
        when "brand_primary_active" then palette.brand_primary_active
        when "brand_secondary"      then palette.brand_secondary
        when "brand_accent"         then palette.brand_accent
        when "surface_canvas"       then palette.surface_canvas
        when "surface_panel"        then palette.surface_panel
        when "surface_elevated"     then palette.surface_elevated
        when "surface_sunken"       then palette.surface_sunken
        when "surface_inverse"      then palette.surface_inverse
        when "text_primary"         then palette.text_primary
        when "text_secondary"       then palette.text_secondary
        when "text_muted"           then palette.text_muted
        when "text_inverse"         then palette.text_inverse
        when "text_link"            then palette.text_link
        when "border_subtle"        then palette.border_subtle
        when "border_default"       then palette.border_default
        when "border_strong"        then palette.border_strong
        when "border_focus"         then palette.border_focus
        when "success"              then palette.success
        when "warning"              then palette.warning
        when "danger"               then palette.danger
        when "info"                 then palette.info
        else                             nil
        end
      end

      private def lookup_radius_key(key : String) : Float64?
        case key
        when "none" then @radius.none
        when "sm"   then @radius.sm
        when "md"   then @radius.md
        when "lg"   then @radius.lg
        when "xl"   then @radius.xl
        when "x2l"  then @radius.x2l
        when "pill" then @radius.pill
        else             nil
        end
      end

      private def lookup_type_step(name : String) : TypeStep?
        case name
        when "caption"   then @type.caption
        when "body"      then @type.body
        when "body_emph" then @type.body_emph
        when "title"     then @type.title
        when "headline"  then @type.headline
        when "display"   then @type.display
        else                  nil
        end
      end

      # The canonical built-in brand. Transcribed from
      # `src/components/css/tokens/amber_theme.cr` (OKLCH source values).
      def self.default : Tokens
        new(
          colors_light: Defaults.light_palette,
          colors_dark: Defaults.dark_palette,
          spacing: Defaults.spacing,
          type: Defaults.type_scale,
          radius: Defaults.radius_scale,
          shadow: Defaults.shadow_scale,
          motion: Defaults.motion_scale,
          breakpoints: Defaults.breakpoints,
          touch_target_minimum_px: 44.0,
        )
      end
    end

    # Override surface. A consumer subclasses `Brand`, sets any subset of the
    # `override_*` hooks, and passes the instance to
    # `Tokens.default.with_brand(...)`. Unset fields fall through to defaults.
    #
    # Phase 3 (SwiftUI bridge), Phase 5 (Glass material tokens), and Phase 6
    # (Side-by-side demo app) all inherit the shape of this interface. Changing
    # it after Phase 1 ships requires a coordinated cross-phase update.
    abstract class Brand
      # Compose all override hooks into a new `Tokens`. Returns a NEW object;
      # never mutates `base`.
      def apply(base : Tokens) : Tokens
        base.copy_with(
          colors_light: override_color_light(base.colors_light),
          colors_dark: override_color_dark(base.colors_dark),
          spacing: override_spacing(base.spacing),
          type: override_type(base.type),
          radius: override_radius(base.radius),
          shadow: override_shadow(base.shadow),
          motion: override_motion(base.motion),
          breakpoints: override_breakpoints(base.breakpoints),
          touch_target_minimum_px: override_touch_target_minimum_px(base.touch_target_minimum_px),
        )
      end

      protected def override_color_light(palette : ColorPalette) : ColorPalette
        palette
      end

      protected def override_color_dark(palette : ColorPalette) : ColorPalette
        palette
      end

      protected def override_spacing(scale : SpacingScale) : SpacingScale
        scale
      end

      protected def override_type(scale : TypeScale) : TypeScale
        scale
      end

      protected def override_radius(scale : RadiusScale) : RadiusScale
        scale
      end

      protected def override_shadow(scale : ShadowScale) : ShadowScale
        scale
      end

      protected def override_motion(scale : MotionScale) : MotionScale
        scale
      end

      protected def override_breakpoints(scale : Breakpoints) : Breakpoints
        scale
      end

      protected def override_touch_target_minimum_px(value : Float64) : Float64
        value
      end
    end

    # Default palette and scale values. Kept in a private namespace so the
    # `Tokens.default` factory is the one publicly-documented entry point.
    #
    # Numeric values match `Components::CSS::Tokens::Theme.amber_default` and
    # `Components::CSS::Config` exactly — `amber_theme.cr` is the source of
    # truth for OKLCH values; `css_config.cr` is the source of truth for
    # spacing/radius/typography/breakpoints.
    module Defaults
      extend self

      def light_palette : ColorPalette
        ColorPalette.new(
          brand_primary: Color.oklch(0.52, 0.16, 50.0),
          brand_primary_hover: Color.oklch(0.47, 0.17, 48.0),
          brand_primary_active: Color.oklch(0.40, 0.15, 46.0),
          brand_secondary: Color.oklch(0.47, 0.15, 265.0),
          brand_accent: Color.oklch(0.73, 0.15, 190.0),
          surface_canvas: Color.oklch(0.985, 0.009, 82.0),
          surface_panel: Color.oklch(1.0, 0.0, 0.0),
          surface_elevated: Color.oklch(0.995, 0.003, 80.0),
          surface_sunken: Color.oklch(0.955, 0.011, 79.0),
          surface_inverse: Color.oklch(0.18, 0.018, 248.0),
          text_primary: Color.oklch(0.18, 0.018, 248.0),
          text_secondary: Color.oklch(0.38, 0.028, 248.0),
          text_muted: Color.oklch(0.52, 0.025, 248.0),
          text_inverse: Color.oklch(0.99, 0.003, 80.0),
          text_link: Color.oklch(0.5, 0.13, 235.0),
          border_subtle: Color.oklch(0.91, 0.014, 82.0),
          border_default: Color.oklch(0.82, 0.021, 82.0),
          border_strong: Color.oklch(0.62, 0.04, 75.0),
          border_focus: Color.oklch(0.66, 0.15, 50.0, 0.58),
          success: Color.oklch(0.47, 0.12, 155.0),
          warning: Color.oklch(0.58, 0.15, 75.0),
          danger: Color.oklch(0.45, 0.18, 28.0),
          info: Color.oklch(0.48, 0.13, 235.0),
        )
      end

      def dark_palette : ColorPalette
        ColorPalette.new(
          brand_primary: Color.oklch(0.78, 0.17, 58.0),
          brand_primary_hover: Color.oklch(0.84, 0.15, 60.0),
          brand_primary_active: Color.oklch(0.70, 0.18, 54.0),
          brand_secondary: Color.oklch(0.75, 0.12, 265.0),
          brand_accent: Color.oklch(0.80, 0.14, 190.0),
          surface_canvas: Color.oklch(0.15, 0.025, 260.0),
          surface_panel: Color.oklch(0.20, 0.024, 260.0),
          surface_elevated: Color.oklch(0.25, 0.028, 260.0),
          surface_sunken: Color.oklch(0.12, 0.022, 260.0),
          surface_inverse: Color.oklch(0.95, 0.006, 80.0),
          text_primary: Color.oklch(0.95, 0.006, 80.0),
          text_secondary: Color.oklch(0.78, 0.015, 85.0),
          text_muted: Color.oklch(0.65, 0.018, 85.0),
          text_inverse: Color.oklch(0.18, 0.018, 248.0),
          text_link: Color.oklch(0.77, 0.10, 225.0),
          border_subtle: Color.oklch(0.31, 0.02, 248.0),
          border_default: Color.oklch(0.38, 0.025, 248.0),
          border_strong: Color.oklch(0.52, 0.03, 248.0),
          border_focus: Color.oklch(0.75, 0.14, 58.0, 0.62),
          success: Color.oklch(0.72, 0.14, 153.0),
          warning: Color.oklch(0.80, 0.15, 78.0),
          danger: Color.oklch(0.72, 0.18, 28.0),
          info: Color.oklch(0.72, 0.12, 235.0),
        )
      end

      # Tailwind/css_config-derived spacing scale in rem.
      def spacing : SpacingScale
        SpacingScale.new(
          px: 1.0 / 16.0,
          x0: 0.0,
          x0_5: 0.125,
          x1: 0.25,
          x1_5: 0.375,
          x2: 0.5,
          x2_5: 0.625,
          x3: 0.75,
          x3_5: 0.875,
          x4: 1.0,
          x5: 1.25,
          x6: 1.5,
          x7: 1.75,
          x8: 2.0,
          x9: 2.25,
          x10: 2.5,
          x11: 2.75,
          x12: 3.0,
          x14: 3.5,
          x16: 4.0,
          x20: 5.0,
          x24: 6.0,
          x28: 7.0,
          x32: 8.0,
          x36: 9.0,
          x40: 10.0,
          x44: 11.0,
          x48: 12.0,
          x52: 13.0,
          x56: 14.0,
          x60: 15.0,
          x64: 16.0,
          x72: 18.0,
          x80: 20.0,
          x96: 24.0,
        )
      end

      # The body/title/headline sizes are stored in rem (1rem == 16 logical
      # points). The Apple generator multiplies by 16 and overrides with
      # HIG-canonical sizes (17 pt body) only when the brand has not customized
      # the size — see `AppleGenerator` for the policy.
      def type_scale : TypeScale
        TypeScale.new(
          family_sans: "Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
          family_display: "Newsreader, Georgia, ui-serif, serif",
          family_mono: "ui-monospace, SFMono-Regular, \"SF Mono\", Consolas, monospace",
          caption: TypeStep.new(size: 0.78125, line_height: 1.4, weight: 450, tracking: 0.0),  # 12.5px
          body: TypeStep.new(size: 1.0, line_height: 1.55, weight: 450, tracking: 0.0),         # 16px
          body_emph: TypeStep.new(size: 1.0, line_height: 1.55, weight: 600, tracking: 0.0),    # 16px semibold
          title: TypeStep.new(size: 1.375, line_height: 1.3, weight: 600, tracking: 0.0),       # 22px
          headline: TypeStep.new(size: 2.125, line_height: 1.2, weight: 720, tracking: 0.0),    # 34px
          display: TypeStep.new(size: 3.0, line_height: 1.05, weight: 720, tracking: -0.01),    # 48px
        )
      end

      # Library-generic radius scale. Names: none / sm / md / lg / xl / x2l / pill.
      # Numeric values track `css_config.cr` `default_border_radius`.
      def radius_scale : RadiusScale
        RadiusScale.new(
          none: 0.0,
          xs: 0.25,            # 4pt — small bar / chip / micro chart corner
          sm: 0.125,           # 2pt — small inline element
          md: 0.375,           # 6pt — default control corner (button, field)
          lg: 0.5,             # 8pt — thumbnail / plot background
          xl: 0.75,            # 12pt — alert card
          x2l: 1.0,            # 16pt — action sheet / large glass surface
          card: 0.625,         # 10pt — inset-grouped card, popover, snackbar, tile
          sheet: 0.875,        # 14pt — sheet / glass card (slightly tighter than x2l)
          avatar: 1.875,       # 30pt — 60pt circular destination icon
          avatar_lg: 3.75,     # 60pt — 120pt circular hero (pie chart, large avatar)
          pill: 624.9375,      # 9999 / 16 — the canonical "pill" sentinel in rem.
        )
      end

      def shadow_scale : ShadowScale
        # Approximate the existing CSS strings ("0 1px 2px oklch(0 0 0 / 0.08), ...").
        # The exact spread of layers matches `amber_theme.cr` `ElevationScale`.
        raised = [
          ShadowLevel.new(
            offset_x: 0.0, offset_y: 0.0625, blur: 0.125, spread: 0.0,
            color: Color.oklch(0.0, 0.0, 0.0, 0.08),
          ),
          ShadowLevel.new(
            offset_x: 0.0, offset_y: 0.5, blur: 1.5, spread: 0.0,
            color: Color.oklch(0.18, 0.02, 248.0, 0.08),
          ),
        ]
        floating = [
          ShadowLevel.new(
            offset_x: 0.0, offset_y: 1.0, blur: 2.625, spread: 0.0,
            color: Color.oklch(0.18, 0.02, 248.0, 0.16),
          ),
        ]
        overlay = [
          ShadowLevel.new(
            offset_x: 0.0, offset_y: 1.5, blur: 5.0, spread: 0.0,
            color: Color.oklch(0.18, 0.02, 248.0, 0.22),
          ),
        ]
        ShadowScale.new(
          flat: [] of ShadowLevel,
          raised: raised,
          floating: floating,
          overlay: overlay,
        )
      end

      def motion_scale : MotionScale
        MotionScale.new(
          duration_instant_ms: 80,
          duration_fast_ms: 150,
          duration_base_ms: 240,
          duration_slow_ms: 420,
          ease_standard: "cubic-bezier(0.2, 0, 0, 1)",
          ease_emphasized: "cubic-bezier(0.16, 1, 0.3, 1)",
          spring: "linear(0, 0.35 25%, 1.08 70%, 1)",
        )
      end

      def breakpoints : Breakpoints
        Breakpoints.new(
          sm: 640.0,
          md: 768.0,
          lg: 1024.0,
          xl: 1280.0,
          x2l: 1536.0,
        )
      end
    end
  end
end
