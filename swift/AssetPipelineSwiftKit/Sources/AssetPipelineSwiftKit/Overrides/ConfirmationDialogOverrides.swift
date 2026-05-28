// ConfirmationDialogOverrides — per-ConfirmationDialog overrides above
// ViewOverrides.
//
// Field semantics:
//   title         : dialog title (positional on the facade).
//   message       : optional message body.
//   isPresented   : NSNumber bool. nil = false.
//   confirmLabel  : confirm button label. nil = "Confirm".  (binary path)
//   cancelLabel   : cancel button label. nil = "Cancel".    (binary path)
//   confirmStyle  : "default" | "destructive". nil = "default". (binary path)
//   confirmToken  : NSNumber UInt64 action token for confirm. (binary path)
//   cancelToken   : NSNumber UInt64 action token for cancel.  (binary path)
//
// Phase 10D-polish iter 2 (B-ACTIONSHEET-MULTI-ACTION):
//   actionLabels  : parallel array of button titles for multi-action mode.
//                   When non-empty, the facade switches from the binary
//                   confirm/cancel path to a ForEach over these arrays.
//   actionStyles  : "default" | "destructive" | "cancel". Parallel to
//                   actionLabels. SwiftUI's `Button(role:)` maps the
//                   string to .destructive / .cancel / nil so the
//                   confirmation dialog renders the HIG-correct chrome
//                   (cancel pinned bottom, destructive red).
//   actionTokens  : NSArray<NSNumber *> of UInt64 callback tokens.
//                   Parallel to actionLabels.

import Foundation

@objc(APSKConfirmationDialogOverrides)
public class ConfirmationDialogOverrides: ViewOverrides {
    @objc public var title: String? = nil
    @objc public var message: String? = nil
    @objc public var isPresented: NSNumber? = nil
    @objc public var confirmLabel: String? = nil
    @objc public var cancelLabel: String? = nil
    @objc public var confirmStyle: String? = nil
    @objc public var confirmToken: NSNumber? = nil
    @objc public var cancelToken: NSNumber? = nil

    // Multi-action arrays — when actionLabels is non-empty the facade
    // ignores the binary confirm/cancel fields and renders every action.
    @objc public var actionLabels: [String] = []
    @objc public var actionStyles: [String] = []
    @objc public var actionTokens: [NSNumber] = []

    @objc public override init() { super.init() }
}
