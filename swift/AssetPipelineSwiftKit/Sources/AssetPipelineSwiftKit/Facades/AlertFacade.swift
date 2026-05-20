// AlertFacade — SwiftUI .alert(_:isPresented:actions:message:) bridge.
//
// Alert content is entirely data-driven (title, message, button list).
// No child views are needed — the buttons come from the
// AlertOverrides parallel arrays.

import SwiftUI
import Foundation

@objc(APSKAlertFacade)
public class AlertFacade: NSObject {
    @objc public static func makeAlert(
        title: String,
        message: String,
        overrides: AlertOverrides
    ) -> APSKPlatformView {
        let isPresented = overrides.isPresented?.boolValue ?? false
        // Alerts dismiss themselves when an action button is tapped;
        // we still expose a token (`buttonTokens` carries them) so the
        // Crystal action runs. No separate dismiss-token surface needed.
        let storage = BoolStorage(initial: isPresented, token: 0)

        let labels = overrides.buttonLabels
        let styles = overrides.buttonStyles
        let tokens = overrides.buttonTokens

        var content: AnyView = AnyView(
            Color.clear
                .frame(width: 1, height: 1)
                .alert(title, isPresented: storage.binding) {
                    ForEach(0..<labels.count, id: \.self) { idx in
                        let style = idx < styles.count ? styles[idx] : "default"
                        let token = idx < tokens.count ? tokens[idx].uint64Value : 0
                        Button(
                            role: roleFor(style),
                            action: { CallbackBridge.fire(token: token, value: 0.0) }
                        ) {
                            Text(labels[idx])
                        }
                    }
                } message: {
                    if !message.isEmpty {
                        Text(message)
                    }
                }
        )

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(AlertHost(storage: storage, content: content))
    }

    private static func roleFor(_ style: String) -> ButtonRole? {
        switch style {
        case "destructive": return .destructive
        case "cancel":      return .cancel
        default:            return nil
        }
    }
}

private struct AlertHost<Content: View>: View {
    @ObservedObject var storage: BoolStorage
    let content: Content
    var body: some View { content }
}
