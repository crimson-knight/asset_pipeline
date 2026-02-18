require "../platform_visitor"
require "../../components"

module UI
  module Web
    # Renders a UI view tree to HTML using the Components::Elements system.
    #
    # The renderer walks the view tree via the visitor pattern and produces
    # an equivalent DOM tree built from `Components::Elements` classes.
    # Call `render` on a view to get the final HTML string.
    #
    # Example:
    #   label = UI::Label.new("Hello")
    #   renderer = UI::Web::Renderer.new
    #   label.accept(renderer)
    #   renderer.output # => "<span style=\"font-size: 17.0px; color: rgba(0, 0, 0, 1.0); text-align: left\">Hello</span>"
    class Renderer < UI::PlatformVisitor
      # Stack of elements being built. The top of the stack is the current
      # parent container that child elements will be added to.
      @element_stack : Array(Components::Elements::HTMLElement)

      # The root element produced by the most recent `visit` call at the
      # top level.
      @root : Components::Elements::HTMLElement?

      def initialize
        @element_stack = [] of Components::Elements::HTMLElement
        @root = nil
      end

      # Returns the rendered HTML string for the view tree.
      def output : String
        @root.try(&.render) || ""
      end

      # Convenience method: accept a view and return the HTML string.
      def render(view : UI::View) : String
        view.accept(self)
        output
      end

      # ---------------------------------------------------------------
      # Visit methods
      # ---------------------------------------------------------------

      def visit(view : UI::Label)
        el = Components::Elements::Span.new
        el << view.text

        # Font styles
        apply_font_styles(el, view.font)

        # Text color
        c = view.text_color
        el.add_style("color: rgba(#{to_rgb_int(c.r)}, #{to_rgb_int(c.g)}, #{to_rgb_int(c.b)}, #{c.a})")

        # Text alignment
        el.add_style("text-align: #{alignment_to_css(view.text_alignment)}")

        # Line clamping
        if view.number_of_lines > 0
          el.add_style("display: -webkit-box; -webkit-line-clamp: #{view.number_of_lines}; -webkit-box-orient: vertical; overflow: hidden")
        end

        apply_common_styles(el, view)
        push_element(el)
      end

      def visit(view : UI::Button)
        el = Components::Elements::Button.new(type: "button")
        el << view.label

        # Font styles
        apply_font_styles(el, view.font)

        # Foreground color
        c = view.foreground_color
        el.add_style("color: rgba(#{to_rgb_int(c.r)}, #{to_rgb_int(c.g)}, #{to_rgb_int(c.b)}, #{c.a})")

        # Disabled state
        if view.disabled
          el.set_attribute("disabled", "disabled")
        end

        # Action identifier (data attribute for JS binding)
        if view.on_tap
          el.set_attribute("data-action", "click")
        end

        # Accessibility
        if label = view.accessibility_label
          el.set_attribute("aria-label", label)
        end

        apply_common_styles(el, view)
        push_element(el)
      end

      def visit(view : UI::VStack)
        el = Components::Elements::Div.new
        el.add_style("display: flex; flex-direction: column; gap: #{view.spacing}px")

        # Alignment maps to align-items for the cross axis
        el.add_style("align-items: #{stack_align_items(view.alignment)}")

        apply_common_styles(el, view)

        # Push as current parent, visit children, pop
        push_container(el) do
          view.children.each { |child| child.accept(self) }
        end
      end

      def visit(view : UI::HStack)
        el = Components::Elements::Div.new
        el.add_style("display: flex; flex-direction: row; gap: #{view.spacing}px")

        # Alignment maps to align-items for the cross axis
        el.add_style("align-items: #{stack_align_items(view.alignment)}")

        apply_common_styles(el, view)

        push_container(el) do
          view.children.each { |child| child.accept(self) }
        end
      end

      def visit(view : UI::ZStack)
        el = Components::Elements::Div.new
        el.add_style("position: relative")

        apply_common_styles(el, view)

        # ZStack children need position: absolute (except the first which
        # establishes the size). We track the index during iteration.
        @element_stack.push(el)
        view.children.each_with_index do |child, index|
          child.accept(self)
          # After visiting the child, the last child added to el needs
          # position: absolute if it's not the first child.
          if index > 0
            last_child = el.children.last?
            if last_child.is_a?(Components::Elements::HTMLElement)
              last_child.add_style("position: absolute; top: 0; left: 0")
            end
          end
        end
        @element_stack.pop

        if parent = @element_stack.last?
          parent.as(Components::Elements::ContainerElement).add_child(el)
        else
          @root = el
        end
      end

      def visit(view : UI::Image)
        el = Components::Elements::Img.new
        el.set_attribute("src", view.source)
        el.set_attribute("alt", view.accessibility_label || view.source)

        # Content mode -> object-fit
        case view.content_mode
        when ContentMode::Fit
          el.add_style("object-fit: contain")
        when ContentMode::Fill
          el.add_style("object-fit: cover")
        when ContentMode::Stretch
          el.add_style("object-fit: fill")
        end

        # Tint color (CSS filter approach)
        if tint = view.tint_color
          el.add_style("filter: drop-shadow(0 0 0 rgba(#{to_rgb_int(tint.r)}, #{to_rgb_int(tint.g)}, #{to_rgb_int(tint.b)}, #{tint.a}))")
        end

        apply_common_styles(el, view)
        push_element(el)
      end

      def visit(view : UI::TextField)
        el = Components::Elements::Input.new

        # Input type based on secure_entry
        if view.secure_entry
          el.set_attribute("type", "password")
        else
          el.set_attribute("type", "text")
        end

        # Placeholder
        unless view.placeholder.empty?
          el.set_attribute("placeholder", view.placeholder)
        end

        # Current value
        unless view.text.empty?
          el.set_attribute("value", view.text)
        end

        # Keyboard type -> inputmode attribute
        case view.keyboard_type
        when KeyboardType::EmailAddress
          el.set_attribute("inputmode", "email")
        when KeyboardType::NumberPad
          el.set_attribute("inputmode", "numeric")
        when KeyboardType::PhonePad
          el.set_attribute("inputmode", "tel")
        when KeyboardType::URL
          el.set_attribute("inputmode", "url")
        end

        # Font and text color
        apply_font_styles(el, view.font)
        c = view.text_color
        el.add_style("color: rgba(#{to_rgb_int(c.r)}, #{to_rgb_int(c.g)}, #{to_rgb_int(c.b)}, #{c.a})")

        apply_common_styles(el, view)
        push_element(el)
      end

      def visit(view : UI::ScrollView)
        el = Components::Elements::Div.new

        # Overflow based on scroll axes
        case {view.scroll_horizontal, view.scroll_vertical}
        when {true, true}
          el.add_style("overflow: auto")
        when {true, false}
          el.add_style("overflow-x: auto; overflow-y: hidden")
        when {false, true}
          el.add_style("overflow-x: hidden; overflow-y: auto")
        else
          el.add_style("overflow: hidden")
        end

        apply_common_styles(el, view)

        # Visit the content child if present
        if content = view.content
          push_container(el) do
            content.accept(self)
          end
        else
          push_element(el)
        end
      end

      def visit(view : UI::Spacer)
        el = Components::Elements::Div.new
        el.add_style("flex: 1 1 0%")

        if view.min_length > 0
          el.add_style("min-height: #{view.min_length}px; min-width: #{view.min_length}px")
        end

        apply_common_styles(el, view)
        push_element(el)
      end

      # ---------------------------------------------------------------
      # Private helpers
      # ---------------------------------------------------------------

      # Apply common View base-class styles to any element.
      private def apply_common_styles(el : Components::Elements::HTMLElement, view : UI::View)
        # Padding
        p = view.padding
        if p.top != 0.0 || p.trailing != 0.0 || p.bottom != 0.0 || p.leading != 0.0
          el.add_style("padding: #{p.top}px #{p.trailing}px #{p.bottom}px #{p.leading}px")
        end

        # Background color
        if bg = view.background
          el.add_style("background-color: rgba(#{to_rgb_int(bg.r)}, #{to_rgb_int(bg.g)}, #{to_rgb_int(bg.b)}, #{bg.a})")
        end

        # Hidden
        if view.hidden
          el.add_style("display: none")
        end

        # Opacity
        if view.opacity < 1.0
          el.add_style("opacity: #{view.opacity}")
        end

        # View ID -> HTML id
        if id = view.id
          el.set_attribute("id", id)
        end

        # Accessibility label -> aria-label (only if not already set)
        if label = view.accessibility_label
          unless el["aria-label"]
            el.set_attribute("aria-label", label)
          end
        end
      end

      # Apply font properties as inline CSS.
      private def apply_font_styles(el : Components::Elements::HTMLElement, font : UI::Font)
        el.add_style("font-size: #{font.size}px")

        unless font.family == "system"
          el.add_style("font-family: #{font.family}")
        end

        case font.weight
        when :bold
          el.add_style("font-weight: bold")
        when :semibold
          el.add_style("font-weight: 600")
        when :medium
          el.add_style("font-weight: 500")
        when :light
          el.add_style("font-weight: 300")
        when :thin
          el.add_style("font-weight: 100")
        end
        # :regular is the default, no need to emit

        if font.italic
          el.add_style("font-style: italic")
        end
      end

      # Convert a UI::Alignment to a CSS text-align value.
      private def alignment_to_css(alignment : UI::Alignment) : String
        case alignment
        when Alignment::Leading  then "left"
        when Alignment::Center   then "center"
        when Alignment::Trailing then "right"
        else                          "left"
        end
      end

      # Convert a UI::Alignment to a CSS align-items value for stacks.
      private def stack_align_items(alignment : UI::Alignment) : String
        case alignment
        when Alignment::Leading  then "flex-start"
        when Alignment::Center   then "center"
        when Alignment::Trailing then "flex-end"
        when Alignment::Top      then "flex-start"
        when Alignment::Bottom   then "flex-end"
        when Alignment::Fill     then "stretch"
        else                          "center"
        end
      end

      # Convert a 0.0-1.0 color component to a 0-255 integer.
      private def to_rgb_int(value : Float64) : Int32
        (value * 255).round.to_i.clamp(0, 255)
      end

      # Push an element as either a child of the current parent or as root.
      private def push_element(el : Components::Elements::HTMLElement)
        if parent = @element_stack.last?
          parent.as(Components::Elements::ContainerElement).add_child(el)
        else
          @root = el
        end
      end

      # Push a container element onto the stack, execute the block (which
      # visits children and adds them to this container), then pop and
      # register the container with its own parent or as root.
      private def push_container(el : Components::Elements::ContainerElement, &)
        @element_stack.push(el)
        yield
        @element_stack.pop

        if parent = @element_stack.last?
          parent.as(Components::Elements::ContainerElement).add_child(el)
        else
          @root = el
        end
      end
    end
  end
end
