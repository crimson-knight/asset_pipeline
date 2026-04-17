require "./ui/view"
require "./ui/views/*"
require "./ui/platform_visitor"
require "./ui/theme"
require "./ui/notifications"
require "./ui/renderers/web_renderer"

# Reactive state and component bridge
require "./ui/state"
require "./ui/view_adapter"

# Native platform infrastructure (memory management, FFI handles, callbacks)
require "./ui/native/release_strategy"
require "./ui/native/lib_objc_runtime"
require "./ui/native/handle_tracker"
require "./ui/native/native_handle"
require "./ui/native/objc_handle"
require "./ui/native/jni_handle"
require "./ui/native/callback_registry"
require "./ui/native/native_view"

# Collection bridge wrappers (platform-gated: ObjC on Darwin, JNI on Android)
require "./ui/native/objc_collections"
require "./ui/native/jni_collections"

# Platform-specific renderers (compile-time gated)
require "./ui/renderers/appkit_renderer"
require "./ui/renderers/uikit_renderer"
require "./ui/renderers/android_renderer"
