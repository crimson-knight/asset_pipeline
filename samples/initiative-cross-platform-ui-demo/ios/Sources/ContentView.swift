import SwiftUI
import UIKit

struct ContentView: View {
    let slug: String

    var body: some View {
        CascadeHost(slug: slug)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier("cascade-root-host")
    }
}

/// Bridges a Crystal-produced UIView into the SwiftUI tree.
struct CascadeHost: UIViewRepresentable {
    let slug: String

    func makeUIView(context: Context) -> UIView {
        if let view = CascadeBridge.render(slug: slug) {
            return view
        }
        let fallback = UILabel()
        fallback.text = "render failed: \(slug)"
        fallback.accessibilityIdentifier = "cascade-root-fallback"
        return fallback
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
