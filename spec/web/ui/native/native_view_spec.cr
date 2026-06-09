require "spec"
require "../../../../src/ui"

# Helper to create a mock NativeHandle with Unowned strategy for testing.
# Uses a fake pointer address to avoid null-pointer edge cases.
private def make_handle(address : UInt64 = 0x1000_u64, label : String? = nil) : UI::NativeHandle
  ptr = Pointer(Void).new(address)
  UI::NativeHandle.new(ptr, UI::ReleaseStrategy::Unowned, label: label)
end

# Helper to create a NativeView with a mock handle.
private def make_view(address : UInt64 = 0x1000_u64, label : String? = nil) : UI::NativeView
  UI::NativeView.new(make_handle(address, label))
end

# Phase 12.D — helper to create a NativeView that looks like a mounted
# reactive presentation (Sheet / ConfirmationDialog): a non-nil
# reactive_kind, presentation_identity, and a non-null state_handle —
# exactly the shape `build_reuse_registry` keys on. The state_handle is
# a fake (non-null) pointer; the web lane never dereferences it (the
# SwiftKit dispatch is compile-gated to -Dmacos/-Dios).
private def make_reactive_view(
  identity : String?,
  kind : Symbol = :sheet,
  address : UInt64 = 0x1000_u64,
  state_address : UInt64 = 0xBEEF_u64,
) : UI::NativeView
  handle = make_handle(address, "reactive")
  handle.reactive_kind = kind
  handle.presentation_identity = identity
  handle.state_handle = Pointer(Void).new(state_address)
  UI::NativeView.new(handle)
end

describe UI::NativeView do
  # Clean up callback registry between tests.
  after_each do
    UI::CallbackRegistry.clear
  end

  describe "#initialize" do
    it "creates a view in Created state" do
      view = make_view
      view.state.should eq(UI::NativeView::State::Created)
    end

    it "has an empty children array" do
      view = make_view
      view.children.should be_empty
    end

    it "wraps the given handle" do
      handle = make_handle(0xABCD_u64, "test-view")
      view = UI::NativeView.new(handle)
      view.handle.should eq(handle)
      view.handle.label.should eq("test-view")
    end

    it "accepts pre-built children" do
      child1 = make_view(0x2000_u64)
      child2 = make_view(0x3000_u64)
      parent = UI::NativeView.new(make_handle, [child1, child2])
      parent.children.size.should eq(2)
    end
  end

  describe "#add_child" do
    it "appends a child to the children array" do
      parent = make_view
      child = make_view(0x2000_u64)
      parent.add_child(child)
      parent.children.size.should eq(1)
      parent.children.first.should eq(child)
    end

    it "preserves insertion order" do
      parent = make_view
      child1 = make_view(0x2000_u64, "first")
      child2 = make_view(0x3000_u64, "second")
      child3 = make_view(0x4000_u64, "third")
      parent.add_child(child1)
      parent.add_child(child2)
      parent.add_child(child3)
      parent.children.map(&.handle.label).should eq(["first", "second", "third"])
    end

    it "raises if the view is torn down" do
      parent = make_view
      parent.teardown!
      expect_raises(Exception, /torn down/) do
        parent.add_child(make_view(0x2000_u64))
      end
    end
  end

  describe "#remove_child" do
    it "removes a specific child" do
      parent = make_view
      child1 = make_view(0x2000_u64)
      child2 = make_view(0x3000_u64)
      parent.add_child(child1)
      parent.add_child(child2)
      result = parent.remove_child(child1)
      result.should be_true
      parent.children.size.should eq(1)
      parent.children.first.should eq(child2)
    end

    it "returns false if the child is not found" do
      parent = make_view
      orphan = make_view(0x9999_u64)
      result = parent.remove_child(orphan)
      result.should be_false
    end

    it "does not teardown the removed child" do
      parent = make_view
      child = make_view(0x2000_u64)
      parent.add_child(child)
      parent.remove_child(child)
      child.torn_down?.should be_false
      child.handle.valid?.should be_true
    end

    it "raises if the view is torn down" do
      parent = make_view
      child = make_view(0x2000_u64)
      parent.add_child(child)
      parent.teardown!
      expect_raises(Exception, /torn down/) do
        parent.remove_child(child)
      end
    end
  end

  describe "#remove_all_children" do
    it "clears all children" do
      parent = make_view
      parent.add_child(make_view(0x2000_u64))
      parent.add_child(make_view(0x3000_u64))
      parent.add_child(make_view(0x4000_u64))
      parent.remove_all_children
      parent.children.should be_empty
    end

    it "is safe when there are no children" do
      parent = make_view
      parent.remove_all_children
      parent.children.should be_empty
    end
  end

  describe "#attach!" do
    it "transitions from Created to Attached" do
      view = make_view
      view.state.should eq(UI::NativeView::State::Created)
      view.attach!
      view.state.should eq(UI::NativeView::State::Attached)
    end

    it "raises if already torn down" do
      view = make_view
      view.teardown!
      expect_raises(Exception, /torn down/) do
        view.attach!
      end
    end
  end

  describe "#detach!" do
    it "transitions to Detached state" do
      view = make_view
      view.attach!
      view.detach!
      view.state.should eq(UI::NativeView::State::Detached)
    end

    it "raises if already torn down" do
      view = make_view
      view.teardown!
      expect_raises(Exception, /torn down/) do
        view.detach!
      end
    end
  end

  describe "#register_callback" do
    it "registers a callback and returns an ID" do
      view = make_view
      called = false
      id = view.register_callback { called = true }
      id.should be > 0_u64
      UI::CallbackRegistry.call(id)
      called.should be_true
    end

    it "registers a Proc callback" do
      view = make_view
      called = false
      callback = Proc(Nil).new { called = true }
      id = view.register_callback(callback)
      UI::CallbackRegistry.call(id)
      called.should be_true
    end

    it "tracks multiple callbacks" do
      view = make_view
      results = [] of String
      view.register_callback { results << "a" }
      view.register_callback { results << "b" }
      UI::CallbackRegistry.size.should eq(2)
    end

    it "raises if the view is torn down" do
      view = make_view
      view.teardown!
      expect_raises(Exception, /torn down/) do
        view.register_callback { }
      end
    end
  end

  describe "#teardown!" do
    it "transitions to TornDown state" do
      view = make_view
      view.teardown!
      view.state.should eq(UI::NativeView::State::TornDown)
      view.torn_down?.should be_true
    end

    it "releases the handle" do
      view = make_view
      view.handle.valid?.should be_true
      view.teardown!
      view.handle.released?.should be_true
      view.handle.valid?.should be_false
    end

    it "is idempotent: double teardown is safe" do
      view = make_view
      view.teardown!
      view.teardown!  # should not raise
      view.torn_down?.should be_true
    end

    it "cascades to children (post-order)" do
      child1 = make_view(0x2000_u64, "child1")
      child2 = make_view(0x3000_u64, "child2")
      parent = make_view(0x1000_u64, "parent")
      parent.add_child(child1)
      parent.add_child(child2)

      parent.teardown!

      child1.torn_down?.should be_true
      child1.handle.released?.should be_true
      child2.torn_down?.should be_true
      child2.handle.released?.should be_true
      parent.torn_down?.should be_true
      parent.handle.released?.should be_true
    end

    it "cascades through deeply nested children" do
      grandchild = make_view(0x3000_u64, "grandchild")
      child = make_view(0x2000_u64, "child")
      child.add_child(grandchild)
      parent = make_view(0x1000_u64, "parent")
      parent.add_child(child)

      parent.teardown!

      grandchild.torn_down?.should be_true
      child.torn_down?.should be_true
      parent.torn_down?.should be_true
    end

    it "clears children array after teardown" do
      parent = make_view
      parent.add_child(make_view(0x2000_u64))
      parent.add_child(make_view(0x3000_u64))
      parent.teardown!
      parent.children.should be_empty
    end

    it "unregisters callbacks from CallbackRegistry" do
      view = make_view
      view.register_callback { }
      view.register_callback { }
      UI::CallbackRegistry.size.should eq(2)
      view.teardown!
      UI::CallbackRegistry.size.should eq(0)
    end

    it "prevents registered callbacks from firing after teardown" do
      view = make_view
      called = false
      id = view.register_callback { called = true }
      view.teardown!
      UI::CallbackRegistry.call(id)
      called.should be_false
    end

    it "handles a view with no children and no callbacks" do
      view = make_view
      view.teardown!
      view.torn_down?.should be_true
      view.handle.released?.should be_true
    end

    it "works from Attached state" do
      view = make_view
      view.attach!
      view.teardown!
      view.torn_down?.should be_true
    end

    it "works from Detached state" do
      view = make_view
      view.attach!
      view.detach!
      view.teardown!
      view.torn_down?.should be_true
    end
  end

  describe "lifecycle state transitions" do
    it "follows Created -> Attached -> TornDown" do
      view = make_view
      view.state.should eq(UI::NativeView::State::Created)
      view.attach!
      view.state.should eq(UI::NativeView::State::Attached)
      view.teardown!
      view.state.should eq(UI::NativeView::State::TornDown)
    end

    it "follows Created -> Attached -> Detached -> TornDown" do
      view = make_view
      view.state.should eq(UI::NativeView::State::Created)
      view.attach!
      view.state.should eq(UI::NativeView::State::Attached)
      view.detach!
      view.state.should eq(UI::NativeView::State::Detached)
      view.teardown!
      view.state.should eq(UI::NativeView::State::TornDown)
    end

    it "allows direct Created -> TornDown" do
      view = make_view
      view.teardown!
      view.state.should eq(UI::NativeView::State::TornDown)
    end
  end

  describe "complex tree teardown" do
    it "tears down a tree with mixed callbacks and children" do
      root = make_view(0x1000_u64, "root")
      child_a = make_view(0x2000_u64, "child_a")
      child_b = make_view(0x3000_u64, "child_b")
      grandchild = make_view(0x4000_u64, "grandchild")

      results = [] of String
      root.register_callback { results << "root_cb" }
      child_a.register_callback { results << "child_a_cb" }
      grandchild.register_callback { results << "grandchild_cb" }

      child_a.add_child(grandchild)
      root.add_child(child_a)
      root.add_child(child_b)

      UI::CallbackRegistry.size.should eq(3)

      root.teardown!

      # All views should be torn down
      root.torn_down?.should be_true
      child_a.torn_down?.should be_true
      child_b.torn_down?.should be_true
      grandchild.torn_down?.should be_true

      # All handles should be released
      root.handle.released?.should be_true
      child_a.handle.released?.should be_true
      child_b.handle.released?.should be_true
      grandchild.handle.released?.should be_true

      # All callbacks should be unregistered
      UI::CallbackRegistry.size.should eq(0)

      # Callbacks should not fire after teardown
      results.should be_empty
    end
  end

  # Phase 12.D (continuing-presentation reuse) — the platform-agnostic
  # half of the reuse path: building the identity-keyed registry from a
  # prior render's root, and the detach/reused bookkeeping that keeps a
  # carried-over NativeView from being double-released. The SwiftKit
  # state-handle adoption + marker emission live in the renderers
  # (compile-gated to -Dmacos/-Dios) and are exercised in the native
  # lanes; here we pin the identity matching + registry construction.
  describe ".build_reuse_registry" do
    it "returns an empty registry when prior is nil (first render)" do
      registry = UI::NativeView.build_reuse_registry(nil)
      registry.should be_empty
    end

    it "keys a reactive presentation by its presentation_identity" do
      sheet = make_reactive_view("voyager-editor-sheet", :sheet)
      root = make_view(0x1_u64, "root")
      root.add_child(sheet)

      registry = UI::NativeView.build_reuse_registry(root)
      registry.size.should eq(1)
      registry["voyager-editor-sheet"].should be(sheet)
    end

    it "collects presentations nested deep in the tree" do
      dialog = make_reactive_view("share-dialog", :confirmation_dialog, 0x2_u64)
      mid = make_view(0x3_u64, "mid")
      mid.add_child(dialog)
      root = make_view(0x1_u64, "root")
      root.add_child(mid)

      registry = UI::NativeView.build_reuse_registry(root)
      registry.keys.should eq(["share-dialog"])
    end

    it "collects multiple distinct identities" do
      sheet = make_reactive_view("editor-sheet", :sheet, 0x2_u64)
      dialog = make_reactive_view("share-dialog", :confirmation_dialog, 0x3_u64)
      root = make_view(0x1_u64, "root")
      root.add_child(sheet)
      root.add_child(dialog)

      registry = UI::NativeView.build_reuse_registry(root)
      registry.size.should eq(2)
      registry["editor-sheet"].should be(sheet)
      registry["share-dialog"].should be(dialog)
    end

    it "skips reactive views with a nil presentation_identity" do
      # Defensive: a sheet authored without test_id / accessibility_label
      # cannot participate in identity-keyed reuse.
      anon = make_reactive_view(nil, :sheet)
      root = make_view(0x1_u64, "root")
      root.add_child(anon)

      UI::NativeView.build_reuse_registry(root).should be_empty
    end

    it "skips non-reactive views (no reactive_kind)" do
      plain = make_view(0x2_u64, "plain-label")
      root = make_view(0x1_u64, "root")
      root.add_child(plain)

      UI::NativeView.build_reuse_registry(root).should be_empty
    end

    it "prunes torn-down subtrees (released handles never enter the registry)" do
      sheet = make_reactive_view("dead-sheet", :sheet)
      root = make_view(0x1_u64, "root")
      root.add_child(sheet)
      sheet.teardown!

      UI::NativeView.build_reuse_registry(root).should be_empty
    end

    it "last-render-wins on duplicate identities" do
      first = make_reactive_view("dupe", :sheet, 0x2_u64)
      second = make_reactive_view("dupe", :sheet, 0x3_u64)
      root = make_view(0x1_u64, "root")
      root.add_child(first)
      root.add_child(second)

      registry = UI::NativeView.build_reuse_registry(root)
      registry.size.should eq(1)
      # walk_reactive_views pops the stack so the LATER child wins.
      registry["dupe"].should be(second)
    end
  end

  describe "#reused? + #detach_reused!" do
    it "defaults reused? to false" do
      make_view.reused?.should be_false
    end

    it "removes a reused child from its parent without recursing into it" do
      reused_child = make_reactive_view("carried-sheet", :sheet, 0x2_u64)
      kept_child = make_view(0x3_u64, "kept")
      root = make_view(0x1_u64, "root")
      root.add_child(reused_child)
      root.add_child(kept_child)
      reused_child.reused = true

      root.detach_reused!

      # The reused subtree is now owned by the NEW tree — it must be gone
      # from the prior parent so the prior tree's teardown/GC cannot
      # double-release the shared handle.
      root.children.includes?(reused_child).should be_false
      root.children.includes?(kept_child).should be_true
      # The carried view itself is untouched (NOT torn down).
      reused_child.torn_down?.should be_false
      reused_child.handle.released?.should be_false
    end

    it "clears the reused flag on extraction so the next render starts clean" do
      reused_child = make_reactive_view("carried-sheet", :sheet, 0x2_u64)
      root = make_view(0x1_u64, "root")
      root.add_child(reused_child)
      reused_child.reused = true

      root.detach_reused!

      reused_child.reused?.should be_false
    end

    it "recurses into non-reused branches to find deeper reused nodes" do
      deep_reused = make_reactive_view("deep-sheet", :sheet, 0x4_u64)
      branch = make_view(0x3_u64, "branch")
      branch.add_child(deep_reused)
      root = make_view(0x1_u64, "root")
      root.add_child(branch)
      deep_reused.reused = true

      root.detach_reused!

      branch.children.includes?(deep_reused).should be_false
      root.children.includes?(branch).should be_true
    end
  end

  describe "#walk_reactive_views" do
    it "yields only views with a non-nil reactive_kind" do
      sheet = make_reactive_view("a-sheet", :sheet, 0x2_u64)
      plain = make_view(0x3_u64, "plain")
      root = make_view(0x1_u64, "root")
      root.add_child(sheet)
      root.add_child(plain)

      yielded = [] of UI::NativeView
      root.walk_reactive_views { |v| yielded << v }

      yielded.should eq([sheet])
    end

    it "prunes torn-down subtrees" do
      sheet = make_reactive_view("a-sheet", :sheet, 0x2_u64)
      root = make_view(0x1_u64, "root")
      root.add_child(sheet)
      sheet.teardown!

      yielded = [] of UI::NativeView
      root.walk_reactive_views { |v| yielded << v }

      yielded.should be_empty
    end
  end
end
