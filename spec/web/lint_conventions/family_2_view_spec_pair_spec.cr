# Phase 10A.0b — Family 2 view-spec pair regression spec.
#
# Mirrors `family_1_naming_spec.cr` for Family 2 fixtures under
# `spec/web/lint_conventions/fixtures/family_2/`. Each fixture file
# declares the rule it targets, the expected outcome (pass / fail),
# and a synthetic file_path. The rule is replayed against the
# fixture content using the synthetic_path, and the spec asserts
# whether a diagnostic was produced.
#
# Family 2 rules check disk state (File.exists? on view files and
# spec files), so fixtures must use synthetic paths whose paired
# file genuinely exists OR is genuinely absent — they are not
# isolated from the live repo tree.

require "spec"
require "../../../src/lsp_rules/convention_rule"

# Auto-require every rule file so `ConventionRule.registered_rules`
# is populated when the spec runs.
{% for path in `cd #{__DIR__}/../../../src/lsp_rules && find . -type f -name "*_rule.cr" | sed 's|^\\./|../../../src/lsp_rules/|'`.split('\n').reject(&.empty?) %}
  require {{ path }}
{% end %}

private record Family2Fixture,
  path : String,
  fixture_for : Array(String),
  expected : Symbol,
  synthetic_path : String,
  content : String

private def parse_family_2_fixture(path : String) : Family2Fixture
  content = File.read(path)
  fixture_for = [] of String
  expected = :pass
  synthetic_path = ""
  content.each_line do |raw|
    line = raw.strip
    break unless line.starts_with?("#")
    body = line.sub(/^#\s*/, "")
    if body.starts_with?("fixture_for:")
      fixture_for = body.sub("fixture_for:", "").split(',').map(&.strip).reject(&.empty?)
    elsif body.starts_with?("expected:")
      raw_val = body.sub("expected:", "").strip
      expected = case raw_val
                 when "fail" then :fail
                 else             :pass
                 end
    elsif body.starts_with?("synthetic_path:")
      synthetic_path = body.sub("synthetic_path:", "").strip
    end
  end
  Family2Fixture.new(
    path: path,
    fixture_for: fixture_for,
    expected: expected,
    synthetic_path: synthetic_path,
    content: content
  )
end

private def family_2_rules : Array(ConventionRule)
  # Use a FRESH ConventionConfig that does NOT load .lint_conventions.yml,
  # so the production allowlist does not bleed into fixture replay. The
  # rule's behavior must be observable in isolation.
  config = ConventionConfig.new
  ConventionRule.registered_rules.map do |klass|
    instance = klass.new
    instance.configure(config)
    instance.as(ConventionRule)
  end
end

private def family_2_rule_by_name(name : String) : ConventionRule
  rule = family_2_rules.find { |r| r.rule_name == name }
  raise "no rule named '#{name}'" unless rule
  rule
end

describe "Family 2 view-spec pair rules — regression fixtures" do
  fixture_root = File.join(__DIR__, "fixtures", "family_2")
  fixture_paths = Dir.glob(File.join(fixture_root, "*.cr")).sort

  it "loads at least 10 fixtures" do
    fixture_paths.size.should be >= 10
  end

  fixture_paths.each do |path|
    fixture = parse_family_2_fixture(path)
    basename = File.basename(path)

    fixture.fixture_for.each do |rule_name|
      it "[#{basename}] rule #{rule_name} -> #{fixture.expected}" do
        rule = family_2_rule_by_name(rule_name)
        diagnostics = rule.check(fixture.synthetic_path, fixture.content)
        case fixture.expected
        when :pass
          unless diagnostics.empty?
            fail "expected no diagnostics, got: #{diagnostics.map(&.to_s).join("\n")}"
          end
        when :fail
          if diagnostics.empty?
            fail "expected at least one diagnostic for rule #{rule_name}, got none"
          end
          diagnostics.first.rule_name.should eq(rule_name)
        end
      end
    end
  end

  it "the rule registry contains all 3 Family 2 rules" do
    names = family_2_rules.map(&.rule_name)
    names.should contain("family_2/view_has_spec")
    names.should contain("family_2/spec_has_view")
    names.should contain("family_2/spec_describe_matches_class")
  end
end
