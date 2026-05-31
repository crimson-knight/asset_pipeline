require "spec"
require "../../../../src/ui"

# Value-fidelity unit tests for the ColorPicker colour channel fix.
#
# The renderers register `UI::ColorPicker.parse_rgba` on the STRING channel;
# the Swift ColorStorage binding fires "r,g,b,a" (sRGB 0..1). These specs
# prove the parse + the registry round-trip without a native build — the
# fast CI gate for the value-drop fix (handler must get the NEW colour).
describe UI::ColorPicker do
  describe ".parse_rgba" do
    it "parses a well-formed RGBA payload into a UI::Color" do
      c = UI::ColorPicker.parse_rgba("1.0,0.0,0.0,1.0")
      c.should_not be_nil
      c = c.not_nil!
      c.r.should eq(1.0)
      c.g.should eq(0.0)
      c.b.should eq(0.0)
      c.a.should eq(1.0)
    end

    it "parses fractional channels" do
      c = UI::ColorPicker.parse_rgba("0.5,0.25,0.75,0.5").not_nil!
      c.r.should be_close(0.5, 1e-9)
      c.g.should be_close(0.25, 1e-9)
      c.b.should be_close(0.75, 1e-9)
      c.a.should be_close(0.5, 1e-9)
    end

    it "clamps out-of-range channels to 0.0..1.0" do
      c = UI::ColorPicker.parse_rgba("1.5,-0.2,0.0,2.0").not_nil!
      c.r.should eq(1.0)
      c.g.should eq(0.0)
      c.b.should eq(0.0)
      c.a.should eq(1.0)
    end

    it "returns nil for wrong arity" do
      UI::ColorPicker.parse_rgba("1.0,0.0,0.0").should be_nil
    end

    it "returns nil for non-numeric payloads" do
      UI::ColorPicker.parse_rgba("a,b,c,d").should be_nil
    end

    it "returns nil for an empty payload" do
      UI::ColorPicker.parse_rgba("").should be_nil
    end
  end

  describe "string-channel round-trip" do
    after_each { UI::CallbackRegistry.clear }

    it "delivers the NEW picked colour to on_change via the string channel" do
      captured : UI::Color? = nil
      # Mirror what the renderer registers: a string callback that parses
      # the RGBA payload and calls the handler with the resulting colour.
      token = UI::CallbackRegistry.register_string(->(payload : String) {
        if color = UI::ColorPicker.parse_rgba(payload)
          captured = color
        end
        nil
      })

      # Simulate the Swift ColorStorage binding firing the new pick (red).
      UI::CallbackRegistry.call_string(token, "1.0,0.0,0.0,1.0")

      captured.should_not be_nil
      captured.not_nil!.r.should eq(1.0)
      captured.not_nil!.g.should eq(0.0)
      captured.not_nil!.b.should eq(0.0)
    end
  end
end
