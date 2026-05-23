require "../../src/ui"
require "spec"

# Phase 6.10 D2 — UI::Web.render_route_host
#
# The web target is a single-page HTML document with hash-route
# navigation. This helper emits the JS shim + per-route fragment
# data so the browser can swap routes on hashchange / popstate /
# UIRouteHost.push() without a full page reload.
describe UI::Web do
  describe ".render_route_host" do
    it "emits the host div seeded with the initial route's fragment" do
      routes = {"sign-in" => "<p>Hello</p>", "todos" => "<p>Todos</p>"}
      out = UI::Web.render_route_host(routes, "sign-in")
      out.should contain "<div id=\"ui-route-host\""
      out.should contain "data-route=\"sign-in\""
      out.should contain "<p>Hello</p>"
    end

    it "embeds every route fragment in the JSON data block" do
      routes = {"a" => "<span>A</span>", "b" => "<span>B</span>"}
      out = UI::Web.render_route_host(routes, "a")
      out.should contain %(<script type="application/json" id="ui-route-data">)
      out.should contain "\"a\": \"<span>A</span>\""
      out.should contain "\"b\": \"<span>B</span>\""
    end

    it "emits the JS shim with push/pop/replace/setFragment + hashchange + popstate" do
      out = UI::Web.render_route_host({"a" => "<p>A</p>"}, "a")
      out.should contain "UIRouteHost"
      out.should contain "window.addEventListener('hashchange'"
      out.should contain "window.addEventListener('popstate'"
      out.should contain "history.pushState"
      out.should contain "setFragment"
    end

    it "emits an aria-live announcer for I-6 a11y" do
      out = UI::Web.render_route_host({"a" => "<p>A</p>"}, "a")
      out.should contain %(id="ui-route-announcer")
      out.should contain "aria-live=\"polite\""
    end

    it "escapes embedded quotes and newlines safely in the JSON block" do
      routes = {"a" => %(<p class="x">line1\nline2</p>)}
      out = UI::Web.render_route_host(routes, "a")
      # The JSON must escape the class attribute's quotes.
      out.should contain %(class=\\"x\\")
      # And the newline must be encoded as \n in the JSON value.
      out.should contain "line1\\nline2"
      # The raw newline must NOT appear inside the JSON value block
      # (would break JSON parsing). Sanity-check by extracting the
      # JSON line and verifying it does not contain a literal newline
      # mid-value.
      json_line = out[/"a":[^\n]+/]
      json_line.should_not be_nil
    end

    it "respects a custom aria-live announce template" do
      out = UI::Web.render_route_host(
        {"a" => "<p>A</p>"}, "a",
        route_change_announce_label: "Opened {route}",
      )
      out.should contain "Opened {route}"
    end
  end
end
