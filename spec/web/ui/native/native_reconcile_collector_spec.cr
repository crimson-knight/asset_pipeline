require "spec"
require "../../../../samples/initiative-cross-platform-ui-voyager/native_reconcile_collector"

private def reconcile_handle(address : UInt64, label : String, state_address : UInt64? = nil) : UI::NativeHandle
  handle = UI::NativeHandle.new(Pointer(Void).new(address), UI::ReleaseStrategy::Unowned, label: label)
  handle.state_handle = Pointer(Void).new(state_address.not_nil!) if state_address
  handle
end

private def reconcile_label_native(address : UInt64, state_address : UInt64) : UI::NativeView
  UI::NativeView.new(reconcile_handle(address, "UIHostingController[Label]", state_address))
end

private def reconcile_stack_native(children : Array(UI::NativeView)) : UI::NativeView
  UI::NativeView.new(reconcile_handle(0x1000_u64, "UIStackView[v]"), children)
end

private def reconcile_tree(title : String, echo : String) : UI::View
  stack = UI::VStack.new
  stack << UI::Label.new(title)
  stack << UI::Label.new(echo)
  stack
end

describe Voyager::NativeReconcileCollector do
  it "stages only the changed label while retaining the prior logical tree" do
    session = Voyager::NativeReconcileCollector::Session.new
    prior = reconcile_tree("Stable title", "frame-0")
    session.replace!(prior)
    mounted = reconcile_stack_native([
      reconcile_label_native(0x2000_u64, 0x2100_u64),
      reconcile_label_native(0x3000_u64, 0x3100_u64),
    ])
    current = reconcile_tree("Stable title", "frame-1")
    ops = [] of Voyager::NativeReconcileCollector::Op

    session.collect(current, mounted, ops, Voyager::NativeReconcileCollector::CommitMode::DirtyLabelCommit).should eq(2)
    ops.should eq([{Pointer(Void).new(0x3100_u64), "frame-1"}])
    session.previous.should eq(prior)

    session.commit!(current)
    session.previous.should eq(current)
  end

  it "retains the historical all-label baseline without changing the structural workload" do
    prior = reconcile_tree("Stable title", "frame-0")
    current = reconcile_tree("Stable title", "frame-1")
    mounted = reconcile_stack_native([
      reconcile_label_native(0x2000_u64, 0x2100_u64),
      reconcile_label_native(0x3000_u64, 0x3100_u64),
    ])
    ops = [] of Voyager::NativeReconcileCollector::Op

    Voyager::NativeReconcileCollector.collect(prior, current, mounted, ops, Voyager::NativeReconcileCollector::CommitMode::AllLabelCommit).should eq(2)
    ops.map(&.[1]).should eq(["Stable title", "frame-1"])
  end

  it "clears staged writes and preserves the prior tree on a deep mismatch" do
    session = Voyager::NativeReconcileCollector::Session.new
    prior = reconcile_tree("Stable title", "frame-0")
    session.replace!(prior)
    # The first child is valid and would stage an op; the second is deliberately
    # the wrong native kind. The public collector must return no staged writes.
    mounted = reconcile_stack_native([
      reconcile_label_native(0x2000_u64, 0x2100_u64),
      UI::NativeView.new(reconcile_handle(0x3000_u64, "UIHostingController[Button]", 0x3100_u64)),
    ])
    ops = [] of Voyager::NativeReconcileCollector::Op

    session.collect(reconcile_tree("Changed title", "frame-1"), mounted, ops, Voyager::NativeReconcileCollector::CommitMode::DirtyLabelCommit).should be_nil
    ops.should be_empty
    session.previous.should eq(prior)
  end
end
