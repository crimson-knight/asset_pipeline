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

// Register a Swift callback Crystal invokes whenever the dispatcher republishes after
// an action (Rerender/Pop/…). Swift bumps its render token to re-call voyager_watch_render.
void voyager_watch_register_rerender(void (*cb)(void));

// Drive a Send through the real dispatch path (seed the compose field + dispatch
// :send_message). Exercises the reactive loop end-to-end for verification.
void voyager_watch_test_send(const char *text);

// Drive a real navigation (dispatch :open_check_in → Navigate(:check_in)). Used to verify
// the watch is a navigable multi-screen app (the push/mount_screen path). Bootstrap at
// :settings, then this navigates to the check-in screen.
void voyager_watch_test_nav(void);

#endif /* VOYAGER_WATCH_BRIDGING_HEADER_H */
