// objc_bridge.m — Type-safe ObjC message send wrappers for ARM64
//
// On ARM64 (AAPCS64), objc_msgSend's variadic C signature cannot be called
// directly when floating-point arguments must land in d-registers.  Each
// wrapper casts objc_msgSend to the exact function-pointer type so the
// compiler places arguments in the correct registers.
//
// CGRect is a Homogeneous Floating-point Aggregate (HFA) with 4 doubles,
// passed in d0-d3 on ARM64.
//
// Memory management: This bridge does NOT use ARC.  Crystal's NativeHandle
// with ReleaseStrategy manages all object lifetimes.  Raw void* pointers
// are simply cast to/from id for the message send and back.
//
// Compile:
//   clang -c src/ui/native/objc_bridge.m -o objc_bridge.o -fno-objc-arc

#include <objc/runtime.h>
#include <objc/message.h>
#import <AppKit/AppKit.h>

// ============================================================
// Section 1: Basic message sends (integer / pointer arguments)
// ============================================================

// (id, SEL) -> id
void *objc_send(void *obj, void *sel) {
    return ((id (*)(id, SEL))objc_msgSend)((id)obj, sel);
}

// (id, SEL, id) -> id
void *objc_send_id(void *obj, void *sel, void *arg) {
    return ((id (*)(id, SEL, id))objc_msgSend)((id)obj, sel, (id)arg);
}

// (id, SEL, id, id) -> id
void *objc_send_id_id(void *obj, void *sel, void *arg1, void *arg2) {
    return ((id (*)(id, SEL, id, id))objc_msgSend)(
        (id)obj, sel, (id)arg1, (id)arg2);
}

// (id, SEL, id, id, id) -> id
void *objc_send_id_id_id(void *obj, void *sel, void *arg1, void *arg2, void *arg3) {
    return ((id (*)(id, SEL, id, id, id))objc_msgSend)(
        (id)obj, sel, (id)arg1, (id)arg2, (id)arg3);
}

// (id, SEL, BOOL) -> void
void objc_send_bool(void *obj, void *sel, int val) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)((id)obj, sel, (BOOL)val);
}

// (id, SEL, NSInteger) -> id
void *objc_send_long(void *obj, void *sel, long long val) {
    return ((id (*)(id, SEL, NSInteger))objc_msgSend)((id)obj, sel, (NSInteger)val);
}

// (id, SEL, NSUInteger) -> id
void *objc_send_ulong(void *obj, void *sel, unsigned long long val) {
    return ((id (*)(id, SEL, NSUInteger))objc_msgSend)((id)obj, sel, (NSUInteger)val);
}

// (id, SEL, id) -> void
void objc_send_void_id(void *obj, void *sel, void *arg) {
    ((void (*)(id, SEL, id))objc_msgSend)((id)obj, sel, (id)arg);
}

// (id, SEL, SEL) -> void
void objc_send_sel(void *obj, void *sel, void *arg) {
    ((void (*)(id, SEL, SEL))objc_msgSend)((id)obj, sel, (SEL)arg);
}

// (id, SEL, id, NSInteger) -> id
void *objc_send_id_long(void *obj, void *sel, void *arg1, long long arg2) {
    return ((id (*)(id, SEL, id, NSInteger))objc_msgSend)(
        (id)obj, sel, (id)arg1, (NSInteger)arg2);
}

// ============================================================
// Section 2: Double / float register sends
// ============================================================

// (id, SEL, CGFloat) -> void
void objc_send_1d(void *obj, void *sel, double d0) {
    ((void (*)(id, SEL, CGFloat))objc_msgSend)((id)obj, sel, (CGFloat)d0);
}

// (id, SEL, CGFloat) -> id
void *objc_send_1d_ret_id(void *obj, void *sel, double d0) {
    return ((id (*)(id, SEL, CGFloat))objc_msgSend)((id)obj, sel, (CGFloat)d0);
}

// (id, SEL, CGFloat, CGFloat) -> id
void *objc_send_2d_ret_id(void *obj, void *sel, double d0, double d1) {
    return ((id (*)(id, SEL, CGFloat, CGFloat))objc_msgSend)(
        (id)obj, sel, (CGFloat)d0, (CGFloat)d1);
}

// (id, SEL, CGFloat, CGFloat, CGFloat, CGFloat) -> id
void *objc_send_4d_ret_id(void *obj, void *sel, double d0, double d1, double d2, double d3) {
    return ((id (*)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat))objc_msgSend)(
        (id)obj, sel, (CGFloat)d0, (CGFloat)d1, (CGFloat)d2, (CGFloat)d3);
}

// ============================================================
// Section 3: CGRect / HFA sends
// ============================================================

typedef struct { double x, y, width, height; } BridgeCGRect;

// (id, SEL, NSRect) -> id
void *objc_send_rect(void *obj, void *sel, BridgeCGRect rect) {
    NSRect r = NSMakeRect(rect.x, rect.y, rect.width, rect.height);
    return ((id (*)(id, SEL, NSRect))objc_msgSend)((id)obj, sel, r);
}

// (id, SEL, NSRect) -> void
void objc_send_rect_void(void *obj, void *sel, BridgeCGRect rect) {
    NSRect r = NSMakeRect(rect.x, rect.y, rect.width, rect.height);
    ((void (*)(id, SEL, NSRect))objc_msgSend)((id)obj, sel, r);
}

// (id, SEL) -> BOOL
int objc_send_ret_bool(void *obj, void *sel) {
    return (int)((BOOL (*)(id, SEL))objc_msgSend)((id)obj, sel);
}

// ============================================================
// Section 4: Convenience helpers
// ============================================================

// Create an NSString from a C string (caller must manage retain/release)
void *nsstring_from_cstr(const char *str) {
    if (!str) return NULL;
    return [NSString stringWithUTF8String:str];
}

// [NSColor colorWithRed:green:blue:alpha:]
void *nscolor_rgba(double r, double g, double b, double a) {
    return [NSColor colorWithRed:(CGFloat)r
                           green:(CGFloat)g
                            blue:(CGFloat)b
                           alpha:(CGFloat)a];
}

// [NSColor colorWithWhite:alpha:]
void *nscolor_white_alpha(double white, double alpha) {
    return [NSColor colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha];
}

// [NSFont systemFontOfSize:]
void *nsfont_system(double size) {
    return [NSFont systemFontOfSize:(CGFloat)size];
}

// [NSFont boldSystemFontOfSize:]
void *nsfont_bold_system(double size) {
    return [NSFont boldSystemFontOfSize:(CGFloat)size];
}

// [NSFont systemFontOfSize:weight:]
void *nsfont_system_weight(double size, double weight) {
    return [NSFont systemFontOfSize:(CGFloat)size weight:(NSFontWeight)weight];
}

// [NSFont monospacedSystemFontOfSize:weight:]
void *nsfont_monospaced_system(double size, double weight) {
    return [NSFont monospacedSystemFontOfSize:(CGFloat)size weight:(NSFontWeight)weight];
}

// [NSFont fontWithName:size:]
void *nsfont_named(void *name, double size) {
    return [NSFont fontWithName:(NSString *)name size:(CGFloat)size];
}

// [parent addSubview:child]
void objc_add_subview(void *parent, void *child) {
    [(NSView *)parent addSubview:(NSView *)child];
}

// view.autoresizingMask = mask
void objc_set_autoresize(void *view, unsigned long long mask) {
    ((NSView *)view).autoresizingMask = (NSAutoresizingMaskOptions)mask;
}

// [obj setFrame:rect]
void objc_set_frame(void *obj, BridgeCGRect frame) {
    NSRect r = NSMakeRect(frame.x, frame.y, frame.width, frame.height);
    [(NSView *)obj setFrame:r];
}
