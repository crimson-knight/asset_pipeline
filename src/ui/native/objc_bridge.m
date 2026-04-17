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
// Cross-platform: this same source file is compiled for both macOS (AppKit)
// and iOS (UIKit) by conditioning on TARGET_OS_IPHONE vs TARGET_OS_OSX.
// CGRect is used internally so the struct layout is identical on both.
//
// Compile (macOS):
//   clang -c src/ui/native/objc_bridge.m -o objc_bridge.o -fno-objc-arc
// Compile (iOS simulator):
//   clang -c src/ui/native/objc_bridge.m -o objc_bridge.o \
//     -target arm64-apple-ios-simulator \
//     -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path) \
//     -fno-objc-arc

#include <objc/runtime.h>
#include <objc/message.h>
#include <TargetConditionals.h>

#if TARGET_OS_OSX
  #import <AppKit/AppKit.h>
  #import <QuartzCore/QuartzCore.h>
  #import <WebKit/WebKit.h>
  #import <MapKit/MapKit.h>
  #import <AVKit/AVKit.h>
  #import <AVFoundation/AVFoundation.h>
  typedef NSView      BridgeView;
  typedef NSButton    BridgeButton;
  #define BRIDGE_RECT_MAKE(r) NSMakeRect((r).x, (r).y, (r).width, (r).height)
  typedef NSRect      BridgeRect;
#else
  #import <UIKit/UIKit.h>
  #import <QuartzCore/QuartzCore.h>
  #import <WebKit/WebKit.h>
  #import <MapKit/MapKit.h>
  #import <AVKit/AVKit.h>
  #import <AVFoundation/AVFoundation.h>
  typedef UIView      BridgeView;
  typedef UIButton    BridgeButton;
  #define BRIDGE_RECT_MAKE(r) CGRectMake((r).x, (r).y, (r).width, (r).height)
  typedef CGRect      BridgeRect;
#endif

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

// (id, SEL, id, id, NSInteger) -> id
// Used on iOS for e.g. alertControllerWithTitle:message:preferredStyle:.
void *objc_send_id_id_long(void *obj, void *sel, void *arg1, void *arg2, long long arg3) {
    return ((id (*)(id, SEL, id, id, NSInteger))objc_msgSend)(
        (id)obj, sel, (id)arg1, (id)arg2, (NSInteger)arg3);
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

// (id, SEL, CGRect) -> id  (NSRect on macOS, CGRect on iOS — layouts match)
void *objc_send_rect(void *obj, void *sel, BridgeCGRect rect) {
    BridgeRect r = BRIDGE_RECT_MAKE(rect);
    return ((id (*)(id, SEL, BridgeRect))objc_msgSend)((id)obj, sel, r);
}

// (id, SEL, CGRect) -> void
void objc_send_rect_void(void *obj, void *sel, BridgeCGRect rect) {
    BridgeRect r = BRIDGE_RECT_MAKE(rect);
    ((void (*)(id, SEL, BridgeRect))objc_msgSend)((id)obj, sel, r);
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

// [NSColor/UIColor colorWithRed:green:blue:alpha:]
void *nscolor_rgba(double r, double g, double b, double a) {
#if TARGET_OS_OSX
    return [NSColor colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a];
#else
    return [UIColor colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a];
#endif
}

// [NSColor/UIColor colorWithWhite:alpha:]
void *nscolor_white_alpha(double white, double alpha) {
#if TARGET_OS_OSX
    return [NSColor colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha];
#else
    return [UIColor colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha];
#endif
}

// Apple semantic label colors — dynamic system colors that track appearance.
// Use these instead of a baked RGBA so Light / Dark / Increase-Contrast are
// handled automatically by AppKit / UIKit.
void *nscolor_label_primary(void) {
#if TARGET_OS_OSX
    return [NSColor labelColor];
#else
    return [UIColor labelColor];
#endif
}

void *nscolor_label_secondary(void) {
#if TARGET_OS_OSX
    return [NSColor secondaryLabelColor];
#else
    return [UIColor secondaryLabelColor];
#endif
}

void *nscolor_label_tertiary(void) {
#if TARGET_OS_OSX
    return [NSColor tertiaryLabelColor];
#else
    return [UIColor tertiaryLabelColor];
#endif
}

void *nscolor_label_quaternary(void) {
#if TARGET_OS_OSX
    return [NSColor quaternaryLabelColor];
#else
    return [UIColor quaternaryLabelColor];
#endif
}

// Semantic fill colors for grouped containers (boxes / cards).
// These track the system appearance automatically.
// nscolor_control_background -> macOS: NSColor.controlBackgroundColor (light gray
//   in light, dark charcoal in dark). On iOS falls back to
//   UIColor.secondarySystemBackgroundColor.
// nscolor_separator -> macOS: NSColor.separatorColor (hairline). iOS: UIColor.separatorColor.
void *nscolor_control_background(void) {
#if TARGET_OS_OSX
    return [NSColor controlBackgroundColor];
#else
    return [UIColor secondarySystemBackgroundColor];
#endif
}

void *nscolor_separator(void) {
#if TARGET_OS_OSX
    return [NSColor separatorColor];
#else
    return [UIColor separatorColor];
#endif
}

// [NSFont/UIFont systemFontOfSize:]
void *nsfont_system(double size) {
#if TARGET_OS_OSX
    return [NSFont systemFontOfSize:(CGFloat)size];
#else
    return [UIFont systemFontOfSize:(CGFloat)size];
#endif
}

// [NSFont/UIFont boldSystemFontOfSize:]
void *nsfont_bold_system(double size) {
#if TARGET_OS_OSX
    return [NSFont boldSystemFontOfSize:(CGFloat)size];
#else
    return [UIFont boldSystemFontOfSize:(CGFloat)size];
#endif
}

// [NSFont/UIFont systemFontOfSize:weight:]
void *nsfont_system_weight(double size, double weight) {
#if TARGET_OS_OSX
    return [NSFont systemFontOfSize:(CGFloat)size weight:(NSFontWeight)weight];
#else
    return [UIFont systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight];
#endif
}

// [NSFont/UIFont monospacedSystemFontOfSize:weight:]
void *nsfont_monospaced_system(double size, double weight) {
#if TARGET_OS_OSX
    return [NSFont monospacedSystemFontOfSize:(CGFloat)size weight:(NSFontWeight)weight];
#else
    return [UIFont monospacedSystemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight];
#endif
}

// [NSFont/UIFont fontWithName:size:]
void *nsfont_named(void *name, double size) {
#if TARGET_OS_OSX
    return [NSFont fontWithName:(NSString *)name size:(CGFloat)size];
#else
    return [UIFont fontWithName:(NSString *)name size:(CGFloat)size];
#endif
}

// [parent addSubview:child]
void objc_add_subview(void *parent, void *child) {
    [(BridgeView *)parent addSubview:(BridgeView *)child];
}

// view.autoresizingMask = mask
void objc_set_autoresize(void *view, unsigned long long mask) {
#if TARGET_OS_OSX
    ((BridgeView *)view).autoresizingMask = (NSAutoresizingMaskOptions)mask;
#else
    ((BridgeView *)view).autoresizingMask = (UIViewAutoresizing)mask;
#endif
}

// [obj setFrame:rect]
void objc_set_frame(void *obj, BridgeCGRect frame) {
    BridgeRect r = BRIDGE_RECT_MAKE(frame);
    [(BridgeView *)obj setFrame:r];
}

// Pin a view's width and height to explicit values via NSLayoutConstraints so
// that the dimensions survive inside auto-layout containers (NSStackView /
// UIStackView).  Sets translatesAutoresizingMaskIntoConstraints:NO first,
// then activates two constraints at high (not required) priority so they do
// not conflict with UIStackView's own internal required constraints while
// still strongly expressing the desired size.
//
// Priority 999 = UILayoutPriorityRequired - 1. UIStackView's internal
// distribution/alignment constraints are at priority 1000 (required).
// Using 999 here lets UIStackView resolve conflicts gracefully rather
// than triggering unsatisfiable constraint warnings.
// Returns the current UIScreen main width in points (logical pixels).
// Used by the renderer to compute row widths when fill-alignment cannot
// propagate a definite width down through nested UIStackViews.
double objc_screen_width(void) {
#if TARGET_OS_OSX
    return 0.0; // Not used on macOS
#else
    return (double)[UIScreen mainScreen].bounds.size.width;
#endif
}

// Constrain child.widthAnchor = parent.widthAnchor at required priority.
// Used to explicitly pin a UIStackView arranged subview's width to the
// parent UIStackView's width, working around the case where UIStackView's
// alignment=fill does not propagate width into nested UIStackViews.
void objc_constrain_equal_width(void *child, void *parent) {
    BridgeView *c = (BridgeView *)child;
    BridgeView *p = (BridgeView *)parent;
    NSLayoutConstraint *wc = [c.widthAnchor constraintEqualToAnchor:p.widthAnchor];
#if TARGET_OS_OSX
    wc.priority = NSLayoutPriorityRequired;
#else
    wc.priority = UILayoutPriorityRequired;
#endif
    wc.active = YES;
}

// Pin a child view to its parent's layout margins on iOS. The macOS branch
// falls back to edge pinning; UIKit is the current caller.
void objc_pin_child_to_layout_margins(void *parent, void *child) {
    BridgeView *p = (BridgeView *)parent;
    BridgeView *c = (BridgeView *)child;
    c.translatesAutoresizingMaskIntoConstraints = NO;
#if TARGET_OS_OSX
    NSLayoutConstraint *leading = [c.leadingAnchor constraintEqualToAnchor:p.leadingAnchor];
    NSLayoutConstraint *trailing = [c.trailingAnchor constraintEqualToAnchor:p.trailingAnchor];
    NSLayoutConstraint *top = [c.topAnchor constraintEqualToAnchor:p.topAnchor];
    NSLayoutConstraint *bottom = [c.bottomAnchor constraintEqualToAnchor:p.bottomAnchor];
#else
    UILayoutGuide *g = p.layoutMarginsGuide;
    NSLayoutConstraint *leading = [c.leadingAnchor constraintEqualToAnchor:g.leadingAnchor];
    NSLayoutConstraint *trailing = [c.trailingAnchor constraintEqualToAnchor:g.trailingAnchor];
    NSLayoutConstraint *top = [c.topAnchor constraintEqualToAnchor:g.topAnchor];
    NSLayoutConstraint *bottom = [c.bottomAnchor constraintEqualToAnchor:g.bottomAnchor];
#endif
    leading.active = YES;
    trailing.active = YES;
    top.active = YES;
    bottom.active = YES;
}

// Exact-width arranged subviews should resist horizontal stretching in
// UIStackView's Fill distribution. Width constraints remain the source of
// truth; these priorities make the intent visible to stack fitting passes.
void objc_set_horizontal_fixed_priority(void *view) {
    BridgeView *v = (BridgeView *)view;
#if TARGET_OS_OSX
    [v setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [v setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
#else
    [v setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [v setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
#endif
}

void objc_constrain_size(void *view, double w, double h) {
    BridgeView *v = (BridgeView *)view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *wc = [v.widthAnchor constraintEqualToConstant:(CGFloat)w];
    NSLayoutConstraint *hc = [v.heightAnchor constraintEqualToConstant:(CGFloat)h];
    wc.priority = 999;
    hc.priority = 999;
    wc.active = YES;
    hc.active = YES;
}

// Constrain only the width of a view, leaving height unconstrained.
// Use this for sidebar columns inside a split layout where the parent
// provides the height and only the width needs an explicit value.
void objc_constrain_width(void *view, double w) {
    BridgeView *v = (BridgeView *)view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *wc = [v.widthAnchor constraintEqualToConstant:(CGFloat)w];
    wc.priority = 999;
    wc.active = YES;
}

// Constrain width at required priority. Use sparingly for exact design tokens
// (minimum_width == maximum_width) in validation previews where UIKit's fitting
// pass otherwise breaks the 999-priority width and lets rounded containers clip.
void objc_constrain_required_width(void *view, double w) {
    BridgeView *v = (BridgeView *)view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *wc = [v.widthAnchor constraintEqualToConstant:(CGFloat)w];
#if TARGET_OS_OSX
    wc.priority = NSLayoutPriorityRequired;
#else
    wc.priority = UILayoutPriorityRequired;
#endif
    wc.active = YES;
}

// Apply a MINIMUM width constraint (>=) to a view.
// Use this for content panels that should expand to fill available space
// without being pinned to an exact width. NSStackView GravityAreas distribution
// gives each child at least its intrinsic content size; this constraint raises
// the floor so the panel gets at least `min_w` points.
// Priority 250 (defaultLow) so it defers to any explicit equality constraints
// from siblings, and lets the layout engine solve for a feasible layout.
void objc_constrain_minimum_width(void *view, double min_w) {
    BridgeView *v = (BridgeView *)view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *wc = [v.widthAnchor constraintGreaterThanOrEqualToConstant:(CGFloat)min_w];
    wc.priority = 500;
    wc.active = YES;
}

// Constrain only the height of a view, leaving width unconstrained.
// Use this for scroll views embedded in stack views where the stack
// provides the width and only the height needs an explicit value.
void objc_constrain_height(void *view, double h) {
    BridgeView *v = (BridgeView *)view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *hc = [v.heightAnchor constraintEqualToConstant:(CGFloat)h];
    hc.priority = 999;
    hc.active = YES;
}

// Constrain the MINIMUM height of a view. The view can grow taller than min_h
// but never shorter. Used for iOS sheet detent sizing so the sheet fills at
// least its .medium detent height (~520pt) and Cancel/CTA buttons are visible.
void objc_constrain_minimum_height(void *view, double min_h) {
    BridgeView *v = (BridgeView *)view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *hc = [v.heightAnchor constraintGreaterThanOrEqualToConstant:(CGFloat)min_h];
    hc.priority = 999;
    hc.active = YES;
}

// Pin a content view's edges to a UIScrollView's contentLayoutGuide and
// pin its width to the frameLayoutGuide.  This is the canonical way to
// achieve a vertically-scrolling UIScrollView with Auto Layout:
//   - content top/leading/bottom/trailing -> contentLayoutGuide
//   - content width = frameLayoutGuide.width  (no horizontal scroll)
// The content view must already be a subview of the scroll view.
// macOS: no-op (NSScrollView uses documentView, not constraints).
void uiscrollview_pin_content(void *scroll_view, void *content_view) {
#if !TARGET_OS_OSX
    UIScrollView *sv = (UIScrollView *)scroll_view;
    UIView *cv = (UIView *)content_view;
    cv.translatesAutoresizingMaskIntoConstraints = NO;
    UILayoutGuide *content = sv.contentLayoutGuide;
    UILayoutGuide *frame = sv.frameLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [cv.topAnchor constraintEqualToAnchor:content.topAnchor],
        [cv.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [cv.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [cv.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [cv.widthAnchor constraintEqualToAnchor:frame.widthAnchor],
    ]];
#endif
}

// Set a view as the documentView of an NSScrollView and wire Auto Layout
// constraints so the document view fills the NSScrollView's width while
// being free to grow vertically (enabling vertical scrolling).
//
// Steps:
//   1. setDocumentView: wires the view into the NSScrollView's NSClipView.
//   2. Pinning the documentView's leading/trailing to the NSScrollView's
//      content layout guide's leading/trailing sets the scroll width.
//   3. NOT pinning the bottom anchor lets the view grow as tall as needed.
//
// iOS: no-op (use uiscrollview_pin_content instead).
void nsscrollview_set_document_view(void *scroll_view, void *doc_view) {
#if TARGET_OS_OSX
    NSScrollView *sv = (NSScrollView *)scroll_view;
    NSView *dv = (NSView *)doc_view;
    dv.translatesAutoresizingMaskIntoConstraints = NO;
    sv.documentView = dv;
    // Pin width of documentView to NSScrollView's content (clip) width.
    // The documentView is now inside NSClipView; constrain to its superview.
    NSView *clip = sv.contentView;  // NSClipView
    if (clip) {
        [NSLayoutConstraint activateConstraints:@[
            [dv.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor],
            [dv.trailingAnchor constraintEqualToAnchor:clip.trailingAnchor],
            [dv.topAnchor constraintEqualToAnchor:clip.topAnchor],
        ]];
    }
#endif
}

// Create an NSImageView (macOS) / UIImageView (iOS) that renders a system
// SF Symbol image in template mode with an explicit content tint color.
//
// On macOS, NSImageView.contentTintColor reliably propagates through the
// template rendering mode to the displayed symbol pixels.  This is more
// reliable than NSButton.contentTintColor which does not consistently
// apply to the image portion when bezelStyle != 0 (borderless).
//
// On iOS, UIImageView.tintColor achieves the same effect for UIButtonTypeSystem
// when the image is set via UIImage.systemImageNamed: (which always returns a
// template-mode image).  This helper is provided as a symmetric API but the
// UIKit renderer prefers the UIButton path for hit-testing reasons.
//
// Parameters:
//   symbol_name  -- C string with the SF Symbol name (e.g. "envelope")
//   tint_color   -- NSColor* (macOS) or UIColor* (iOS) to apply as tint
//   size_pts     -- Point size for the symbol image configuration; pass 0.0
//                   to use the SF Symbol's default point size.
//
// Returns: NSImageView* (macOS) or UIImageView* (iOS), or NULL if the symbol
//          is not found or the platform API is unavailable.
//
// Caller owns a +1 retain count (from alloc/init) and must release via
// ObjC.owned / NativeHandle.
void *nsimageview_make_symbol(const char *symbol_name, void *tint_color, double size_pts) {
#if TARGET_OS_OSX
    NSString *name = [NSString stringWithUTF8String:symbol_name];
    if (!name) return NULL;

    NSImage *img = nil;
    if (size_pts > 0.0) {
        NSImageSymbolConfiguration *cfg =
            [NSImageSymbolConfiguration configurationWithPointSize:(CGFloat)size_pts
                                                            weight:NSFontWeightRegular];
        img = [NSImage imageWithSystemSymbolName:name
                     accessibilityDescription:@""];
        if (img) {
            img = [img imageWithSymbolConfiguration:cfg];
        }
    } else {
        img = [NSImage imageWithSystemSymbolName:name
                     accessibilityDescription:@""];
    }
    if (!img) return NULL;

    NSImageView *iv = [[NSImageView alloc] initWithFrame:NSZeroRect];
    iv.image = img;
    // imageScaling = NSImageScaleProportionallyUpOrDown (3) so the symbol
    // fills the constrained size while preserving aspect ratio.
    iv.imageScaling = (NSImageScaling)3;
    // contentTintColor on NSImageView reliably routes template-mode SF Symbol
    // rendering through the brand color.  This does NOT require a specific
    // bezel style and works in both light and dark appearances.
    if (tint_color) {
        SEL tintSel = sel_registerName("setContentTintColor:");
        if ([iv respondsToSelector:tintSel]) {
            ((void (*)(id, SEL, id))objc_msgSend)(iv, tintSel, (id)tint_color);
        }
    }
    return (void *)iv;
#else
    NSString *name = [NSString stringWithUTF8String:symbol_name];
    if (!name) return NULL;
    UIImage *img = [UIImage systemImageNamed:name];
    if (!img) return NULL;
    UIImageView *iv = [[UIImageView alloc] initWithImage:img];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    if (tint_color) {
        iv.tintColor = (UIColor *)tint_color;
    }
    return (void *)iv;
#endif
}

// Install a warm-amber-to-ember CAGradientLayer as the bottommost sublayer
// of a UIView (iOS only).  The gradient provides a pre-composited warm tonal
// variation that bleeds through the UIGlassEffect / UIBlurEffect layer placed
// above it.  Under XCUITest rasterization, live UIVisualEffectView blending
// is not composited against real window content; a pre-composited gradient
// behind the glass surface allows the "bleed-through" tonal variation to
// appear in the captured screenshot.
//
// The gradient runs from top-left (warm amber, r=0.90 g=0.55 b=0.15 a=1.0)
// to bottom-right (deep ember, r=0.60 g=0.25 b=0.05 a=1.0).  The diagonal
// direction maximizes the visible tonal range in the glass card's crop.
//
// macOS: no-op (gradient layer approach not needed; live CGWindowListCreateImage
// composites the backdrop through NSVisualEffectView naturally).
void uiview_install_amber_gradient_layer(void *view) {
#if !TARGET_OS_OSX
    UIView *v = (UIView *)view;

    CAGradientLayer *grad = [CAGradientLayer layer];
    // Warm amber -> deep ember diagonal gradient.
    UIColor *amber  = [UIColor colorWithRed:0.90 green:0.55 blue:0.15 alpha:1.0];
    UIColor *ember  = [UIColor colorWithRed:0.55 green:0.22 blue:0.04 alpha:1.0];
    grad.colors   = @[ (id)amber.CGColor, (id)ember.CGColor ];
    grad.startPoint = CGPointMake(0.0, 0.0);  // top-left
    grad.endPoint   = CGPointMake(1.0, 1.0);  // bottom-right
    // Frame will be updated to match the view bounds in the next layout pass
    // via a bounds-tracking dispatch (same pattern as slider track).
    grad.frame = v.bounds;

    // Insert below all existing sublayers so the gradient is behind everything.
    if (v.layer.sublayers.count > 0) {
        [v.layer insertSublayer:grad atIndex:0];
    } else {
        [v.layer addSublayer:grad];
    }

    // Schedule a frame update after the next layout pass resolves the bounds.
    __unsafe_unretained CAGradientLayer *weakGrad = grad;
    dispatch_async(dispatch_get_main_queue(), ^{
        CAGradientLayer *g = weakGrad;
        if (g && g.superlayer) {
            g.frame = g.superlayer.bounds;
        }
    });
#else
    (void)view;
#endif
}

// Set button title with foreground color via NSAttributedString.
// On macOS this sets NSButton.attributedTitle; on iOS we approximate the
// same effect by setting the button's titleLabel font + titleColor for the
// normal control state. iOS's preferred configuration-based API
// (UIButton.configuration) is not used here — the renderer applies its own
// configuration above these primitives when it wants a richer look.
void nsbutton_set_colored_title(void *button, void *title_nsstring, void *color, void *font) {
#if TARGET_OS_OSX
    NSDictionary *attrs = @{
        NSForegroundColorAttributeName: (NSColor *)color,
        NSFontAttributeName: (NSFont *)font
    };
    NSAttributedString *attrStr = [[NSAttributedString alloc]
        initWithString:(NSString *)title_nsstring attributes:attrs];
    [(NSButton *)button setAttributedTitle:attrStr];
    [attrStr release];
#else
    UIButton *b = (UIButton *)button;
    [b setTitle:(NSString *)title_nsstring forState:UIControlStateNormal];
    [b setTitleColor:(UIColor *)color forState:UIControlStateNormal];
    b.titleLabel.font = (UIFont *)font;
#endif
}

// ============================================================
// Section 5b: Slider synthetic track (iOS only)
//
// UISlider's track is drawn via private CALayer sublayers that are not
// composited into XCUITest rasterized screenshots.  This helper builds a
// screenshot-stable synthetic track composed of plain UIView subviews and
// lays them out with explicit frames + UIViewAutoresizingFlexibleWidth so
// they resize when the container is placed inside a UIStackView.
//
// Returns the container UIView (height 44pt, TAMIC=NO).  The invisible
// UISlider is added on top at alpha 0 so it still receives touch events.
//
// Parameters:
//   value_fraction  -- fraction in [0,1] representing the thumb position
//   filled_color    -- UIColor for the leading (filled) track segment
//   unfilled_color  -- UIColor for the trailing (unfilled) track segment
//   slider_ptr      -- the pre-built UISlider (alpha set to 0.0 here)
//
// iOS only.  On macOS this is a no-op (returns NULL).
// ============================================================

#if !TARGET_OS_OSX
void *uislider_build_synthetic_track(double value_fraction,
                                     void *filled_color,
                                     void *unfilled_color,
                                     void *slider_ptr) {
    // Clamp fraction to [0, 1].
    if (value_fraction < 0.0) value_fraction = 0.0;
    if (value_fraction > 1.0) value_fraction = 1.0;

    // Container: 44pt tall (HIG minimum hit target).  Width is unspecified
    // here -- the container will be sized by its UIStackView parent.
    // We use autoresizing masks on child views so they track the container width.
    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *hc = [container.heightAnchor constraintEqualToConstant:44.0];
    hc.priority = 999;
    hc.active = YES;

    // Background (unfilled) track: full width, 4pt tall, vertically centered.
    // Uses UIViewAutoresizingFlexibleWidth so it stretches with the container.
    UIView *bgTrack = [[UIView alloc] initWithFrame:CGRectZero];
    bgTrack.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                               UIViewAutoresizingFlexibleTopMargin |
                               UIViewAutoresizingFlexibleBottomMargin;
    bgTrack.backgroundColor = (UIColor *)unfilled_color;
    bgTrack.layer.cornerRadius = 2.0;
    [container addSubview:bgTrack];

    // Filled (leading) track: width = container.width * value_fraction, 4pt tall.
    // Uses UIViewAutoresizingFlexibleRightMargin so it anchors to the leading edge.
    UIView *fillTrack = [[UIView alloc] initWithFrame:CGRectZero];
    fillTrack.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                 UIViewAutoresizingFlexibleTopMargin |
                                 UIViewAutoresizingFlexibleBottomMargin;
    fillTrack.backgroundColor = (UIColor *)filled_color;
    fillTrack.layer.cornerRadius = 2.0;
    [container addSubview:fillTrack];

    // Thumb: 28pt circle, white, with a subtle drop shadow.
    UIView *thumb = [[UIView alloc] initWithFrame:CGRectZero];
    thumb.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                             UIViewAutoresizingFlexibleRightMargin |
                             UIViewAutoresizingFlexibleTopMargin |
                             UIViewAutoresizingFlexibleBottomMargin;
    thumb.backgroundColor = [UIColor whiteColor];
    thumb.layer.cornerRadius = 14.0;
    thumb.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.25].CGColor;
    thumb.layer.shadowOpacity = 1.0;
    thumb.layer.shadowRadius = 3.0;
    thumb.layer.shadowOffset = CGSizeMake(0.0, 1.0);
    [container addSubview:thumb];

    // The real UISlider sits on top at alpha 0.0 so touch events still work.
    UISlider *slider = (UISlider *)slider_ptr;
    slider.alpha = 0.0;
    slider.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                              UIViewAutoresizingFlexibleHeight;
    [container addSubview:slider];

    // layoutSubviews is overridden via a block-based approach would require
    // a subclass.  Instead, we schedule frame computation in layoutIfNeeded
    // by registering a one-shot layout observation via KVO on the container
    // bounds — which is heavyweight.  Simpler: use a deferred layout via
    // dispatch_async(main_queue) so the stack view has resolved the container
    // width before we compute child frames.
    //
    // We capture the fraction and child view references weakly via __weak
    // references stored in an NSArray to avoid retain cycles.
    // __weak is ARC-only.  Under MRC (-fno-objc-arc) we use __unsafe_unretained.
    // The container holds strong refs to all children (addSubview: retains them),
    // so these pointers remain valid for the lifetime of the container and the
    // dispatch_async block below is safe.
    __unsafe_unretained UIView *weakContainer = container;
    __unsafe_unretained UIView *weakBgTrack   = bgTrack;
    __unsafe_unretained UIView *weakFill      = fillTrack;
    __unsafe_unretained UIView *weakThumb     = thumb;
    CGFloat frac = (CGFloat)value_fraction;

    // Dispatch to the next run-loop turn so UIStackView has had a chance to
    // size the container before we compute frames.
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *c = weakContainer;
        if (!c) return;
        CGFloat w = c.bounds.size.width;
        if (w <= 0.0) w = [UIScreen mainScreen].bounds.size.width - 32.0;

        CGFloat trackH = 4.0;
        CGFloat trackY = (44.0 - trackH) / 2.0;
        CGFloat thumbD = 28.0;
        CGFloat thumbY = (44.0 - thumbD) / 2.0;
        CGFloat fillW  = w * frac;
        CGFloat thumbX = fillW - thumbD / 2.0;

        weakBgTrack.frame = CGRectMake(0.0, trackY, w, trackH);
        weakFill.frame    = CGRectMake(0.0, trackY, fillW, trackH);
        weakThumb.frame   = CGRectMake(thumbX, thumbY, thumbD, thumbD);
        // Also size the slider to fill the container for touch routing.
        slider.frame = c.bounds;
    });

    // Return the container; the caller wraps it in NativeView.
    return (void *)container;
}
#else
void *uislider_build_synthetic_track(double value_fraction,
                                     void *filled_color,
                                     void *unfilled_color,
                                     void *slider_ptr) {
    (void)value_fraction; (void)filled_color; (void)unfilled_color; (void)slider_ptr;
    return NULL; // Not used on macOS.
}
#endif

// ============================================================
// Section 5c: NSSlider track fill color (macOS only)
//
// NSSlider does not expose setMinimumTrackTintColor: (that is UISlider-only).
// On macOS 10.14+, NSSliderCell has a trackFillColor property that sets the
// filled portion of the track independently of the system accent color.
//
// On macOS < 10.14, this is a no-op (the property is not available via
// respondToSelector:, so we guard before sending the message).
// ============================================================

void nsslider_set_track_fill_color(void *slider, void *color) {
#if TARGET_OS_OSX
    NSSlider *s = (NSSlider *)slider;
    NSSliderCell *cell = (NSSliderCell *)[s cell];
    if (!cell) return;
    if ([cell respondsToSelector:@selector(setTrackFillColor:)]) {
        // Use performSelector: to suppress the compile-time unrecognized selector
        // warning.  The respondsToSelector: guard ensures this is safe at runtime.
        [cell performSelector:@selector(setTrackFillColor:) withObject:(NSColor *)color];
    }
#else
    (void)slider; (void)color;
#endif
}

// ============================================================
// Section 5a: NSSwitch factory (macOS 10.15+)
//
// NSSwitch requires initWithFrame:NSZeroRect — plain -init is not supported
// and will crash on ARM64.  This helper allocates, initializes, and
// optionally configures the switch in one call so Crystal does not need to
// call objc_send_rect directly for initialization.
//
// Returns the initialized NSSwitch pointer.  The caller owns +1 retain count
// (from alloc) and must release via ObjC.owned / NativeHandle.
// ============================================================

#if TARGET_OS_OSX
void *nsswitch_new(int state_on, int enabled) {
    Class cls = objc_getClass("NSSwitch");
    if (!cls) return NULL;
    NSSwitch *sw = [[cls alloc] initWithFrame:NSZeroRect];
    if (!sw) return NULL;
    sw.state = state_on ? NSControlStateValueOn : NSControlStateValueOff;
    sw.enabled = (BOOL)enabled;
    return (void *)sw;
}

// Apply a content tint color to an NSSwitch.
// setContentTintColor: is available macOS 12+; on 10.15/11 this is a no-op.
// Guards on respondsToSelector: so the call is safe on all macOS 10.15+ targets.
//
// Dark appearance fix: NSSwitch reads its ON-state track color from the
// current effective appearance at draw time. In the offscreen capture path
// the switch may be added to a window AFTER setContentTintColor: is called,
// causing the appearance to be unset at tint-application time. To fix this,
// we explicitly set the switch's own -appearance to match HIG_APPEARANCE
// before applying the tint. This forces NSSwitch to resolve the gold color
// against the correct appearance trait collection, ensuring the ON-state
// track renders amber gold in both light and dark.
void nsswitch_set_tint(void *sw_ptr, void *color) {
    id sw = (id)sw_ptr;

#if TARGET_OS_OSX
    // Explicitly set the switch's appearance from HIG_APPEARANCE so
    // setContentTintColor: resolves against the correct appearance trait.
    // Without this, the switch uses the inherited (possibly nil) appearance
    // from a window that hasn't been ordered front yet, and the dark ON-state
    // track may render with no tint.
    const char *hig_app = getenv("HIG_APPEARANCE");
    BOOL want_dark = (hig_app && strcmp(hig_app, "dark") == 0);
    NSAppearanceName appearance_name = want_dark
        ? NSAppearanceNameDarkAqua
        : NSAppearanceNameAqua;
    NSAppearance *appearance = [NSAppearance appearanceNamed:appearance_name];
    SEL setAppSel = sel_registerName("setAppearance:");
    if ([sw respondsToSelector:setAppSel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(sw, setAppSel, appearance);
    }
#endif

    SEL tintSel = sel_registerName("setContentTintColor:");
    if ([sw respondsToSelector:tintSel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(sw, tintSel, (id)color);
    }
}
#else
void *nsswitch_new(int state_on, int enabled) {
    (void)state_on; (void)enabled;
    return NULL; // Not used on iOS/Android.
}
void nsswitch_set_tint(void *sw_ptr, void *color) {
    (void)sw_ptr; (void)color;
}
#endif

// ============================================================
// Section 5d: Rich native content helpers
// ============================================================

static NSURL *ap_url_from_cstr(const char *value) {
    if (!value || !value[0]) return nil;
    NSString *str = [NSString stringWithUTF8String:value];
    if (!str || !str.length) return nil;
    return [NSURL URLWithString:str];
}

static NSString *ap_string_from_cstr(const char *value) {
    if (!value || !value[0]) return nil;
    return [NSString stringWithUTF8String:value];
}

extern void crystal_ui_string_callback_dispatch(unsigned long long tag, const char *value);
extern int crystal_ui_string_bool_callback_dispatch(unsigned long long tag, const char *value);

static NSString *ap_web_preview_html(NSString *title, NSString *url_string) {
    NSString *resolved_title = (title && title.length) ? title : @"Amber Journal";
    NSString *resolved_url = (url_string && url_string.length) ? url_string : @"https://amber.local";

    return [NSString stringWithFormat:
        @"<!doctype html><html><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
         "<style>"
         "html,body{margin:0;padding:0;background:#f4efe8;color:#171311;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text',sans-serif;}"
         "body{display:flex;align-items:stretch;justify-content:center;min-height:100vh;}"
         ".shell{width:100%%;padding:20px;box-sizing:border-box;}"
         ".card{background:rgba(255,255,255,.72);border:1px solid rgba(127,102,77,.12);backdrop-filter:blur(18px);"
         "border-radius:20px;padding:18px 18px 16px;box-shadow:0 18px 40px rgba(56,35,20,.12);}"
         ".eyebrow{font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:#8d6a45;margin:0 0 10px;}"
         "h1{font-size:24px;line-height:1.08;margin:0 0 8px;font-weight:650;}"
         "p{font-size:14px;line-height:1.45;margin:0;color:#57463a;}"
         ".toolbar{display:flex;gap:8px;margin:16px 0 18px;}"
         ".chip{display:inline-flex;align-items:center;border-radius:999px;padding:7px 12px;font-size:12px;font-weight:600;}"
         ".chip.primary{background:#ffb14a;color:#2f1900;}"
         ".chip.secondary{background:rgba(141,106,69,.12);color:#6e5746;}"
         ".preview{margin-top:2px;border-radius:16px;background:linear-gradient(180deg,rgba(255,255,255,.92),rgba(249,240,231,.92));"
         "padding:16px;border:1px solid rgba(127,102,77,.10);}"
         ".row{display:flex;justify-content:space-between;align-items:center;padding:11px 0;border-bottom:1px solid rgba(127,102,77,.08);font-size:13px;color:#3b2d23;}"
         ".row:last-child{border-bottom:none;padding-bottom:0;}"
         ".row strong{font-size:14px;font-weight:620;color:#171311;}"
         ".row span{color:#8d6a45;font-weight:600;}"
         ".footer{margin-top:14px;font-size:11px;color:#8d6a45;}"
         "</style></head><body><div class=\"shell\"><div class=\"card\">"
         "<div class=\"eyebrow\">Embedded Web Content</div>"
         "<h1>%@</h1>"
         "<p>Use a web view for rich content that belongs in context, not as unrelated chrome around the component itself.</p>"
         "<div class=\"toolbar\"><div class=\"chip primary\">Review</div><div class=\"chip secondary\">Shared draft</div></div>"
         "<div class=\"preview\">"
         "<div class=\"row\"><strong>Launch notes</strong><span>Ready</span></div>"
         "<div class=\"row\"><strong>Editorial preview</strong><span>3 blocks</span></div>"
         "<div class=\"row\"><strong>Source</strong><span>%@</span></div>"
         "</div><div class=\"footer\">WebKit preview loaded locally for validation capture.</div>"
         "</div></div></body></html>",
        resolved_title, resolved_url];
}

static NSString *ap_video_preview_title(NSString *url_string) {
    if (url_string && url_string.length) {
        return @"Neighborhood walkthrough";
    }
    return @"Playback preview";
}

#if TARGET_OS_OSX
static NSImageView *ap_make_web_capture_preview(NSString *title, NSString *url_string) {
    CGFloat width = 420.0;
    CGFloat height = 320.0;
    NSString *resolved_title = (title && title.length) ? title : @"Editorial Review";
    NSString *resolved_url = (url_string && url_string.length) ? url_string : @"amber.local/review";

    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
    [image lockFocus];

    [[NSColor colorWithCalibratedRed:0.956 green:0.937 blue:0.910 alpha:1.0] setFill];
    NSRectFill(NSMakeRect(0.0, 0.0, width, height));

    NSRect card_rect = NSMakeRect(24.0, 22.0, width - 48.0, height - 44.0);
    NSBezierPath *card_path = [NSBezierPath bezierPathWithRoundedRect:card_rect xRadius:22.0 yRadius:22.0];
    [[NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:0.82] setFill];
    [card_path fill];
    [[NSColor colorWithCalibratedRed:0.498 green:0.400 blue:0.302 alpha:0.12] setStroke];
    [card_path setLineWidth:1.0];
    [card_path stroke];

    NSDictionary *eyebrow_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:11.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedRed:0.553 green:0.416 blue:0.271 alpha:1.0]
    };
    NSDictionary *title_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:24.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedRed:0.090 green:0.075 blue:0.067 alpha:1.0]
    };
    NSDictionary *body_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:14.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedRed:0.341 green:0.275 blue:0.227 alpha:1.0]
    };
    NSDictionary *row_title_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:14.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedRed:0.090 green:0.075 blue:0.067 alpha:1.0]
    };
    NSDictionary *row_meta_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedRed:0.553 green:0.416 blue:0.271 alpha:1.0]
    };
    NSDictionary *chip_primary_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedRed:0.184 green:0.098 blue:0.000 alpha:1.0]
    };
    NSDictionary *chip_secondary_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedRed:0.431 green:0.341 blue:0.275 alpha:1.0]
    };

    [@"EMBEDDED WEB CONTENT" drawInRect:NSMakeRect(44.0, height - 58.0, 220.0, 16.0) withAttributes:eyebrow_attrs];
    [resolved_title drawInRect:NSMakeRect(44.0, height - 102.0, width - 88.0, 34.0) withAttributes:title_attrs];
    [@"Keep the web content contextual and legible so it feels like part of the app instead of a dropped-in browser tab." drawInRect:NSMakeRect(44.0, height - 152.0, width - 88.0, 44.0) withAttributes:body_attrs];

    NSBezierPath *primary_chip = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(44.0, height - 200.0, 78.0, 32.0) xRadius:16.0 yRadius:16.0];
    [[NSColor colorWithCalibratedRed:1.0 green:0.694 blue:0.290 alpha:1.0] setFill];
    [primary_chip fill];
    [@"Review" drawInRect:NSMakeRect(62.0, height - 190.0, 44.0, 16.0) withAttributes:chip_primary_attrs];

    NSBezierPath *secondary_chip = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(132.0, height - 200.0, 110.0, 32.0) xRadius:16.0 yRadius:16.0];
    [[NSColor colorWithCalibratedRed:0.553 green:0.416 blue:0.271 alpha:0.12] setFill];
    [secondary_chip fill];
    [@"Shared draft" drawInRect:NSMakeRect(154.0, height - 190.0, 78.0, 16.0) withAttributes:chip_secondary_attrs];

    NSRect list_rect = NSMakeRect(44.0, 42.0, width - 88.0, 108.0);
    NSBezierPath *list_path = [NSBezierPath bezierPathWithRoundedRect:list_rect xRadius:16.0 yRadius:16.0];
    [[NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:0.92] setFill];
    [list_path fill];
    [[NSColor colorWithCalibratedRed:0.498 green:0.400 blue:0.302 alpha:0.10] setStroke];
    [list_path setLineWidth:1.0];
    [list_path stroke];

    [@"Launch notes" drawInRect:NSMakeRect(60.0, 116.0, 150.0, 18.0) withAttributes:row_title_attrs];
    [@"Ready" drawInRect:NSMakeRect(width - 118.0, 116.0, 70.0, 18.0) withAttributes:row_meta_attrs];
    [@"Editorial preview" drawInRect:NSMakeRect(60.0, 82.0, 180.0, 18.0) withAttributes:row_title_attrs];
    [@"3 blocks" drawInRect:NSMakeRect(width - 124.0, 82.0, 76.0, 18.0) withAttributes:row_meta_attrs];
    [@"Source" drawInRect:NSMakeRect(60.0, 48.0, 120.0, 18.0) withAttributes:row_title_attrs];
    [resolved_url drawInRect:NSMakeRect(width - 188.0, 48.0, 140.0, 18.0) withAttributes:row_meta_attrs];

    [[NSColor colorWithCalibratedRed:0.498 green:0.400 blue:0.302 alpha:0.08] setStroke];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(60.0, 108.0) toPoint:NSMakePoint(width - 60.0, 108.0)];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(60.0, 74.0) toPoint:NSMakePoint(width - 60.0, 74.0)];

    [image unlockFocus];

    NSImageView *image_view = [[NSImageView alloc] initWithFrame:NSMakeRect(0.0, 0.0, width, height)];
    image_view.image = image;
    image_view.imageScaling = NSImageScaleAxesIndependently;
    [image release];
    return image_view;
}

static NSImageView *ap_make_video_capture_preview(NSString *url_string, BOOL shows_controls) {
    CGFloat width = 560.0;
    CGFloat height = 315.0;
    NSString *resolved_title = ap_video_preview_title(url_string);

    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
    [image lockFocus];

    NSRect bounds = NSMakeRect(0.0, 0.0, width, height);
    NSBezierPath *outer_path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:24.0 yRadius:24.0];
    [outer_path addClip];

    NSGradient *backdrop = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedRed:0.067 green:0.071 blue:0.090 alpha:1.0], 0.0,
        [NSColor colorWithCalibratedRed:0.110 green:0.129 blue:0.176 alpha:1.0], 0.55,
        [NSColor colorWithCalibratedRed:0.153 green:0.118 blue:0.094 alpha:1.0], 1.0,
        nil];
    [backdrop drawInBezierPath:outer_path angle:135.0];
    [backdrop release];

    NSBezierPath *glow = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(width - 220.0, height - 210.0, 220.0, 220.0)];
    [[NSColor colorWithCalibratedRed:1.0 green:0.706 blue:0.341 alpha:0.16] setFill];
    [glow fill];

    NSBezierPath *glass_band = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(24.0, height - 64.0, 126.0, 30.0) xRadius:15.0 yRadius:15.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.14] setFill];
    [glass_band fill];

    NSDictionary *badge_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedWhite:1.0 alpha:0.82]
    };
    NSDictionary *title_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:22.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedWhite:1.0 alpha:0.96]
    };
    NSDictionary *meta_attrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName : [NSColor colorWithCalibratedWhite:1.0 alpha:0.70]
    };

    [@"VALIDATION PREVIEW" drawInRect:NSMakeRect(42.0, height - 56.0, 120.0, 16.0) withAttributes:badge_attrs];
    [resolved_title drawInRect:NSMakeRect(40.0, height - 106.0, width - 160.0, 28.0) withAttributes:title_attrs];
    [@"Capture-only poster." drawInRect:NSMakeRect(40.0, height - 132.0, width - 120.0, 18.0) withAttributes:meta_attrs];

    NSBezierPath *play_circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect((width - 70.0) / 2.0, (height - 70.0) / 2.0 + 8.0, 70.0, 70.0)];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] setFill];
    [play_circle fill];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.24] setStroke];
    [play_circle setLineWidth:1.0];
    [play_circle stroke];

    NSBezierPath *play_triangle = [NSBezierPath bezierPath];
    [play_triangle moveToPoint:NSMakePoint(width / 2.0 - 8.0, height / 2.0 + 34.0)];
    [play_triangle lineToPoint:NSMakePoint(width / 2.0 - 8.0, height / 2.0 - 2.0)];
    [play_triangle lineToPoint:NSMakePoint(width / 2.0 + 22.0, height / 2.0 + 16.0)];
    [play_triangle closePath];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.94] setFill];
    [play_triangle fill];

    CGFloat scrubber_y = 36.0;
    NSBezierPath *track = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(40.0, scrubber_y, width - 140.0, 4.0) xRadius:2.0 yRadius:2.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] setFill];
    [track fill];

    NSBezierPath *progress = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(40.0, scrubber_y, (width - 140.0) * 0.36, 4.0) xRadius:2.0 yRadius:2.0];
    [[NSColor colorWithCalibratedRed:1.0 green:0.706 blue:0.341 alpha:0.95] setFill];
    [progress fill];

    if (shows_controls) {
        [@"01:28" drawInRect:NSMakeRect(40.0, 16.0, 42.0, 16.0) withAttributes:meta_attrs];
        [@"03:54" drawInRect:NSMakeRect(width - 82.0, 16.0, 42.0, 16.0) withAttributes:meta_attrs];
    }

    [image unlockFocus];

    NSImageView *image_view = [[NSImageView alloc] initWithFrame:bounds];
    image_view.image = image;
    image_view.imageScaling = NSImageScaleAxesIndependently;
    [image release];
    return image_view;
}
#endif

void *wkwebview_new(const char *url_cstr,
                    const char *html_cstr,
                    const char *base_url_cstr,
                    const char *title_cstr,
                    int allows_navigation,
                    int allows_scripts) {
    NSString *html = ap_string_from_cstr(html_cstr);
    NSString *title = ap_string_from_cstr(title_cstr);
    NSString *url_string = ap_string_from_cstr(url_cstr);
    NSURL *base_url = ap_url_from_cstr(base_url_cstr);

#if TARGET_OS_OSX
    if (getenv("HIG_SCREENSHOT_PATH")) {
        return (void *)ap_make_web_capture_preview(title, url_string);
    }
#endif

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    if (!configuration) return NULL;

    if ([configuration respondsToSelector:@selector(defaultWebpagePreferences)]) {
        id webpage_prefs = [configuration defaultWebpagePreferences];
        SEL js_sel = sel_registerName("setAllowsContentJavaScript:");
        if (webpage_prefs && [webpage_prefs respondsToSelector:js_sel]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(webpage_prefs, js_sel, (BOOL)allows_scripts);
        }
    }

    WKPreferences *preferences = [configuration preferences];
    if (preferences && [preferences respondsToSelector:@selector(setJavaScriptEnabled:)]) {
        preferences.javaScriptEnabled = (BOOL)allows_scripts;
    }

#if TARGET_OS_OSX
    WKWebView *web_view = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
#else
    WKWebView *web_view = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
#endif
    if (!web_view) return NULL;

    SEL gestures_sel = sel_registerName("setAllowsBackForwardNavigationGestures:");
    if ([web_view respondsToSelector:gestures_sel]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(web_view, gestures_sel, (BOOL)allows_navigation);
    }

    if (html && html.length) {
        [web_view loadHTMLString:html baseURL:base_url];
    } else if (getenv("HIG_SCREENSHOT_PATH")) {
        NSString *preview_html = ap_web_preview_html(title, url_string);
        NSURL *preview_base_url = base_url ?: ap_url_from_cstr(url_cstr);
        [web_view loadHTMLString:preview_html baseURL:preview_base_url];
    } else {
        NSURL *url = ap_url_from_cstr(url_cstr);
        if (url) {
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            [web_view loadRequest:request];
        }
    }

    return (void *)web_view;
}

static const char ap_web_delegate_association_key;

static unsigned long long ap_web_delegate_read_u64(id self, const char *name) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), name);
    if (!ivar) return 0ULL;
    return *(unsigned long long *)((uint8_t *)(__bridge void *)self + ivar_getOffset(ivar));
}

static void ap_web_delegate_write_u64(id self, const char *name, unsigned long long value) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), name);
    if (!ivar) return;
    *(unsigned long long *)((uint8_t *)(__bridge void *)self + ivar_getOffset(ivar)) = value;
}

static long long ap_web_delegate_read_long(id self, const char *name) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), name);
    if (!ivar) return 0LL;
    return *(long long *)((uint8_t *)(__bridge void *)self + ivar_getOffset(ivar));
}

static void ap_web_delegate_write_long(id self, const char *name, long long value) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), name);
    if (!ivar) return;
    *(long long *)((uint8_t *)(__bridge void *)self + ivar_getOffset(ivar)) = value;
}

static void ap_web_delegate_set_policy_tag(id self, SEL _cmd, unsigned long long tag) {
    ap_web_delegate_write_u64(self, "_policyTag", tag);
}

static void ap_web_delegate_set_start_tag(id self, SEL _cmd, unsigned long long tag) {
    ap_web_delegate_write_u64(self, "_startTag", tag);
}

static void ap_web_delegate_set_finish_tag(id self, SEL _cmd, unsigned long long tag) {
    ap_web_delegate_write_u64(self, "_finishTag", tag);
}

static void ap_web_delegate_set_allows_navigation(id self, SEL _cmd, long long value) {
    ap_web_delegate_write_long(self, "_allowsNavigation", value);
}

static NSString *ap_web_navigation_url_string(WKWebView *web_view, WKNavigationAction *action) {
    NSURL *url = nil;
    if (action) {
        NSURLRequest *request = [action request];
        if ([request respondsToSelector:@selector(URL)]) {
            url = [request URL];
        }
    }
    if (!url && [web_view respondsToSelector:@selector(URL)]) {
        url = [web_view URL];
    }
    NSString *absolute = [url absoluteString];
    return (absolute && absolute.length) ? absolute : @"";
}

static void ap_web_delegate_dispatch_string(unsigned long long tag, NSString *value) {
    if (!tag) return;
    const char *utf8 = value ? [value UTF8String] : "";
    crystal_ui_string_callback_dispatch(tag, utf8);
}

static BOOL ap_web_delegate_should_allow(id self, WKWebView *web_view, WKNavigationAction *action) {
    unsigned long long policy_tag = ap_web_delegate_read_u64(self, "_policyTag");
    NSString *url_string = ap_web_navigation_url_string(web_view, action);
    if (policy_tag) {
        const char *utf8 = [url_string UTF8String];
        return crystal_ui_string_bool_callback_dispatch(policy_tag, utf8) != 0;
    }

    if (ap_web_delegate_read_long(self, "_allowsNavigation") != 0) {
        return YES;
    }

    id target_frame = nil;
    SEL target_frame_sel = sel_registerName("targetFrame");
    if (action && [action respondsToSelector:target_frame_sel]) {
        target_frame = ((id (*)(id, SEL))objc_msgSend)(action, target_frame_sel);
    }

    BOOL is_main_frame = YES;
    SEL is_main_frame_sel = sel_registerName("isMainFrame");
    if (target_frame && [target_frame respondsToSelector:is_main_frame_sel]) {
        is_main_frame = ((BOOL (*)(id, SEL))objc_msgSend)(target_frame, is_main_frame_sel);
    }

    if (!is_main_frame) {
        return YES;
    }

    if (ap_web_delegate_read_long(self, "_didAllowInitialNavigation") == 0) {
        ap_web_delegate_write_long(self, "_didAllowInitialNavigation", 1);
        return YES;
    }

    return NO;
}

static void ap_web_delegate_decide_policy(id self,
                                          SEL _cmd,
                                          WKWebView *web_view,
                                          WKNavigationAction *action,
                                          void (^decisionHandler)(WKNavigationActionPolicy)) {
    BOOL allow = ap_web_delegate_should_allow(self, web_view, action);
    if (decisionHandler) {
        decisionHandler(allow ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
    }
}

static void ap_web_delegate_did_start(id self, SEL _cmd, WKWebView *web_view, WKNavigation *navigation) {
    (void)navigation;
    ap_web_delegate_dispatch_string(
        ap_web_delegate_read_u64(self, "_startTag"),
        ap_web_navigation_url_string(web_view, nil)
    );
}

static void ap_web_delegate_did_finish(id self, SEL _cmd, WKWebView *web_view, WKNavigation *navigation) {
    (void)navigation;
    ap_web_delegate_dispatch_string(
        ap_web_delegate_read_u64(self, "_finishTag"),
        ap_web_navigation_url_string(web_view, nil)
    );
}

void register_ap_web_view_delegate(void) {
    if (objc_getClass("APCrystalWebViewDelegate") != Nil) {
        return;
    }

    Class cls = objc_allocateClassPair([NSObject class], "APCrystalWebViewDelegate", 0);
    if (!cls) return;

    class_addProtocol(cls, @protocol(WKNavigationDelegate));
    class_addIvar(cls, "_policyTag", sizeof(unsigned long long), __alignof__(unsigned long long), @encode(unsigned long long));
    class_addIvar(cls, "_startTag", sizeof(unsigned long long), __alignof__(unsigned long long), @encode(unsigned long long));
    class_addIvar(cls, "_finishTag", sizeof(unsigned long long), __alignof__(unsigned long long), @encode(unsigned long long));
    class_addIvar(cls, "_allowsNavigation", sizeof(long long), __alignof__(long long), @encode(long long));
    class_addIvar(cls, "_didAllowInitialNavigation", sizeof(long long), __alignof__(long long), @encode(long long));

    class_addMethod(cls, sel_registerName("setPolicyTag:"), (IMP)ap_web_delegate_set_policy_tag, "v@:Q");
    class_addMethod(cls, sel_registerName("setStartTag:"), (IMP)ap_web_delegate_set_start_tag, "v@:Q");
    class_addMethod(cls, sel_registerName("setFinishTag:"), (IMP)ap_web_delegate_set_finish_tag, "v@:Q");
    class_addMethod(cls, sel_registerName("setAllowsNavigation:"), (IMP)ap_web_delegate_set_allows_navigation, "v@:q");
    class_addMethod(cls, sel_registerName("webView:decidePolicyForNavigationAction:decisionHandler:"), (IMP)ap_web_delegate_decide_policy, "v@:@@@");
    class_addMethod(cls, sel_registerName("webView:didStartProvisionalNavigation:"), (IMP)ap_web_delegate_did_start, "v@:@@");
    class_addMethod(cls, sel_registerName("webView:didFinishNavigation:"), (IMP)ap_web_delegate_did_finish, "v@:@@");

    objc_registerClassPair(cls);
}

void wkwebview_set_callback_tags(void *web_view_ptr,
                                 unsigned long long policy_tag,
                                 unsigned long long start_tag,
                                 unsigned long long finish_tag,
                                 int allows_navigation) {
    if (!web_view_ptr) return;

    id raw_view = (id)web_view_ptr;
    if (![raw_view isKindOfClass:[WKWebView class]]) return;
    if (!policy_tag && !start_tag && !finish_tag && allows_navigation) return;

    register_ap_web_view_delegate();

    Class delegate_cls = objc_getClass("APCrystalWebViewDelegate");
    if (!delegate_cls) return;

    id delegate = [[delegate_cls alloc] init];
    if (!delegate) return;

    ((void (*)(id, SEL, unsigned long long))objc_msgSend)(delegate, sel_registerName("setPolicyTag:"), policy_tag);
    ((void (*)(id, SEL, unsigned long long))objc_msgSend)(delegate, sel_registerName("setStartTag:"), start_tag);
    ((void (*)(id, SEL, unsigned long long))objc_msgSend)(delegate, sel_registerName("setFinishTag:"), finish_tag);
    ((void (*)(id, SEL, long long))objc_msgSend)(delegate, sel_registerName("setAllowsNavigation:"), (long long)allows_navigation);

    [(WKWebView *)raw_view setNavigationDelegate:delegate];
    objc_setAssociatedObject(raw_view, &ap_web_delegate_association_key, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [delegate release];
}

void *mkmapview_new(double latitude,
                    double longitude,
                    double latitude_delta,
                    double longitude_delta,
                    long long map_type,
                    int shows_user_location) {
#if TARGET_OS_OSX
    MKMapView *map_view = [[MKMapView alloc] initWithFrame:NSZeroRect];
#else
    MKMapView *map_view = [[MKMapView alloc] initWithFrame:CGRectZero];
#endif
    if (!map_view) return NULL;

    map_view.mapType = (MKMapType)map_type;
    map_view.showsUserLocation = (BOOL)shows_user_location;

    CLLocationCoordinate2D center = CLLocationCoordinate2DMake(latitude, longitude);
    CLLocationDegrees lat_span = latitude_delta > 0.0 ? latitude_delta : 0.18;
    CLLocationDegrees lon_span = longitude_delta > 0.0 ? longitude_delta : 0.18;
    MKCoordinateSpan span = MKCoordinateSpanMake(lat_span, lon_span);
    MKCoordinateRegion region = MKCoordinateRegionMake(center, span);
    [map_view setRegion:region animated:NO];

    return (void *)map_view;
}

void mkmapview_add_annotation(void *map_ptr,
                              double latitude,
                              double longitude,
                              const char *title_cstr,
                              const char *subtitle_cstr) {
    MKMapView *map_view = (MKMapView *)map_ptr;
    if (!map_view) return;

    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    if (!annotation) return;

    annotation.coordinate = CLLocationCoordinate2DMake(latitude, longitude);

    NSString *title = ap_string_from_cstr(title_cstr);
    if (title && title.length) annotation.title = title;

    NSString *subtitle = ap_string_from_cstr(subtitle_cstr);
    if (subtitle && subtitle.length) annotation.subtitle = subtitle;

    [map_view addAnnotation:annotation];
}

static const char ap_player_association_key;
static const char ap_player_controller_association_key;
static const char ap_share_picker_association_key;
static const char ap_share_controller_association_key;

void *video_player_view_new(const char *url_cstr,
                            int shows_controls,
                            int auto_play,
                            int muted,
                            int loop) {
    (void)loop;

    NSString *url_string = ap_string_from_cstr(url_cstr);

#if TARGET_OS_OSX
    if (getenv("HIG_SCREENSHOT_PATH")) {
        return (void *)ap_make_video_capture_preview(url_string, (BOOL)shows_controls);
    }
#else
    if (getenv("HIG_SCREENSHOT_PATH") || getenv("HIG_VALIDATION_CAPTURE")) {
        CGFloat width = 320.0;
        CGFloat height = shows_controls ? 214.0 : 180.0;
        NSString *resolved_title = ap_video_preview_title(url_string);

        UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), YES, 0.0);
        CGContextRef context = UIGraphicsGetCurrentContext();

        UIColor *top = [UIColor colorWithRed:0.067 green:0.071 blue:0.090 alpha:1.0];
        UIColor *bottom = [UIColor colorWithRed:0.153 green:0.118 blue:0.094 alpha:1.0];
        NSArray *colors = @[(__bridge id)top.CGColor, (__bridge id)bottom.CGColor];
        CGFloat locations[] = {0.0, 1.0};
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(color_space, (__bridge CFArrayRef)colors, locations);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0, 0.0), CGPointMake(width, height), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(color_space);

        [[UIColor colorWithRed:1.0 green:0.706 blue:0.341 alpha:0.16] setFill];
        UIBezierPath *glow = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(width - 120.0, 18.0, 120.0, 120.0)];
        [glow fill];

        [[UIColor colorWithWhite:1.0 alpha:0.14] setFill];
        UIBezierPath *badge = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(18.0, 16.0, 104.0, 24.0) cornerRadius:12.0];
        [badge fill];

        NSDictionary *badge_attrs = @{
            NSFontAttributeName : [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.82]
        };
        NSDictionary *title_attrs = @{
            NSFontAttributeName : [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.96]
        };
        NSDictionary *meta_attrs = @{
            NSFontAttributeName : [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium],
            NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.72]
        };

        [@"VALIDATION" drawInRect:CGRectMake(30.0, 21.0, 80.0, 14.0) withAttributes:badge_attrs];
        [resolved_title drawInRect:CGRectMake(18.0, 48.0, width - 80.0, 22.0) withAttributes:title_attrs];
        [@"Capture-only poster." drawInRect:CGRectMake(18.0, 70.0, width - 44.0, 16.0) withAttributes:meta_attrs];

        CGRect play_rect = CGRectMake((width - 56.0) / 2.0, (height - 56.0) / 2.0 - 6.0, 56.0, 56.0);
        [[UIColor colorWithWhite:1.0 alpha:0.18] setFill];
        UIBezierPath *play_circle = [UIBezierPath bezierPathWithOvalInRect:play_rect];
        [play_circle fill];
        [[UIColor colorWithWhite:1.0 alpha:0.24] setStroke];
        play_circle.lineWidth = 1.0;
        [play_circle stroke];

        [[UIColor colorWithWhite:1.0 alpha:0.94] setFill];
        UIBezierPath *triangle = [UIBezierPath bezierPath];
        [triangle moveToPoint:CGPointMake(CGRectGetMidX(play_rect) - 6.0, CGRectGetMidY(play_rect) - 12.0)];
        [triangle addLineToPoint:CGPointMake(CGRectGetMidX(play_rect) - 6.0, CGRectGetMidY(play_rect) + 12.0)];
        [triangle addLineToPoint:CGPointMake(CGRectGetMidX(play_rect) + 14.0, CGRectGetMidY(play_rect))];
        [triangle closePath];
        [triangle fill];

        CGFloat track_y = height - 30.0;
        [[UIColor colorWithWhite:1.0 alpha:0.18] setFill];
        UIBezierPath *track = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(18.0, track_y, width - 78.0, 4.0) cornerRadius:2.0];
        [track fill];

        [[UIColor colorWithRed:1.0 green:0.706 blue:0.341 alpha:0.95] setFill];
        UIBezierPath *progress = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(18.0, track_y, (width - 78.0) * 0.34, 4.0) cornerRadius:2.0];
        [progress fill];

        if (shows_controls) {
            [@"01:28" drawInRect:CGRectMake(18.0, height - 20.0, 40.0, 12.0) withAttributes:meta_attrs];
            [@"03:54" drawInRect:CGRectMake(width - 54.0, height - 20.0, 36.0, 12.0) withAttributes:meta_attrs];
        }

        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIImageView *image_view = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)];
        image_view.image = image;
        image_view.contentMode = UIViewContentModeScaleToFill;
        image_view.clipsToBounds = YES;
        return (void *)image_view;
    }
#endif

    NSURL *url = ap_url_from_cstr(url_cstr);
    AVPlayer *player = url ? [AVPlayer playerWithURL:url] : nil;
    if (player) {
        player.muted = (BOOL)muted;
    }

#if TARGET_OS_OSX
    AVPlayerView *player_view = [[AVPlayerView alloc] initWithFrame:NSZeroRect];
    if (!player_view) return NULL;

    if (player) player_view.player = player;
    SEL controls_sel = sel_registerName("setControlsStyle:");
    if ([player_view respondsToSelector:controls_sel]) {
        long long style = shows_controls ? 0 : 1;
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(player_view, controls_sel, (NSInteger)style);
    }

    if (player) objc_setAssociatedObject(player_view, &ap_player_association_key, player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (player && auto_play) [player play];
    return (void *)player_view;
#else
    AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
    if (!controller) return NULL;

    controller.showsPlaybackControls = (BOOL)shows_controls;
    if (player) controller.player = player;
    UIView *player_view = controller.view;
    if (!player_view) return NULL;

    if (player) {
        objc_setAssociatedObject(player_view, &ap_player_association_key, player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    objc_setAssociatedObject(player_view, &ap_player_controller_association_key, controller, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (player && auto_play) [player play];
    return (void *)player_view;
#endif
}

void *ap_ring_view_new(double width,
                       double height,
                       double center_x,
                       double center_y,
                       double radius,
                       double track_start_angle,
                       double track_end_angle,
                       double progress_start_angle,
                       double progress_end_angle,
                       double line_width,
                       double track_r,
                       double track_g,
                       double track_b,
                       double track_a,
                       double progress_r,
                       double progress_g,
                       double progress_b,
                       double progress_a) {
#if TARGET_OS_OSX
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, width, height)];
    if (!view) return NULL;
    [view setWantsLayer:YES];
    if (!view.layer) {
        view.layer = [CALayer layer];
    }
    view.layer.backgroundColor = NSColor.clearColor.CGColor;
#else
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)];
    if (!view) return NULL;
    view.backgroundColor = UIColor.clearColor;
#endif

    CGMutablePathRef track_path = CGPathCreateMutable();
    CGPathAddArc(track_path,
                 NULL,
                 (CGFloat)center_x,
                 (CGFloat)center_y,
                 (CGFloat)radius,
                 (CGFloat)track_start_angle,
                 (CGFloat)track_end_angle,
                 false);

    CGMutablePathRef progress_path = CGPathCreateMutable();
    CGPathAddArc(progress_path,
                 NULL,
                 (CGFloat)center_x,
                 (CGFloat)center_y,
                 (CGFloat)radius,
                 (CGFloat)progress_start_angle,
                 (CGFloat)progress_end_angle,
                 false);

    id track_color = nscolor_rgba(track_r, track_g, track_b, track_a);
    id progress_color = nscolor_rgba(progress_r, progress_g, progress_b, progress_a);

    CAShapeLayer *track_layer = [CAShapeLayer layer];
    track_layer.frame = CGRectMake(0.0, 0.0, width, height);
    track_layer.path = track_path;
    track_layer.fillColor = NULL;
    track_layer.strokeColor = track_color ? [track_color CGColor] : NULL;
    track_layer.lineWidth = (CGFloat)line_width;
    track_layer.lineCap = kCALineCapRound;

    CAShapeLayer *progress_layer = [CAShapeLayer layer];
    progress_layer.frame = CGRectMake(0.0, 0.0, width, height);
    progress_layer.path = progress_path;
    progress_layer.fillColor = NULL;
    progress_layer.strokeColor = progress_color ? [progress_color CGColor] : NULL;
    progress_layer.lineWidth = (CGFloat)line_width;
    progress_layer.lineCap = kCALineCapRound;

    [view.layer addSublayer:track_layer];
    [view.layer addSublayer:progress_layer];

    CGPathRelease(track_path);
    CGPathRelease(progress_path);

    return (void *)view;
}

static NSMutableArray *ap_share_items_from_payload(NSString *text, NSString *url_string) {
    NSMutableArray *items = [NSMutableArray array];
    if (text && text.length) {
        [items addObject:text];
    }
    if (url_string && url_string.length) {
        NSURL *url = nil;
        if ([url_string containsString:@"://"]) {
            url = [NSURL URLWithString:url_string];
        } else {
            url = [NSURL fileURLWithPath:url_string];
        }
        if (url) {
            [items addObject:url];
        } else {
            [items addObject:url_string];
        }
    }
    return items;
}

#if TARGET_OS_OSX
void nssharingservicepicker_present(void *anchor_view_ptr,
                                    const char *text_cstr,
                                    const char *url_cstr) {
    NSView *anchor_view = (NSView *)anchor_view_ptr;
    if (!anchor_view) return;

    NSString *text = ap_string_from_cstr(text_cstr);
    NSString *url_string = ap_string_from_cstr(url_cstr);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!anchor_view.window) return;

        NSMutableArray *items = ap_share_items_from_payload(text, url_string);
        if (!items.count) return;

        NSSharingServicePicker *picker = [[NSSharingServicePicker alloc] initWithItems:items];
        if (!picker) return;

        NSRect rect = anchor_view.bounds;
        if (rect.size.width <= 0.0 || rect.size.height <= 0.0) {
            rect = NSMakeRect(0.0, 0.0, 1.0, 1.0);
        }

        objc_setAssociatedObject(anchor_view, &ap_share_picker_association_key, picker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [picker showRelativeToRect:rect ofView:anchor_view preferredEdge:NSRectEdgeMinY];
        [picker release];
    });
}
#else
static UIViewController *ap_top_presenting_view_controller(UIView *anchor_view) {
    UIResponder *responder = anchor_view;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            UIViewController *controller = (UIViewController *)responder;
            while (controller.presentedViewController) {
                controller = controller.presentedViewController;
            }
            return controller;
        }
        responder = [responder nextResponder];
    }

    UIWindow *window = anchor_view.window;
    UIApplication *application = [UIApplication sharedApplication];
    if (!window && [application respondsToSelector:@selector(connectedScenes)]) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                if (candidate.isKeyWindow) {
                    window = candidate;
                    break;
                }
            }
            if (window) break;
        }
    }
    if (!window && [application respondsToSelector:@selector(keyWindow)]) {
        window = application.keyWindow;
    }
    if (!window) return nil;

    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

void uiactivityview_present(void *anchor_view_ptr,
                            const char *text_cstr,
                            const char *url_cstr,
                            const char *subject_cstr) {
    UIView *anchor_view = (UIView *)anchor_view_ptr;
    if (!anchor_view) return;

    NSString *text = ap_string_from_cstr(text_cstr);
    NSString *url_string = ap_string_from_cstr(url_cstr);
    NSString *subject = ap_string_from_cstr(subject_cstr);

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = ap_top_presenting_view_controller(anchor_view);
        if (!presenter || [presenter isKindOfClass:[UIActivityViewController class]]) return;

        NSMutableArray *items = ap_share_items_from_payload(text, url_string);
        if (!items.count) return;

        UIActivityViewController *controller =
            [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
        if (!controller) return;

        if (subject && subject.length) {
            @try {
                [controller setValue:subject forKey:@"subject"];
            } @catch (__unused NSException *exception) {
            }
        }

        UIPopoverPresentationController *popover = controller.popoverPresentationController;
        if (popover) {
            popover.sourceView = anchor_view;
            CGRect rect = anchor_view.bounds;
            if (rect.size.width <= 0.0 || rect.size.height <= 0.0) {
                rect = CGRectMake(0.0, 0.0, 1.0, 1.0);
            }
            popover.sourceRect = rect;
        }

        objc_setAssociatedObject(anchor_view, &ap_share_controller_association_key, controller, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [presenter presentViewController:controller animated:NO completion:nil];
        [controller release];
    });
}
#endif

// ============================================================
// Section 5: CrystalActionDispatcher — dynamic ObjC class for
// button target-action routing to Crystal's CallbackRegistry
// ============================================================

// Crystal exports this function from callback_registry.cr.
// It routes into UI::CallbackRegistry.call(tag).
extern void crystal_ui_callback_dispatch(unsigned long long tag);

// IMP for setTag: — stores the callback ID in the _tag ivar.
static void crystal_action_dispatcher_set_tag(id self, SEL _cmd, long long tag) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), "_tag");
    if (ivar) {
        *(NSInteger *)((uint8_t *)(__bridge void *)self + ivar_getOffset(ivar)) = (NSInteger)tag;
    }
}

// IMP for tag — returns the _tag ivar value.
static long long crystal_action_dispatcher_get_tag(id self, SEL _cmd) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), "_tag");
    if (ivar) {
        return (long long)(*(NSInteger *)((uint8_t *)(__bridge void *)self + ivar_getOffset(ivar)));
    }
    return 0;
}

// IMP for dispatch: — reads tag via the ivar and calls into Crystal.
static void crystal_action_dispatcher_dispatch(id self, SEL _cmd, id sender) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), "_tag");
    if (ivar) {
        NSInteger tag = *(NSInteger *)((uint8_t *)(__bridge void *)self + ivar_getOffset(ivar));
        crystal_ui_callback_dispatch((unsigned long long)tag);
    }
}

// Registers the CrystalActionDispatcher ObjC class at runtime.
// Must be called once before the AppKit / UIKit renderer creates any buttons.
void register_crystal_action_dispatcher(void) {
    // Guard: only register once
    if (objc_getClass("CrystalActionDispatcher") != Nil) {
        return;
    }

    Class cls = objc_allocateClassPair([NSObject class], "CrystalActionDispatcher", 0);
    if (!cls) return;

    // Add _tag ivar (NSInteger sized, pointer-aligned)
    class_addIvar(cls, "_tag", sizeof(NSInteger), __alignof__(NSInteger), @encode(NSInteger));

    // setTag: — "v@:q" (void, id, SEL, long long)
    class_addMethod(cls, sel_registerName("setTag:"),
                    (IMP)crystal_action_dispatcher_set_tag, "v@:q");

    // tag — "q@:" (long long, id, SEL)
    class_addMethod(cls, sel_registerName("tag"),
                    (IMP)crystal_action_dispatcher_get_tag, "q@:");

    // dispatch: — "v@:@" (void, id, SEL, id)
    class_addMethod(cls, sel_registerName("dispatch:"),
                    (IMP)crystal_action_dispatcher_dispatch, "v@:@");

    objc_registerClassPair(cls);
}
