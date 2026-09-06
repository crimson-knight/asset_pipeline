module AndroidJavaFailureFixture
  class FaultView < UI::View
    def initialize(@env : Void*, @context : Void*, @kind : Int32)
      super()
    end

    def accept(visitor : UI::PlatformVisitor)
      case @kind
      when 1
        UI::Android::LibAndroidBridge.android_view_new(@env, "dev/assetpipeline/DefinitelyMissingView", @context)
      when 2
        view = UI::Android::LibAndroidBridge.android_view_new(@env, "android/view/View", @context)
        UI::Android::LibAndroidBridge.android_textview_set_text(@env, view, "invalid receiver type", 21)
      when 3
        UI::Android::LibAndroidBridge.android_view_new(@env, "dev/assetpipeline/androidhost/ThrowingConstructorView", @context)
      when 4
        view = UI::Android::LibAndroidBridge.android_view_new(@env, "dev/assetpipeline/androidhost/ThrowingTextView", @context)
        UI::Android::LibAndroidBridge.android_textview_set_text(@env, view, "private-java-input", 18)
      when 5
        UI::JNI::LibJNICollectionBridge.jni_object_array_create(@env, "dev/assetpipeline/MissingElement", Pointer(Void*).null, 0)
      when 6
        list = UI::JNI::LibJNICollectionBridge.jni_arraylist_create(@env, Pointer(Void*).null, 0)
        UI::JNI::LibJNICollectionBridge.jni_arraylist_get(@env, list, -1)
      when 7
        UI::Android::LibAndroidBridge.android_textview_set_text(@env, Pointer(Void).null, "invalid receiver", 16)
      when 8
        # Intentionally use the raw calls to prove that a subsequent optional
        # fallback cannot clear an exception that was already pending on entry.
        UI::Android::RawAndroidBridge.android_view_new(@env, "dev/assetpipeline/OriginalMissingView", @context)
        UI::Android::RawAndroidBridge.android_context_resolve_material_color(@env, @context, "colorSurface", 0)
        UI::Android::RawAndroidBridge.android_view_apply_glass(@env, Pointer(Void).null, 1.0_f32, 0)
        UI::Android::JavaBoundary.check!(@env)
      else
        raise ArgumentError.new("Unknown Java failure kind")
      end
      raise "The deliberate Java failure did not occur"
    end
  end
end

fun crystal_android_java_failure_render_probe(env : Void*, context : Void*, kind : Int32) : Int32
  fault = AndroidJavaFailureFixture::FaultView.new(env, context, kind)
  UI::Android::Renderer.new(env, context).render(AndroidFailureFixture.partial_tree(fault))
  0
    rescue error : UI::Android::PendingJavaException
      1
    rescue
      -1
end
