require "spec"
require "yaml"

# Configuration contracts for the Apple lane, not an assertion that remote CI
# has executed.
describe "Apple CI declaration" do
  root = File.expand_path("..", __DIR__)
  text = File.read(File.join(root, ".github/workflows/apple-native.yml"))
  workflow = YAML.parse(text)
  native = workflow["jobs"]["native"]
  steps = native["steps"].as_a
  report = workflow["jobs"]["report"]

  it "runs the current image and the preview image, never a deprecated one" do
    entries = native["strategy"]["matrix"]["include"].as_a
    entries.map { |entry| {entry["runner"].as_s, entry["role"].as_s} }.should eq([{"macos-26", "current"}, {"xcode-27", "preview"}])
    native["runs-on"].as_s.should eq("${{ matrix.runner }}")
    text.should_not contain("macos-14")
    native["strategy"]["fail-fast"].as_bool.should be_false
    native["timeout-minutes"].as_i.should be >= 45
    native["timeout-minutes"].as_i.should be <= 90
  end

  it "triggers on pull requests, pushes to main, a nightly schedule and dispatch" do
    workflow["on"].as_h.keys.map(&.as_s).sort.should eq(["pull_request", "push", "schedule", "workflow_dispatch"])
    workflow["on"]["push"]["branches"].as_a.map(&.as_s).should eq(["main"])
    crons = workflow["on"]["schedule"].as_a.map { |entry| entry["cron"].as_s }
    crons.size.should eq(1)
    crons.first.should match(/\A\d{1,2} \d{1,2} \* \* \*\z/)
    workflow["on"]["workflow_dispatch"]["inputs"]["report_selftest"]["default"].as_bool.should be_false
  end

  it "never ignores or conditionally skips a mandatory gate" do
    native["continue-on-error"]?.should be_nil
    native["if"]?.should be_nil
    steps.each do |step|
      step["continue-on-error"]?.should be_nil
      unless step["name"].as_s == "Retain evidence, including failures"
        step["if"]?.should be_nil
      end
    end
  end

  it "pins every external action in every job and gives checkout no persistent credential" do
    workflow["jobs"].as_h.each_value do |job|
      job["steps"].as_a.each do |step|
        if action = step["uses"]?.try(&.as_s)
          action.should match(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+@[0-9a-f]{40}\z/)
        end
        if step["name"].as_s == "Checkout"
          step["with"]["persist-credentials"].as_bool.should be_false
        end
      end
    end
    workflow["permissions"].as_h.size.should eq(1)
    workflow["permissions"]["contents"].as_s.should eq("read")
  end

  it "installs stock Crystal for the web specs and the pinned fork for the Apple targets" do
    runs = steps.compact_map { |step| step["run"]?.try(&.as_s) }.join("\n")
    runs.should contain("source config/android_toolchain.env")
    runs.should contain("source config/apple_toolchain.env")
    steps.find { |step| step["name"].as_s == "Install pinned Crystal" }.not_nil!["with"]["crystal"].as_s.should eq("${{ steps.pins.outputs.crystal }}")
    # Make reads CRYSTAL from the environment (?=), so the job must not set it globally.
    native["env"]["CRYSTAL"]?.should be_nil
    fork = steps.find { |step| step["name"].as_s.starts_with?("Install the fork compiler") }.not_nil!
    fork["env"]["FORK_VERSION"].as_s.should eq("${{ steps.pins.outputs.fork_version }}")
    fork["run"].as_s.should contain("brew tap \"$FORK_TAP\"")
    fork["run"].as_s.should contain("brew link --overwrite")
    keg = steps.find { |step| step["name"].as_s == "Restore the fork compiler keg" }.not_nil!
    keg["with"]["key"].as_s.should contain("${{ steps.pins.outputs.fork_version }}")
    ios = steps.find { |step| step["name"].as_s.starts_with?("iOS host behavior tests") }.not_nil!
    ios["env"]["CRYSTAL"].as_s.should eq("acrystal")
    runs.should contain("crystal spec spec/android_ci_spec.cr spec/apple_ci_spec.cr")
    runs.should contain("make test-web")
    runs.should contain("make -C samples/cross_platform/macos_host build CODESIGN_IDENTITY=- CRYSTAL=acrystal")
    runs.should contain("make test-ios")
    runs.should contain("git diff --exit-code")
    runs.should_not contain("|| true\n")
    # The fork is addressed by its formula command, never by the developer-machine symlink.
    runs.should_not contain("crystal-alpha")
  end

  it "keeps the cross-compiled C dependencies in a cache keyed on their recipe and pins" do
    cache = steps.find { |step| step["name"].as_s == "Restore the cross-compiled C dependencies" }.not_nil!
    cache["uses"].as_s.should start_with("actions/cache@")
    cache["with"]["path"].as_s.should eq("build/apple-deps")
    cache["with"]["key"].as_s.should contain("hashFiles('scripts/cross_compile_deps.sh'")
    native["env"]["CRYSTAL_CROSS_DEPS"].as_s.should eq("${{ github.workspace }}/build/apple-deps")
  end

  it "reports the outcome to an issue on the runs nobody is watching, with its own lane" do
    report["needs"].as_s.should eq("native")
    report["if"].as_s.should eq("always() && github.event_name != 'pull_request'")
    report["permissions"].as_h.size.should eq(2)
    report["permissions"]["issues"].as_s.should eq("write")
    reporter = report["steps"].as_a.find { |step| step["run"]?.try(&.as_s) == "bash scripts/ci/report_outcome.sh" }.not_nil!
    reporter["env"]["OUTCOME"].as_s.should eq("${{ needs.native.result }}")
    reporter["env"]["LANE"].as_s.should eq("apple-native")
    selftest = report["steps"].as_a.find { |step| step["name"].as_s.starts_with?("Reporter self-test") }.not_nil!
    selftest["if"].as_s.should eq("github.event_name == 'workflow_dispatch' && inputs.report_selftest")
    selftest["env"]["LANE"].as_s.should eq("selftest")
  end

  it "retains evidence on failure and fails when no requested artifacts exist" do
    upload = steps.last
    upload["if"].as_s.should eq("always()")
    upload["with"]["if-no-files-found"].as_s.should eq("error")
    upload["with"]["path"].as_s.should contain("build/apple-ci/")
  end

  it "backs make test-ios with the real lane script, not a placeholder" do
    makefile = File.read(File.join(root, "Makefile"))
    makefile.should match(/^test-ios:\n\t@bash scripts\/test_ios_host\.sh$/m)
    makefile.should_not contain("attempted-blocked")
    File::Info.executable?(File.join(root, "scripts/test_ios_host.sh")).should be_true
  end
end
