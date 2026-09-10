require "../../../src/ui"
require "../../../src/ui/android/navigation_state"
require "spec"

describe UI::Android::NavigationState do
  it "leaves Back to Android at root and pops each committed screen" do
    root = UI::Label.new("root")
    first = UI::Label.new("first")
    nav = UI::NavigationStack.new(root)
    state = UI::Android::NavigationState.new
    state.within(nav) { state.current_stack.should be(nav) }
    state.current_stack.should be_nil
    state.can_go_back?.should be_false
    state.go_back.should be_false
    state.push_link(nav, root, first)
    state.push_link(nav, root, first) # stale double tap before a render
    nav.stack.size.should eq(1)
    state.can_go_back?.should be_true
    state.go_back.should be_true
    nav.current_view.should be(root)
    state.go_back.should be_false
  end

  it "pops the deepest visible scope and rejects links in outgoing branches" do
    root = UI::Label.new("root")
    inner_root = UI::Label.new("inner root")
    inner = UI::NavigationStack.new(inner_root)
    outer = UI::NavigationStack.new(root)
    outer.push(inner)
    inner.push(UI::Label.new("inner detail"))
    state = UI::Android::NavigationState.new
    state.within(outer) { state.within(inner) { } }
    state.go_back.should be_true
    inner.current_view.should be(inner_root)
    outer.current_view.should be(inner)
    state.go_back.should be_true
    outer.current_view.should be(root)
    # Before rerender, hidden nested state must not intercept Back or a tap.
    inner.push(UI::Label.new("hidden detail"))
    state.can_go_back?.should be_false
    state.push_link(inner, inner.current_view, UI::Label.new("not visible"))
    state.pop_stack(inner, inner.current_view)
    inner.stack.size.should eq(1)
  end

  it "reflects programmatic pop-to-root without a stale depth cache" do
    nav = UI::NavigationStack.new(UI::Label.new("root"))
    state = UI::Android::NavigationState.new
    state.within(nav) { }
    nav.push(UI::Label.new("one"))
    nav.push(UI::Label.new("two"))
    state.can_go_back?.should be_true
    nav.pop_to_root
    state.can_go_back?.should be_false
  end

  it "does not let a hidden navigation stack or its descendants consume Back" do
    inner = UI::NavigationStack.new(UI::Label.new("inner"))
    outer = UI::NavigationStack.new(inner)
    inner.push(UI::Label.new("detail"))
    outer.hidden = true
    state = UI::Android::NavigationState.new
    state.within(outer) { state.within(inner) { } }
    state.can_go_back?.should be_false
    state.push_link(inner, inner.current_view, UI::Label.new("unseen"))
    inner.stack.size.should eq(1)
  end

  it "rejects recursive scopes and always balances scope ownership" do
    nav = UI::NavigationStack.new(UI::Label.new("root"))
    state = UI::Android::NavigationState.new
    expect_raises(ArgumentError, "Cyclic") do
      state.within(nav) { state.within(nav) { } }
    end
    state.current_stack.should be_nil
  end

  it "does not capture unseen stacks and gives the last sibling precedence" do
    one = UI::NavigationStack.new(UI::Label.new("one"))
    two = UI::NavigationStack.new(UI::Label.new("two"))
    state = UI::Android::NavigationState.new
    state.push_link(one, one.root, UI::Label.new("unseen"))
    one.stack.should be_empty
    state.within(one) { }
    state.within(two) { }
    one.push(UI::Label.new("one detail"))
    two.push(UI::Label.new("two detail"))
    state.go_back.should be_true
    one.stack.size.should eq(1)
    two.stack.should be_empty
  end
end
