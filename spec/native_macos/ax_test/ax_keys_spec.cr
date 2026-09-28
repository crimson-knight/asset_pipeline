{% if flag?(:macos) %}
  require "spec"
  require "../../../src/ui"
  require "../../../src/ui/ax_test"

  # A6 — Synthetic keyboard events via CGEvent, delivered to ONE process.
  #
  # Every example posts to a throwaway `/bin/sleep` process that has no windows,
  # so nothing typed here can reach the owner's apps. Real delivery into a
  # focused field is covered by the fixture-app specs (surface craft, Voyager),
  # which pass their own launched App.
  private def with_key_sink(&)
    sink = Process.new("/bin/sleep", ["30"])
    begin
      yield sink.pid.to_i32
    ensure
      sink.terminate rescue nil
      sink.wait rescue nil
    end
  end

  describe UI::AXTest::Keys do
    describe "named key helpers" do
      it "posts every named key to the target pid without raising" do
        with_key_sink do |target_pid|
          UI::AXTest::Keys.escape!(target_pid)
          UI::AXTest::Keys.tab!(target_pid)
          UI::AXTest::Keys.shift_tab!(target_pid)
          UI::AXTest::Keys.return!(target_pid)
          UI::AXTest::Keys.arrow_up!(target_pid)
          UI::AXTest::Keys.arrow_down!(target_pid)
          UI::AXTest::Keys.arrow_left!(target_pid)
          UI::AXTest::Keys.arrow_right!(target_pid)
          UI::AXTest::Keys.space!(target_pid)
          UI::AXTest::Keys.delete!(target_pid)
        end
      end

      it "posts press(keycode, modifiers) to the target pid" do
        with_key_sink do |target_pid|
          UI::AXTest::Keys.press(target_pid, UI::AXTest::Keys::TAB, LibCGEvent::CGEventFlagShift)
        end
      end
    end

    describe "#type" do
      it "types a multi-character string into the target pid" do
        with_key_sink do |target_pid|
          UI::AXTest::Keys.type(target_pid, "hello world 123")
        end
      end

      it "handles unicode characters" do
        with_key_sink do |target_pid|
          UI::AXTest::Keys.type(target_pid, "café — résumé — 中文")
        end
      end

      it "handles an empty string" do
        with_key_sink do |target_pid|
          UI::AXTest::Keys.type(target_pid, "")
        end
      end

      it "refuses a line break instead of pressing Return" do
        with_key_sink do |target_pid|
          expect_raises(UI::AXTest::Keys::LineBreakRefused) do
            UI::AXTest::Keys.type(target_pid, "first line\nsecond line")
          end
          expect_raises(UI::AXTest::Keys::LineBreakRefused) do
            UI::AXTest::Keys.type(target_pid, "carriage\r")
          end
        end
      end
    end

    describe "permission integration" do
      pending "delivers an Escape key to a focused fixture app and verifies dismiss (requires Accessibility permission)"
    end
  end
{% end %}
