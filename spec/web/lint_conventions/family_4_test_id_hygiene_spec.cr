# Phase 10A.final — Family 4 test_id hygiene rule regression spec.
#
# Fixture-driven, mirroring Family 1 / Family 2 / Family 3 shape.
# Each fixture under
# `spec/web/lint_conventions/fixtures/family_4_test_id_hygiene/`
# declares its target rule, expected outcome (pass/fail), and a
# synthetic file_path. The rule is replayed against the fixture
# content using the synthetic_path; the spec asserts the diagnostic
# count matches the expectation.

require "spec"
require "../../../src/lsp_rules/convention_rule"

# Auto-require every rule file so `ConventionRule.registered_rules`
# is populated when the spec runs.
{% for path in `cd #{__DIR__}/../../../src/lsp_rules && find . -type f -name "*_rule.cr" | sed 's|^\\./|../../../src/lsp_rules/|'`.split('\n').reject(&.empty?) %}
  require {{ path }}
{% end %}

private record Family4Fixture,
  path : String,
  fixture_for : Array(String),
  expected : Symbol,
  synthetic_path : String,
  content : String

private def parse_family_4_fixture(path : String) : Family4Fixture
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
  Family4Fixture.new(
    path: path,
    fixture_for: fixture_for,
    expected: expected,
    synthetic_path: synthetic_path,
    content: content
  )
end

private def family_4_all_rules : Array(ConventionRule)
  config = ConventionConfig.new
  ConventionRule.registered_rules.map do |klass|
    instance = klass.new
    instance.configure(config)
    instance.as(ConventionRule)
  end
end

private def family_4_rule_by_name(name : String) : ConventionRule
  rule = family_4_all_rules.find { |r| r.rule_name == name }
  raise "no rule named '#{name}'" unless rule
  rule
end

describe "Family 4 test_id hygiene rules — regression fixtures" do
  fixture_root = File.join(__DIR__, "fixtures", "family_4_test_id_hygiene")
  fixture_paths = Dir.glob(File.join(fixture_root, "*.cr")).sort

  it "loads at least 11 fixtures (3 rules × {pass + fail + ≥2 false-positive guards})" do
    fixture_paths.size.should be >= 11
  end

  fixture_paths.each do |path|
    fixture = parse_family_4_fixture(path)
    basename = File.basename(path)

    fixture.fixture_for.each do |rule_name|
      it "[#{basename}] rule #{rule_name} -> #{fixture.expected}" do
        rule = family_4_rule_by_name(rule_name)
        diagnostics = rule.check(fixture.synthetic_path, fixture.content)
        case fixture.expected
        when :pass
          diagnostics.empty?.should be_true
        when :fail
          diagnostics.empty?.should be_false
          diagnostics.first.rule_name.should eq(rule_name)
        end
      end
    end
  end

  it "the rule registry contains all 3 Family 4 rules" do
    names = family_4_all_rules.map(&.rule_name)
    names.should contain("family_4/interactive_widget_test_id")
    names.should contain("family_4/spec_test_id_reference")
    names.should contain("family_4/unique_test_id_per_screen")
  end
end
