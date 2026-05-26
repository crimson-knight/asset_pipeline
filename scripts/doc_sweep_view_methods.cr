# Phase 10A.final iter 2 — Finding 1 doc sweep helper (methods pass).
#
# Walks every `src/ui/views/*.cr` file. For each public `def`
# declaration that is NOT already preceded by a `#`-comment line,
# inserts a 1-line semantic doc comment above it.
#
# Skipped:
#   * `def accept(visitor : PlatformVisitor)` — visitor boilerplate
#   * `def default_accessibility_role` — override IS the doc
#   * `def default_focusable` — override IS the doc
#   * `def initialize(...)` — class-level docs cover construction
#   * any def already preceded by a `#` line (preserves existing docs)
#   * any def whose name starts with `_` (private convention) — none
#     exist in views but kept as a safety net
#   * `private def` blocks — only public surface gets docs
#
# Run:
#   crystal run scripts/doc_sweep_view_methods.cr
#
# Script is idempotent — rerunning is a no-op.

SKIP_METHODS = Set.new([
  "accept",
  "default_accessibility_role",
  "default_focusable",
  "initialize",
])

# Curated semantic docs by method name.
METHOD_DOCS = {
  # Container/composition
  "<<"               => "Appends `child` to the container's children and returns self for chaining.",
  "fallback_view"    => "Returns a composed view that renders an equivalent surface on platforms without a dedicated native bridge.",

  # Counts
  "action_count"     => "Returns the number of actions currently attached.",
  "column_count"     => "Returns the number of columns currently configured.",
  "field_count"      => "Returns the number of fields currently configured.",
  "item_count"       => "Returns the number of items currently configured.",
  "node_count"       => "Returns the number of nodes currently configured.",
  "row_count"        => "Returns the number of rows currently configured.",
  "token_count"      => "Returns the number of tokens currently configured.",

  # Mutation
  "add_action"       => "Appends an action affordance and returns the newly-created action.",
  "add_button"       => "Appends a button affordance and returns the newly-created button.",
  "add_item"         => "Appends an item and returns the newly-created item.",
  "add_root"         => "Appends a root node and returns the newly-created node.",
  "add_row"          => "Appends a row and returns the newly-created row.",
  "add_section"     => "Appends a section and returns the newly-created section.",
  "add_span"         => "Appends a styled span to the rich-text run.",
  "add_token"        => "Appends a token and returns the newly-created token.",

  # Navigation / lifecycle
  "present"          => "Presents the overlay / modal.",
  "dismiss"          => "Dismisses the overlay / modal.",
  "show"             => "Renders the overlay / modal in the visible state.",
  "close"            => "Closes the overlay / modal.",
  "push"             => "Pushes a new screen onto the navigation stack.",
  "pop"              => "Pops the topmost screen off the navigation stack.",
  "pop_to_root"      => "Pops every screen off the navigation stack down to the root.",

  # Toggle behavior
  "toggle"           => "Flips the control's on / off state.",
  "increment"        => "Increases the value by `step_value`, clamping or wrapping per `wraps`.",
  "decrement"        => "Decreases the value by `step_value`, clamping or wrapping per `wraps`.",

  # Path / canvas drawing
  "begin_path"       => "Starts a new sub-path on the canvas.",
  "close_path"       => "Closes the current sub-path with a line back to the starting point.",
  "move_to"          => "Moves the cursor to `(x, y)` without drawing.",
  "line_to"          => "Draws a line from the current cursor to `(x, y)`.",
  "curve_to"         => "Draws a curve from the current cursor to the destination.",
  "arc"              => "Draws an arc segment with the given radius and angle range.",
  "fill"             => "Fills the current path with `fill_color`.",
  "stroke"           => "Strokes the current path with `stroke_color` + `stroke_width`.",
  "to_svg_path"      => "Returns the path as an SVG `d=` attribute string.",

  # Activity rings
  "move_fraction"    => "Returns the move ring's completion fraction in `0.0..1.0`.",
  "exercise_fraction" => "Returns the exercise ring's completion fraction in `0.0..1.0`.",
  "stand_fraction"   => "Returns the stand ring's completion fraction in `0.0..1.0`.",
  "progress_fraction" => "Returns the overall progress fraction in `0.0..1.0`.",
  "normalized_value" => "Returns the value normalized into `0.0..1.0` against `minimum`..`maximum`.",
  "effective_duration" => "Returns the actual duration after platform clamping rules are applied.",

  # Display helpers
  "display_value"    => "Returns the user-facing formatted value string.",
  "plain_text"       => "Returns the unstyled plain-text content.",
  "selected_segment" => "Returns the selected segment label (or nil if no valid selection).",
  "selected_option"  => "Returns the selected option label (or nil if no valid selection).",
  "selected_path"    => "Returns the selected path component string (or nil if no selection).",
  "selected_tokens"  => "Returns every token currently in the selected set.",
  "has_image"        => "Returns true when an image is currently assigned.",
  "current_view"     => "Returns the currently-active view inside the container.",
  "current_content"  => "Returns the currently-active content inside the container.",

  # Setters — disambiguated descriptions
  "value="           => "Assigns the value and fires `on_change` listeners.",
  "is_on="           => "Assigns the on/off state and fires `on_change` listeners.",
  "is_presented="    => "Assigns the presentation flag; the renderer reacts on the next layout pass.",
  "text="            => "Assigns the body text.",
  "disabled="        => "Assigns the disabled flag.",
  "background="      => "Assigns the background fill.",
  "foreground_color=" => "Assigns the foreground color.",
  "corner_radius="   => "Assigns the corner radius (pt).",

  # Misc
  "flexible"         => "Returns true when the view is allowed to grow / shrink along the layout axis.",
  "self"             => "Returns self.",
} of String => String

# Match `def name(...)` or `def name` lines. Captures the indent and name.
# We require the indent to be at least 4 spaces — class-level defs in
# views are nested in `module UI` + `class Foo < View`, so they sit at
# 4-space indent.
METHOD_RE = /^(\s{4,})def\s+([A-Za-z_<>=!]+[A-Za-z_0-9?<>=!]*)/

def already_documented?(lines : Array(String), index : Int32) : Bool
  return false if index == 0
  prev = lines[index - 1].strip
  prev.starts_with?("#")
end

def previous_non_blank(lines : Array(String), index : Int32) : String
  i = index - 1
  while i >= 0
    s = lines[i].strip
    return s unless s.empty?
    i -= 1
  end
  ""
end

# Returns true if the def at `index` lives inside a `private` block.
# Heuristic: walk backwards inside the same indent looking for a bare
# `private` declarator. Stops at class boundary.
def inside_private_block?(lines : Array(String), index : Int32, indent : String) : Bool
  i = index - 1
  while i >= 0
    raw = lines[i]
    stripped = raw.strip
    if stripped == "private" || stripped.starts_with?("private ")
      # If a `private` line sits at the same indent, check whether
      # it's a one-liner (`private def`) — that means our def is not
      # inside a private block. Our caller's regex skips `private def`
      # already by not seeing the bare `def` token at position 0 of
      # the indent. So if we hit a `private` qualifier here it's
      # either: (a) a `private def x` modifier (single-line, doesn't
      # affect subsequent defs), or (b) a block-form `private` opener.
      # Crystal doesn't have block-form private blocks though — every
      # `private` modifier is per-decl. Safe to return false.
      return false
    end
    if raw.starts_with?("class ") || raw.starts_with?("module ")
      return false
    end
    i -= 1
  end
  false
end

def line_is_private_def?(line : String) : Bool
  line.lstrip.starts_with?("private def ")
end

def sweep_file(path : String) : Int32
  original = File.read(path)
  lines = original.lines(chomp: false)
  output = [] of String
  inserted = 0

  lines.each_with_index do |line, idx|
    next_unmatched = true
    if !line_is_private_def?(line) && (md = line.match(METHOD_RE))
      indent = md[1]
      name = md[2]
      if !SKIP_METHODS.includes?(name) && !already_documented?(lines, idx)
        if doc = METHOD_DOCS[name]?
          output << "#{indent}# #{doc}\n"
          inserted += 1
        end
      end
      next_unmatched = false
    end
    _ = next_unmatched
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
