require "./views/*"

module UI
  # Abstract visitor for platform-specific rendering of UI views.
  #
  # Each concrete platform renderer (macOS/AppKit, iOS/UIKit, Android,
  # Web/HTML) implements this interface. The visitor pattern decouples
  # the view tree structure from rendering logic, allowing the same
  # view hierarchy to be rendered natively on any target platform.
  #
  # Example:
  #   class WebRenderer < UI::PlatformVisitor
  #     def visit(view : UI::Label)
  #       # emit <span> element
  #     end
  #     # ... implement all visit methods
  #   end
  abstract class PlatformVisitor
    abstract def visit(view : Label)
    abstract def visit(view : Button)
    abstract def visit(view : VStack)
    abstract def visit(view : HStack)
    abstract def visit(view : ZStack)
    abstract def visit(view : Image)
    abstract def visit(view : TextField)
    abstract def visit(view : ScrollView)
    abstract def visit(view : Spacer)
  end
end
