# Phase 10A.final — Family 5 partial rule regression spec.
#
# Fixture-driven, mirroring Family 1 / Family 2 / Family 3 / Family 4
# shape. Covers all three Family 5 rules:
#
#   * `family_5_partial/spec_platform_directory` (shipped in 10C.0;
#     this spec file backfills its regression coverage).
#   * `family_5_partial/native_spec_has_platform_flag` (10A.final new).
#   * `family_5_partial/cross_target_spec_purity` (10A.final new).
#
# Each fixture under
# `spec/web/lint_conventions/fixtures/family_5_partial/` declares its
# target rule, expected outcome (pass/fail), and a synthetic file_path.

require "spec"
require "../../../src/lsp_rules/convention_rule"

# Auto-require every rule file so `ConventionRule.registered_rules`
# is populated when the spec runs.
{% for path in `cd #{__DIR__}/../../../src/lsp_rules && find . -type f -name "*_rule.cr" | sed 's|^\\./|../../../src/lsp_rules/|'`.split('\n').reject(&.empty?) %}
  require {{ path }}
{% end %}

private record Family5Fixture,
  path : String,
  fixture_for : Array(String),
  expected : Symbol,
  synthetic_path : String,
  content : String

private def parse_family_5_fixture(path : String) : Family5Fixture
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
  Family5Fixture.new(
    path: path,
    fixture_for: fixture_for,
    expected: expected,
    synthetic_path: synthetic_path,
    content: content
  )
end

private def family_5_all_rules : Array(ConventionRule)
  config = ConventionConfig.new
  ConventionRule.registered_rules.map do |klass|
    instance = klass.new
    instance.configure(config)
    instance.as(ConventionRule)
  end
end

private def family_5_rule_by_name(name : String) : ConventionRule
  rule = family_5_all_rules.find { |r| r.rule_name == name }
  raise "no rule named '#{name}'" unless rule
  rule
end

describe "Family 5 partial rules — regression fixtures" do
  fixture_root = File.join(__DIR__, "fixtures", "family_5_partial")
  fixture_paths = Dir.glob(File.join(fixture_root, "*.cr")).sort

  it "loads at least 10 fixtures (3 rules × {pass + fail + false-positive guards})" do
    fixture_paths.size.should be >= 10
  end

  fixture_paths.each do |path|
    fixture = parse_family_5_fixture(path)
    basename = File.basename(path)

    fixture.fixture_for.each do |rule_name|
      it "[#{basename}] rule #{rule_name} -> #{fixture.expected}" do
        rule = family_5_rule_by_name(rule_name)
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

  it "the rule registry contains all 3 Family 5 partial rules" do
    names = family_5_all_rules.map(&.rule_name)
    names.should contain("family_5_partial/spec_platform_directory")
    names.should contain("family_5_partial/native_spec_has_platform_flag")
    names.should contain("family_5_partial/cross_target_spec_purity")
  end
end
