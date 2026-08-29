# Phase 8D.2 — flag-agnostic host bootstrap helper.
#
# Encapsulates the canonical dispatcher construction sequence so the
# iOS bridge AND any future host can call ONE primitive instead of
# duplicating the order. The macOS host predates this helper and may
# be migrated to it in a follow-up cleanup; it is NOT in 8D.2 scope.
#
# Returns a `Bootstrap::Result` struct carrying all the constructed
# collaborators. Caller is responsible for pinning them per its own
# GC discipline (iOS class-vars; macOS local vars).
#
# Per Codex HIGH 4 + R11 elevation in brief-8d.2.md: extracting this
# sequence makes the runtime invariants ("bootstrap before construct",
# "mount_screen before any render", "assign Voyager.state and
# Voyager.dispatcher exactly once") testable under default `crystal
# spec` — no `-Dios` required because the helper does not depend on
# the UIKit renderer.

require "./app"

module Voyager
  module HostBootstrap
    record Result,
      state : Voyager::State,
      coord : UI::NavigationCoordinator,
      session : UI::Session::InProcess,
      flash : UI::Flash::InProcess,
      dispatcher : UI::ActionDispatcher

    # Build the full host substrate. Calls `VoyagerApp.bootstrap!`,
    # constructs state + coord + session + flash + dispatcher, calls
    # `dispatcher.mount_screen` for the initial route, assigns
    # `Voyager.state` and `Voyager.dispatcher`. Returns the constructed
    # collaborators for host-level pinning.
    #
    # Phase 10D — `platform` arg is now wired through to the dispatcher
    # so `UI::WidgetRoute.resolve` returns the correct widget for the running
    # target. iOS / macOS bridge files set this explicitly; defaults to
    # the Crystal compile-time flag (`:ios` under `-Dios`, `:macos`
    # under `-Dmacos`, `:web_wide` otherwise).
    def self.build(initial_route_id : Symbol = :sign_in,
                   platform : Symbol = default_platform) : Result
      VoyagerApp.bootstrap!

      # Test determinism: VOYAGER_RESET_PREFS=1 wipes persisted settings BEFORE
      # State.new reads them, so UI tests start from known defaults despite the
      # new UI::Preferences persistence. No-op in normal use.
      UI::Preferences.clear_all if ENV["VOYAGER_RESET_PREFS"]? == "1"

      state = Voyager::State.new
      Voyager.state = state

      coord = UI::NavigationCoordinator.new(
        UI::NavigationCoordinator::Route.new(initial_route_id)
      )
      session = UI::Session::InProcess.new
      flash = UI::Flash::InProcess.new
      dispatcher = UI::ActionDispatcher.new(
        app: VoyagerApp,
        navigation: coord,
        session: session,
        flash: flash,
        design_tokens: UI::DesignTokens::Tokens.default,
        platform: platform,
      )
      dispatcher.mount_screen(coord.current)
      Voyager.dispatcher = dispatcher

      # Cohesion payoff: when an agent notification is delivered while the app is
      # open, read it aloud (UI::Notifications foreground delivery → UI::Speech).
      # The agent reaches you AND talks to you — on macOS, iOS, and the wrist.
      # Installs the platform UNUserNotificationCenter delegate; no-op on web.
      UI::Notifications.on_foreground { |body| UI::Speech.speak(body, rate: Voyager.state.speech_rate) }

      Result.new(
        state: state,
        coord: coord,
        session: session,
        flash: flash,
        dispatcher: dispatcher,
      )
    end

    # Compile-time-derived default platform. Mirrors the same
    # platform-symbol lookup `UI::Environment.platform` does so the
    # dispatcher's intent resolver picks the right widget on every
    # build target.
    def self.default_platform : Symbol
      {% if flag?(:macos) %}
        :macos
      {% elsif flag?(:ipados) %}
        :ipados
      {% elsif flag?(:ios) %}
        :ios
      {% elsif flag?(:watchos) %}
        :watchos
      {% elsif flag?(:android) %}
        :android
      {% else %}
        :web_wide
      {% end %}
    end
  end
end
