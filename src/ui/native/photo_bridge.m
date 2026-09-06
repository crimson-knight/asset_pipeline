// photo_bridge.m — portable "give me a photo as JPEG bytes" bridge for iOS.
//
// WHY THIS FILE EXISTS (separate from asset_pipeline's objc_bridge.m)
//   objc_bridge.m is a VIEW bridge: every function there builds or mutates a
//   UIView/NSView. Photo acquisition is not a view — it is a modal capability
//   with an asynchronous result, so it lives in its own translation unit that
//   imports only Foundation + UIKit + PhotosUI. That keeps it linkable from any
//   Apple target that has a UI (iOS today; catalyst/macOS with an #if later) and
//   keeps objc_bridge.m free of a Photos dependency.
//
//   This is a candidate for upstream adoption into
//   lib/asset_pipeline/src/ui/native/ — the API below is deliberately generic
//   (no QuiltPerfect, no happy_coach, no demo vocabulary). A mirror copy lives
//   at open_source_coding_projects/asset_pipeline/src/ui/native/photo_bridge.m.
//
// THE CONTRACT — a POLLED handoff, not a callback into Crystal.
//   Crystal's iOS host runs -Dwithout_mt: the main fiber IS the OS main thread
//   and it is parked inside UIApplicationMain forever, so a Crystal `fun`
//   invoked from an ObjC completion block would be re-entering a runtime that
//   has no scheduler turn to give it. Every other async surface in this app
//   (the demo boot fetch) therefore uses the host's 1 Hz tick as its one
//   guaranteed main-thread entry point. This bridge matches that shape:
//
//     ap_photo_pick_begin()  -> presents the picker, returns immediately
//     ap_photo_pick_state()  -> polled from the host tick
//     ap_photo_pick_copy_bytes() -> transfers the JPEG once state == READY
//     ap_photo_pick_reset()  -> frees the buffer, returns to IDLE
//
//   No Crystal symbol is referenced from this file, so it links into any host.
//
// IMAGE NORMALISATION
//   Whatever the library hands back (HEIC, PNG, a 12 MP JPEG, a screenshot) is
//   decoded to a UIImage, redrawn upright at <= max_dimension on its long edge,
//   and re-encoded as JPEG at the requested quality. Callers therefore always
//   receive `image/jpeg` of a predictable size — the server never has to know
//   HEIC exists, and a 4 MB phone photo becomes a ~300 KB upload.
//
// Compile (iOS simulator):
//   clang -c photo_bridge.m -o photo_bridge_ios.o \
//     -target arm64-apple-ios-simulator -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path) \
//     -mios-version-min=17.0 -fno-objc-arc
//   Link: -framework UIKit -framework PhotosUI -framework Photos
//
// MEMORY: built -fno-objc-arc (matches objc_bridge.m). Retains are explicit.

#include <stdlib.h>
#include <string.h>
#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#endif

// ---------------------------------------------------------------------------
// Public C ABI (also declared on the Crystal side in src/demo/photo_picker.cr)
// ---------------------------------------------------------------------------
//
//   source: 0 = photo library (PHPickerViewController)
//           1 = camera        (UIImagePickerController)
//
//   state:  0 = IDLE      nothing in flight
//           1 = ACTIVE    picker on screen, user deciding
//           2 = READY     a JPEG is waiting in the buffer
//           3 = CANCELLED user dismissed without choosing
//           4 = ERROR     see ap_photo_pick_error()

#define AP_PHOTO_SOURCE_LIBRARY 0
#define AP_PHOTO_SOURCE_CAMERA  1

#define AP_PHOTO_STATE_IDLE      0
#define AP_PHOTO_STATE_ACTIVE    1
#define AP_PHOTO_STATE_READY     2
#define AP_PHOTO_STATE_CANCELLED 3
#define AP_PHOTO_STATE_ERROR     4

int         ap_photo_source_available(int source);
int         ap_photo_pick_begin(int source, int max_dimension, double jpeg_quality);
int         ap_photo_pick_state(void);
long long   ap_photo_pick_byte_count(void);
long long   ap_photo_pick_copy_bytes(void *dst, long long capacity);
const char *ap_photo_pick_error(void);
void        ap_photo_pick_reset(void);

// ---------------------------------------------------------------------------
// Shared state. Written on the main thread only (every mutation is either
// called from Crystal's main-thread tick or hopped onto the main queue), so the
// polled reads Crystal performs from that same thread need no lock.
// ---------------------------------------------------------------------------

static int       g_state    = AP_PHOTO_STATE_IDLE;
static void     *g_bytes    = NULL;
static long long g_len      = 0;
static char      g_error[256];
static int       g_max_dim  = 2000;
static double    g_quality  = 0.8;

static void ap_photo_set_error(NSString *message) {
    const char *utf8 = message ? [message UTF8String] : "unknown photo error";
    strncpy(g_error, utf8 ? utf8 : "unknown photo error", sizeof(g_error) - 1);
    g_error[sizeof(g_error) - 1] = '\0';
    g_state = AP_PHOTO_STATE_ERROR;
}

static void ap_photo_free_buffer(void) {
    if (g_bytes) { free(g_bytes); g_bytes = NULL; }
    g_len = 0;
}

#if TARGET_OS_IPHONE

// ---------------------------------------------------------------------------
// Presentation host: the top-most presented view controller of the key window.
// A modal presented on an already-presenting controller is a silent no-op in
// UIKit, so walking the chain is not optional.
// ---------------------------------------------------------------------------
static UIViewController *ap_photo_top_view_controller(void) {
    UIWindow *key = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) { key = window; break; }
        }
        if (key) break;
    }
    if (!key) {
        // Fall back to any window with a root VC (covers a scene that has not
        // reported active yet during a cold launch).
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.rootViewController) { key = window; break; }
            }
            if (key) break;
        }
    }
    UIViewController *vc = key.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

// Redraw upright at <= max_dimension on the long edge, then JPEG-encode.
// UIGraphicsImageRenderer bakes in the EXIF orientation, so the server never
// receives a sideways sewing machine.
static NSData *ap_photo_normalized_jpeg(UIImage *image, int max_dimension, double quality) {
    if (!image) return nil;

    CGSize size = image.size;
    if (size.width <= 0 || size.height <= 0) return nil;

    CGFloat longest = MAX(size.width, size.height);
    CGFloat scale = (max_dimension > 0 && longest > (CGFloat)max_dimension)
                      ? ((CGFloat)max_dimension / longest)
                      : 1.0;
    CGSize target = CGSizeMake(floor(size.width * scale), floor(size.height * scale));
    if (target.width < 1 || target.height < 1) return nil;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    // scale 1.0: `target` is in PIXELS, not points — a 3x device would otherwise
    // produce a 6000px bitmap from a 2000pt request.
    format.scale = 1.0;
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer =
        [[[UIGraphicsImageRenderer alloc] initWithSize:target format:format] autorelease];
    UIImage *flat = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        (void)ctx;
        [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    }];
    if (!flat) return nil;

    CGFloat q = (CGFloat)((quality > 0.0 && quality <= 1.0) ? quality : 0.8);
    return UIImageJPEGRepresentation(flat, q);
}

// Runs on the main thread. Takes ownership of nothing; copies the JPEG into a
// malloc buffer Crystal will drain via ap_photo_pick_copy_bytes.
static void ap_photo_publish_image(UIImage *image) {
    NSData *jpeg = ap_photo_normalized_jpeg(image, g_max_dim, g_quality);
    if (!jpeg || jpeg.length == 0) {
        ap_photo_set_error(@"could not read that photo");
        return;
    }
    ap_photo_free_buffer();
    g_bytes = malloc((size_t)jpeg.length);
    if (!g_bytes) {
        ap_photo_set_error(@"out of memory encoding the photo");
        return;
    }
    memcpy(g_bytes, jpeg.bytes, (size_t)jpeg.length);
    g_len = (long long)jpeg.length;
    g_state = AP_PHOTO_STATE_READY;
}

// ---------------------------------------------------------------------------
// Delegate — one long-lived instance, reused across picks.
// ---------------------------------------------------------------------------
@interface APPhotoPickerDelegate : NSObject <PHPickerViewControllerDelegate,
                                             UIImagePickerControllerDelegate,
                                             UINavigationControllerDelegate>
@end

@implementation APPhotoPickerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];

    if (results.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{ g_state = AP_PHOTO_STATE_CANCELLED; });
        return;
    }

    NSItemProvider *provider = results.firstObject.itemProvider;
    if (![provider canLoadObjectOfClass:[UIImage class]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ap_photo_set_error(@"that item is not a photo");
        });
        return;
    }

    // loadObjectOfClass: completes on an ARBITRARY queue — hop to main before
    // touching g_* so the polled reads stay single-threaded.
    [provider loadObjectOfClass:[UIImage class] completionHandler:^(id object, NSError *error) {
        UIImage *image = [object isKindOfClass:[UIImage class]] ? [[(UIImage *)object retain] autorelease] : nil;
        NSString *message = error ? [error localizedDescription] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image) {
                ap_photo_set_error(message ?: @"could not load that photo");
            } else {
                ap_photo_publish_image(image);
            }
        });
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    UIImage *retained = image ? [[image retain] autorelease] : nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!retained) {
            ap_photo_set_error(@"the camera returned no image");
        } else {
            ap_photo_publish_image(retained);
        }
    });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
    dispatch_async(dispatch_get_main_queue(), ^{ g_state = AP_PHOTO_STATE_CANCELLED; });
}

@end

static APPhotoPickerDelegate *g_delegate = nil;

#endif // TARGET_OS_IPHONE

// ---------------------------------------------------------------------------
// C ABI
// ---------------------------------------------------------------------------

int ap_photo_source_available(int source) {
#if TARGET_OS_IPHONE
    if (source == AP_PHOTO_SOURCE_CAMERA) {
        // NO on every simulator — the caller uses this to hide "Take a photo".
        return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] ? 1 : 0;
    }
    return 1; // PHPicker is always available on iOS 14+ (deployment target is 17).
#else
    (void)source;
    return 0;
#endif
}

int ap_photo_pick_begin(int source, int max_dimension, double jpeg_quality) {
#if TARGET_OS_IPHONE
    if (g_state == AP_PHOTO_STATE_ACTIVE) return 0; // already on screen

    ap_photo_free_buffer();
    g_error[0] = '\0';
    g_max_dim = max_dimension > 0 ? max_dimension : 2000;
    g_quality = (jpeg_quality > 0.0 && jpeg_quality <= 1.0) ? jpeg_quality : 0.8;
    g_state = AP_PHOTO_STATE_ACTIVE;

    if (!g_delegate) g_delegate = [[APPhotoPickerDelegate alloc] init];

    // Present on the NEXT main-queue turn. The caller is a Crystal button
    // callback whose return triggers a re-render + a host view swap; presenting
    // synchronously would modally cover a view controller that is about to have
    // its hosted subview replaced underneath it.
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *host = ap_photo_top_view_controller();
        if (!host) {
            ap_photo_set_error(@"no window to present from");
            return;
        }

        if (source == AP_PHOTO_SOURCE_CAMERA) {
            if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                ap_photo_set_error(@"this device has no camera");
                return;
            }
            UIImagePickerController *cam = [[[UIImagePickerController alloc] init] autorelease];
            cam.sourceType = UIImagePickerControllerSourceTypeCamera;
            cam.delegate = g_delegate;
            cam.allowsEditing = NO;
            [host presentViewController:cam animated:YES completion:nil];
            return;
        }

        // PHPicker runs OUT OF PROCESS: the app never gains photo-library
        // access, so no PHPhotoLibrary authorization prompt is shown and none
        // is required. (NSPhotoLibraryUsageDescription is still declared for
        // the day a caller wants in-process access.)
        PHPickerConfiguration *config = [[[PHPickerConfiguration alloc] init] autorelease];
        config.selectionLimit = 1;
        config.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker =
            [[[PHPickerViewController alloc] initWithConfiguration:config] autorelease];
        picker.delegate = g_delegate;
        [host presentViewController:picker animated:YES completion:nil];
    });
    return 1;
#else
    (void)source; (void)max_dimension; (void)jpeg_quality;
    ap_photo_set_error(@"photo picking is iOS-only");
    return 0;
#endif
}

int ap_photo_pick_state(void) {
    return g_state;
}

long long ap_photo_pick_byte_count(void) {
    return g_len;
}

// Copy at most `capacity` bytes into `dst`; returns the number copied (0 on a
// short buffer, so a caller that sized from ap_photo_pick_byte_count always
// succeeds). The internal buffer stays valid until ap_photo_pick_reset().
long long ap_photo_pick_copy_bytes(void *dst, long long capacity) {
    if (!dst || !g_bytes || g_len <= 0 || capacity < g_len) return 0;
    memcpy(dst, g_bytes, (size_t)g_len);
    return g_len;
}

const char *ap_photo_pick_error(void) {
    return g_error;
}

void ap_photo_pick_reset(void) {
    ap_photo_free_buffer();
    g_error[0] = '\0';
    g_state = AP_PHOTO_STATE_IDLE;
}
