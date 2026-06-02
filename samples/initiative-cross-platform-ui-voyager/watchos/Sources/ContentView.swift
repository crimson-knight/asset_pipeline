import SwiftUI

// ContentView — the Voyager watch app's purpose surface: an AGENT CHAT on the wrist
// (chat notifications + a compose row to reply). It is composed entirely from
// asset_pipeline SwiftKit facades — Label (message text + title), Card (the message
// bubble chrome), TextField (the compose field), IconButton (send) — by embedding
// each facade's `APSKWatchHostView.content` (the SwiftUI body the Crystal renderer
// would compose) into a SwiftUI watch layout. This drives the facades from Swift so
// the surface renders on a real watch while the Crystal UI::WatchKit::Renderer is
// blocked on the toolchain fix.
//
// actionToken 0 throughout: with no Crystal callback registry, CallbackBridge.fire
// is a no-op — fine for a render demo.
struct ContentView: View {
    // (text, isAgent) — agent messages hug the leading edge, the user's reply trails.
    // Kept short so the title, a bubble exchange, AND the compose row all fit one
    // watch screen for the render proof.
    private let messages: [(String, Bool)] = [
        ("Meeting moved to 10:00.", true),
        ("Remind me at 9:45", false),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                facade(LabelFacade.makeLabel(text: "Agent", overrides: titleOverrides()))

                ForEach(messages.indices, id: \.self) { i in
                    let msg = messages[i]
                    HStack(spacing: 0) {
                        if !msg.1 { Spacer(minLength: 28) }
                        bubble(msg.0)
                        if msg.1 { Spacer(minLength: 28) }
                    }
                }

                composeRow()
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

    // The compose row: a TextField facade + a paperplane IconButton facade.
    private func composeRow() -> some View {
        let field = TextFieldFacade.makeTextField(
            placeholder: "Message…", initialText: "",
            overrides: TextFieldOverrides(), actionToken: 0)
        let send = IconButtonFacade.makeIconButton(
            icon: "paperplane.fill",
            overrides: IconButtonOverrides(), actionToken: 0)
        return HStack(spacing: 6) {
            facade(field)
            facade(send)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func facade(_ box: APSKWatchHostView) -> some View {
        box.content
    }

    private func titleOverrides() -> LabelOverrides {
        let o = LabelOverrides()
        o.fontSize = NSNumber(value: 20.0)
        o.fontWeight = NSNumber(value: 700)
        return o
    }
}
