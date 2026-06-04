{% if flag?(:macos) %}

require "spec"
require "../../../src/ui"
require "../../../src/ui/ax_test"

# A1 — find by AXIdentifier.
#
# These specs exercise the API surface and the recursive-walk semantics.
# Connecting to Finder verifies the wiring works end-to-end against a
# real AX tree (no AX permission required to *read* attributes, but the
# spec runner must have Accessibility access for cross-process reads —
# the existing `ax_app_spec.cr` already establishes this is the case in
# this repo's test environment).
describe UI::AXTest::Element do
  describe "#identifier" do
    it "is a string-returning attribute reader (nil-tolerant)" do
      # Pure surface test: connect to Finder's root, read identifier;
      # may be nil — root apps rarely have AXIdentifier set.
      output = IO::Memory.new
      Process.run("pgrep", ["-x", "Finder"], output: output)
      pid = output.to_s.strip.to_i32
      app = UI::AXTest::App.connect(pid)
      result = app.root.identifier
      (result.nil? || result.is_a?(String)).should be_true
    end
  end

  # These are signature + nil/raise smoke tests against a real AX tree (Finder).
  # They search for a SYNTHETIC id that never matches, which forces a full walk —
  # so they cap max_depth to a shallow level. Without the cap an unmatched query
  # walks Finder's default depth-10, a pathologically wide tree (effectively
  # hangs the spec). A bogus id is absent at any depth, so a shallow walk still
  # correctly returns nil / raises.
  describe "#find(identifier: ...)" do
    it "accepts identifier as a named parameter" do
      output = IO::Memory.new
      Process.run("pgrep", ["-x", "Finder"], output: output)
      pid = output.to_s.strip.to_i32
      app = UI::AXTest::App.connect(pid)
      app.find(identifier: "__nonexistent_test_id_#{Time.utc.to_unix}", max_depth: 2).should be_nil
    end

    it "combines identifier filter with role filter" do
      output = IO::Memory.new
      Process.run("pgrep", ["-x", "Finder"], output: output)
      pid = output.to_s.strip.to_i32
      app = UI::AXTest::App.connect(pid)
      # Combining filters should still return nil for a bogus id.
      app.find(role: "AXButton", identifier: "__bogus__", max_depth: 2).should be_nil
    end
  end

  describe "#find_by_id / #find_by_id!" do
    it "find_by_id returns nil when no element matches" do
      output = IO::Memory.new
      Process.run("pgrep", ["-x", "Finder"], output: output)
      pid = output.to_s.strip.to_i32
      app = UI::AXTest::App.connect(pid)
      app.find_by_id("__nonexistent__", max_depth: 2).should be_nil
    end

    it "find_by_id! raises when no element matches" do
      output = IO::Memory.new
      Process.run("pgrep", ["-x", "Finder"], output: output)
      pid = output.to_s.strip.to_i32
      app = UI::AXTest::App.connect(pid)
      expect_raises(Exception, /no element with AXIdentifier/) do
        app.find_by_id!("__nonexistent__", max_depth: 2)
      end
    end
  end
end

{% end %}
