module Components
  module CSS
    module Tokens
      record Palette,
        name : String,
        stops : Hash(String, String)

      record SemanticColor,
        indicator : String,
        bg : String,
        bg_hover : String,
        border : String,
        text : String,
        focus_ring : String

      record StateScale,
        default : String,
        hover : String,
        active : String,
        selected : String,
        disabled : String,
        loading : String

      record TypographyScale,
        sans : String,
        display : String,
        mono : String,
        body_size : String,
        body_line_height : String,
        paragraph_size : String,
        paragraph_line_height : String,
        heading_weight : String,
        body_weight : String

      record MotionScale,
        duration_instant : String,
        duration_fast : String,
        duration_base : String,
        duration_slow : String,
        ease_standard : String,
        ease_emphasized : String,
        spring : String,
        distance_subtle : String

      record ElevationScale,
        flat : String,
        raised : String,
        floating : String,
        overlay : String

      record RadiusScale,
        control : String,
        card : String,
        panel : String,
        pill : String

      # Web-first design-token contract.
      #
      # The current default palette grew out of the Amber project, but the
      # public component API should use generic design-system names.
      class Theme
        getter light : Hash(String, String)
        getter dark : Hash(String, String)
        getter palettes : Hash(String, Palette)
        getter intents : Hash(String, SemanticColor)
        getter states : StateScale
        getter typography : TypographyScale
        getter motion : MotionScale
        getter elevation : ElevationScale
        getter radius : RadiusScale

        @overrides : Hash(String, String)
        @dark_overrides : Hash(String, String)

        def initialize(
          @light : Hash(String, String),
          @dark : Hash(String, String),
          @palettes : Hash(String, Palette),
          @intents : Hash(String, SemanticColor),
          @states : StateScale,
          @typography : TypographyScale,
          @motion : MotionScale,
          @elevation : ElevationScale,
          @radius : RadiusScale,
        )
          @overrides = {} of String => String
          @dark_overrides = {} of String => String
        end

        def self.amber_default : Theme
          light = {
            "brand-primary"        => "oklch(0.52 0.16 50)",
            "brand-secondary"      => "oklch(0.47 0.15 265)",
            "brand-accent"         => "oklch(0.73 0.15 190)",
            "brand-primary-hover"  => "oklch(0.47 0.17 48)",
            "brand-primary-active" => "oklch(0.4 0.15 46)",

            "surface-canvas"   => "oklch(0.985 0.009 82)",
            "surface-panel"    => "oklch(1 0 0)",
            "surface-elevated" => "oklch(0.995 0.003 80)",
            "surface-sunken"   => "oklch(0.955 0.011 79)",
            "surface-inverse"  => "oklch(0.18 0.018 248)",

            "text-primary"   => "oklch(0.18 0.018 248)",
            "text-secondary" => "oklch(0.38 0.028 248)",
            "text-muted"     => "oklch(0.52 0.025 248)",
            "text-inverse"   => "oklch(0.99 0.003 80)",
            "text-link"      => "oklch(0.5 0.13 235)",

            "border-subtle"    => "oklch(0.91 0.014 82)",
            "border-default"   => "oklch(0.82 0.021 82)",
            "border-strong"    => "oklch(0.62 0.04 75)",
            "border-focus"     => "oklch(0.66 0.15 50 / 0.58)",
            "focus-ring-solid" => "rgb(12 112 214)",

            "success-indicator"  => "oklch(0.47 0.12 155)",
            "success-bg"         => "oklch(0.95 0.035 153)",
            "success-bg-hover"   => "oklch(0.9 0.06 153)",
            "success-border"     => "oklch(0.73 0.09 153)",
            "success-text"       => "oklch(0.31 0.09 153)",
            "success-focus-ring" => "oklch(0.67 0.13 153 / 0.45)",

            "warning-indicator"  => "oklch(0.58 0.15 75)",
            "warning-bg"         => "oklch(0.96 0.052 82)",
            "warning-bg-hover"   => "oklch(0.91 0.08 82)",
            "warning-border"     => "oklch(0.75 0.12 78)",
            "warning-text"       => "oklch(0.36 0.09 70)",
            "warning-focus-ring" => "oklch(0.72 0.12 78 / 0.45)",

            "danger-indicator"  => "oklch(0.45 0.18 28)",
            "danger-bg"         => "oklch(0.96 0.025 28)",
            "danger-bg-hover"   => "oklch(0.9 0.055 28)",
            "danger-border"     => "oklch(0.75 0.12 28)",
            "danger-text"       => "oklch(0.36 0.15 28)",
            "danger-focus-ring" => "oklch(0.64 0.17 28 / 0.45)",

            "info-indicator"  => "oklch(0.48 0.13 235)",
            "info-bg"         => "oklch(0.95 0.03 235)",
            "info-bg-hover"   => "oklch(0.9 0.055 235)",
            "info-border"     => "oklch(0.72 0.09 235)",
            "info-text"       => "oklch(0.34 0.1 235)",
            "info-focus-ring" => "oklch(0.62 0.14 235 / 0.45)",

            "state-default"  => "var(--ap-color-surface-panel)",
            "state-hover"    => "oklch(0.96 0.014 78)",
            "state-active"   => "oklch(0.91 0.028 74)",
            "state-selected" => "oklch(0.92 0.07 58)",
            "state-disabled" => "oklch(0.9 0.006 248 / 0.68)",
            "state-loading"  => "oklch(0.93 0.018 235)",
          }

          dark = {
            "brand-primary"        => "oklch(0.78 0.17 58)",
            "brand-secondary"      => "oklch(0.75 0.12 265)",
            "brand-accent"         => "oklch(0.8 0.14 190)",
            "brand-primary-hover"  => "oklch(0.84 0.15 60)",
            "brand-primary-active" => "oklch(0.7 0.18 54)",

            "surface-canvas"   => "oklch(0.15 0.025 260)",
            "surface-panel"    => "oklch(0.2 0.024 260)",
            "surface-elevated" => "oklch(0.25 0.028 260)",
            "surface-sunken"   => "oklch(0.12 0.022 260)",
            "surface-inverse"  => "oklch(0.95 0.006 80)",

            "text-primary"   => "oklch(0.95 0.006 80)",
            "text-secondary" => "oklch(0.78 0.015 85)",
            "text-muted"     => "oklch(0.65 0.018 85)",
            "text-inverse"   => "oklch(0.18 0.018 248)",
            "text-link"      => "oklch(0.77 0.1 225)",

            "border-subtle"    => "oklch(0.31 0.02 248)",
            "border-default"   => "oklch(0.38 0.025 248)",
            "border-strong"    => "oklch(0.52 0.03 248)",
            "border-focus"     => "oklch(0.75 0.14 58 / 0.62)",
            "focus-ring-solid" => "rgb(132 184 255)",

            "success-indicator"  => "oklch(0.72 0.14 153)",
            "success-bg"         => "oklch(0.25 0.045 153)",
            "success-bg-hover"   => "oklch(0.31 0.065 153)",
            "success-border"     => "oklch(0.54 0.09 153)",
            "success-text"       => "oklch(0.84 0.09 153)",
            "success-focus-ring" => "oklch(0.74 0.12 153 / 0.5)",

            "warning-indicator"  => "oklch(0.8 0.15 78)",
            "warning-bg"         => "oklch(0.28 0.052 78)",
            "warning-bg-hover"   => "oklch(0.34 0.075 78)",
            "warning-border"     => "oklch(0.58 0.12 78)",
            "warning-text"       => "oklch(0.88 0.1 82)",
            "warning-focus-ring" => "oklch(0.78 0.12 78 / 0.5)",

            "danger-indicator"  => "oklch(0.72 0.18 28)",
            "danger-bg"         => "oklch(0.25 0.06 28)",
            "danger-bg-hover"   => "oklch(0.31 0.085 28)",
            "danger-border"     => "oklch(0.55 0.13 28)",
            "danger-text"       => "oklch(0.86 0.09 28)",
            "danger-focus-ring" => "oklch(0.75 0.16 28 / 0.5)",

            "info-indicator"  => "oklch(0.72 0.12 235)",
            "info-bg"         => "oklch(0.25 0.045 235)",
            "info-bg-hover"   => "oklch(0.31 0.065 235)",
            "info-border"     => "oklch(0.55 0.1 235)",
            "info-text"       => "oklch(0.84 0.08 235)",
            "info-focus-ring" => "oklch(0.75 0.12 235 / 0.5)",

            "state-default"  => "var(--ap-color-surface-panel)",
            "state-hover"    => "oklch(0.27 0.022 248)",
            "state-active"   => "oklch(0.32 0.026 248)",
            "state-selected" => "oklch(0.3 0.062 58)",
            "state-disabled" => "oklch(0.42 0.012 248 / 0.56)",
            "state-loading"  => "oklch(0.29 0.04 235)",
          }

          palettes = {
            "amber" => Palette.new("amber", {
              "50"  => "oklch(0.98 0.018 78)",
              "500" => light["brand-primary"],
              "700" => light["brand-primary-active"],
            }),
            "slate" => Palette.new("slate", {
              "50"  => "oklch(0.985 0.003 248)",
              "500" => "oklch(0.52 0.025 248)",
              "900" => "oklch(0.18 0.018 248)",
            }),
            "teal" => Palette.new("teal", {
              "100" => "oklch(0.93 0.04 170)",
              "500" => light["brand-accent"],
              "800" => "oklch(0.35 0.09 170)",
            }),
          }

          intents = {
            "success" => semantic_from(light, "success"),
            "warning" => semantic_from(light, "warning"),
            "danger"  => semantic_from(light, "danger"),
            "info"    => semantic_from(light, "info"),
          }

          typography = TypographyScale.new(
            sans: "Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
            display: "Newsreader, Georgia, ui-serif, serif",
            mono: "ui-monospace, SFMono-Regular, \"SF Mono\", Consolas, monospace",
            body_size: "1rem",
            body_line_height: "1.55",
            paragraph_size: "1.03125rem",
            paragraph_line_height: "1.72",
            heading_weight: "720",
            body_weight: "450",
          )

          motion = MotionScale.new(
            duration_instant: "80ms",
            duration_fast: "150ms",
            duration_base: "240ms",
            duration_slow: "420ms",
            ease_standard: "cubic-bezier(0.2, 0, 0, 1)",
            ease_emphasized: "cubic-bezier(0.16, 1, 0.3, 1)",
            spring: "linear(0, 0.35 25%, 1.08 70%, 1)",
            distance_subtle: "0.375rem",
          )

          new(
            light: light,
            dark: dark,
            palettes: palettes,
            intents: intents,
            states: StateScale.new(
              default: light["state-default"],
              hover: light["state-hover"],
              active: light["state-active"],
              selected: light["state-selected"],
              disabled: light["state-disabled"],
              loading: light["state-loading"],
            ),
            typography: typography,
            motion: motion,
            elevation: ElevationScale.new(
              flat: "none",
              raised: "0 1px 2px oklch(0 0 0 / 0.08), 0 8px 24px oklch(0.18 0.02 248 / 0.08)",
              floating: "0 16px 42px oklch(0.18 0.02 248 / 0.16)",
              overlay: "0 24px 80px oklch(0.18 0.02 248 / 0.22)",
            ),
            radius: RadiusScale.new(
              control: "0.5rem",
              card: "0.5rem",
              panel: "0.75rem",
              pill: "999px",
            ),
          )
        end

        def self.design_system_default : Theme
          amber_default
        end

        def override_token(name : String, value : String, dark_value : String? = nil) : self
          @overrides[name] = value
          @dark_overrides[name] = dark_value if dark_value
          self
        end

        def override_tokens(values : Hash(String, String), dark_values : Hash(String, String) = {} of String => String) : self
          values.each { |name, value| @overrides[name] = value }
          dark_values.each { |name, value| @dark_overrides[name] = value }
          self
        end

        def css_variables(scheme : Symbol = :light) : Hash(String, String)
          values = scheme == :dark ? @dark.dup : @light.dup
          @overrides.each { |name, value| values[name] = value }
          @dark_overrides.each { |name, value| values[name] = value } if scheme == :dark

          vars = {} of String => String
          values.each do |name, value|
            add_design_system_variable(vars, "color-#{name}", value)
          end

          add_design_system_variable(vars, "font-sans", typography.sans)
          add_design_system_variable(vars, "font-display", typography.display)
          add_design_system_variable(vars, "font-mono", typography.mono)
          add_design_system_variable(vars, "type-body-size", typography.body_size)
          add_design_system_variable(vars, "type-body-line-height", typography.body_line_height)
          add_design_system_variable(vars, "type-paragraph-size", typography.paragraph_size)
          add_design_system_variable(vars, "type-paragraph-line-height", typography.paragraph_line_height)
          add_design_system_variable(vars, "type-heading-weight", typography.heading_weight)
          add_design_system_variable(vars, "type-body-weight", typography.body_weight)

          add_design_system_variable(vars, "motion-duration-instant", motion.duration_instant)
          add_design_system_variable(vars, "motion-duration-fast", motion.duration_fast)
          add_design_system_variable(vars, "motion-duration-base", motion.duration_base)
          add_design_system_variable(vars, "motion-duration-slow", motion.duration_slow)
          add_design_system_variable(vars, "motion-ease-standard", motion.ease_standard)
          add_design_system_variable(vars, "motion-ease-emphasized", motion.ease_emphasized)
          add_design_system_variable(vars, "motion-spring", motion.spring)
          add_design_system_variable(vars, "motion-distance-subtle", motion.distance_subtle)

          add_design_system_variable(vars, "elevation-flat", elevation.flat)
          add_design_system_variable(vars, "elevation-raised", elevation.raised)
          add_design_system_variable(vars, "elevation-floating", elevation.floating)
          add_design_system_variable(vars, "elevation-overlay", elevation.overlay)

          add_design_system_variable(vars, "radius-control", radius.control)
          add_design_system_variable(vars, "radius-card", radius.card)
          add_design_system_variable(vars, "radius-panel", radius.panel)
          add_design_system_variable(vars, "radius-pill", radius.pill)

          vars
        end

        def to_css_variables(scheme : Symbol = :light) : String
          String.build do |io|
            css_variables(scheme).each do |name, value|
              io << "#{name}: #{value};\n"
            end
          end
        end

        private def self.semantic_from(values : Hash(String, String), name : String) : SemanticColor
          SemanticColor.new(
            indicator: values["#{name}-indicator"],
            bg: values["#{name}-bg"],
            bg_hover: values["#{name}-bg-hover"],
            border: values["#{name}-border"],
            text: values["#{name}-text"],
            focus_ring: values["#{name}-focus-ring"],
          )
        end

        private def add_design_system_variable(vars : Hash(String, String), name : String, value : String) : Nil
          generic_name = "--ap-#{name}"
          vars[generic_name] = value.gsub("--amber-", "--ap-")
          vars["--amber-#{name}"] = "var(#{generic_name})"
        end
      end
    end
  end
end
