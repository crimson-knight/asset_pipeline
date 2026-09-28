# Synthesizes keyboard events via CGEvent for AXTest harnesses. Every event is
# delivered to one target process by pid, never to the frontmost app.

{% if flag?(:macos) %}
  require "./ax_ffi"

  module UI::AXTest
    # Synthesize keyboard events via CGEvent. Each helper posts a clean
    # key-down + key-up pair to ONE target process (`CGEventPostToPid`), so a
    # spec can only ever type into the fixture app it launched.
    #
    # There is deliberately no way to post to the global HID event tap: an
    # event posted there goes to whatever app has keyboard focus, so a spec run
    # while the owner is chatting would type into (and, with Return, send
    # messages from) their real apps. Pass the fixture `App` (or its pid).
    #
    # `type` refuses strings containing a line break for the same reason; send
    # Return explicitly with `return!` when a fixture needs it.
    #
    # ## Permission requirement
    #
    # Posting CGEvents requires the process running `crystal spec` to have
    # **Accessibility** permission (System Settings → Privacy & Security →
    # Accessibility). Without it the OS silently drops the event.
    #
    # ## Key codes
    #
    # Codes are US-layout virtual key codes (Apple's `HIToolbox/Events.h`
    # constants). Non-US layouts are not yet supported.
    module Keys
      extend self

      # Raised when `type` is given a line break (which would press Return).
      class LineBreakRefused < ArgumentError
      end

      # Common virtual key codes (US layout, Carbon/HIToolbox values).
      ESCAPE      =  53_u16
      TAB         =  48_u16
      RETURN      =  36_u16
      SPACE       =  49_u16
      DELETE      =  51_u16
      ARROW_LEFT  = 123_u16
      ARROW_RIGHT = 124_u16
      ARROW_DOWN  = 125_u16
      ARROW_UP    = 126_u16

      # Post a single key-down + key-up pair for `keycode` to `target`. Optional
      # modifier flags (bitwise OR of LibCGEvent::CGEventFlag*) apply to the
      # key-down event only.
      def press(target : App, keycode : UInt16, modifiers : UInt64 = 0_u64) : Nil
        press(target.pid, keycode, modifiers)
      end

      # :ditto:
      def press(target_pid : Int32, keycode : UInt16, modifiers : UInt64 = 0_u64) : Nil
        down = LibCGEvent.CGEventCreateKeyboardEvent(Pointer(Void).null, keycode, 1_u8)
        LibCGEvent.CGEventSetFlags(down, modifiers) if modifiers != 0
        LibCGEvent.CGEventPostToPid(target_pid, down)
        LibCF.CFRelease(down)

        up = LibCGEvent.CGEventCreateKeyboardEvent(Pointer(Void).null, keycode, 0_u8)
        LibCGEvent.CGEventPostToPid(target_pid, up)
        LibCF.CFRelease(up)
      end

      # Escape key (dismiss menu, sheet, popover).
      def escape!(target : App | Int32) : Nil
        press(target, ESCAPE)
      end

      # Tab key (advance focus).
      def tab!(target : App | Int32) : Nil
        press(target, TAB)
      end

      # Shift+Tab (retreat focus).
      def shift_tab!(target : App | Int32) : Nil
        press(target, TAB, LibCGEvent::CGEventFlagShift)
      end

      # Return / Enter key (commit, default-button activation), to the target only.
      def return!(target : App | Int32) : Nil
        press(target, RETURN)
      end

      def arrow_up!(target : App | Int32) : Nil
        press(target, ARROW_UP)
      end

      def arrow_down!(target : App | Int32) : Nil
        press(target, ARROW_DOWN)
      end

      def arrow_left!(target : App | Int32) : Nil
        press(target, ARROW_LEFT)
      end

      def arrow_right!(target : App | Int32) : Nil
        press(target, ARROW_RIGHT)
      end

      def space!(target : App | Int32) : Nil
        press(target, SPACE)
      end

      def delete!(target : App | Int32) : Nil
        press(target, DELETE)
      end

      # Type a string into `target` by posting CGEvents with each character set
      # as the event's Unicode string, which works for any printable character
      # regardless of keyboard layout. Raises `LineBreakRefused` for "\n" or "\r".
      def type(target : App, string : String) : Nil
        type(target.pid, string)
      end

      # :ditto:
      def type(target_pid : Int32, string : String) : Nil
        if string.includes?('\n') || string.includes?('\r')
          raise LineBreakRefused.new("AXTest::Keys.type refuses line breaks; press Return explicitly with return!(target)")
        end

        string.each_char do |character|
          utf16 = character.to_s.to_utf16
          down = LibCGEvent.CGEventCreateKeyboardEvent(Pointer(Void).null, 0_u16, 1_u8)
          LibCGEvent.CGEventKeyboardSetUnicodeString(down, utf16.size.to_i64, utf16.to_unsafe)
          LibCGEvent.CGEventPostToPid(target_pid, down)
          LibCF.CFRelease(down)

          up = LibCGEvent.CGEventCreateKeyboardEvent(Pointer(Void).null, 0_u16, 0_u8)
          LibCGEvent.CGEventKeyboardSetUnicodeString(up, utf16.size.to_i64, utf16.to_unsafe)
          LibCGEvent.CGEventPostToPid(target_pid, up)
          LibCF.CFRelease(up)
        end
      end
    end
  end
{% end %}
