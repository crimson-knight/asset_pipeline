require "spec"
require "yaml"

# Configuration contracts, not an assertion that remote CI has executed.
describe "Android CI declaration" do
  root = File.expand_path("..", __DIR__)
  workflow = YAML.parse(File.read(File.join(root, ".github/workflows/android-native.yml")))
  native = workflow["jobs"]["native"]
  steps = native["steps"].as_a

  it "declares both minimum and current API runtime gates on an explicit Linux runner" do
    native["runs-on"].as_s.should eq("ubuntu-24.04")
    native["strategy"]["matrix"]["api"].as_a.map(&.as_i).should eq([31, 35, 36])
    native["strategy"]["fail-fast"].as_bool.should be_false
    native["timeout-minutes"].as_i.should be >= 45
    workflow["on"].as_h.keys.map(&.as_s).sort.should eq(["pull_request", "push", "workflow_dispatch"])
    workflow["on"]["push"]["branches"].as_a.map(&.as_s).should eq(["main"])
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

  it "pins every external action and gives checkout no persistent credential" do
    steps.compact_map { |step| step["uses"]?.try(&.as_s) }.each do |action|
      action.should match(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+@[0-9a-f]{40}\z/)
    end
    steps.find { |step| step["name"].as_s == "Checkout" }.not_nil!["with"]["persist-credentials"].as_bool.should be_false
    workflow["permissions"].as_h.size.should eq(1)
    workflow["permissions"]["contents"].as_s.should eq("read")
  end

  it "uses the complete Makefile target on one explicitly named emulator with a software keyboard" do
    emulator = steps.find { |step| step["name"].as_s == "Native build, runtime and isolated failure gates" }.not_nil!
    emulator["uses"].as_s.should start_with("reactivecircus/android-emulator-runner@")
    inputs = emulator["with"]
    inputs["script"].as_s.should eq("make test-android")
    inputs["arch"].as_s.should eq("x86_64")
    inputs["emulator-port"].as_i.should eq(5554)
    inputs["disable-animations"].as_bool.should be_false
    inputs["enable-hw-keyboard"].as_bool.should be_false
    native["env"]["ANDROID_SERIAL"].as_s.should eq("emulator-5554")
    native["env"].as_h.keys.map(&.as_s).none?(&.starts_with?("ANDROID_SMOKE_")).should be_true
  end

  it "reads toolchain pins, builds the declared ABI bundles and runs host contracts" do
    runs = steps.compact_map { |step| step["run"]?.try(&.as_s) }.join("\n")
    runs.should contain("source config/android_toolchain.env")
    runs.should contain("android_each_abi")
    runs.should contain("bash scripts/build_android_deps.sh")
    runs.should contain("bash scripts/tests/android_target_entrypoint.sh")
    runs.should contain("crystal spec spec/android_ci_spec.cr spec/web/ui")
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
