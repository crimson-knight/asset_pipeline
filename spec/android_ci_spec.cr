require "spec"
require "yaml"

# Configuration contracts, not an assertion that remote CI has executed.
describe "Android CI declaration" do
  root = File.expand_path("..", __DIR__)
  text = File.read(File.join(root, ".github/workflows/android-native.yml"))
  workflow = YAML.parse(text)
  native = workflow["jobs"]["native"]
  steps = native["steps"].as_a
  report = workflow["jobs"]["report"]

  it "declares the floor, an intermediate release and the target on an explicit Linux runner" do
    native["runs-on"].as_s.should eq("ubuntu-24.04")
    # Strings, because Android names minor SDK releases (36.1, 37.0). The newest
    # released runtime runs in android-next.yml, never in this gate.
    native["strategy"]["matrix"]["api"].as_a.map(&.as_s).should eq(["31", "35", "36"])
    native["strategy"]["fail-fast"].as_bool.should be_false
    native["timeout-minutes"].as_i.should be >= 45
    workflow["on"].as_h.keys.map(&.as_s).sort.should eq(["pull_request", "push", "schedule", "workflow_dispatch"])
    workflow["on"]["push"]["branches"].as_a.map(&.as_s).should eq(["main"])
  end

  it "runs nightly without anyone pushing" do
    crons = workflow["on"]["schedule"].as_a.map { |entry| entry["cron"].as_s }
    crons.size.should eq(1)
    crons.first.should match(/\A\d{1,2} \d{1,2} \* \* \*\z/)
  end

  it "never ignores or conditionally skips a mandatory gate" do
    native["continue-on-error"]?.should be_nil
    native["if"]?.should be_nil
    steps.each do |step|
      step["continue-on-error"]?.should be_nil
      unless step["name"].as_s == "Retain evidence and packages, including failures"
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

  it "reports the outcome to an issue on the runs nobody is watching, and only there" do
    report["needs"].as_s.should eq("native")
    report["if"].as_s.should contain("always()")
    report["if"].as_s.should contain("github.event_name != 'pull_request'")
    report["permissions"].as_h.size.should eq(2)
    report["permissions"]["contents"].as_s.should eq("read")
    report["permissions"]["issues"].as_s.should eq("write")
    reporter = report["steps"].as_a.find { |step| step["run"]? }.not_nil!
    reporter["run"].as_s.should eq("bash scripts/ci/report_outcome.sh")
    env = reporter["env"]
    env["OUTCOME"].as_s.should eq("${{ needs.native.result }}")
    env["LANE"].as_s.should eq("android-native")
    env["MAINTAINERS"].as_s.should eq("${{ vars.CI_MAINTAINERS }}")
    env["GH_TOKEN"].as_s.should eq("${{ github.token }}")
    File::Info.executable?(File.join(root, "scripts/ci/report_outcome.sh")).should be_true
    File::Info.executable?(File.join(root, "scripts/tests/report_outcome.sh")).should be_true
    selftest = report["steps"].as_a.find { |step| step["name"].as_s.starts_with?("Reporter self-test") }.not_nil!
    selftest["if"].as_s.should eq("github.event_name == 'workflow_dispatch' && inputs.report_selftest")
    selftest["env"]["LANE"].as_s.should eq("selftest")
    workflow["on"]["workflow_dispatch"]["inputs"]["report_selftest"]["default"].as_bool.should be_false
  end

  it "boots one explicitly named emulator through the lane's own launcher and runs the complete Makefile target on it" do
    gate = steps.find { |step| step["name"].as_s == "Native build, runtime and isolated failure gates" }.not_nil!
    gate["uses"]?.should be_nil
    gate["run"].as_s.should eq(%(bash scripts/ci/android_emulator.sh run "$ANDROID_RUNTIME_API" 5554 -- make test-android))
    env = gate["env"]
    env["ANDROID_RUNTIME_API"].as_s.should eq("${{ matrix.api }}")
    # ANDROID_API is the shard's native compile-floor override; a runtime level there
    # made the bridge look for an API 36 compiler on the runner.
    env["ANDROID_API"]?.should be_nil
    env["EMULATOR_TARGET"].as_s.should eq("google_apis")
    env["EMULATOR_ARCH"].as_s.should eq("x86_64")
    env["EMULATOR_PROFILE"].as_s.should eq("pixel_6")
    env["EMULATOR_CORES"].as_s.should eq("4")
    env["EMULATOR_RAM_MB"].as_s.should eq("4096")
    # The launcher's defaults stand: no window, SwiftShader, no snapshot, animations on, software keyboard.
    env["EMULATOR_OPTIONS"]?.should be_nil
    native["env"]["ANDROID_SERIAL"].as_s.should eq("emulator-5554")
    native["env"].as_h.keys.map(&.as_s).none?(&.starts_with?("ANDROID_SMOKE_")).should be_true
    File::Info.executable?(File.join(root, "scripts/ci/android_emulator.sh")).should be_true
    text.should_not contain("android-emulator-runner")
  end

  it "reads toolchain pins, builds the declared ABI bundles and runs host contracts" do
    runs = steps.compact_map { |step| step["run"]?.try(&.as_s) }.join("\n")
    runs.should contain("source config/android_toolchain.env")
    runs.should contain("android_each_abi")
    runs.should contain("bash scripts/build_android_deps.sh")
    runs.should contain("bash scripts/tests/android_target_entrypoint.sh")
    runs.should contain("crystal spec spec/android_ci_spec.cr spec/web/ui")
    runs.should contain("ruby scripts/view_parity_matrix.rb --check")
    runs.should contain("ruby scripts/support_matrix.rb --check")
    runs.should contain("test -c /dev/kvm")
    runs.should contain("git diff --exit-code")
    runs.should_not contain("|| true")
  end

  it "retains evidence on failure and fails when no requested artifacts exist" do
    upload = steps.last
    upload["if"].as_s.should eq("always()")
    upload["with"]["if-no-files-found"].as_s.should eq("error")
    upload["with"]["path"].as_s.should contain("build/android-ci/")
    upload["with"]["path"].as_s.should contain("outputs/apk/")
    upload["with"]["path"].as_s.should contain("outputs/bundle/")
  end

  it "removes the old false-success Android placeholder without removing other platform jobs" do
    legacy = YAML.parse(File.read(File.join(root, ".github/workflows/initiative-cross-platform-ui.yml")))
    legacy["jobs"]["test-android"]?.should be_nil
    %w[test-web-linux test-web-macos test-macos test-ios].each { |name| legacy["jobs"][name]?.should_not be_nil }
  end
end
