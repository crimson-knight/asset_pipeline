# scripts/validate_catalog_coverage.cr
#
# Validates docs/initiative-cross-platform-ui/catalog-coverage.yml against
# tier-matrix.md (every Tier 1+2 widget present), intent-catalog.md (every
# intent present), the filesystem (every cited path exists), and the
# source-hash freshness invariant (when set, hash matches the file).
#
# Exit codes:
#   0 — clean
#   1 — at least one diagnostic
#
# Enforces merge-readiness-gate.md §"D. Lint clean".

require "yaml"
require "digest/sha256"

REPO_ROOT      = File.expand_path("..", __DIR__)
MANIFEST_PATH  = File.join(REPO_ROOT, "docs/initiative-cross-platform-ui/catalog-coverage.yml")
TIER_MATRIX    = File.join(REPO_ROOT, "docs/initiative-cross-platform-ui/tier-matrix.md")
INTENT_CATALOG = File.join(REPO_ROOT, "docs/initiative-cross-platform-ui/architecture/intent-catalog.md")

VALID_WIDGET_CLASSES = %w[
  static-primitive
  container-layout
  form-control
  button-cluster
  modal-presentation
  navigation
  list-presentation
  media
  data-viz
  system-bridge
]

VALID_OVERRIDE_STATUSES = %w[
  public-knobs
  facade-extension-required
  no-override-yet-tracked-in-backlog
  not-yet-set
  n/a
]

VALID_DEMO_STATUSES = %w[
  not-demonstrated
  demonstrated-in-Voyager
  demonstrated-in-Notes
  demonstrated-in-Mailbox
  demonstrated-in-HealthLog
  demonstrated-in-Photos
  demonstrated-in-Freeform
  documented-with-default-experience
  internal-only
]

VALID_INTENT_CLASSES = %w[A B C D]

class Diagnostic
  property severity : Symbol
  property message : String

  def initialize(@severity, @message); end

  def to_s(io)
    io << "[#{severity.to_s.upcase}] #{message}"
  end
end

diagnostics = [] of Diagnostic

def fail!(diagnostics, message)
  diagnostics << Diagnostic.new(:error, message)
end

def warn(diagnostics, message)
  diagnostics << Diagnostic.new(:warning, message)
end

# ---------- Load and parse the manifest ----------

unless File.exists?(MANIFEST_PATH)
  STDERR.puts "FATAL: manifest not found at #{MANIFEST_PATH}"
  exit 1
end

manifest = YAML.parse(File.read(MANIFEST_PATH))

# ---------- Extract Tier 1+2 widget names from tier-matrix.md ----------

tier_matrix_widgets = Set(String).new
File.read(TIER_MATRIX).each_line do |line|
  if md = line.match(/^\|\s*([A-Z][A-Za-z]+)\s*\|\s*`src\/ui\/views\//)
    tier_matrix_widgets << md[1]
  end
end

# Remove Tier 3 entries (they have a different table structure) — Tier 3
# table starts after the "## Tier 3" heading.
# The simple regex above catches all rows; we then drop the Tier 3 names
# explicitly.
TIER_3_WIDGETS = %w[ActionSheet ContextMenu PathControl ActionSheetWithWebFallback ContextMenuWithWebFallback PathControlWithWebFallback]
TIER_3_WIDGETS.each { |w| tier_matrix_widgets.delete(w) }

# ---------- Extract intent identifiers from intent-catalog.md ----------

intent_catalog_identifiers = Set(String).new
File.read(INTENT_CATALOG).each_line do |line|
  if md = line.match(/^### `(:[a-z_]+)`/)
    intent_catalog_identifiers << md[1]
  end
end

# ---------- Validate widgets section ----------

widgets_yaml = manifest["widgets"].as_a

manifest_widget_names = Set(String).new
widgets_yaml.each do |widget|
  name = widget["name"].as_s
  manifest_widget_names << name

  # 1. widget_class must be valid
  klass = widget["widget_class"].as_s
  unless VALID_WIDGET_CLASSES.includes?(klass)
    fail!(diagnostics, "widget #{name}: invalid widget_class '#{klass}' " \
                       "(must be one of: #{VALID_WIDGET_CLASSES.join(", ")})")
  end

  # 2. tier must be 1 or 2
  tier = widget["tier"].as_i
  unless [1, 2].includes?(tier)
    fail!(diagnostics, "widget #{name}: invalid tier #{tier} (must be 1 or 2)")
  end

  # 3. override_path_status must be valid
  ops_node = widget["override_path_status"]?
  if ops_node
    ops = ops_node.as_s
    unless VALID_OVERRIDE_STATUSES.includes?(ops)
      fail!(diagnostics, "widget #{name}: invalid override_path_status '#{ops}' " \
                         "(must be one of: #{VALID_OVERRIDE_STATUSES.join(", ")})")
    end
  end

  # 4. demo_status must be valid
  ds_node = widget["demo_status"]?
  if ds_node
    ds = ds_node.as_s
    unless VALID_DEMO_STATUSES.includes?(ds)
      fail!(diagnostics, "widget #{name}: invalid demo_status '#{ds}' " \
                         "(must be one of: #{VALID_DEMO_STATUSES.join(", ")})")
    end
  end

  # 5. If canonical_example is set, the cited file must exist and
  #    the line number must be addressable.
  ce_node = widget["canonical_example"]?
  if ce_node && !ce_node.raw.nil?
    file_node = ce_node["file"]?
    if file_node && !file_node.raw.nil?
      file = file_node.as_s
      full_path = File.join(REPO_ROOT, file)
      unless File.exists?(full_path)
        fail!(diagnostics, "widget #{name}: canonical_example.file '#{file}' does not exist")
      else
        # Verify the line number is within the file
        line_node = ce_node["line"]?
        if line_node && !line_node.raw.nil?
          line_num = line_node.as_i
          line_count = File.read(full_path).lines.size
          if line_num < 1 || line_num > line_count
            fail!(diagnostics, "widget #{name}: canonical_example.line #{line_num} " \
                               "out of range for #{file} (#{line_count} lines)")
          end
        end

        # If source_hash is set, verify it matches
        hash_node = ce_node["source_hash"]?
        if hash_node && !hash_node.raw.nil?
          expected = hash_node.as_s
          actual = Digest::SHA256.hexdigest(File.read(full_path))
          if actual != expected
            fail!(diagnostics, "widget #{name}: source_hash drift on '#{file}' " \
                               "(expected #{expected[0..15]}..., got #{actual[0..15]}...)")
          end
        end
      end
    end
  end

  # 6. If usage_doc is set, the cited file must exist.
  ud_node = widget["usage_doc"]?
  if ud_node && !ud_node.raw.nil?
    path_node = ud_node["path"]?
    if path_node && !path_node.raw.nil?
      path = path_node.as_s
      full_path = File.join(REPO_ROOT, path)
      unless File.exists?(full_path)
        fail!(diagnostics, "widget #{name}: usage_doc.path '#{path}' does not exist")
      end
    end
  end

  # 7. blocking_p1s must be an array of strings
  bp1_node = widget["blocking_p1s"]?
  if bp1_node && !bp1_node.raw.nil?
    bp1_node.as_a.each do |item|
      _ = item.as_s # type check; raises if not a string
    end
  end
end

# 8. Every Tier 1+2 widget in tier-matrix.md MUST be in the manifest
missing_widgets = tier_matrix_widgets - manifest_widget_names
missing_widgets.each do |w|
  fail!(diagnostics, "widget '#{w}' in tier-matrix.md but missing from manifest")
end

# 9. Every widget in the manifest MUST be in tier-matrix.md
extra_widgets = manifest_widget_names - tier_matrix_widgets
extra_widgets.each do |w|
  fail!(diagnostics, "widget '#{w}' in manifest but missing from tier-matrix.md")
end

# ---------- Validate intents section ----------

intents_yaml = manifest["intents"].as_a

manifest_intent_identifiers = Set(String).new
intents_yaml.each do |intent|
  identifier = intent["identifier"].as_s
  manifest_intent_identifiers << identifier

  # 1. class must be one of A/B/C/D
  klass = intent["class"].as_s
  unless VALID_INTENT_CLASSES.includes?(klass)
    fail!(diagnostics, "intent #{identifier}: invalid class '#{klass}' " \
                       "(must be one of: A, B, C, D)")
  end

  # 2. owning_widgets must reference real widgets
  ow_node = intent["owning_widgets"]?
  if ow_node && !ow_node.raw.nil?
    ow_node.as_a.each do |w|
      w_name = w.as_s
      unless manifest_widget_names.includes?(w_name)
        fail!(diagnostics, "intent #{identifier}: owning_widget '#{w_name}' " \
                           "not in manifest widgets section")
      end
    end
  end
end

# 3. Every intent in intent-catalog.md MUST be in the manifest
missing_intents = intent_catalog_identifiers - manifest_intent_identifiers
missing_intents.each do |i|
  fail!(diagnostics, "intent '#{i}' in intent-catalog.md but missing from manifest")
end

# 4. Every intent in the manifest MUST be in intent-catalog.md
extra_intents = manifest_intent_identifiers - intent_catalog_identifiers
extra_intents.each do |i|
  fail!(diagnostics, "intent '#{i}' in manifest but missing from intent-catalog.md")
end

# ---------- Validate blocking_p1_violations section ----------

p1_node = manifest["blocking_p1_violations"]?
if p1_node && !p1_node.raw.nil?
  p1_node.as_a.each do |violation|
    id = violation["id"].as_s

    # Affected widgets must be in the manifest
    aw_node = violation["affected_widgets"]?
    if aw_node && !aw_node.raw.nil?
      aw_node.as_a.each do |w|
        w_name = w.as_s
        unless manifest_widget_names.includes?(w_name)
          fail!(diagnostics, "P1 violation #{id}: affected_widget '#{w_name}' " \
                             "not in manifest widgets section")
        end
      end
    end

    # Verify the cited reproduction_spec path (if not TBD)
    rs_node = violation["reproduction_spec"]?
    if rs_node && !rs_node.raw.nil?
      rs = rs_node.as_s
      unless rs.starts_with?("TBD") || rs.includes?("# TBD")
        full_path = File.join(REPO_ROOT, rs)
        unless File.exists?(full_path)
          warn(diagnostics, "P1 violation #{id}: reproduction_spec '#{rs}' " \
                            "does not yet exist (acceptable if violation is not-reproduced-by-spec)")
        end
      end
    end
  end
end

# ---------- Report ----------

errors = diagnostics.select { |d| d.severity == :error }
warnings = diagnostics.select { |d| d.severity == :warning }

if diagnostics.empty?
  puts "OK — catalog-coverage.yml clean (#{manifest_widget_names.size} widgets, " \
       "#{manifest_intent_identifiers.size} intents)"
  exit 0
end

errors.each { |d| puts d }
warnings.each { |d| puts d }

puts ""
puts "Summary: #{errors.size} errors, #{warnings.size} warnings"
puts "Manifest: #{manifest_widget_names.size} widgets, #{manifest_intent_identifiers.size} intents"

exit(errors.empty? ? 0 : 1)
