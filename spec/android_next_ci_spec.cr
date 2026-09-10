require "spec"
require "yaml"

# Configuration contracts for the next-runtime lane, not an assertion that
# remote CI has executed.
describe "Android next runtime declaration" do
  root = File.expand_path("..", __DIR__)
  workflow = YAML.parse(File.read(File.join(root, ".github/workflows/android-next.yml")))
  job = workflow["jobs"]["next"]
  steps = job["steps"].as_a
  report = workflow["jobs"]["report"]
  pins = File.read(File.join(root, "config/android_toolchain.env"))

  it "runs nightly and on dispatch, never as a pull-request or push gate" do
    workflow["on"].as_h.keys.map(&.as_s).sort.should eq(["schedule", "workflow_dispatch"])
    workflow["on"]["schedule"].as_a.first["cron"].as_s.should match(/\A\d{1,2} \d{1,2} \* \* \*\z/)
    workflow["on"]["workflow_dispatch"]["inputs"]["report_selftest"]["default"].as_bool.should be_false
  end

  it "takes the newest released runtime from the toolchain pins and hands it to the lane's launcher" do
    pins.should match(/^ANDROID_NEXT_RUNTIME=\d+(\.\d+)?$/m)
    runs = steps.compact_map { |step| step["run"]?.try(&.as_s) }.join("\n")
    runs.should contain("source config/android_toolchain.env")
    runs.should contain(%(printf 'crystal=%s\\njava=%s\\nnext=%s\\n' "$CRYSTAL_ANDROID_VERSION" "$ANDROID_JAVA_VERSION" "$ANDROID_NEXT_RUNTIME"))
    gate = steps.find { |step| step["name"].as_s == "Native build, runtime and isolated failure gates" }.not_nil!
    gate["env"]["ANDROID_RUNTIME_API"].as_s.should eq("${{ steps.pins.outputs.next }}")
    gate["env"]["ANDROID_API"]?.should be_nil
    gate["env"]["EMULATOR_ARCH"].as_s.should eq("x86_64")
    gate["run"].as_s.should eq(%(bash scripts/ci/android_emulator.sh run "$ANDROID_RUNTIME_API" 5554 -- make test-android))
    runs.should contain("bash scripts/build_android_deps.sh")
    runs.should contain("git diff --exit-code")
    runs.should_not contain("|| true")
    job["runs-on"].as_s.should eq("ubuntu-24.04")
    job["env"]["ANDROID_SERIAL"].as_s.should eq("emulator-5554")
  end

  it "never ignores a gate and pins every external action" do
    job["continue-on-error"]?.should be_nil
    job["if"]?.should be_nil
    workflow["jobs"].as_h.each_value do |j|
      j["steps"].as_a.each do |step|
        step["continue-on-error"]?.should be_nil
        if action = step["uses"]?.try(&.as_s)
          action.should match(/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+@[0-9a-f]{40}\z/)
        end
        step["with"]["persist-credentials"].as_bool.should be_false if step["name"].as_s == "Checkout"
      end
    end
    steps.each { |step| step["if"]?.should be_nil unless step["name"].as_s == "Retain evidence and packages, including failures" }
    workflow["permissions"].as_h.size.should eq(1)
    workflow["permissions"]["contents"].as_s.should eq("read")
  end

  it "reports every run to its own issue lane, since none of its runs is a pull request" do
    report["needs"].as_s.should eq("next")
    report["if"].as_s.should eq("always()")
    report["permissions"]["issues"].as_s.should eq("write")
    reporter = report["steps"].as_a.find { |step| step["run"]?.try(&.as_s) == "bash scripts/ci/report_outcome.sh" }.not_nil!
    reporter["env"]["LANE"].as_s.should eq("android-next")
    reporter["env"]["OUTCOME"].as_s.should eq("${{ needs.next.result }}")
    upload = steps.last
    upload["if"].as_s.should eq("always()")
    upload["with"]["if-no-files-found"].as_s.should eq("error")
  end
end
