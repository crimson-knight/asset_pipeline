import SwiftUI

// ContentView — the Voyager watch app. The ENTIRE screen is authored in Crystal and
// rendered by UI::WatchKit::Renderer: `voyager_watch_render()` (watchos/bridge.cr)
// bootstraps the shared Voyager host substrate, builds the registered
// Voyager::AgentChatScreen from the shared State + dispatcher, walks it into SwiftKit
// facade boxes, and returns the root APSKWatchHostView. We take the +1-retained box
// via Unmanaged and embed its `.content`.
//
// This is the cohesion proof: the SAME Crystal `UI::Screen` that renders on macOS and
// iOS renders here on the wrist — no Swift-authored layout, no per-platform fork. The
// screen reflows to the watch because the WatchKit renderer installs a watch-class
// DeviceMetrics provider and the screen clamps its content width to the device.
struct ContentView: View {
    var body: some View {
        crystalScreen
    }

    @ViewBuilder
    private var crystalScreen: some View {
        if let box = Self.crystalBox {
            box.content
        } else {
            Text("Crystal render unavailable")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // Render once and cache so the bridge runs a single time per view lifetime.
    private static let crystalBox: APSKWatchHostView? = {
        guard let raw = voyager_watch_render() else { return nil }
        return Unmanaged<APSKWatchHostView>.fromOpaque(raw).takeRetainedValue()
    }()
}
