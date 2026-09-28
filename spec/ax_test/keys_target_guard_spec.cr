require "spec"

# Runs in the plain lane on purpose: it reads source, so it guards every
# platform build. A key event posted to the global HID tap types into whatever
# app has focus (it once sent chat messages from the owner's Messages app
# during a spec run). AXTest may only post keys to a target pid.
describe "AXTest keyboard synthesis" do
  it "never posts events to the global event tap" do
    list_of_offenders = Dir.glob("#{__DIR__}/../../src/ui/ax_test/**/*.cr").select do |path|
      source = File.read(path)
      source.includes?("CGEventPost(") || source.includes?("CGHIDEventTap") || source.includes?("CGSessionEventTap")
    end
    list_of_offenders.should be_empty
  end
end
