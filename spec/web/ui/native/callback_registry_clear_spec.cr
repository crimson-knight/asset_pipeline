require "spec"
require "../../../../src/ui"

describe "UI::CallbackRegistry clearing with outstanding native ownership" do
  before_each { UI::CallbackRegistry.clear }
  after_each { UI::CallbackRegistry.clear }

  it "never makes an old action token dispatch a new registration" do
    retired = UI::CallbackRegistry.register_action { }
    UI::CallbackRegistry.clear
    fired = 0
    current = UI::CallbackRegistry.register_action { fired += 1 }

    UI::CallbackRegistry.invoke_swiftkit(retired, 0.0)
    fired.should eq(0)
    UI::CallbackRegistry.invoke_swiftkit(current, 0.0)
    fired.should eq(1)
  end

  it "does not let stale cleanup delete a registration of another callback type" do
    retired = UI::CallbackRegistry.register_action { }
    UI::CallbackRegistry.clear
    received = 0.0
    current = UI::CallbackRegistry.register_action_with_value { |value| received = value }

    UI::CallbackRegistry.unregister(retired)
    UI::CallbackRegistry.size.should eq(1)
    UI::CallbackRegistry.invoke_swiftkit(current, 0.75)
    received.should eq(0.75)
  end

  it "keeps a new callback alive when an older NativeView is finalized after clear" do
    handle = UI::NativeHandle.new(Pointer(Void).new(0xD00D_u64), UI::ReleaseStrategy::Unowned)
    retired_view = UI::NativeView.new(handle)
    retired_view.register_callback { }
    UI::CallbackRegistry.clear
    fired = 0
    current = UI::CallbackRegistry.register_action { fired += 1 }

    begin
      # Exercise the exact finalizer path deterministically; no GC timing or
      # fake collection result substitutes for the ownership operation.
      retired_view.finalize
      UI::CallbackRegistry.invoke_swiftkit(current, 0.0)
      fired.should eq(1)
      UI::CallbackRegistry.size.should eq(1)
    ensure
      retired_view.teardown!
    end
  end
end
