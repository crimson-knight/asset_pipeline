module AndroidFailureFixture
  class ExpectedCallbackFailure < Exception
  end

  class ExpectedRenderFailure < Exception
  end

  class BrokenView < UI::View
    def accept(visitor : UI::PlatformVisitor)
      raise ExpectedRenderFailure.new("intentional partial-render contract")
    end
  end

  def self.partial_tree(failure : UI::View = BrokenView.new) : UI::View
    root = UI::VStack.new
    root << UI::Label.new("Constructed before failure")
    button = UI::Button.new("Retained callback") { nil }
    button.maximum_width = 180.5
    button.accessibility_actions << UI::AccessibilityAction.new("Temporary button action") { nil }
    row = UI::HStack.new
    row.fill_equally = true
    row << button
    root << row
    inner = UI::VStack.new
    field = UI::TextField.new("Temporary input") { |_value| nil }
    field.maximum_width = 160.5
    field.accessibility_actions << UI::AccessibilityAction.new("Temporary editor action") { nil }
    inner << field
    inner << failure
    root << UI::NavigationStack.new(inner, "Partial navigation")
    root
  end

  def self.callback(kind : Int32) : UInt64
    case kind
    when 1 then UI::CallbackRegistry.register(-> { raise ExpectedCallbackFailure.new("private-android-callback-void"); nil })
    when 2 then UI::CallbackRegistry.register_string(->(value : String) { raise ExpectedCallbackFailure.new(value); nil })
    when 3 then UI::CallbackRegistry.register_bool(->(value : Bool) { raise ExpectedCallbackFailure.new("private-android-callback-bool"); nil })
    when 4 then UI::CallbackRegistry.register_float(->(value : Float64) { raise ExpectedCallbackFailure.new("private-android-callback-float"); nil })
    when 5 then UI::CallbackRegistry.register_int(->(value : Int32) { raise ExpectedCallbackFailure.new("private-android-callback-int"); nil })
    else        raise ArgumentError.new("Unknown failure fixture kind")
    end
  end
end

fun crystal_android_failure_fixture_register(kind : Int32) : UInt64
  AndroidFailureFixture.callback(kind)
  rescue
    0_u64
end

fun crystal_android_failure_fixture_unregister(id : UInt64) : Nil
  UI::CallbackRegistry.unregister(id)
end

fun crystal_android_failure_fixture_render_probe(env : Void*, context : Void*) : Int32
  UI::Android::Renderer.new(env, context).render(AndroidFailureFixture.partial_tree)
  0
  rescue error : AndroidFailureFixture::ExpectedRenderFailure
    1
  rescue
    -1
end
