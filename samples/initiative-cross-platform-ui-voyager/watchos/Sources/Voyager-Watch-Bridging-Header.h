// Bridging header for the Voyager watch app.
//
// Exposes the Crystal watch bridge entry point to Swift. `voyager_watch_render`
// is implemented in watchos/bridge.cr (compiled into build/libvoyagerwatch.a):
// it initializes the Crystal runtime, builds a UI::View tree, walks it with
// UI::WatchKit::Renderer, and returns the root APSKWatchHostView* (a +1-retained
// NSObject whose `.content` is the composed SwiftUI body).
//
// Swift calls it, takes the retained box via Unmanaged, and embeds `.content` —
// see ContentView.crystalRendered. This is the on-device proof that a
// Crystal-authored screen renders on watchOS through the same SwiftKit facade
// catalog the other platforms use.
#ifndef VOYAGER_WATCH_BRIDGING_HEADER_H
#define VOYAGER_WATCH_BRIDGING_HEADER_H

void *voyager_watch_render(void);

#endif /* VOYAGER_WATCH_BRIDGING_HEADER_H */
