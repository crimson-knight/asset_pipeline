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
  typedef NSView      BridgeView;
  typedef NSButton    BridgeButton;
  #define BRIDGE_RECT_MAKE(r) NSMakeRect((r).x, (r).y, (r).width, (r).height)
  typedef NSRect      BridgeRect;
#else
  #import <UIKit/UIKit.h>
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
