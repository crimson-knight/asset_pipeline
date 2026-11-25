// APSKInteractionStatePreview — draw controls in a named interaction state
// for an offscreen render.
//
// Hover, pressed and keyboard focus only exist while a person is using the
// app, so an offscreen render (`ap_snapshot_view`) always shows the resting
// state. A design review needs to see the other three. The renderer's
// `ap_snapshot_view_in_interaction_state` sets the state named here for the
// length of one render; every app-styled button then draws that state as
// if the pointer were over it, the mouse button were down, or it held
// keyboard focus. Outside a render the state is `.none` and live input
// alone decides what each control shows.

import Foundation
import SwiftUI

enum APSKPreviewedInteractionState: String {
    case none
    case hover
    case pressed
    case focused
}

final class APSKInteractionStatePreview: ObservableObject {
    static let shared = APSKInteractionStatePreview()

    @Published var previewedState: APSKPreviewedInteractionState = .none
}

/// Set the interaction state every app-styled control draws: "hover",
/// "pressed", "focused", or "none" (and NULL) for live input. Called on the
/// main thread by the offscreen render.
@_cdecl("apsk_preview_interaction_state")
public func apskPreviewInteractionState(_ cState: UnsafePointer<CChar>?) {
    let name = cState.map { String(cString: $0) } ?? "none"
    let state = APSKPreviewedInteractionState(rawValue: name) ?? .none
    if Thread.isMainThread {
        APSKInteractionStatePreview.shared.previewedState = state
    } else {
        DispatchQueue.main.async { APSKInteractionStatePreview.shared.previewedState = state }
    }
}
