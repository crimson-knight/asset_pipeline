require "./probe_store"

module UI::Probes
  # DismissProbe — Phase 3 rubric BX8.
  #
  # Backs the `phase-03-sheet-focus-return` slug. Each documented sheet
  # dismiss path (primary, cancel, swipe, backdrop, escape) writes a
  # canonical reason string into `last_reason`. A mirror Label reads it
  # so XCUITest / AXTest harnesses can assert which dismiss path fired.
  module DismissProbe
    @@last_reason : String = "none"

    def self.last_reason : String
      @@last_reason
    end

    def self.set(reason : String) : Nil
      @@last_reason = reason
      ProbeStore.instance.set("dismiss-reason", reason)
    end

    def self.reset : Nil
      @@last_reason = "none"
      ProbeStore.instance.set("dismiss-reason", "none")
    end

    def self.current_text : String
      @@last_reason
    end
  end
end
