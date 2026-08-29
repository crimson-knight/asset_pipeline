import SwiftUI

// The Voyager watch app. The ENTIRE screen is authored in Crystal and rendered by
// UI::WatchKit::Renderer: voyager_watch_render() bootstraps the shared Voyager host,
// builds the registered Voyager::AgentChatScreen from the shared State + dispatcher,
// walks it into SwiftKit facade boxes, and returns the root APSKWatchHostView. The
// same Crystal UI::Screen renders on macOS and iOS — no per-platform fork.
//
// REACTIVE: Crystal calls back through voyager_watch_register_rerender whenever the
// dispatcher republishes after an action (tapping Send appends to the transcript and
// returns Rerender → republish → on_change → this callback). We re-render and publish
// the new box so SwiftUI re-embeds it — the agent-chat surface updates live.
//
// IMPORTANT: voyager_watch_render() has side effects (it runs the Crystal renderer and
// returns a +1-retained object). It must be called from an explicit action — NEVER
// inside a SwiftUI body evaluation, which re-runs during the observation-graph update
// and crashes (EXC_BAD_ACCESS in ObservationCenter/autorelease). So we render in
// `renderNow()` and the body only READS the published box.

/// Owns the current Crystal-rendered box and bridges the re-render callback into SwiftUI.
final class CrystalBridge: ObservableObject {
    static let shared = CrystalBridge()
    @Published var box: APSKWatchHostView?

    /// Run the Crystal renderer and publish the new root box. Call only from an
    /// explicit action (onAppear / the re-render callback), never from a view body.
    func renderNow() {
        guard let raw = voyager_watch_render() else { box = nil; return }
        // Crystal pins every tree forever (bridge @@roots) and NEVER releases a box, so
        // Swift owns the display copy outright via takeRetainedValue and frees it on the
        // next reassign — no double-free, since Crystal isn't a second releaser.
        box = Unmanaged<APSKWatchHostView>.fromOpaque(raw).takeRetainedValue()
    }
}

// C-callable re-render callback (no captures → usable as a C function pointer). Hops to
// the main queue so the render happens after Crystal's dispatch returns (no re-entrancy
// back into Crystal mid-dispatch).
private func crystalRerenderCallback() {
    DispatchQueue.main.async { CrystalBridge.shared.renderNow() }
}

struct ContentView: View {
    @ObservedObject private var bridge = CrystalBridge.shared

    var body: some View {
        // ScrollView so the height-constrained watch gives the root VStack unbounded
        // height — multi-line labels wrap fully and tall content scrolls.
        ScrollView {
            if let box = bridge.box {
                box.content
            } else {
                Text("Loading…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            voyager_watch_register_rerender(crystalRerenderCallback)
            bridge.renderNow()
            maybeAutoSend()
            maybeAutoNav()
            maybeAutoNotif()
            maybeAutoSpeak()
            maybeAutoFgSpeak()
            maybeAutoVoiceGate()
            maybeAutoPrefs()
            maybeAutoRate()
        }
    }

    // Verification hook for the Settings Voice-speed slider: with
    // VOYAGER_WATCH_TEST_RATE=1 (root at :voyager-settings), drive set_speech_rate
    // + preview through the real controller, then log the resulting rate percent
    // (expect 65) and whether the preview is speaking. No-op in normal use.
    private func maybeAutoRate() {
        guard ProcessInfo.processInfo.environment["VOYAGER_WATCH_TEST_RATE"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let pct = voyager_watch_test_rate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NSLog("VOYAGER_RATE_RESULT pct=\(pct) speaking=\(voyager_watch_speaking())")
            }
        }
    }

    // Verification hook for UI::Preferences persistence: with VOYAGER_WATCH_TEST_PREFS=1,
    // log a counter that increments and is stored each launch. Launch repeatedly: the
    // value grows (0, 1, 2…) only if NSUserDefaults persisted across launches on the
    // wrist. No-op in normal use.
    private func maybeAutoPrefs() {
        guard ProcessInfo.processInfo.environment["VOYAGER_WATCH_TEST_PREFS"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSLog("VOYAGER_PREFS_RESULT counter=\(voyager_watch_test_prefs_counter())")
        }
    }

    // Verification hook for the header mute toggle: with VOYAGER_WATCH_TEST_GATE=1,
    // drive a real agent reply MUTED (expect not speaking) then UNMUTED (expect
    // speaking), each checked after a beat (speech is async). Proves the toggle
    // genuinely gates UI::Speech via the real controller path. No-op in normal use.
    private func maybeAutoVoiceGate() {
        guard ProcessInfo.processInfo.environment["VOYAGER_WATCH_TEST_GATE"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            voyager_watch_test_voice_gate(1) // muted
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                NSLog("VOYAGER_GATE_RESULT muted_speaking=\(voyager_watch_speaking())")
                voyager_watch_test_voice_gate(0) // unmuted
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    NSLog("VOYAGER_GATE_RESULT unmuted_speaking=\(voyager_watch_speaking())")
                }
            }
        }
    }

    // Verification hook for the COHESION loop: with VOYAGER_WATCH_TEST_FG=1,
    // schedule a 3s notification; when it's delivered to the foregrounded app the
    // native delegate → Crystal on_foreground handler speaks it. Log whether the
    // synthesizer is speaking after delivery — proof that "agent buzzes + reads it
    // aloud" works on the wrist. No-op in normal use.
    private func maybeAutoFgSpeak() {
        guard ProcessInfo.processInfo.environment["VOYAGER_WATCH_TEST_FG"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            voyager_watch_test_fg_speak() // schedules a 3s notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                NSLog("VOYAGER_FG_SPEAK_RESULT speaking=\(voyager_watch_speaking())")
            }
        }
    }

    // Verification hook: with VOYAGER_WATCH_TEST_SPEAK=1, speak a phrase via
    // UI::Speech (AVSpeechSynthesizer) and, after a beat (speech starts async),
    // log whether the synthesizer is actually speaking — the honest runtime proof
    // that TTS works on the wrist. No-op in normal use.
    private func maybeAutoSpeak() {
        guard ProcessInfo.processInfo.environment["VOYAGER_WATCH_TEST_SPEAK"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            voyager_watch_test_speak()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NSLog("VOYAGER_SPEAK_RESULT speaking=\(voyager_watch_speaking())")
            }
        }
    }

    // Verification hook: launched at :voyager-check-in with
    // VOYAGER_WATCH_TEST_NOTIF=1, drives a real Save (dispatch :save_checkin →
    // schedule a real recurring local notification via UI::Notifications on the
    // wrist) and logs the system's actual pending count. Proves the watch
    // genuinely scheduled a notification (UNUserNotificationCenter pending queue),
    // covering the watch's lack of XCUITest with a machine-checkable outcome.
    private func maybeAutoNotif() {
        guard ProcessInfo.processInfo.environment["VOYAGER_WATCH_TEST_NOTIF"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let pending = voyager_watch_test_notif()
            NSLog("VOYAGER_NOTIF_RESULT pending=\(pending)")
        }
    }

    // Verification hook: launched at :settings with VOYAGER_WATCH_TEST_NAV=1, drives a real
    // navigation (dispatch :open_check_in → Navigate(:check_in)) a couple seconds after
    // launch to prove the watch is a navigable multi-screen app — the new screen renders via
    // the Crystal→Swift re-render callback. No-op in normal use.
    private func maybeAutoNav() {
        guard ProcessInfo.processInfo.environment["VOYAGER_WATCH_TEST_NAV"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            voyager_watch_test_nav()
        }
    }

    // Verification hook: when launched with VOYAGER_WATCH_AUTOSEND=1, drive a Send
    // through the real dispatch path a couple seconds after launch to prove the
    // reactive loop end-to-end (the title's message count ticks up via the
    // Crystal→Swift re-render callback). No-op in normal use.
    private func maybeAutoSend() {
        guard ProcessInfo.processInfo.environment["VOYAGER_WATCH_AUTOSEND"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            voyager_watch_test_send("On my way!")
        }
    }
}
