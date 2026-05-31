module Voyager
  # Module-singleton state for the Component Gallery's live-interaction
  # section. Holds the observable results of interacting with the demo
  # widgets so the screen can render a readout that updates on every
  # dispatch → Rerender cycle — proving the widgets actually FUNCTION,
  # not just render.
  #
  # Nilable-by-default class vars + lazy accessors per the iOS class-init
  # gap (see `project_crystal_ios_class_init_gap` memory): no class-var
  # initializer side effects that the iOS embedding would strand.
  module GalleryState
    @@tap_count : Int32? = nil
    @@toggle_on : Bool? = nil
    @@segment_index : Int32? = nil
    @@stepper_value : Int32? = nil
    @@last_event : String? = nil
    @@captured_text : String? = nil

    # Shared readout for the showcase sections: the most recent
    # interaction with any wired widget. Lets every widget demonstrate it
    # FUNCTIONS (interaction → visible result) without a dedicated label
    # per widget.
    def self.last_event : String
      @@last_event ||= "(interact with any widget below)"
    end

    def self.last_event=(value : String) : String
      @@last_event = value
    end

    # Capture-then-reveal readout for text inputs (SearchField, TextArea,
    # TextEditor). Their on_change stores the REAL typed text here without
    # dispatching — so we don't rerender mid-keystroke and steal focus —
    # and a "reveal" button later rerenders to surface the captured value.
    # An XCUITest types real text, taps reveal, and asserts this label
    # shows it, proving the typed string reached the Crystal handler (the
    # SecureField bug class: the string channel must carry real text).
    def self.captured_text : String
      @@captured_text ||= "(nothing captured yet)"
    end

    def self.captured_text=(value : String) : String
      @@captured_text = value
    end

    def self.tap_count : Int32
      @@tap_count ||= 0
    end

    def self.bump_tap : Int32
      @@tap_count = tap_count + 1
    end

    def self.toggle_on : Bool
      v = @@toggle_on
      v.nil? ? false : v
    end

    def self.toggle_on=(value : Bool) : Bool
      @@toggle_on = value
    end

    def self.segment_index : Int32
      @@segment_index ||= 0
    end

    def self.segment_index=(value : Int32) : Int32
      @@segment_index = value
    end

    # NB: deliberately NOT a module constant. Module/class-level Array
    # constants are initialized via `Crystal.once`, which does NOT run
    # under the iOS embedding (the class-init gap — see
    # `project_crystal_ios_class_init_gap` memory), so accessing such a
    # constant null-derefs on iOS. Returning a fresh array from a method
    # (runtime allocation) sidesteps the gap entirely.
    def self.segment_labels : Array(String)
      ["Day", "Week", "Month"]
    end

    def self.segment_label : String
      case segment_index
      when 1 then "Week"
      when 2 then "Month"
      else        "Day"
      end
    end

    def self.stepper_value : Int32
      @@stepper_value ||= 0
    end

    def self.stepper_value=(value : Int32) : Int32
      @@stepper_value = value
    end
  end
end
