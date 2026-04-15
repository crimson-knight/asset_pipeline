{% if flag?(:macos) %}

# Raw FFI bindings for the macOS Accessibility API (AXUIElement) and
# CoreFoundation helpers needed to read accessibility tree attributes.
#
# These bindings wrap the C API from HIServices.framework (part of
# ApplicationServices) and CoreFoundation.framework.
#
# Link flags: -framework ApplicationServices -framework CoreFoundation

@[Link(framework: "ApplicationServices")]
@[Link(framework: "CoreFoundation")]
lib LibAX
  # --- AXUIElement Types ---
  type AXUIElementRef = Void*
  alias AXError = Int32

  # AXError constants
  AXErrorSuccess                = 0
  AXErrorFailure                = -25200
  AXErrorIllegalArgument        = -25201
  AXErrorInvalidUIElement       = -25202
  AXErrorInvalidUIElementObserver = -25203
  AXErrorCannotComplete         = -25204
  AXErrorAttributeUnsupported   = -25205
  AXErrorActionUnsupported      = -25206
  AXErrorNotificationUnsupported = -25207
  AXErrorNotImplemented         = -25208
  AXErrorNotificationAlreadyRegistered = -25209
  AXErrorNotificationNotRegistered = -25210
  AXErrorAPIDisabled            = -25211
  AXErrorNoValue                = -25212
  AXErrorParameterizedAttributeUnsupported = -25213
  AXErrorNotEnoughPrecision     = -25214

  # --- AXUIElement Creation ---
  fun AXUIElementCreateApplication(pid : Int32) : AXUIElementRef
  fun AXUIElementCreateSystemWide : AXUIElementRef
  fun AXUIElementGetPid(element : AXUIElementRef, pid : Int32*) : AXError

  # --- Attribute Reading ---
  fun AXUIElementCopyAttributeNames(element : AXUIElementRef, names : Void**) : AXError
  fun AXUIElementCopyAttributeValue(element : AXUIElementRef, attribute : Void*, value : Void**) : AXError
  fun AXUIElementGetAttributeValueCount(element : AXUIElementRef, attribute : Void*, count : LibC::Long*) : AXError
  fun AXUIElementCopyAttributeValues(element : AXUIElementRef, attribute : Void*, index : LibC::Long, max_values : LibC::Long, values : Void**) : AXError
  fun AXUIElementIsAttributeSettable(element : AXUIElementRef, attribute : Void*, settable : UInt8*) : AXError

  # --- Attribute Writing ---
  fun AXUIElementSetAttributeValue(element : AXUIElementRef, attribute : Void*, value : Void*) : AXError

  # --- Actions ---
  fun AXUIElementCopyActionNames(element : AXUIElementRef, names : Void**) : AXError
  fun AXUIElementPerformAction(element : AXUIElementRef, action : Void*) : AXError

  # --- Element Discovery ---
  fun AXUIElementCopyElementAtPosition(app : AXUIElementRef, x : Float32, y : Float32, element : Void**) : AXError

  # --- Configuration ---
  fun AXUIElementSetMessagingTimeout(element : AXUIElementRef, timeout : Float32) : AXError

  # --- Global Accessibility Check ---
  fun AXIsProcessTrusted : UInt8
end

# CoreFoundation bindings for string/array manipulation needed by AXUIElement
@[Link(framework: "CoreFoundation")]
lib LibCF
  alias CFIndex = LibC::Long

  # CFString encoding constants
  CFStringEncodingUTF8 = 0x08000100_u32

  # --- CFString ---
  fun CFStringCreateWithCString(alloc : Void*, cstr : UInt8*, encoding : UInt32) : Void*
  fun CFStringGetLength(str : Void*) : CFIndex
  fun CFStringGetCString(str : Void*, buffer : UInt8*, buffer_size : CFIndex, encoding : UInt32) : UInt8
  fun CFStringGetCStringPtr(str : Void*, encoding : UInt32) : UInt8*

  # --- CFArray ---
  fun CFArrayGetCount(array : Void*) : CFIndex
  fun CFArrayGetValueAtIndex(array : Void*, index : CFIndex) : Void*

  # --- CFBoolean ---
  fun CFBooleanGetValue(boolean : Void*) : UInt8

  # --- CFNumber ---
  fun CFNumberGetValue(number : Void*, type : Int32, value_ptr : Void*) : UInt8

  # --- CFType ---
  fun CFGetTypeID(cf : Void*) : LibC::ULong
  fun CFStringGetTypeID : LibC::ULong
  fun CFArrayGetTypeID : LibC::ULong
  fun CFBooleanGetTypeID : LibC::ULong
  fun CFNumberGetTypeID : LibC::ULong

  # --- Memory ---
  fun CFRelease(cf : Void*) : Void
  fun CFRetain(cf : Void*) : Void*
end

{% end %}
