// swiftkit_bridge.m — C trampolines that forward calls from Crystal's
// `LibSwiftKitBridge` into the Swift companion library's `@objc` facade
// classes.
//
// Each trampoline locates the `APSK*Facade` / `APSK*Overrides` class via
// the ObjC runtime (`objc_getClass`) and dispatches to the
// `@objc public static func make...` method through `objc_msgSend`.
// Selector lookup and argument boxing live here so the Crystal-side
// callers see a flat C ABI; the Swift side never has to know about
// `objc_msgSend` casting.
//
// Compile (macOS / iOS) with `-fno-objc-arc`; this file follows the same
// memory convention as `objc_bridge.m`: returned objects are autoreleased
// per Cocoa convention, the Crystal-side `NativeHandle` takes ownership
// with `objc_retain` (+1) on the receiving side.
//
// Phase 3 ships the Button facade end-to-end. Phase 3 remediation /
// follow-up commits add a trampoline per widget in the §6 coverage list.

#include <objc/runtime.h>
#include <objc/message.h>
#include <stdlib.h>
#include <string.h>
#include <Foundation/Foundation.h>

// Forward-declare to keep the file self-contained; the actual Swift
// implementations land in AssetPipelineSwiftKit via @objc.
extern Class objc_getClass(const char *name);
extern SEL sel_registerName(const char *name);

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

static inline NSString *apsk_nsstring(const char *utf8) {
    if (utf8 == NULL) return nil;
    return [NSString stringWithUTF8String:utf8];
}

// Box a UInt64 token into an NSNumber so `@objc` method signatures that
// accept `actionToken: UInt64` can route through `objc_msgSend` cleanly.
// Swift's `@objc` UInt64 lowers to `unsigned long long`; ObjC handles it
// natively, no NSNumber needed — kept here as a future hook.

// -----------------------------------------------------------------------------
// Overrides allocators
// -----------------------------------------------------------------------------

void *apsk_view_overrides_new(void) {
    Class cls = objc_getClass("APSKViewOverrides");
    if (cls == nil) return NULL;
    return ((id (*)(Class, SEL))objc_msgSend)(cls, sel_registerName("new"));
}

void *apsk_button_overrides_new(void) {
    Class cls = objc_getClass("APSKButtonOverrides");
    if (cls == nil) return NULL;
    return ((id (*)(Class, SEL))objc_msgSend)(cls, sel_registerName("new"));
}

// -----------------------------------------------------------------------------
// Runtime initialization
// -----------------------------------------------------------------------------

// Install the Crystal-side action trampoline pointer onto APSKRuntime.
// `trampoline` is the address of Crystal's `fun ap_swiftkit_invoke_action`.
void apsk_runtime_initialize(void *trampoline) {
    Class cls = objc_getClass("APSKRuntime");
    if (cls == nil) return;
    SEL sel = sel_registerName("initializeWithActionTrampoline:");
    ((void (*)(Class, SEL, void *))objc_msgSend)(cls, sel, trampoline);
}

// Install (or replace) the brand tint colour applied to every SwiftUI
// facade root. Crystal calls this on every `render(...)` entry with the
// active `design_tokens.colors_light.brand_primary` RGBA so a brand
// override on the renderer's `design_tokens` cascades through to every
// hosted SwiftUI Button (and any other tint-aware widget in later
// dispatches). Channel values are normalised 0...1 sRGB.
//
// Selector is `setBrandTintWithRed:green:blue:alpha:` — that is the ObjC
// name Swift synthesises for `@objc static func setBrandTint(red:green:
// blue:alpha:)`.
void apsk_runtime_set_brand_tint(double r, double g, double b, double a) {
    Class cls = objc_getClass("APSKRuntime");
    if (cls == nil) return;
    SEL sel = sel_registerName("setBrandTintWithRed:green:blue:alpha:");
    ((void (*)(Class, SEL, double, double, double, double))objc_msgSend)(
        cls, sel, r, g, b, a);
}

// Clear the brand tint. Hosted roots fall back to SwiftUI's automatic
// accent colour. Currently used by spec helpers and by sample builds
// that want raw SwiftUI defaults.
void apsk_runtime_clear_brand_tint(void) {
    Class cls = objc_getClass("APSKRuntime");
    if (cls == nil) return;
    SEL sel = sel_registerName("clearBrandTint");
    ((void (*)(Class, SEL))objc_msgSend)(cls, sel);
}

// -----------------------------------------------------------------------------
// Overrides field setters
// -----------------------------------------------------------------------------
//
// Each setter takes the `APSK*Overrides` instance pointer, the setter
// selector NAME (e.g. "setBackgroundColor:"), and the value. The
// selector-name path keeps the C surface flat: Crystal's
// `Populator::Sender` already enumerates setter Symbols, so passing the
// Symbol as a UTF-8 C string + dispatching via `sel_registerName` matches
// the Crystal-side abstraction exactly without exposing `objc_msgSend`
// casting to renderer call sites.
//
// `NULL` selector / `NULL` target are silently no-ops so the renderer
// can pass overrides constructed from a renderer that does not yet have
// a `LibSwiftKitBridge` link (the Web/Android renderers).

// Boxes a normalised sRGB quad into a platform-specific colour object.
// On iOS this is `+[UIColor colorWithRed:green:blue:alpha:]`; on macOS
// this is `+[NSColor colorWithRed:green:blue:alpha:]`. The same selector
// works on both classes; only the receiving class differs.
static id apsk_make_platform_color(double r, double g, double b, double a) {
#if TARGET_OS_IPHONE
    Class color_cls = objc_getClass("UIColor");
#else
    Class color_cls = objc_getClass("NSColor");
#endif
    if (color_cls == nil) return nil;
    SEL sel = sel_registerName("colorWithRed:green:blue:alpha:");
    return ((id (*)(Class, SEL, double, double, double, double))objc_msgSend)(
        color_cls, sel, r, g, b, a);
}

void apsk_overrides_set_color(void *target, const char *setter_name,
                              double r, double g, double b, double a) {
    if (target == NULL || setter_name == NULL) return;
    id color = apsk_make_platform_color(r, g, b, a);
    if (color == nil) return;
    SEL sel = sel_registerName(setter_name);
    ((void (*)(id, SEL, id))objc_msgSend)((id)target, sel, color);
}

void apsk_overrides_set_number(void *target, const char *setter_name,
                               double value) {
    if (target == NULL || setter_name == NULL) return;
    NSNumber *boxed = [NSNumber numberWithDouble:value];
    SEL sel = sel_registerName(setter_name);
    ((void (*)(id, SEL, id))objc_msgSend)((id)target, sel, boxed);
}

void apsk_overrides_set_bool(void *target, const char *setter_name,
                             int value) {
    if (target == NULL || setter_name == NULL) return;
    NSNumber *boxed = [NSNumber numberWithBool:(value != 0)];
    SEL sel = sel_registerName(setter_name);
    ((void (*)(id, SEL, id))objc_msgSend)((id)target, sel, boxed);
}

void apsk_overrides_set_string(void *target, const char *setter_name,
                               const char *value) {
    if (target == NULL || setter_name == NULL) return;
    NSString *ns_value = apsk_nsstring(value);
    if (ns_value == nil) return;
    SEL sel = sel_registerName(setter_name);
    ((void (*)(id, SEL, id))objc_msgSend)((id)target, sel, ns_value);
}

// -----------------------------------------------------------------------------
// Facade entry points
// -----------------------------------------------------------------------------

// makeButton(label:overrides:actionToken:) → UIView*/NSView*
void *apsk_make_button(const char *label,
                       void *overrides,
                       unsigned long long action_token) {
    Class cls = objc_getClass("APSKButtonFacade");
    if (cls == nil) return NULL;
    NSString *ns_label = apsk_nsstring(label);
    SEL sel = sel_registerName("makeButtonWithLabel:overrides:actionToken:");
    return ((id (*)(Class, SEL, id, id, unsigned long long))objc_msgSend)(
        cls, sel, ns_label, (id)overrides, action_token);
}
