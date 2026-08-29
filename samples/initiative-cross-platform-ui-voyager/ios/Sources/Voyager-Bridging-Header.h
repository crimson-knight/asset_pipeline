// Voyager-Bridging-Header.h
// Exposes the Voyager Crystal C-ABI surface to Swift.
// See: samples/initiative-cross-platform-ui-voyager/ios/bridge.cr for implementations.

#ifndef Voyager_Bridging_Header_h
#define Voyager_Bridging_Header_h

#import <UIKit/UIKit.h>

void voyager_init(void);
void* voyager_render(const char* slug);
const char* voyager_current_slug(void);
// cb receives (slug, kind): kind 0 = navigation, 1 = same-route rerender.
void voyager_register_route_changed_callback(void (*cb)(const char*, int));
// Attempt an in-place reconcile for a same-route rerender. Returns 1 if
// applied (host should NOT teardown), 0 to fall back to a full render.
int voyager_reconcile(const char* slug);

#endif
