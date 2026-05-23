// TextFieldFacade — SwiftUI TextField bridge.
//
// Default: system body font, system focus ring, dark/light adaptive, no
// autocorrect changes. When `secureEntry` override is set, the facade
// emits a `SecureField` instead so password-AutoFill engages.
//
// `actionToken` is invoked with the new text length as the value
// channel (Crystal lifts the actual string back from the on_change
// closure indirectly; the value channel here just carries
// "something changed"). A richer text-bound dispatch is a future hook.

import SwiftUI
import Foundation

@objc(APSKTextFieldFacade)
public class TextFieldFacade: NSObject {
    @objc public static func makeTextField(
        placeholder: String,
        initialText: String,
        overrides: TextFieldOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let storage = TextStorage(initial: initialText, token: actionToken)

        let base: AnyView
        if let secure = overrides.secureEntry, secure.boolValue {
            base = AnyView(SecureField(placeholder, text: storage.binding))
        } else {
            base = AnyView(TextField(placeholder, text: storage.binding))
        }

        var content: AnyView = base

        // Beauty-by-default: apply `.textFieldStyle(.roundedBorder)` so the
        // field has visible chrome (rounded border + padding) on every
        // platform. SwiftUI's iOS default is a plain TextField with no
        // border — fine inside a Form, but not on a stand-alone sign-in
        // surface where the user expects a recognisable field. Macros
        // and per-widget style overrides will land in a follow-up.
        content = AnyView(content.textFieldStyle(.roundedBorder))

        #if canImport(UIKit)
        if let kt = overrides.keyboardType {
            switch kt {
            case "email":  content = AnyView(content.keyboardType(.emailAddress))
            case "number": content = AnyView(content.keyboardType(.numberPad))
            case "phone":  content = AnyView(content.keyboardType(.phonePad))
            case "url":    content = AnyView(content.keyboardType(.URL))
            default: break
            }
        }
        #endif

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(StorageHost(storage: storage, content: content))
    }
}

// Per-field state holder. SwiftUI requires the bound state to outlive
// individual layout passes; we keep it on a class object that the
// facade pins via `objc_setAssociatedObject` in HostingHelpers.host.
final class TextStorage: ObservableObject {
    @Published var text: String
    let token: UInt64
    init(initial: String, token: UInt64) {
        self.text = initial
        self.token = token
    }
    var binding: Binding<String> {
        Binding(
            get: { self.text },
            set: { newValue in
                self.text = newValue
                CallbackBridge.fire(token: self.token, value: Double(newValue.count))
            }
        )
    }
}

private struct StorageHost<Content: View>: View {
    @ObservedObject var storage: TextStorage
    let content: Content
    var body: some View { content }
}
