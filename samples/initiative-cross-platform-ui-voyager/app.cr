# Phase 6.10 — Voyager demo app.
#
# A navigable Todos CRUD demo built on the new
# UI::NavigationCoordinator + UI::SwipeActionRow primitives. A single
# Crystal source compiles to web (HTML w/ hash-route navigation),
# macOS (AppKit .app with NSWindow contentView swap), and iOS (UIKit
# .app with SwiftUI @State trampoline).
#
# Routes (5):
#   :sign_in       -> SignInScreen
#   :todos         -> TodosScreen
#   :todo_editor   -> TodoEditorScreen (params: id => todo id, or "0")
#   :settings      -> SettingsScreen
#
# State-propagation litmus (per brief): toggle Settings.hide_completed
# → tap back → Todos list AND chart reflect immediately. Verified
# by build_route always pulling state.visible_todos at render time
# (no caching across pops).

require "../../src/ui"
require "./brand"
require "./screens/state"
require "./screens/sign_in"
require "./screens/todos"
require "./screens/todo_editor"
require "./screens/settings"

module Voyager
  SLUGS = ["voyager-sign-in", "voyager-todos", "voyager-todo-editor", "voyager-settings"]

  # Build a View tree for the given Route + State. The route's params
  # carry per-route arguments (e.g. todo_editor's :id).
  def self.build_route(state : State, coord : UI::NavigationCoordinator, route : UI::NavigationCoordinator::Route) : UI::View
    case route.id
    when :sign_in
      SignInScreen.build(state, coord)
    when :todos
      TodosScreen.build(state, coord)
    when :todo_editor
      id = (route.params[:id]? || "0").to_i? || 0
      TodoEditorScreen.build(state, coord, id)
    when :settings
      SettingsScreen.build(state, coord)
    else
      placeholder = UI::Label.new("Unknown route: #{route.id}")
      placeholder.accessibility_label = "Unknown route"
      placeholder.as(UI::View)
    end
  end

  # Map a static slug ("voyager-todos") to a Route. Used by the web
  # static-site generator (which renders one fragment per known slug
  # at build time) and by the iOS/macOS hosts when they need to
  # pre-build a route by name.
  def self.route_for_slug(slug : String) : UI::NavigationCoordinator::Route
    case slug
    when "voyager-sign-in"     then UI::NavigationCoordinator::Route.new(:sign_in)
    when "voyager-todos"       then UI::NavigationCoordinator::Route.new(:todos)
    when "voyager-todo-editor" then UI::NavigationCoordinator::Route.new(:todo_editor)
    when "voyager-settings"    then UI::NavigationCoordinator::Route.new(:settings)
    else                            UI::NavigationCoordinator::Route.new(:sign_in)
    end
  end

  # Slug for a Route.id (inverse of route_for_slug). Used by the
  # web renderer's UIRouteHost push glue.
  def self.slug_for_route_id(route_id : Symbol) : String
    case route_id
    when :sign_in     then "voyager-sign-in"
    when :todos       then "voyager-todos"
    when :todo_editor then "voyager-todo-editor"
    when :settings    then "voyager-settings"
    else                   "voyager-sign-in"
    end
  end
end
