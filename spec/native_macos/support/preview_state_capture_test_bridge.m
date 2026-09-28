#import <AppKit/AppKit.h>
#import <ImageIO/ImageIO.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

extern void appkit_view_apply_surface_craft(void *view_ptr, const char *json);
extern void *ap_surface_noise_texture_tile_create(
    double base_frequency,
    int octave_count,
    int seed,
    int tile_size,
    double backing_scale,
    int color_interpolation_filters);

@interface APSpecBackingScaleWindow : NSWindow
@property(nonatomic) CGFloat specBackingScaleFactor;
@end

@implementation APSpecBackingScaleWindow
- (CGFloat)backingScaleFactor {
    return self.specBackingScaleFactor > 0.0
        ? self.specBackingScaleFactor
        : [super backingScaleFactor];
}
@end

static APSpecBackingScaleWindow *ap_spec_held_window;

// Offscreen window for the AppKit view capture. AppKit would otherwise pull
// a frame at (-30000, -30000) back onto a screen.
@interface APSpecOffscreenCaptureWindow : NSWindow
@end

@implementation APSpecOffscreenCaptureWindow
- (NSRect)constrainFrameRect:(NSRect)frame_rect toScreen:(NSScreen *)screen {
    return frame_rect;
}
@end

static CALayer *ap_spec_surface_layer_named(CALayer *root, NSString *name) {
    for (CALayer *layer in root.sublayers) {
        if ([layer.name isEqualToString:name]) return layer;
    }
    return nil;
}

static CGContextRef ap_spec_srgb_bitmap_context(uint8_t *pixels, size_t width, size_t height) {
    CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (color_space == NULL) return NULL;
    CGContextRef context = CGBitmapContextCreate(
        pixels,
        width,
        height,
        8,
        width * 4,
        color_space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color_space);
    return context;
}

static void ap_spec_release_noise_pixels(void *info, const void *data, size_t size) {
    (void)info;
    (void)size;
    free((void *)data);
}

int32_t ap_spec_render_noise_red_grayscale_reference(
    double base_frequency,
    int32_t octave_count,
    int32_t seed,
    int32_t tile_size,
    double backing_scale,
    uint8_t *pixels,
    int32_t capacity,
    int32_t *pixel_width,
    int32_t *pixel_height) {
    if (pixels == NULL || pixel_width == NULL || pixel_height == NULL ||
        tile_size <= 0 || backing_scale <= 0.0) return 0;

    size_t output_width = (size_t)llround((double)tile_size * backing_scale);
    size_t output_height = output_width;
    if (output_width == 0 || output_width > INT32_MAX ||
        output_width * output_height > SIZE_MAX / 4 ||
        (size_t)capacity < output_width * output_height * 4) return 0;

    @autoreleasepool {
        // The noise-tile fixture sets color-interpolation-filters="sRGB" (1).
        CGImageRef noise_tile = (CGImageRef)ap_surface_noise_texture_tile_create(
            base_frequency, octave_count, seed, tile_size, backing_scale, 1);
        if (noise_tile == NULL) return 0;

        size_t tile_width = CGImageGetWidth(noise_tile);
        size_t tile_height = CGImageGetHeight(noise_tile);
        size_t source_row_bytes = CGImageGetBytesPerRow(noise_tile);
        CGDataProviderRef source_provider = CGImageGetDataProvider(noise_tile);
        CFDataRef source_data = source_provider == NULL ? NULL : CGDataProviderCopyData(source_provider);
        CGImageRelease(noise_tile);
        if (source_data == NULL || tile_width != output_width || tile_height != output_height) {
            if (source_data != NULL) CFRelease(source_data);
            return 0;
        }

        const uint8_t *source = CFDataGetBytePtr(source_data);
        size_t gray_row_bytes = tile_width * 4;
        if (source == NULL || source_row_bytes < gray_row_bytes) {
            CFRelease(source_data);
            return 0;
        }
        uint8_t *gray_pixels = calloc(tile_width * tile_height, 4);
        if (gray_pixels == NULL) {
            CFRelease(source_data);
            return 0;
        }
        for (size_t y = 0; y < tile_height; y++) {
            for (size_t x = 0; x < tile_width; x++) {
                const uint8_t *source_pixel = source + y * source_row_bytes + x * 4;
                uint8_t alpha = source_pixel[3];
                uint8_t red = alpha == 0 ? 0 : (uint8_t)MIN(255, ((int)source_pixel[0] * 255 + alpha / 2) / alpha);
                uint8_t *gray_pixel = gray_pixels + y * gray_row_bytes + x * 4;
                gray_pixel[0] = red;
                gray_pixel[1] = red;
                gray_pixel[2] = red;
                gray_pixel[3] = 255;
            }
        }
        CFRelease(source_data);

        CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        if (color_space == NULL) {
            free(gray_pixels);
            return 0;
        }
        CGDataProviderRef gray_provider = CGDataProviderCreateWithData(
            NULL, gray_pixels, gray_row_bytes * tile_height, ap_spec_release_noise_pixels);
        if (gray_provider == NULL) {
            CGColorSpaceRelease(color_space);
            free(gray_pixels);
            return 0;
        }
        CGImageRef gray_tile = CGImageCreate(
            tile_width,
            tile_height,
            8,
            32,
            gray_row_bytes,
            color_space,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
            gray_provider,
            NULL,
            false,
            kCGRenderingIntentDefault);
        if (gray_provider != NULL) CGDataProviderRelease(gray_provider);
        CGColorSpaceRelease(color_space);
        if (gray_tile == NULL) {
            return 0;
        }

        NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, tile_size, tile_size)];
        view.wantsLayer = YES;
        view.layer.contentsScale = backing_scale;
        view.layer.backgroundColor = [NSColor colorWithSRGBRed:128.0 / 255.0
            green:128.0 / 255.0 blue:128.0 / 255.0 alpha:1.0].CGColor;
        CALayer *image_layer = [CALayer layer];
        image_layer.frame = view.bounds;
        image_layer.contentsScale = backing_scale;
        image_layer.contents = (__bridge id)gray_tile;
        image_layer.opacity = 0.07;
        [view.layer addSublayer:image_layer];

        CGContextRef context = ap_spec_srgb_bitmap_context(pixels, output_width, output_height);
        if (context == NULL) {
            CGImageRelease(gray_tile);
            [view release];
            return 0;
        }
        CGContextTranslateCTM(context, 0, output_height);
        CGContextScaleCTM(context, backing_scale, -backing_scale);
        [view.layer renderInContext:context];
        CGContextFlush(context);
        CGContextRelease(context);
        CGImageRelease(gray_tile);
        [view release];
        *pixel_width = (int32_t)output_width;
        *pixel_height = (int32_t)output_height;
        return 1;
    }
}

static void ap_spec_texture_tile_pixel_size(NSView *view, int32_t *width, int32_t *height) {
    CALayer *texture_layer = ap_spec_surface_layer_named(view.layer, @"ap.surfaceCraft.texture");
    CALayer *row_layer = texture_layer.sublayers.count > 0 ? texture_layer.sublayers[0] : nil;
    CALayer *image_layer = row_layer.sublayers.count > 0 ? row_layer.sublayers[0] : nil;
    CGImageRef tile = (CGImageRef)image_layer.contents;
    *width = tile == NULL ? 0 : (int32_t)CGImageGetWidth(tile);
    *height = tile == NULL ? 0 : (int32_t)CGImageGetHeight(tile);
}

static int32_t ap_spec_attach_view_to_offscreen_window(
    NSView *view,
    double point_width,
    double point_height,
    double initial_scale,
    double changed_scale,
    BOOL should_change_scale,
    BOOL should_hold_window,
    int32_t *initial_tile_width,
    int32_t *initial_tile_height,
    int32_t *changed_tile_width,
    int32_t *changed_tile_height) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSRect frame = NSMakeRect(0, 0, point_width, point_height);
        NSScreen *screen = [NSScreen mainScreen];
        if (screen != nil) {
            NSRect visible_frame = screen.visibleFrame;
            frame.origin = NSMakePoint(
                NSMidX(visible_frame) - point_width / 2.0,
                NSMidY(visible_frame) - point_height / 2.0);
        }
        NSRect initial_frame = frame;
        initial_frame.size = NSMakeSize(32.0, 32.0);
        APSpecBackingScaleWindow *window = [[APSpecBackingScaleWindow alloc]
            initWithContentRect:initial_frame
            styleMask:NSWindowStyleMaskBorderless
            backing:NSBackingStoreBuffered
            defer:NO];
        if (window == nil) return 0;
        [window setReleasedWhenClosed:NO];
        window.specBackingScaleFactor = initial_scale;
        int32_t result = 1;
        @try {
            [view setFrame:NSMakeRect(0, 0, 32.0, 32.0)];
            [window setContentView:view];
            [window orderOut:nil];
            [window layoutIfNeeded];
            [view layoutSubtreeIfNeeded];
            [window displayIfNeeded];
            [view displayIfNeeded];

            // Grow after attachment so the backing-properties and layout hooks
            // see the final bounds rather than the provisional content frame.
            [window setContentSize:NSMakeSize(point_width, point_height)];
            [window layoutIfNeeded];
            [view layoutSubtreeIfNeeded];
            [window displayIfNeeded];
            [view displayIfNeeded];
            if (initial_tile_width != NULL && initial_tile_height != NULL) {
                ap_spec_texture_tile_pixel_size(view, initial_tile_width, initial_tile_height);
            }

            if (should_change_scale) {
                window.specBackingScaleFactor = changed_scale;
                [view viewDidChangeBackingProperties];
                [window layoutIfNeeded];
                [view layoutSubtreeIfNeeded];
                [window displayIfNeeded];
                [view displayIfNeeded];
                if (changed_tile_width != NULL && changed_tile_height != NULL) {
                    ap_spec_texture_tile_pixel_size(view, changed_tile_width, changed_tile_height);
                }
            }
        } @catch (NSException *exception) {
            fprintf(stderr, "SurfaceCraft attach exception: %s: %s\n",
                exception.name.UTF8String, exception.reason.UTF8String);
            result = 2;
        }

        if (should_hold_window && result == 1) {
            ap_spec_held_window = window;
        } else {
            @try {
                [window setContentView:nil];
                [window close];
            } @catch (NSException *exception) {
                fprintf(stderr, "SurfaceCraft window cleanup exception: %s: %s\n",
                    exception.name.UTF8String, exception.reason.UTF8String);
                result = 2;
            }
            [window release];
        }
        return result;
    }
}

int32_t ap_spec_attach_noise_view_and_change_backing_scale(
    void *view_ptr,
    double point_width,
    double point_height,
    double initial_scale,
    double changed_scale,
    int32_t *initial_tile_width,
    int32_t *initial_tile_height,
    int32_t *changed_tile_width,
    int32_t *changed_tile_height) {
    if (view_ptr == NULL || initial_scale <= 0.0 || changed_scale <= 0.0 ||
        initial_tile_width == NULL || initial_tile_height == NULL ||
        changed_tile_width == NULL || changed_tile_height == NULL) return 0;
    return ap_spec_attach_view_to_offscreen_window(
        (__bridge NSView *)view_ptr,
        point_width,
        point_height,
        initial_scale,
        changed_scale,
        YES,
        NO,
        initial_tile_width,
        initial_tile_height,
        changed_tile_width,
        changed_tile_height);
}

int32_t ap_spec_attach_and_detach_noise_view(void *view_ptr, double point_width, double point_height, double backing_scale) {
    if (view_ptr == NULL || backing_scale <= 0.0) return 0;
    return ap_spec_attach_view_to_offscreen_window(
        (__bridge NSView *)view_ptr,
        point_width,
        point_height,
        backing_scale,
        backing_scale,
        NO,
        NO,
        NULL,
        NULL,
        NULL,
        NULL);
}

int32_t ap_spec_attach_noise_view_to_held_window(void *view_ptr, double point_width, double point_height, double backing_scale) {
    if (view_ptr == NULL || backing_scale <= 0.0 || ap_spec_held_window != nil) return 0;
    return ap_spec_attach_view_to_offscreen_window(
        (__bridge NSView *)view_ptr,
        point_width,
        point_height,
        backing_scale,
        backing_scale,
        NO,
        YES,
        NULL,
        NULL,
        NULL,
        NULL);
}

void ap_spec_close_held_noise_window(void) {
    @autoreleasepool {
        APSpecBackingScaleWindow *window = ap_spec_held_window;
        if (window == nil) return;
        ap_spec_held_window = nil;
        [window setContentView:nil];
        [window close];
        [window release];
    }
}

int32_t ap_spec_noise_texture_layout_metrics(
    void *view_ptr,
    double *texture_width,
    double *texture_height,
    int32_t *row_count,
    int32_t *column_count) {
    if (view_ptr == NULL || texture_width == NULL || texture_height == NULL ||
        row_count == NULL || column_count == NULL) return 0;
    NSView *view = (__bridge NSView *)view_ptr;
    CALayer *texture = ap_spec_surface_layer_named(view.layer, @"ap.surfaceCraft.texture");
    CAReplicatorLayer *vertical = [texture isKindOfClass:[CAReplicatorLayer class]] ?
        (CAReplicatorLayer *)texture : nil;
    CAReplicatorLayer *row = vertical.sublayers.count > 0 &&
        [vertical.sublayers[0] isKindOfClass:[CAReplicatorLayer class]] ?
        (CAReplicatorLayer *)vertical.sublayers[0] : nil;
    if (vertical == nil || row == nil) return 0;
    *texture_width = CGRectGetWidth(vertical.frame);
    *texture_height = CGRectGetHeight(vertical.frame);
    *row_count = (int32_t)vertical.instanceCount;
    *column_count = (int32_t)row.instanceCount;
    return 1;
}

int32_t ap_spec_surface_layer_count(void *view_ptr, const char *name) {
    if (view_ptr == NULL || name == NULL) return 0;
    NSView *view = (__bridge NSView *)view_ptr;
    NSString *target = [NSString stringWithUTF8String:name];
    int32_t count = 0;
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer.name isEqualToString:target]) count++;
    }
    return count;
}

int32_t ap_spec_render_surface_craft_json(
    const char *json,
    double point_width,
    double point_height,
    double backing_scale,
    uint8_t *pixels,
    int32_t capacity,
    int32_t *pixel_width,
    int32_t *pixel_height,
    int32_t *tile_pixel_width,
    int32_t *tile_pixel_height,
    double *texture_opacity,
    double *contents_scale,
    int32_t *has_compositing_filter) {
    if (json == NULL || pixels == NULL || pixel_width == NULL || pixel_height == NULL ||
        tile_pixel_width == NULL || tile_pixel_height == NULL || texture_opacity == NULL ||
        contents_scale == NULL || has_compositing_filter == NULL || backing_scale <= 0.0) return 0;

    size_t output_width = (size_t)llround(point_width * backing_scale);
    size_t output_height = (size_t)llround(point_height * backing_scale);
    if (output_width == 0 || output_height == 0 || output_width > INT32_MAX ||
        output_height > INT32_MAX || output_width * output_height > SIZE_MAX / 4 ||
        (size_t)capacity < output_width * output_height * 4) return 0;

    @autoreleasepool {
        NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, point_width, point_height)];
        if (view == nil) return 0;
        view.wantsLayer = YES;
        view.layer.contentsScale = backing_scale;
        appkit_view_apply_surface_craft(view, json);

        CALayer *texture_layer = ap_spec_surface_layer_named(view.layer, @"ap.surfaceCraft.texture");
        CALayer *row_layer = texture_layer.sublayers.count > 0 ? texture_layer.sublayers[0] : nil;
        CALayer *image_layer = row_layer.sublayers.count > 0 ? row_layer.sublayers[0] : nil;
        CGImageRef tile = (CGImageRef)image_layer.contents;
        *tile_pixel_width = tile == NULL ? 0 : (int32_t)CGImageGetWidth(tile);
        *tile_pixel_height = tile == NULL ? 0 : (int32_t)CGImageGetHeight(tile);
        *texture_opacity = texture_layer == nil ? 0.0 : texture_layer.opacity;
        *contents_scale = image_layer == nil ? 0.0 : image_layer.contentsScale;
        *has_compositing_filter = image_layer.compositingFilter == nil ? 0 : 1;

        CGContextRef context = ap_spec_srgb_bitmap_context(pixels, output_width, output_height);
        if (context == NULL) {
            [view release];
            return 0;
        }
        CGContextTranslateCTM(context, 0, output_height);
        CGContextScaleCTM(context, backing_scale, -backing_scale);
        [view.layer renderInContext:context];
        CGContextFlush(context);
        CGContextRelease(context);
        [view release];

        *pixel_width = (int32_t)output_width;
        *pixel_height = (int32_t)output_height;
        return 1;
    }
}

int32_t ap_spec_rebake_noise_surface_on_scale_change(
    const char *json,
    double point_width,
    double point_height,
    double initial_scale,
    double new_scale,
    int32_t *initial_tile_width,
    int32_t *initial_tile_height,
    double *initial_contents_scale,
    int32_t *new_tile_width,
    int32_t *new_tile_height,
    double *new_contents_scale) {
    if (json == NULL || initial_tile_width == NULL || initial_tile_height == NULL ||
        initial_contents_scale == NULL || new_tile_width == NULL || new_tile_height == NULL ||
        new_contents_scale == NULL || initial_scale <= 0.0 || new_scale <= 0.0) return 0;

    @autoreleasepool {
        NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, point_width, point_height)];
        if (view == nil) return 0;
        view.wantsLayer = YES;
        view.layer.contentsScale = initial_scale;
        appkit_view_apply_surface_craft(view, json);

        CALayer *texture_layer = ap_spec_surface_layer_named(view.layer, @"ap.surfaceCraft.texture");
        CALayer *row_layer = texture_layer.sublayers.count > 0 ? texture_layer.sublayers[0] : nil;
        CALayer *image_layer = row_layer.sublayers.count > 0 ? row_layer.sublayers[0] : nil;
        CGImageRef initial_tile = (CGImageRef)image_layer.contents;
        *initial_tile_width = initial_tile == NULL ? 0 : (int32_t)CGImageGetWidth(initial_tile);
        *initial_tile_height = initial_tile == NULL ? 0 : (int32_t)CGImageGetHeight(initial_tile);
        *initial_contents_scale = image_layer == nil ? 0.0 : image_layer.contentsScale;

        view.layer.contentsScale = new_scale;
        [view viewDidChangeBackingProperties];

        texture_layer = ap_spec_surface_layer_named(view.layer, @"ap.surfaceCraft.texture");
        row_layer = texture_layer.sublayers.count > 0 ? texture_layer.sublayers[0] : nil;
        image_layer = row_layer.sublayers.count > 0 ? row_layer.sublayers[0] : nil;
        CGImageRef new_tile = (CGImageRef)image_layer.contents;
        *new_tile_width = new_tile == NULL ? 0 : (int32_t)CGImageGetWidth(new_tile);
        *new_tile_height = new_tile == NULL ? 0 : (int32_t)CGImageGetHeight(new_tile);
        *new_contents_scale = image_layer == nil ? 0.0 : image_layer.contentsScale;

        [view release];
        return 1;
    }
}

int32_t ap_spec_copy_png_rgba(
    const char *path,
    uint8_t *pixels,
    int32_t capacity,
    int32_t *pixel_width,
    int32_t *pixel_height) {
    if (path == NULL || pixels == NULL || pixel_width == NULL || pixel_height == NULL) return 0;

    @autoreleasepool {
        NSString *path_string = [NSString stringWithUTF8String:path];
        NSURL *url = [NSURL fileURLWithPath:path_string];
        CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
        if (source == NULL) return 0;
        CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CFRelease(source);
        if (image == NULL) return 0;

        size_t width = CGImageGetWidth(image);
        size_t height = CGImageGetHeight(image);
        if (width == 0 || height == 0 || width > INT32_MAX || height > INT32_MAX ||
            width * height > SIZE_MAX / 4 || (size_t)capacity < width * height * 4) {
            CGImageRelease(image);
            return 0;
        }

        CGContextRef context = ap_spec_srgb_bitmap_context(pixels, width, height);
        if (context == NULL) {
            CGImageRelease(image);
            return 0;
        }
        CGContextTranslateCTM(context, 0, height);
        CGContextScaleCTM(context, 1.0, -1.0);
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
        CGContextFlush(context);
        CGContextRelease(context);
        CGImageRelease(image);
        *pixel_width = (int32_t)width;
        *pixel_height = (int32_t)height;
        return 1;
    }
}

int ap_spec_capture_appkit_view(void *view_ptr) {
    if (view_ptr == NULL) return 0;

    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        NSView *view = (NSView *)view_ptr;
        NSRect frame = NSMakeRect(0, 0, 320, 220);
        [view setFrame:frame];

        // Parked far off every display and ordered in behind all other
        // windows: the capture draws through cacheDisplayInRect:, so the
        // window never needs to be key, frontmost, or visible.
        APSpecOffscreenCaptureWindow *window = [[APSpecOffscreenCaptureWindow alloc]
            initWithContentRect:NSMakeRect(-30000, -30000, NSWidth(frame), NSHeight(frame))
            styleMask:NSWindowStyleMaskBorderless
            backing:NSBackingStoreBuffered
            defer:NO];
        if (window == nil) return 0;
        [window setReleasedWhenClosed:NO];
        [window setContentView:view];
        [window orderBack:nil];

        [window layoutIfNeeded];
        [view layoutSubtreeIfNeeded];
        [window displayIfNeeded];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
        [view layoutSubtreeIfNeeded];
        [view displayIfNeeded];

        NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
        if (bitmap != nil) {
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
        }
        NSData *png = bitmap == nil ? nil : [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];

        [window orderOut:nil];
        [window close];
        [window release];
        return png.length > 0 ? 1 : 0;
    }
}

double ap_spec_appkit_view_layer_translation_y(void *view_ptr) {
    if (view_ptr == NULL) return 0;
    NSView *view = (NSView *)view_ptr;
    CALayer *root = view.layer;
    return root == nil ? 0 : root.transform.m42;
}

float ap_spec_appkit_view_layer_shadow_opacity(void *view_ptr) {
    if (view_ptr == NULL) return 0;
    NSView *view = (NSView *)view_ptr;
    CALayer *root = view.layer;
    return root == nil ? 0 : root.shadowOpacity;
}

// Returns 1 when the named drop-shadow layer carries its host's face as an
// opaque body: the same background color and corner radius as the root layer.
int32_t ap_spec_drop_shadow_layer_carries_face(void *view_ptr, const char *name) {
    if (view_ptr == NULL || name == NULL) return 0;
    NSView *view = (NSView *)view_ptr;
    CALayer *root = view.layer;
    if (root == nil || root.backgroundColor == NULL) return 0;
    CALayer *drop_layer = ap_spec_surface_layer_named(root, [NSString stringWithUTF8String:name]);
    if (drop_layer == nil || drop_layer.backgroundColor == NULL) return 0;
    if (!CGColorEqualToColor(drop_layer.backgroundColor, root.backgroundColor)) return 0;
    return drop_layer.cornerRadius == root.cornerRadius ? 1 : 0;
}

// Resizes *view* to *point_width* x *point_height*, runs its layout pass, and
// reports the bounding box of the named surface-craft layer's shadow path
// (a drop layer) or shape path (an inner layer). Returns 0 when the layer or
// its path is missing.
int32_t ap_spec_surface_path_size_after_layout(
    void *view_ptr,
    const char *name,
    double point_width,
    double point_height,
    double *path_width,
    double *path_height) {
    if (view_ptr == NULL || name == NULL || path_width == NULL || path_height == NULL) return 0;
    @autoreleasepool {
        NSView *view = (__bridge NSView *)view_ptr;
        [view setFrame:NSMakeRect(0, 0, point_width, point_height)];
        [view layout];
        NSString *target = [NSString stringWithUTF8String:name];
        for (CALayer *layer in [NSArray arrayWithArray:view.layer.sublayers]) {
            if (![layer.name isEqualToString:target]) continue;
            CGPathRef path = [layer isKindOfClass:[CAShapeLayer class]] ? ((CAShapeLayer *)layer).path : layer.shadowPath;
            if (path == NULL) return 0;
            CGRect box = CGPathGetBoundingBox(path);
            *path_width = CGRectGetWidth(box);
            *path_height = CGRectGetHeight(box);
            return 1;
        }
        return 0;
    }
}

// Sets *view*'s appearance to Dark Aqua (dark != 0) or Aqua, so surface-craft
// colors applied afterward resolve as they would in that appearance.
void ap_spec_set_view_dark_appearance(void *view_ptr, int32_t dark) {
    if (view_ptr == NULL) return;
    NSView *view = (NSView *)view_ptr;
    view.appearance = [NSAppearance appearanceNamed:(dark != 0 ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua)];
}

// Composites *layer* (which must have no superlayer) with Core Animation's own
// renderer into a *pixel_width* x *pixel_height* sRGB texture at 1x. Unlike
// renderInContext, this draws layer shadows, as the window server does for a
// live window. Returns a calloc'd RGBA buffer (rows top down, 4 bytes per
// pixel, straight from BGRA) the caller frees, or NULL when Metal or the
// renderer is unavailable.
static uint8_t *ap_spec_composite_layer_rgba(CALayer *layer, NSUInteger pixel_width, NSUInteger pixel_height) {
    if (layer == nil || layer.superlayer != nil || pixel_width == 0 || pixel_height == 0) return NULL;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) return NULL;
    id<MTLCommandQueue> queue = [device newCommandQueue];

    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                     width:pixel_width
                                    height:pixel_height
                                 mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    descriptor.storageMode = MTLStorageModeManaged;
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];

    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CARenderer *renderer = [CARenderer rendererWithMTLTexture:texture options:@{
        kCARendererColorSpace: (__bridge id)srgb,
        kCARendererMetalCommandQueue: queue,
    }];
    renderer.layer = layer;
    renderer.bounds = CGRectMake(0, 0, pixel_width, pixel_height);
    [CATransaction flush];
    [renderer beginFrameAtTime:CACurrentMediaTime() timeStamp:NULL];
    [renderer addUpdateRect:renderer.bounds];
    [renderer render];
    [renderer endFrame];

    id<MTLCommandBuffer> readback = [queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [readback blitCommandEncoder];
    [blit synchronizeResource:texture];
    [blit endEncoding];
    [readback commit];
    [readback waitUntilCompleted];
    renderer.layer = nil;
    CGColorSpaceRelease(srgb);

    NSUInteger bytes_per_row = pixel_width * 4;
    uint8_t *pixels = calloc(pixel_height, bytes_per_row);
    if (pixels != NULL) {
        [texture getBytes:pixels bytesPerRow:bytes_per_row
               fromRegion:MTLRegionMake2D(0, 0, pixel_width, pixel_height) mipmapLevel:0];
        for (NSUInteger offset = 0; offset < pixel_height * bytes_per_row; offset += 4) {
            uint8_t blue = pixels[offset];
            pixels[offset] = pixels[offset + 2];
            pixels[offset + 2] = blue;
        }
    }
    [texture release];
    [queue release];
    [device release];
    return pixels;
}

static void ap_spec_copy_rgba(const uint8_t *pixels, NSUInteger pixel_width, NSUInteger x, NSUInteger y, uint8_t *out_rgba) {
    const uint8_t *pixel = pixels + (y * pixel_width + x) * 4;
    memcpy(out_rgba, pixel, 4);
}

// The largest alpha outside the view's box, where only shadow can land.
static uint8_t ap_spec_largest_alpha_outside(
    const uint8_t *pixels, NSUInteger pixel_width, NSUInteger pixel_height,
    double margin, double point_width, double point_height) {
    NSUInteger inner_left = (NSUInteger)floor(margin);
    NSUInteger inner_top = (NSUInteger)floor(margin);
    NSUInteger inner_right = (NSUInteger)ceil(margin + point_width);
    NSUInteger inner_bottom = (NSUInteger)ceil(margin + point_height);
    uint8_t largest_alpha = 0;
    for (NSUInteger y = 0; y < pixel_height; y++) {
        for (NSUInteger x = 0; x < pixel_width; x++) {
            BOOL inside_view = x >= inner_left && x < inner_right && y >= inner_top && y < inner_bottom;
            if (inside_view) continue;
            uint8_t alpha = pixels[(y * pixel_width + x) * 4 + 3];
            if (alpha > largest_alpha) largest_alpha = alpha;
        }
    }
    return largest_alpha;
}

// Lays *view* out at *point_width* x *point_height* and composites its layer
// tree with Core Animation's own renderer into an sRGB texture at 1x, with
// *margin* points of clear space on every side. Unlike renderInContext, this
// draws layer shadows, as the window server does for a live window.
//
// Writes the RGBA of the pixel at the center of the view into *center_rgba*
// and the largest alpha found in the margin (where only shadow can land) into
// *largest_margin_alpha*. Returns 0 when Metal or the renderer is unavailable.
int32_t ap_spec_composite_view_with_shadows(
    void *view_ptr,
    double point_width,
    double point_height,
    double margin,
    uint8_t *center_rgba,
    uint8_t *largest_margin_alpha) {
    if (view_ptr == NULL || center_rgba == NULL || largest_margin_alpha == NULL) return 0;
    if (point_width < 1.0 || point_height < 1.0 || margin < 1.0) return 0;
    @autoreleasepool {
        NSView *view = (NSView *)view_ptr;
        [view setFrame:NSMakeRect(0, 0, point_width, point_height)];
        [view layout];
        CALayer *root = view.layer;
        if (root == nil || root.superlayer != nil) return 0;

        NSUInteger pixel_width = (NSUInteger)ceil(point_width + margin * 2.0);
        NSUInteger pixel_height = (NSUInteger)ceil(point_height + margin * 2.0);
        // A container gives the shadow room to land inside the texture.
        CALayer *container = [CALayer layer];
        container.frame = CGRectMake(0, 0, pixel_width, pixel_height);
        container.backgroundColor = NULL;
        CGRect original_frame = root.frame;
        [container addSublayer:root];
        root.frame = CGRectMake(margin, margin, point_width, point_height);
        uint8_t *pixels = ap_spec_composite_layer_rgba(container, pixel_width, pixel_height);
        [root removeFromSuperlayer];
        root.frame = original_frame;
        if (pixels == NULL) return 0;

        ap_spec_copy_rgba(pixels, pixel_width,
            (NSUInteger)(margin + point_width / 2.0), (NSUInteger)(margin + point_height / 2.0), center_rgba);
        *largest_margin_alpha = ap_spec_largest_alpha_outside(
            pixels, pixel_width, pixel_height, margin, point_width, point_height);
        free(pixels);
        return 1;
    }
}

// Hosts *view* in a real borderless NSWindow (never ordered in, so nothing
// reaches a screen) at *margin* points inside the window's layer-backed
// content view, pinned to *point_width* x *point_height*, and lets AppKit lay
// it out and display it exactly as it would in a live window. Then composites
// the content view's layer tree with Core Animation's renderer, which draws
// layer shadows as the window server does.
//
// Writes the center pixel of the view into *center_rgba*, the four corner
// pixels of the view's box (16 bytes) into *corner_rgba*, the largest alpha
// outside the box into *largest_margin_alpha*, and whether AppKit left the
// view's layer clipping its sublayers into *masks_to_bounds*. Returns 0 when
// Metal or the renderer is unavailable.
int32_t ap_spec_composite_window_hosted_view(
    void *view_ptr,
    double point_width,
    double point_height,
    double margin,
    int32_t dark,
    uint8_t *center_rgba,
    uint8_t *corner_rgba,
    uint8_t *largest_margin_alpha,
    int32_t *masks_to_bounds) {
    if (view_ptr == NULL || center_rgba == NULL || corner_rgba == NULL ||
        largest_margin_alpha == NULL || masks_to_bounds == NULL) return 0;
    if (point_width < 1.0 || point_height < 1.0 || margin < 1.0) return 0;
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];

        NSUInteger pixel_width = (NSUInteger)ceil(point_width + margin * 2.0);
        NSUInteger pixel_height = (NSUInteger)ceil(point_height + margin * 2.0);
        APSpecOffscreenCaptureWindow *window = [[APSpecOffscreenCaptureWindow alloc]
            initWithContentRect:NSMakeRect(-30000, -30000, pixel_width, pixel_height)
                      styleMask:NSWindowStyleMaskBorderless
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [window setReleasedWhenClosed:NO];
        window.appearance = [NSAppearance appearanceNamed:(dark != 0 ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua)];
        window.opaque = NO;
        window.backgroundColor = NSColor.clearColor;

        NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, pixel_width, pixel_height)];
        content.wantsLayer = YES;
        window.contentView = content;
        [content release];

        NSView *view = (NSView *)view_ptr;
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:view];
        [NSLayoutConstraint activateConstraints:@[
            [view.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:margin],
            [view.topAnchor constraintEqualToAnchor:content.topAnchor constant:margin],
            [view.widthAnchor constraintEqualToConstant:point_width],
            [view.heightAnchor constraintEqualToConstant:point_height],
        ]];
        for (int pass = 0; pass < 4; pass++) {
            [content layoutSubtreeIfNeeded];
            [window displayIfNeeded];
            [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode
                                  beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        [CATransaction flush];
        *masks_to_bounds = view.layer.masksToBounds ? 1 : 0;

        // Composite the content view's layer as the window hosts it: detach it
        // from the frame view's layer for the render only, then put it back.
        CALayer *content_layer = content.layer;
        CALayer *frame_layer = content_layer.superlayer;
        NSUInteger content_index = frame_layer != nil ? [frame_layer.sublayers indexOfObject:content_layer] : NSNotFound;
        CGRect content_frame = content_layer.frame;
        [content_layer retain];
        [content_layer removeFromSuperlayer];
        content_layer.frame = CGRectMake(0, 0, pixel_width, pixel_height);
        uint8_t *pixels = ap_spec_composite_layer_rgba(content_layer, pixel_width, pixel_height);
        content_layer.frame = content_frame;
        if (frame_layer != nil && content_index != NSNotFound) {
            [frame_layer insertSublayer:content_layer atIndex:(unsigned)content_index];
        }
        [content_layer release];

        [view removeFromSuperview];
        [window close];
        [window release];
        if (pixels == NULL) return 0;

        NSUInteger left = (NSUInteger)floor(margin);
        NSUInteger top = (NSUInteger)floor(margin);
        NSUInteger right = (NSUInteger)ceil(margin + point_width) - 1;
        NSUInteger bottom = (NSUInteger)ceil(margin + point_height) - 1;
        ap_spec_copy_rgba(pixels, pixel_width,
            (NSUInteger)(margin + point_width / 2.0), (NSUInteger)(margin + point_height / 2.0), center_rgba);
        ap_spec_copy_rgba(pixels, pixel_width, left, top, corner_rgba);
        ap_spec_copy_rgba(pixels, pixel_width, right, top, corner_rgba + 4);
        ap_spec_copy_rgba(pixels, pixel_width, left, bottom, corner_rgba + 8);
        ap_spec_copy_rgba(pixels, pixel_width, right, bottom, corner_rgba + 12);
        *largest_margin_alpha = ap_spec_largest_alpha_outside(
            pixels, pixel_width, pixel_height, margin, point_width, point_height);
        free(pixels);
        return 1;
    }
}

// Returns 1 when *view* clips its subviews and its layer clips its sublayers.
int32_t ap_spec_view_clips_to_bounds(void *view_ptr) {
    if (view_ptr == NULL) return 0;
    NSView *view = (NSView *)view_ptr;
    return view.clipsToBounds && view.layer.masksToBounds ? 1 : 0;
}
