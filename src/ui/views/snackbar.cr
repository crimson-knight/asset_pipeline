# Transient toast / snackbar notification anchored to the bottom of the screen.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

module UI
  # Snackbar — Transient toast / snackbar notification anchored to the bottom of the screen.
  class Snackbar < View
    property message : String
    property action_label : String? = nil
    property duration : Float64 = 4.0  # seconds
    property is_presented : Bool = false
    property on_action : Proc(Nil)? = nil
    property on_dismiss : Proc(Nil)? = nil

    def initialize(@message : String, @action_label : String? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end

  class SnackbarPresenter
    property snackbar : Snackbar
    property is_presenting : Bool = false

    def initialize(@snackbar : Snackbar)
    end

    def show
      @is_presenting = true
      @snackbar.is_presented = true
    end

    def dismiss
      @is_presenting = false
      @snackbar.is_presented = false
      @snackbar.on_dismiss.try(&.call)
    end
  end
end
