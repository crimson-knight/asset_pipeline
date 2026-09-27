#import <AppKit/AppKit.h>
#include <stdint.h>
#include <string.h>

// --- Layout measurement harness -------------------------------------------
//
// These specs run while someone may be using the machine, so the window never
// activates the app, never becomes key, and never appears on a screen: it is
// borderless, parked far outside every display, and never ordered in. Frames
// come from Auto Layout after bounded run-loop passes; ink rows come from
// cacheDisplayInRect:, which draws the view hierarchy without the window
// server.

@interface APSpecOffscreenLayoutWindow : NSWindow
@end

@implementation APSpecOffscreenLayoutWindow
- (NSRect)constrainFrameRect:(NSRect)frame_rect toScreen:(NSScreen *)screen {
    return frame_rect;
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)canBecomeMainWindow {
    return NO;
}
@end

static void ap_spec_layout_pump_run_loop(NSTimeInterval seconds) {
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:until];
}

static void ap_spec_layout_settle(NSWindow *window) {
    for (int pass = 0; pass < 10; pass++) {
        [[window contentView] layoutSubtreeIfNeeded];
        [window displayIfNeeded];
        ap_spec_layout_pump_run_loop(0.02);
    }
}

// Hosts `root_view_ptr` in an offscreen window, pinned to the top-leading
// corner of a flipped container at exactly `width` points wide. The height is
// left free, so the root takes the height its content asks for.
void *ap_spec_layout_window_new(void *root_view_ptr, double width, double height) {
    NSApplication *application = [NSApplication sharedApplication];
    [application setActivationPolicy:NSApplicationActivationPolicyAccessory];

    APSpecOffscreenLayoutWindow *window = [[APSpecOffscreenLayoutWindow alloc]
        initWithContentRect:NSMakeRect(-30000, -30000, width, height)
        styleMask:NSWindowStyleMaskBorderless
        backing:NSBackingStoreBuffered
        defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];

    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
    [window setContentView:container];
    [container release];

    NSView *root = (NSView *)root_view_ptr;
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:root];
    [NSLayoutConstraint activateConstraints:@[
        [root.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [root.topAnchor constraintEqualToAnchor:container.topAnchor],
        [root.widthAnchor constraintEqualToConstant:(CGFloat)width],
    ]];
    ap_spec_layout_settle(window);
    return window;
}

// Writes {x, y, width, height} of `view_ptr` in the root view's coordinates,
// with y measured DOWN from the root's top edge.
int32_t ap_spec_layout_frame_from_top(void *window_ptr, void *root_view_ptr, void *view_ptr, double *out_rect) {
    NSWindow *window = (NSWindow *)window_ptr;
    NSView *root = (NSView *)root_view_ptr;
    NSView *view = (NSView *)view_ptr;
    if (out_rect == NULL || view.window != window) return 0;
    [[window contentView] layoutSubtreeIfNeeded];
    NSRect rect = [root convertRect:[view bounds] fromView:view];
    CGFloat top = root.isFlipped ? NSMinY(rect) : NSHeight(root.bounds) - NSMaxY(rect);
    out_rect[0] = NSMinX(rect);
    out_rect[1] = top;
    out_rect[2] = NSWidth(rect);
    out_rect[3] = NSHeight(rect);
    return 1;
}

// Writes the view's fittingSize {width, height}.
void ap_spec_layout_fitting_size(void *view_ptr, double *out_size) {
    NSSize size = [(NSView *)view_ptr fittingSize];
    out_size[0] = size.width;
    out_size[1] = size.height;
}

// Draws `view_ptr` into a bitmap and marks, per point row from its top, whether
// any pixel in that row is ink (alpha above half and darker than mid-gray).
// `out_rows` holds `capacity` bytes, one per PIXEL row; returns the number of
// rows written and stores the pixel rows per point in `out_pixels_per_point`.
int32_t ap_spec_layout_ink_rows(void *window_ptr, void *view_ptr, uint8_t *out_rows, int32_t capacity, double *out_pixels_per_point) {
    NSWindow *window = (NSWindow *)window_ptr;
    NSView *view = (NSView *)view_ptr;
    if (out_rows == NULL || view.window != window) return 0;
    [[window contentView] layoutSubtreeIfNeeded];

    NSRect bounds = [view bounds];
    NSBitmapImageRep *cached = [view bitmapImageRepForCachingDisplayInRect:bounds];
    if (cached == nil) return 0;
    [view cacheDisplayInRect:bounds toBitmapImageRep:cached];

    NSInteger pixel_width = [cached pixelsWide];
    NSInteger pixel_height = [cached pixelsHigh];
    CGFloat scale = pixel_height / NSHeight(bounds);
    int32_t rows = (int32_t)(pixel_height);
    if (rows > capacity) rows = capacity;

    uint8_t *rgba = calloc((size_t)(pixel_width * pixel_height * 4), 1);
    if (rgba == NULL) return 0;
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(
        rgba, pixel_width, pixel_height, 8, pixel_width * 4, srgb,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(srgb);
    if (context == NULL) {
        free(rgba);
        return 0;
    }
    CGContextDrawImage(context, CGRectMake(0, 0, pixel_width, pixel_height), [cached CGImage]);
    CGContextRelease(context);

    // Bitmap row 0 is the top of the image.
    for (int32_t row = 0; row < rows; row++) {
        uint8_t inked = 0;
        for (NSInteger column = 0; column < pixel_width && !inked; column++) {
            uint8_t *pixel = rgba + (row * pixel_width + column) * 4;
            if (pixel[3] > 128 && pixel[0] < 128 && pixel[1] < 128 && pixel[2] < 128) inked = 1;
        }
        out_rows[row] = inked;
    }
    free(rgba);
    if (out_pixels_per_point != NULL) *out_pixels_per_point = scale;
    return rows;
}

int32_t ap_spec_layout_application_is_active(void) {
    return [NSApp isActive] ? 1 : 0;
}

void ap_spec_layout_window_close(void *window_ptr) {
    NSWindow *window = (NSWindow *)window_ptr;
    [window close];
    [window release];
}
