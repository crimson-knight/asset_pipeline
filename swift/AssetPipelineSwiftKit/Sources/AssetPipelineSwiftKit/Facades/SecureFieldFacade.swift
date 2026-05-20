// SecureFieldFacade — SwiftUI SecureField bridge.
//
// Mirrors TextFieldFacade but always emits a SecureField so the system
// provides obscured glyphs + password AutoFill out of the box.

import SwiftUI
import Foundation

@objc(APSKSecureFieldFacade)
public class SecureFieldFacade: NSObject {
    @objc public static func makeSecureField(
        placeholder: String,
        initialText: String,
        overrides: SecureFieldOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let storage = TextStorage(initial: initialText, token: actionToken)
        var content: AnyView = AnyView(SecureField(placeholder, text: storage.binding))
        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(SecureStorageHost(storage: storage, content: content))
    }
}

private struct SecureStorageHost<Content: View>: View {
    @ObservedObject var storage: TextStorage
    let content: Content
    var body: some View { content }
}
