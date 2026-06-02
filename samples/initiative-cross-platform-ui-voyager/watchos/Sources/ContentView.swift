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
