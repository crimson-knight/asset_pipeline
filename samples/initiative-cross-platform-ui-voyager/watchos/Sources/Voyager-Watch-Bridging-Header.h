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

// Drive a real Save on the Daily Check-in (dispatch :save_checkin → schedule a
// real recurring local notification via UI::Notifications). Returns the system's
// actual pending-notification count — an honest functional outcome for the watch
// (which has no XCUITest). Bootstrap at :voyager-check-in.
int voyager_watch_test_notif(void);

// Speak a phrase via UI::Speech (AVSpeechSynthesizer) on the wrist, and query
// whether the synthesizer is actively speaking — the honest runtime proof that
// text-to-speech works on watchOS. Speech is async: call _test_speak, then check
// _speaking after a short delay.
void voyager_watch_test_speak(void);
int voyager_watch_speaking(void);

// The cohesion loop: schedule a short local notification; when it fires while the
// app is foregrounded, the native delegate → Crystal on_foreground handler →
// UI::Speech reads it aloud. Check voyager_watch_speaking() a few seconds later.
void voyager_watch_test_fg_speak(void);

// Drive a real agent reply through the controller with the voice mute pref set
// (muted=1 → agent should NOT speak; muted=0 → it should). Check voyager_watch_speaking()
// after a beat to prove the header mute toggle gates speech.
void voyager_watch_test_voice_gate(int muted);

// Persistence proof: returns a counter (read-before-increment) stored in
// UI::Preferences. Across relaunches the value grows, proving NSUserDefaults
// persisted across launches on the watch.
int voyager_watch_test_prefs_counter(void);

#endif /* VOYAGER_WATCH_BRIDGING_HEADER_H */
