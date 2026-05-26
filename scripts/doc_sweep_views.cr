# Phase 10A.final iter 2 — Finding 1 doc sweep helper.
#
# Walks every `src/ui/views/*.cr` file. For each public `property`,
# `getter`, or `setter` declaration that is NOT already preceded by a
# `#`-comment line, inserts a 1-line semantic doc comment above it.
# Comment text is chosen from a curated property-name table; unknown
# names fall back to a generic-but-non-trivial template that mentions
# the declared type.
#
# Skipped:
#   * private declarations (we only doc public surface)
#   * declarations already preceded by a `#` line (preserves existing
#     docs from earlier sweeps)
#   * the `accept(visitor : PlatformVisitor)` method
#   * `default_accessibility_role` and `default_focusable` overrides
#   * `def` methods (out of scope — we only sweep properties here)
#
# Run:
#   crystal run scripts/doc_sweep_views.cr
#
# The script is idempotent: rerunning is a no-op once docs are placed.

require "file_utils"

# Curated semantic docs by property name. Values are the comment body
# WITHOUT the leading `#`. They are written above the declaration with
# the same indentation as the declaration line.
SEMANTIC_DOCS = {
  # Layout / spacing
  "spacing"          => "Space (in pt) between consecutive children. Mapped to UIStackView / NSStackView / LinearLayout spacing on native, gap on web.",
  "alignment"        => "Cross-axis alignment for children. See `UI::Alignment`.",
  "row_spacing"      => "Vertical gap (in pt) between rows.",
  "column_spacing"   => "Horizontal gap (in pt) between columns.",
  "chip_spacing"     => "Horizontal gap (in pt) between adjacent chips / tokens.",
  "chip_padding"     => "Inner padding (pt) inside each chip / token.",
  "row_padding"      => "Inner padding (pt) applied to each row.",
  "content_padding"  => "Inner padding (pt) between the surface edge and the wrapped content.",

  # Sizes / extents
  "width"            => "Intrinsic width in pt.",
  "height"           => "Intrinsic height in pt.",
  "viewport_width"   => "Optional fixed width (in pt) for the rendered viewport. Zero means \"size to content\".",
  "viewport_height"  => "Optional fixed height (in pt) for the rendered viewport. Zero means \"size to content\".",
  "input_min_width"  => "Minimum width (in pt) of the embedded input field.",
  "input_max_width"  => "Maximum width (in pt) of the embedded input field.",
  "minimum"          => "Minimum legal value (inclusive).",
  "maximum"          => "Maximum legal value (inclusive).",
  "step_value"       => "Increment / decrement amount applied per tick.",
  "value"            => "Current value of the control.",
  "value_precision"  => "Number of fractional digits to format the value with.",

  # Text / label
  "title"            => "Primary text shown on the control.",
  "subtitle"         => "Secondary line shown beneath the title.",
  "label"            => "Caption / accessibility label rendered alongside the control.",
  "text"             => "Body text rendered by the view.",
  "placeholder"      => "Placeholder text shown when the field is empty.",
  "prompt"           => "Helper / prompt text shown above or below the field.",
  "message"          => "Body / message text shown in the alert / dialog.",
  "help_text"        => "Help / hint text shown beneath the control.",
  "caption"          => "Short caption rendered alongside the main content.",
  "units"            => "Unit suffix appended after the formatted value (e.g. \"%\").",
  "font"             => "Typography applied to the rendered text.",
  "text_color"       => "Foreground color applied to the text. Overrides any role token.",
  "text_alignment"   => "Horizontal text alignment.",
  "text_color_role"  => "Semantic color role applied to the text. `nil` falls back to the platform default.",

  # Colors / fill
  "tint_color"       => "Tint applied to platform-native chrome (button highlight, selection, etc).",
  "fill_color"       => "Solid fill color for the shape body.",
  "stroke_color"     => "Stroke / outline color for the shape.",
  "stroke_width"     => "Stroke / outline width in pt.",
  "background_color" => "Background fill applied behind the content.",

  # State
  "is_presented"     => "Whether the modal / overlay is currently presented.",
  "is_presenting"    => "Whether the controller is in the act of presenting the overlay.",
  "is_on"            => "Whether the control is in the on / checked state.",
  "is_enabled"       => "Whether the control accepts user input.",
  "is_indeterminate" => "Whether the control should render an indeterminate / busy state.",
  "selected_index"   => "Currently selected index into the segments / options array.",
  "selected_indexes" => "Currently selected indexes into the items array (multi-select).",
  "selected_segment" => "Currently selected segment string, if any.",

  # Collections
  "segments"         => "Ordered list of option labels.",
  "options"          => "Ordered list of option labels.",
  "tokens"           => "Tokens currently displayed.",
  "items"            => "Items rendered by the control.",
  "actions"          => "Actions rendered as interactive affordances.",
  "leading_actions"  => "Actions revealed by a leading-edge swipe.",
  "trailing_actions" => "Actions revealed by a trailing-edge swipe.",

  # Navigation / surfaces
  "content"          => "Child view rendered inside this container.",
  "destination"      => "Destination view pushed when the link is activated.",
  "tabs"             => "Tab destinations rendered by the tab bar.",

  # Behavior toggles
  "wraps"            => "Whether the value wraps around at the min / max boundary.",
  "show_value"       => "Whether to render the current value alongside the control.",
  "shows_separators" => "Whether row separators are drawn.",
  "shows_disclosure_glyphs" => "Whether disclosure (chevron) glyphs are drawn beside expandable rows.",

  # Identifiers
  "icon"             => "Optional icon shown next to the title. Native: SF Symbol name; web: icon class or URL.",
  "url"              => "URL the view points at.",
  "image"            => "Image rendered by the view.",
  "image_name"       => "Asset name to look up the rendered image by.",

  # Callbacks
  "on_change"        => "Invoked when the user changes the control's value.",
  "on_tap"           => "Invoked when the user taps / clicks the control.",
  "on_dismiss"       => "Invoked when the overlay is dismissed (by tap-outside, escape, or programmatic close).",
  "on_submit"        => "Invoked when the user submits the field (Return / Enter).",
  "on_press"         => "Invoked when the press gesture completes.",
  "on_toggle"        => "Invoked when the toggle's `is_on` value flips.",
  "on_value_change"  => "Invoked with the new value after the user adjusts the control.",

  # Material / chrome
  "material"         => "Surface material applied to the background (e.g. `:primary`, `:secondary`, `:thin`).",
  "material_semantic" => "Optional semantic material role (overrides `material` when set).",
  "elevation"        => "Logical Z-depth used for shadow + material selection.",

  # Bounding angles (shapes)
  "start_angle"      => "Starting angle in radians.",
  "end_angle"        => "Ending angle in radians.",
  "radius"           => "Radius in pt.",

  # Long-tail (added in iter 2 finding-1 second pass).
  "style"            => "Visual style variant applied to the control.",
  "children"         => "Ordered list of child views.",
  "role"             => "Semantic role (e.g. `:primary`, `:destructive`, `:cancel`).",
  "components"       => "Sub-components rendered by the view.",
  "on_cancel"        => "Invoked when the user cancels the operation (Escape, swipe-down, tap-outside).",
  "on_confirm"       => "Invoked when the user confirms the operation.",
  "on_select"        => "Invoked with the newly-selected item when the user picks an option.",
  "on_action"        => "Invoked when the action affordance is activated.",
  "on_load"          => "Invoked when the underlying resource finishes loading.",
  "on_error"         => "Invoked with the error when the underlying resource fails to load.",
  "icon_symbol"      => "SF Symbol name (Apple) / icon identifier (Android / web) for the icon.",
  "orientation"      => "Layout orientation (e.g. `:horizontal`, `:vertical`).",
  "selected_date"    => "Currently selected date.",
  "minimum_date"     => "Earliest selectable date (inclusive).",
  "maximum_date"     => "Latest selectable date (inclusive).",
  "selected_time"    => "Currently selected time.",
  "mode"             => "Operating mode for the control.",
  "content_mode"     => "How the content is scaled / aligned within its frame (e.g. `:fit`, `:fill`, `:center`).",
  "position"         => "Geographic / screen position for the view.",
  "map_type"         => "Map presentation style (e.g. `:standard`, `:satellite`, `:hybrid`).",
  "annotations"      => "Annotations rendered on top of the map.",
  "column_visibility" => "Initial visibility / collapse state for each column.",
  "preview_padding"  => "Inner padding (pt) applied to the preview pane.",
  "columns"          => "Column descriptors for the layout.",
  "confirm_style"    => "Style applied to the confirm action (e.g. `:default`, `:destructive`).",
  "chart_type"       => "Chart variant (e.g. `:line`, `:bar`, `:area`, `:donut`).",
  "data_points"      => "Numeric data series rendered by the chart.",
  "arrow_edge"       => "Edge the popover's arrow points at (`:top`, `:bottom`, `:leading`, `:trailing`).",
  "operations"       => "Drawing / canvas operations recorded for replay.",
  "spans"            => "Styled text runs that make up the rich-text content.",
  "roots"            => "Root nodes of the outline.",
  "sections"         => "Section groupings within the view.",
  "detents"          => "Allowed sheet detents (heights the user can drag the sheet to).",
  "selected_detent"  => "Currently active sheet detent.",
  "syntax_highlighting" => "Syntax highlighting language identifier (or nil for plain text).",
  "thumbnail"        => "Optional thumbnail image source.",
  "shape"            => "Bounding shape used to clip / mask the view.",
} of String => String

# Common type-based fallbacks. Keyed by the textual form of the declared
# type as captured from the file. Used when the property name is not in
# `SEMANTIC_DOCS`.
TYPE_FALLBACKS = {
  "Bool"   => "Boolean toggle.",
  "String" => "Text value.",
  "Int32"  => "Integer value.",
  "Float64" => "Numeric value (pt unless otherwise noted).",
  "Color"  => "Color value.",
  "View"   => "Wrapped child view.",
} of String => String

PROPERTY_RE = /^(\s+)(property|getter|setter)\s+(\w+)\s*:\s*([^=\n]+?)(?:\s*=.*)?$/

def doc_for_property(name : String, raw_type : String) : String?
  if doc = SEMANTIC_DOCS[name]?
    return doc
  end
  # Strip generics and nilability for a fallback lookup.
  base_type = raw_type.strip.gsub(/\?\z/, "").gsub(/\(.*\)/, "").strip
  if doc = TYPE_FALLBACKS[base_type]?
    return doc
  end
  nil
end

def already_documented?(lines : Array(String), index : Int32) : Bool
  return false if index == 0
  prev = lines[index - 1].strip
  prev.starts_with?("#")
end

def sweep_file(path : String) : Int32
  original = File.read(path)
  lines = original.lines(chomp: false)
  output = [] of String
  inserted = 0

  lines.each_with_index do |line, idx|
    if md = line.match(PROPERTY_RE)
      indent = md[1]
      name = md[3]
      raw_type = md[4]
      unless already_documented?(lines, idx)
        if doc = doc_for_property(name, raw_type)
          output << "#{indent}# #{doc}\n"
          inserted += 1
        end
      end
    end
    output << line
  end

  if inserted > 0
    File.write(path, output.join)
  end
  inserted
end

# Entry point ---------------------------------------------------------

root = File.expand_path(File.join(__DIR__, "..", "src", "ui", "views"))
unless Dir.exists?(root)
  STDERR.puts "view dir not found: #{root}"
  exit 1
end

total = 0
touched = 0
Dir.glob(File.join(root, "*.cr")).sort.each do |path|
  count = sweep_file(path)
  if count > 0
    touched += 1
    total += count
    puts "#{File.basename(path).ljust(40)} +#{count} docs"
  end
end

puts "------"
puts "touched #{touched} files, inserted #{total} doc lines"
