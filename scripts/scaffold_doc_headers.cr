# Phase 10A.0a — Minimal doc-scaffold sweep.
#
# Idempotently adds a 1-2 sentence file header and a 1-2 sentence
# class summary above public `class Foo < View` declarations across
# the public-surface files listed in scoping-10 v3 §"10A.0".
# NO per-method docs (deferred to 10A.final).
#
# Idempotency rule: a file is treated as "already scaffolded" if its
# first non-blank line is `#` (file header present); class-level
# summaries are inserted only when the line immediately above the
# class declaration is not a `#` comment.

require "file_utils"

# PascalCase -> snake_case helper.
def snake_case_of(class_name : String) : String
  s = class_name.gsub(/([A-Z]+)([A-Z][a-z])/) { "#{$1}_#{$2}" }
  s = s.gsub(/([a-z\d])([A-Z])/) { "#{$1}_#{$2}" }
  s.downcase
end

# Per-view descriptive blurbs.
VIEW_DESCRIPTIONS = {
  "action_sheet"                    => "Modal sheet of choices presented at the bottom of the screen on iOS.",
  "action_sheet_with_web_fallback"  => "Tier-3 action sheet with a web-compatible fallback rendering on non-iOS targets.",
  "activity_indicator"              => "Indeterminate spinner indicating that work is in progress.",
  "activity_ring"                   => "Single circular progress ring rendered in the Activity Rings idiom.",
  "activity_rings"                  => "Composition of activity rings rendered as a stack of progress indicators.",
  "activity_view"                   => "Native share / activity sheet for exporting content to other apps.",
  "alert"                           => "Modal alert dialog used to confirm critical information or destructive actions.",
  "async_image"                     => "Image view that loads its content asynchronously from a URL.",
  "button"                          => "Tappable button with HIG-conformant styling for primary, secondary, and tinted roles.",
  "canvas"                          => "Low-level drawing surface backed by the native platform 2D drawing API.",
  "capsule"                         => "Pill-shaped geometric primitive used for badges and chip backgrounds.",
  "card"                            => "Boxed surface that groups related content with optional title and elevation.",
  "chart_view"                      => "Native chart view wrapping Swift Charts on Apple platforms and the equivalent on other targets.",
  "checkbox"                        => "Two-state checkbox control with a leading label.",
  "circle"                          => "Filled or stroked circular geometric primitive.",
  "color_picker"                    => "Color selection control bridging to the native color picker on each platform.",
  "column_view"                     => "Multi-column information list view (macOS NSTableView column layout).",
  "combo_box"                       => "Text field with an associated drop-down list of suggestions.",
  "confirmation_dialog"             => "Action-confirmation prompt with platform-idiomatic destructive/cancel buttons.",
  "context_menu"                    => "Long-press / right-click contextual menu attached to a host view.",
  "context_menu_with_web_fallback"  => "Tier-3 context menu with a web-compatible fallback rendering on non-native targets.",
  "date_picker"                     => "Calendar-based date selection control.",
  "disclosure_group"                => "Collapsible disclosure section grouping related content under a toggle header.",
  "divider"                         => "Thin horizontal or vertical separator line between content.",
  "form"                            => "Container that groups input controls into sections with HIG-conformant spacing.",
  "gauge"                           => "Bounded value indicator showing progress along a fixed range.",
  "glass_background"                => "Apple glass / translucency background using NSVisualEffectView / UIVisualEffectView.",
  "grid"                            => "Two-dimensional layout that arranges children in rows and columns.",
  "hstack"                          => "Horizontal stack that arranges children leading-to-trailing with configurable spacing.",
  "icon_button"                     => "Compact icon-only button used for toolbar and inline actions.",
  "image"                           => "Static image view loading from an asset or local URL.",
  "image_well"                      => "Drop-target image well control for accepting an image via drag-and-drop or click.",
  "label"                           => "Static text label with semantic typography and accessibility metadata.",
  "link_button"                     => "Button styled as a hyperlink that opens or dispatches a navigation action.",
  "list_view"                       => "Scrolling vertical list of rows with native idiomatic chrome.",
  "live_text_view"                  => "Text view that recognizes live elements (URLs, addresses, phone numbers).",
  "map_view"                        => "Native map view bridging to MapKit on Apple platforms.",
  "menu_button"                     => "Button that reveals a drop-down menu of actions.",
  "modal_view"                      => "Modal presentation container hosting another view tree.",
  "navigation_link"                 => "Navigation affordance that pushes a destination onto the navigation stack.",
  "navigation_split_view"           => "Multi-column navigation container (sidebar + content + detail) for iPad and macOS.",
  "navigation_stack"                => "Push/pop navigation container hosting a sequence of screens.",
  "outline_view"                    => "Hierarchical disclosure view backed by NSOutlineView / UITableView with indents.",
  "page_control"                    => "Horizontal page-indicator dots commonly used under paged scroll views.",
  "path_control"                    => "macOS path control showing a filesystem-style breadcrumb.",
  "path_control_with_web_fallback"  => "Tier-3 path control with a web-compatible fallback rendering on non-macOS targets.",
  "path_view"                       => "Vector path primitive driven by an explicit drawing command sequence.",
  "picker"                          => "Single-selection picker with platform-idiomatic wheel / inline / menu styles.",
  "popover"                         => "Lightweight transient overlay anchored to a host view.",
  "progress_view"                   => "Determinate progress bar / circle for known-duration work.",
  "radio_group"                     => "Group of mutually exclusive radio buttons with a shared selection.",
  "rectangle"                       => "Filled or stroked rectangular geometric primitive.",
  "rich_text"                       => "Read-only rich-text view supporting attributed runs and inline images.",
  "rounded_rectangle"               => "Rectangular primitive with configurable corner radius.",
  "scroll_view"                     => "Single-axis or two-axis scrolling viewport wrapping a content view.",
  "search_field"                    => "Single-line search input with platform-idiomatic clear and scope affordances.",
  "secure_field"                    => "Single-line text input that masks its contents (used for passwords).",
  "segmented_control"               => "Horizontal segmented selector for picking one option from a small set.",
  "sheet"                           => "Modal sheet that slides up from the bottom (iOS) or appears as a dialog (macOS).",
  "slider"                          => "Continuous-value slider control with configurable range and step.",
  "snackbar"                        => "Transient toast / snackbar notification anchored to the bottom of the screen.",
  "spacer"                          => "Layout-only view that expands to fill remaining space along a stack's axis.",
  "stepper"                         => "Increment / decrement stepper for adjusting a discrete numeric value.",
  "surface"                         => "Generic themed surface used as a background for other content.",
  "swipe_action_row"                => "List row with edge-swipe revealed actions (leading / trailing).",
  "tab_view"                        => "Tab-bar container that hosts multiple sibling routes.",
  "table_view"                      => "Multi-column data table with native row chrome and selection.",
  "text_area"                       => "Multi-line plain-text input field.",
  "text_editor"                     => "Rich multi-line text editor with attributed string support.",
  "text_field"                      => "Single-line plain-text input field.",
  "time_picker"                     => "Time-of-day selection control.",
  "token_field"                     => "Multi-value tokenized text field (e.g. recipient field in a mail app).",
  "toggle"                          => "On / off toggle switch with optional label.",
  "toggle_button"                   => "Pressed-state button used as a toggle (e.g. bold / italic toolbar buttons).",
  "toolbar"                         => "Top-of-screen toolbar container hosting buttons and other tools.",
  "tooltip"                         => "Hover / focus-driven tooltip overlay attached to a host view.",
  "video_player"                    => "Native video playback view bridging to AVPlayerViewController on Apple platforms.",
  "vstack"                          => "Vertical stack that arranges children top-to-bottom with configurable spacing.",
  "web_view"                        => "Embedded web content view backed by WKWebView / WebView2.",
  "web_view_component"              => "Embedded web content view backed by WKWebView / WebView2.",
  "zstack"                          => "Overlay container that layers children along the z-axis.",
} of String => String

ASSET_PIPELINE_DESCRIPTIONS = {
  "dependency_analyzer.cr" => "Dependency analyzer for the asset pipeline JS / CSS graph.",
  "design_system.cr"       => "Design-system entry point: token-driven theming for the asset pipeline.",
  "framework_registry.cr"  => "Registry of integration adapters for host frameworks (Amber, Lucky, etc.).",
  "platform.cr"            => "Compile-time platform-gating helpers for the asset_pipeline cross-platform UI.",
  "script_renderer.cr"     => "Renders `<script>` tags and import-map JSON for the FrontLoader.",
} of String => String

UI_TOPLEVEL_DESCRIPTIONS = {
  "design_tokens.cr" => "Tier-1 brand-token contract: semantic colors, spacing, typography, and motion scales.",
  "form_state.cr"    => "Controlled-input state container threaded through screen renders.",
} of String => String

def already_has_header?(content : String) : Bool
  content.each_line do |line|
    stripped = line.strip
    next if stripped.empty?
    return stripped.starts_with?("#")
  end
  false
end

# Prepend `header` to `content` if the file is missing a top-of-file
# comment header. Returns the (possibly-modified) content. The header
# is followed by a blank line so it does not run into a `require`.
def ensure_file_header(content : String, header_lines : Array(String)) : String
  return content if already_has_header?(content)
  prefix = header_lines.map { |line| "# #{line}".rstrip }.join('\n') + "\n\n"
  prefix + content
end

# Inserts a `# summary` line immediately above any `class X < Base`
# declaration that doesn't already have a comment on the prior line.
def ensure_class_summaries(content : String, base_pattern : Regex, &summary_for : String -> String) : String
  lines = content.lines(chomp: false)
  result = [] of String
  lines.each_with_index do |line, idx|
    if base_pattern.match(line)
      m = base_pattern.match(line).not_nil!
      class_name = m[2]
      indent = line[/^\s*/]
      prev_idx = idx - 1
      prev_line = prev_idx >= 0 ? lines[prev_idx] : nil
      unless prev_line && prev_line.strip.starts_with?("#")
        summary = summary_for.call(class_name)
        result << "#{indent}# #{summary}\n"
      end
    end
    result << line
  end
  result.join
end

modified_files = [] of String

Dir.glob("src/ui/views/*.cr") do |path|
  basename = File.basename(path)
  stem = basename.sub(/\.cr$/, "")
  content = File.read(path)
  original = content

  description = VIEW_DESCRIPTIONS[stem]? || "Tier-1/2 UI::View for the asset_pipeline cross-platform component system."
  header_lines = [
    description,
    "Part of the asset_pipeline cross-platform UI::View catalog.",
  ]
  content = ensure_file_header(content, header_lines)
  content = ensure_class_summaries(content, /^(\s*)class\s+([A-Z][A-Za-z0-9_]*)\s*<\s*(?:UI::)?View\b/) do |class_name|
    desc = VIEW_DESCRIPTIONS[snake_case_of(class_name)]? || description
    "#{class_name} — #{desc}"
  end

  if content != original
    File.write(path, content)
    modified_files << path
  end
end

Dir.glob("src/asset_pipeline/*.cr") do |path|
  basename = File.basename(path)
  next unless File.file?(path)
  content = File.read(path)
  original = content
  description = ASSET_PIPELINE_DESCRIPTIONS[basename]?
  next if description.nil? && already_has_header?(content)

  if description.nil?
    description = "Internal module of the asset_pipeline shard."
  end

  header_lines = [
    description,
    "Part of the asset_pipeline shard.",
  ]
  content = ensure_file_header(content, header_lines)
  if content != original
    File.write(path, content)
    modified_files << path
  end
end

UI_TOPLEVEL_DESCRIPTIONS.each do |basename, description|
  path = "src/ui/#{basename}"
  next unless File.exists?(path)
  content = File.read(path)
  original = content
  next if already_has_header?(content)
  header_lines = [
    description,
    "Part of the asset_pipeline cross-platform UI surface.",
  ]
  content = ensure_file_header(content, header_lines)
  if content != original
    File.write(path, content)
    modified_files << path
  end
end

puts "Scaffolded #{modified_files.size} files."
modified_files.each { |p| puts "  + #{p}" }
