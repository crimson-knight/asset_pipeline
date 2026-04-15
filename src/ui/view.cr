module UI
  # Alignment options for stack layouts
  enum Alignment
    Leading
    Center
    Trailing
    Top
    Bottom
    Fill
  end

  # Content mode for image display
  enum ContentMode
    Fit
    Fill
    Stretch
  end

  # Keyboard type hint for text fields
  enum KeyboardType
    Default
    EmailAddress
    NumberPad
    PhonePad
    URL
  end

  # Style for toggle/switch controls
  enum ToggleStyle
    Switch     # iOS-style toggle switch
    Checkbox   # Standard checkbox
  end

  # Style for picker controls
  enum PickerStyle
    Wheel     # Spinning wheel picker
    Segmented # Segmented control inline
    Menu      # Dropdown/popup menu
    Inline    # Expanded inline
  end

  # Mode for date/time pickers
  enum DatePickerMode
    Date         # Date only
    Time         # Time only
    DateAndTime  # Both date and time
  end

  # Style for progress indicators
  enum ProgressStyle
    Linear    # Horizontal progress bar
    Circular  # Spinning circular progress
  end

  # Style for list views
  enum ListStyle
    Plain         # No grouping, no separators between sections
    Inset         # Rounded group sections with insets
    Grouped       # Grouped with section headers
    InsetGrouped  # Rounded grouped sections
    Sidebar       # macOS-style sidebar list
  end

  # Layout mode for list/collection views
  enum ListLayout
    List # Vertical row layout (default; maps to UITableView / NSTableView semantics)
    Grid # Multi-column grid layout (maps to UICollectionView / NSCollectionView semantics)
  end

  # Value type representing an RGBA color
  record Color,
    r : Float64,
    g : Float64,
    b : Float64,
    a : Float64 = 1.0

  # Value type representing a font specification
  record Font,
    family : String = "system",
    size : Float64 = 17.0,
    weight : Symbol = :regular,
    italic : Bool = false

  # Value type representing edge insets (padding/margins)
  record EdgeInsets,
    top : Float64 = 0.0,
    trailing : Float64 = 0.0,
    bottom : Float64 = 0.0,
    leading : Float64 = 0.0

  # Abstract base class for all UI views.
  #
  # Crystal prohibits recursive structs, so View must be a class.
  # VStack/HStack/ZStack children arrays contain View references,
  # creating a recursive type relationship.
  abstract class View
    # Optional identifier for this view, used for lookup and testing
    property id : String? = nil

    # Accessibility label read by screen readers
    property accessibility_label : String? = nil

    # Padding around the view content
    property padding : EdgeInsets = EdgeInsets.new

    # Background color, nil means transparent/inherited
    property background : Color? = nil

    # Whether the view is hidden from display
    property hidden : Bool = false

    # Opacity from 0.0 (fully transparent) to 1.0 (fully opaque)
    property opacity : Float64 = 1.0

    # Shape modifiers
    property corner_radius : Float64 = 0.0
    property clip_to_bounds : Bool = false

    # Shadow modifier
    property shadow_radius : Float64 = 0.0
    property shadow_color : Color? = nil
    property shadow_offset_x : Float64 = 0.0
    property shadow_offset_y : Float64 = 0.0

    # Border modifier
    property border_width : Float64 = 0.0
    property border_color : Color? = nil

    # Blur modifier
    property blur_radius : Float64 = 0.0

    # Size constraints
    property minimum_width : Float64? = nil
    property minimum_height : Float64? = nil
    property maximum_width : Float64? = nil
    property maximum_height : Float64? = nil

    # Test identifier for automated UI testing, maps to native test attributes
    property test_id : String? = nil

    # Accept a platform visitor for rendering dispatch.
    # Each concrete view type calls `visitor.visit(self)`.
    abstract def accept(visitor : PlatformVisitor)
  end
end
