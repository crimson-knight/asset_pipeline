# Embedded web content view backed by WKWebView / WebView2.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # WebViewComponent — Embedded web content view backed by WKWebView / WebView2.
  class WebViewComponent < View
    # URL the view points at.
    property url : String = ""
    # Text value.
    property html : String? = nil
    # Text value.
    property base_url : String? = nil
    # Boolean toggle.
    property allows_navigation : Bool = true
    # Boolean toggle.
    property allows_scripts : Bool = true
    # Primary text shown on the control.
    property title : String? = nil
    property on_navigation_request : Proc(String, Bool)? = nil
    property on_navigation_start : Proc(String, Nil)? = nil
    property on_navigation_finish : Proc(String, Nil)? = nil

    def initialize(@url : String = "")
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:group`.
    def default_accessibility_role : Symbol?
      :group
    end
  end
end
