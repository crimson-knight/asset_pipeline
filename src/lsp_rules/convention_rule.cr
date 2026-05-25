# Phase 10A.0a — Convention rule base class + diagnostic shape.
#
# Every convention rule is a Crystal class subclassing `ConventionRule`.
# Rules are loaded by `scripts/lint_conventions.cr` and applied to every
# file the runner visits. The directory name `src/lsp_rules/` is kept so
# rule classes port directly if AmberLSP later grows a Crystal-compiled
# rule loader; today there is no LSP coupling.

# Diagnostic record produced by a `ConventionRule#check` call.
#
# The runner serializes diagnostics as one line each in the format:
# `<file>:<line>: [<rule_name>] <message> (suggested: <fix>)`
struct Diagnostic
  property file_path : String
  property line : Int32
  property rule_name : String
  property message : String
  property suggested_fix : String?

  def initialize(@file_path : String, @line : Int32, @rule_name : String, @message : String, @suggested_fix : String? = nil)
  end

  # Renders the diagnostic in the runner's stable human + machine format.
  def to_s(io : IO) : Nil
    io << file_path << ':' << line << ": [" << rule_name << "] " << message
    if fix = suggested_fix
      io << " (suggested: " << fix << ')'
    end
  end
end

# Abstract base class for every Phase 10 convention rule.
#
# Subclasses implement `check(file_path, content)` returning zero or more
# `Diagnostic` values. Rules should be stateless — instances are reused
# across files. Heuristics are regex/string level; we do not parse Crystal.
abstract class ConventionRule
  abstract def rule_name : String
  abstract def check(file_path : String, content : String) : Array(Diagnostic)

  # Returns the 1-based line number of the first match of `pattern` in
  # `content`, or `nil` if the pattern is not found. Helper for rules.
  def find_line(content : String, pattern : Regex) : Int32?
    content.each_line.with_index(1) do |line, lineno|
      return lineno if pattern.matches?(line)
    end
    nil
  end

  # Converts `PascalCase` / `camelCase` identifiers to `snake_case`.
  def snake_case(identifier : String) : String
    s = identifier.gsub(/([A-Z]+)([A-Z][a-z])/) { "#{$1}_#{$2}" }
    s = s.gsub(/([a-z\d])([A-Z])/) { "#{$1}_#{$2}" }
    s.downcase
  end
end
