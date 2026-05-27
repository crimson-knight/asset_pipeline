module Voyager
  # Phase 10D — module-singleton state for the Phase 10 exerciser screens.
  #
  # Holds transient strings the exerciser screens read on every render —
  # the most recent dispatch result, the most recent swipe-action tap,
  # the most recent paste payload, and toggles for the new-widgets demo.
  #
  # Why module-singleton instead of `Voyager::State` fields:
  # the Phase 10 exerciser is sample-local and read-only feedback for
  # the hand-tester; it does not belong in the canonical app state.
  # Module class vars are nilable-by-default so the iOS class-init gap
  # cannot strand them (per
  # `project_crystal_ios_class_init_gap` memory).
  module Phase10ExerciserState
    @@last_action : String = "(none yet)"
    @@last_dispatch_result : String = "(none yet)"
    @@last_paste_value : String = "(empty)"
    @@last_dispatched_intent : String = "(none yet)"
    @@full_screen_cover_presented : Bool = false
    @@inspector_presented : Bool = true

    def self.last_action : String
      @@last_action
    end

    def self.last_action=(value : String) : String
      @@last_action = value
    end

    def self.last_dispatch_result : String
      @@last_dispatch_result
    end

    def self.last_dispatch_result=(value : String) : String
      @@last_dispatch_result = value
    end

    def self.last_paste_value : String
      @@last_paste_value
    end

    def self.last_paste_value=(value : String) : String
      @@last_paste_value = value
    end

    def self.last_dispatched_intent : String
      @@last_dispatched_intent
    end

    def self.last_dispatched_intent=(value : String) : String
      @@last_dispatched_intent = value
    end

    def self.full_screen_cover_presented : Bool
      @@full_screen_cover_presented
    end

    def self.full_screen_cover_presented=(value : Bool) : Bool
      @@full_screen_cover_presented = value
    end

    def self.inspector_presented : Bool
      @@inspector_presented
    end

    def self.inspector_presented=(value : Bool) : Bool
      @@inspector_presented = value
    end

    # Format a `UI::Intent::DispatchResult` for visible display in the
    # exerciser screen. Three branches: Success, Unsupported(reason),
    # Failed(reason).
    def self.format_result(result : UI::Intent::DispatchResult) : String
      case result
      when .success?
        "Success"
      when .unsupported?
        "Unsupported: #{result.reason}"
      when .failed?
        "Failed: #{result.reason}"
      else
        "Unknown DispatchResult"
      end
    end
  end
end
