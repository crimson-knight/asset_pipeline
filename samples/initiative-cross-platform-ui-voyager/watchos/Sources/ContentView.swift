import SwiftUI

// ContentView — the Voyager watch app's purpose surface: an AGENT CHAT on the wrist.
//
// The transcript BUBBLES are rendered by asset_pipeline SwiftKit facades (Label +
// Card), embedding each facade's `APSKWatchHostView.content` — the same SwiftUI the
// Crystal renderer would compose. The transcript matches the iOS/macOS seed so the
// design is cohesive across all three platforms.
//
// App LOGIC (the @State transcript + Send) is plain SwiftUI: on watchOS the kit's
// FormState input path runs through the Crystal UI::WatchKit::Renderer, which is
// blocked on the compiler fix — so until then the watch app wires its own input with
// SwiftUI @State (as any watch app would), while still rendering the kit's facades.
// Honest split: facades render the UI; the app owns its state.
struct ContentView: View {
    // (text, isAgent). Seeded to match the iOS/macOS agent-chat transcript.
    @State private var messages: [(String, Bool)] = [
        ("Morning! Your first meeting moved to 10:00.", true),
        ("Thanks — remind me at 9:45", false),
        ("Done. I'll buzz your wrist at 9:45.", true),
    ]
    @State private var draft: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // === Rendered by Crystal ===
                // This block is composed entirely by the Crystal UI::WatchKit::Renderer:
                // watchos/bridge.cr builds a UI::View tree, the renderer walks it into
                // SwiftKit facade boxes, and returns the root APSKWatchHostView whose
                // `.content` we embed here. No Swift authored this subtree's layout —
                // Crystal did. This is the on-device proof of a Crystal-authored watch
                // screen (brick 4b). The agent-chat surface below is the Swift-driven
                // app shell that hosts it.
                crystalRendered

                Divider()

                facade(LabelFacade.makeLabel(text: "Agent", overrides: titleOverrides()))

                ForEach(messages.indices, id: \.self) { i in
                    let msg = messages[i]
                    HStack(spacing: 0) {
                        if !msg.1 { Spacer(minLength: 28) }
                        bubble(msg.0)
                        if msg.1 { Spacer(minLength: 28) }
                    }
                }

                composeRow
            }
            .padding(8)
        }
    }

    // A message bubble: a Card facade wrapping a Label facade.
    private func bubble(_ text: String) -> some View {
        let label = LabelFacade.makeLabel(text: text, overrides: LabelOverrides())
        let card = CardFacade.makeCard(childViews: [label], overrides: CardOverrides())
        return facade(card)
    }

    // Compose row — the app's own SwiftUI input + Send (see file header on why this
    // is native, not facade-driven, on watch). Send appends the typed reply plus a
    // canned agent acknowledgement, mirroring the iOS/macOS controller behaviour.
    private var composeRow: some View {
        HStack(spacing: 6) {
            TextField("Message…", text: $draft)
                .textFieldStyle(.plain)
            Button(action: send) {
                Image(systemName: "paperplane.fill")
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("voyager-agent-chat-send")
        }
        .padding(.top, 4)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messages.append((text, false))
        messages.append(("On it — I'll take care of that.", true))
        draft = ""
    }

    @ViewBuilder
    private func facade(_ box: APSKWatchHostView) -> some View {
        box.content
    }

    // The Crystal-authored subtree. `voyager_watch_render()` (bridge.cr) returns a
    // +1-retained APSKWatchHostView*; take it via Unmanaged and embed its content.
    // Computed once and cached so the bridge runs a single time per view lifetime.
    @ViewBuilder
    private var crystalRendered: some View {
        if let box = Self.crystalBox {
            box.content
        } else {
            Text("Crystal render unavailable")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static let crystalBox: APSKWatchHostView? = {
        guard let raw = voyager_watch_render() else { return nil }
        return Unmanaged<APSKWatchHostView>.fromOpaque(raw).takeRetainedValue()
    }()

    private func titleOverrides() -> LabelOverrides {
        let o = LabelOverrides()
        o.fontSize = NSNumber(value: 20.0)
        o.fontWeight = NSNumber(value: 700)
        return o
    }
}
