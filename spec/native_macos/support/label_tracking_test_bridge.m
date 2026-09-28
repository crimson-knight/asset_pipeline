#import <AppKit/AppKit.h>
#include <stdint.h>
#include <string.h>

// --- Label tracking capture harness --------------------------------------
//
// These specs run while someone may be using the machine, so the capture
// window never activates the app and never becomes key or main: it is
// borderless, parked far outside every display, and only ordered behind
// every other window so the accessibility tree lists it. Pixels come from
// cacheDisplayInRect:, which draws the view hierarchy without the window
// server, into a bitmap at an explicit backing scale.

@interface APSpecOffscreenTrackingWindow : NSWindow
@end

@implementation APSpecOffscreenTrackingWindow
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

static void ap_spec_tracking_settle(NSWindow *window) {
    for (int pass = 0; pass < 10; pass++) {
        [[window contentView] layoutSubtreeIfNeeded];
        [window displayIfNeeded];
        NSDate *until = [NSDate dateWithTimeIntervalSinceNow:0.02];
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:until];
    }
}

// Creates the offscreen window, in the Aqua appearance, with
// `content_view_ptr` as its content view sized to `width` x `height` points.
void *ap_spec_tracking_window_new(void *content_view_ptr, double width, double height) {
    NSApplication *application = [NSApplication sharedApplication];
    [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [application finishLaunching];

    APSpecOffscreenTrackingWindow *window = [[APSpecOffscreenTrackingWindow alloc]
        initWithContentRect:NSMakeRect(-30000, -30000, width, height)
        styleMask:NSWindowStyleMaskBorderless
        backing:NSBackingStoreBuffered
        defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setTitle:@"Label Tracking Probe"];
    [window setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
    [window setContentView:(NSView *)content_view_ptr];
    [window orderBack:nil];
    ap_spec_tracking_settle(window);
    return window;
}

// Draws the window's content view into an 8-bit sRGB RGBA bitmap at
// `scale` pixels per point and copies it into `out_rgba`, row 0 at the top.
// `capacity` is the size of `out_rgba` in bytes. Returns 1 and fills
// `out_size` with {pixel_width, pixel_height} on success.
int32_t ap_spec_tracking_capture(void *window_ptr, double scale, uint8_t *out_rgba, int64_t capacity, int32_t *out_size) {
    NSWindow *window = (NSWindow *)window_ptr;
    NSView *root = [window contentView];
    if (root == nil || out_rgba == NULL || out_size == NULL || scale <= 0) return 0;
    ap_spec_tracking_settle(window);

    NSRect bounds = [root bounds];
    NSInteger width = (NSInteger)(NSWidth(bounds) * scale);
    NSInteger height = (NSInteger)(NSHeight(bounds) * scale);
    if (width <= 0 || height <= 0 || (int64_t)width * height * 4 > capacity) return 0;

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
        pixelsWide:width
        pixelsHigh:height
        bitsPerSample:8
        samplesPerPixel:4
        hasAlpha:YES
        isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace
        bytesPerRow:0
        bitsPerPixel:0];
    if (rep == nil) return 0;
    [rep setSize:bounds.size];
    [root cacheDisplayInRect:bounds toBitmapImageRep:rep];

    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(
        out_rgba, width, height, 8, width * 4, srgb,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(srgb);
    if (context == NULL) {
        [rep release];
        return 0;
    }
    memset(out_rgba, 0, (size_t)(width * height * 4));
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), [rep CGImage]);
    CGContextRelease(context);
    [rep release];

    out_size[0] = (int32_t)width;
    out_size[1] = (int32_t)height;
    return 1;
}

// The content view's fitting size in points: the layout size the text asks
// for, which includes any trailing tracking the text engine appends.
void ap_spec_tracking_fitting_size(void *window_ptr, double *width, double *height) {
    NSWindow *window = (NSWindow *)window_ptr;
    NSSize fitting_size = [[window contentView] fittingSize];
    *width = fitting_size.width;
    *height = fitting_size.height;
}

int32_t ap_spec_tracking_application_is_active(void) {
    return [NSApp isActive] ? 1 : 0;
}

int32_t ap_spec_tracking_window_is_key(void *window_ptr) {
    return [(NSWindow *)window_ptr isKeyWindow] ? 1 : 0;
}

void ap_spec_tracking_window_close(void *window_ptr) {
    NSWindow *window = (NSWindow *)window_ptr;
    [window orderOut:nil];
    [window close];
    [window release];
}

// Sends a left mouse down (is_down != 0) or up to the window at (x, y)
// points from the content view's top-left corner, through sendEvent: as
// AppKit delivers a real click, without making the window key. Returns 0
// when the window has no content view.
int32_t ap_spec_tracking_send_mouse(void *window_ptr, double x, double y, int32_t is_down) {
    NSWindow *window = (NSWindow *)window_ptr;
    NSView *root = [window contentView];
    if (root == nil) return 0;
    NSPoint window_point = NSMakePoint(x, NSHeight([root frame]) - y);
    NSEvent *event = [NSEvent mouseEventWithType:(is_down != 0 ? NSEventTypeLeftMouseDown : NSEventTypeLeftMouseUp)
                                        location:window_point
                                   modifierFlags:0
                                       timestamp:[[NSProcessInfo processInfo] systemUptime]
                                    windowNumber:[window windowNumber]
                                         context:nil
                                     eventNumber:0
                                      clickCount:1
                                        pressure:(is_down != 0 ? 1.0 : 0.0)];
    [window sendEvent:event];
    return 1;
}
