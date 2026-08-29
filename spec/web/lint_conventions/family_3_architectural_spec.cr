# Phase 10A.0c — Family 3 architectural convention rule regression spec.
#
# Mirrors Family 1's fixture-driven shape: each fixture under
# `spec/web/lint_conventions/fixtures/family_3_architectural/` declares
# (via leading `# key: value` comments) which rule it exercises, the
# expected outcome (`pass` or `fail`), and the synthesized file path to
# use during replay.
#
# The fixture set covers, for each Family 3 rule:
#   * one pass fixture (legitimate code),
#   * one fail fixture (intentional violation),
#   * ≥2 false-positive guards (legitimate code that a naive regex
#     might over-flag) per Decision 3.

require "spec"
require "../../../src/lsp_rules/convention_rule"

# Auto-require every rule file so `ConventionRule.registered_rules`
# is populated when the spec runs.
{% for path in `cd #{__DIR__}/../../../src/lsp_rules && find . -type f -name "*_rule.cr" | sed 's|^\\./|../../../src/lsp_rules/|'`.split('\n').reject(&.empty?) %}
  require {{ path }}
{% end %}

private record Family3FixtureCase,
  path : String,
  fixture_for : Array(String),
  expected : Symbol, # :pass or :fail
  synthetic_path : String,
  content : String

private def parse_family_3_fixture(path : String) : Family3FixtureCase
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
  Family3FixtureCase.new(
    path: path,
    fixture_for: fixture_for,
    expected: expected,
    synthetic_path: synthetic_path,
    content: content
  )
end

private def family_3_all_rules : Array(ConventionRule)
  config = ConventionConfig.new
  ConventionRule.registered_rules.map do |klass|
    instance = klass.new
    instance.configure(config)
    instance.as(ConventionRule)
  end
end

private def family_3_rule_by_name(name : String) : ConventionRule
  rule = family_3_all_rules.find { |r| r.rule_name == name }
  raise "no rule named '#{name}'" unless rule
  rule
end

describe "Family 3 architectural rules — regression fixtures" do
  fixture_root = File.join(__DIR__, "fixtures", "family_3_architectural")
  fixture_paths = Dir.glob(File.join(fixture_root, "*.cr")).sort

  it "loads at least 24 fixtures (5 rules × {pass + fail + ≥2 false-positive guards}, plus iter 2 additions)" do
    fixture_paths.size.should be >= 24
  end

  fixture_paths.each do |path|
    fixture = parse_family_3_fixture(path)
    basename = File.basename(path)

    fixture.fixture_for.each do |rule_name|
      it "[#{basename}] rule #{rule_name} -> #{fixture.expected}" do
        rule = family_3_rule_by_name(rule_name)
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

  it "the rule registry contains all 5 Family 3 rules" do
    names = family_3_all_rules.map(&.rule_name)
    names.should contain("family_3/no_app_domain_mutation_in_screen_build")
    names.should contain("family_3/controller_action_returns_action_result")
    names.should contain("family_3/screen_build_signature")
    names.should contain("family_3/widget_route_resolve_capability_arg")
    names.should contain("family_3/override_widget_subclass")
  end
end
