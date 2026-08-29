// ConfirmationDialogFacade — SwiftUI .confirmationDialog(...) bridge.
//
// On iOS the dialog renders as an action sheet from the bottom of the
// screen; on macOS it renders as a modal alert with destructive emphasis
// for the confirm button when style == "destructive".

import SwiftUI
import Foundation

@objc(APSKConfirmationDialogFacade)
public class ConfirmationDialogFacade: NSObject {
    // Legacy non-reactive entry. Shimmed through the reactive variant
    // with outState = nil so callers that haven't migrated keep working
    // (matches the SheetFacade migration pattern).
    @objc public static func makeConfirmationDialog(
        title: String,
        message: String,
        overrides: ConfirmationDialogOverrides
    ) -> APSKPlatformView {
        return makeReactiveConfirmationDialog(
            title: title,
            message: message,
            overrides: overrides,
            outState: nil
        )
    }

    // Phase 12.C — reactive entry (Codex iter-1 BLOCKER 1 fix). Returns
    // a +1 retained `BoolStorage` pointer through `outState` so Crystal
    // can later flip presentation via
    // `apsk_confirmation_dialog_set_presented(state, 0)` during the
    // cross-render sweep. Mirrors the `makeReactiveSheet` pattern in
    // SheetFacade.
    @objc public static func makeReactiveConfirmationDialog(
        title: String,
        message: String,
        overrides: ConfirmationDialogOverrides,
        outState: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
    ) -> APSKPlatformView {
        let isPresented = overrides.isPresented?.boolValue ?? false
        let storage = BoolStorage(initial: isPresented, token: 0)
        // Phase 12.A — interaction-contracts marker tag. The accessibility
        // identifier from the Crystal-side overrides (when set) is used as
        // the viewID; otherwise the marker carries view=anonymous.
        storage.markerWidget = "ConfirmationDialog"
        storage.viewID = overrides.accessibilityIdentifier
        // Emit an initial "present" marker if the dialog is constructed
        // already-presented (init's emit path can't see markerWidget,
        // which is set on the next line).
        if isPresented {
            InteractionContracts.emit(
                widget: "ConfirmationDialog",
                event: "present",
                viewID: storage.viewID,
                kv: ["initial": "true"]
            )
        }

        if let outState = outState {
            outState.pointee = Unmanaged.passRetained(storage).toOpaque()
        }

        let confirmLabel = overrides.confirmLabel ?? "Confirm"
        let cancelLabel = overrides.cancelLabel ?? "Cancel"
        let confirmStyle = overrides.confirmStyle ?? "default"
        let confirmToken = overrides.confirmToken?.uint64Value ?? 0
        let cancelToken = overrides.cancelToken?.uint64Value ?? 0

        // Phase 10D-polish iter 2 — multi-action path. When the
        // overrides carry a non-empty actionLabels array, iterate every
        // entry as a SwiftUI Button inside the .confirmationDialog
        // content closure. SwiftUI natively supports any number of
        // buttons here; the system pins the cancel-role button at the
        // bottom and renders destructive buttons in red.
        let actionLabels = overrides.actionLabels
        let actionStyles = overrides.actionStyles
        let actionTokens = overrides.actionTokens
        let hasMultiAction = !actionLabels.isEmpty

        var content: AnyView = AnyView(
            Color.clear
                .frame(width: 1, height: 1)
                .confirmationDialog(
                    title,
                    isPresented: storage.binding,
                    titleVisibility: .visible
                ) {
                    if hasMultiAction {
                        ForEach(0..<actionLabels.count, id: \.self) { i in
                            let style = i < actionStyles.count ? actionStyles[i] : "default"
                            let token = i < actionTokens.count ? actionTokens[i].uint64Value : 0
                            let label = actionLabels[i]
                            Button(
                                role: ConfirmationDialogFacade.roleFor(style),
                                action: { CallbackBridge.fire(token: token, value: 0.0) }
                            ) {
                                Text(label)
                            }
                        }
                    } else {
                        Button(
                            role: confirmStyle == "destructive" ? .destructive : nil,
                            action: { CallbackBridge.fire(token: confirmToken, value: 0.0) }
                        ) {
                            Text(confirmLabel)
                        }
                        Button(role: .cancel, action: {
                            CallbackBridge.fire(token: cancelToken, value: 0.0)
                        }) {
                            Text(cancelLabel)
                        }
                    }
                } message: {
                    if !message.isEmpty { Text(message) }
                }
        )

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(ConfirmHost(storage: storage, content: content))
    }

    fileprivate static func roleFor(_ style: String) -> ButtonRole? {
        switch style {
        case "destructive": return .destructive
        case "cancel":      return .cancel
        default:            return nil
        }
    }
}

private struct ConfirmHost<Content: View>: View {
    @ObservedObject var storage: BoolStorage
    let content: Content
    var body: some View { content }
}
