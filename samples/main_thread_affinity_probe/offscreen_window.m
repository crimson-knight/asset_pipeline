// Creates and closes one borderless NSWindow far offscreen. The window is never
// ordered in and the app is never activated, so the probe cannot take focus.
// Off the main thread, -[NSWindow initWithContentRect:...] raises
// NSInternalInconsistencyException, which is the failure the probe detects.
#import <AppKit/AppKit.h>

int probe_make_offscreen_window(void) {
    @autoreleasepool {
        NSWindow *window = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(-30000, -30000, 200, 100)
                      styleMask:NSWindowStyleMaskBorderless
                        backing:NSBackingStoreBuffered
                          defer:YES];
        [window setReleasedWhenClosed:NO];
        [window close];
        return window != nil ? 1 : 0;
    }
}
