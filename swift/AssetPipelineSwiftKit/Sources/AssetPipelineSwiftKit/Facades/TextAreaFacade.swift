// TextAreaFacade — SwiftUI multi-line text input bridge.
//
// SwiftUI's stable multi-line input is `TextEditor`; iOS 16+ also
// supports `TextField(text:axis:.vertical)`. We use TextEditor as the
// trunk so behaviour is identical across iOS 16+ and macOS 13+.

import SwiftUI
import Foundation

// watchOS: this facade is not in the watch catalog subset and/or uses UIKit-only
// APIs (UIView/UIControl/SwiftUI-on-watch-unavailable). Gated off watchOS for the
// initial one-facade green compile; watch-native re-enable is a Phase 12 follow-up.
#if !os(watchOS)
@objc(APSKTextAreaFacade)
public class TextAreaFacade: NSObject {
    @objc public static func makeTextArea(
        placeholder: String,
        initialText: String,
        overrides: TextAreaOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let storage = TextStorage(initial: initialText, token: actionToken)

        var content: AnyView = AnyView(
            TextAreaBody(
                storage: storage,
                placeholder: placeholder,
                lineLimit: overrides.lineLimit?.intValue,
                disabled: (overrides.editable.map { !$0.boolValue }) ?? false
            )
        )
        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(TextAreaStorageHost(storage: storage, content: content))
    }
}

// Observes `storage` so the placeholder overlay reacts to typing. SwiftUI's
// `TextEditor` has NO native placeholder (unlike TextField's `prompt:`), and
// the facade previously dropped the `placeholder:` argument entirely — empty
// TextAreas showed no hint. Render it as a top-leading overlay shown only while
// the text is empty (matches the TextField PromptOverlayField recipe).
private struct TextAreaBody: View {
    @ObservedObject var storage: TextStorage
    let placeholder: String
    let lineLimit: Int?
    let disabled: Bool

    var body: some View {
        var editor: AnyView = AnyView(
            TextEditor(text: storage.binding)
                .frame(minHeight: 80)
                .overlay(alignment: .topLeading) {
                    if storage.text.isEmpty && !placeholder.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(Color.primary.opacity(0.5))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                }
        )
        if let n = lineLimit, n > 0 {
            editor = AnyView(editor.lineLimit(n))
        }
        if disabled {
            editor = AnyView(editor.disabled(true))
        }
        return editor
    }
}

private struct TextAreaStorageHost<Content: View>: View {
    @ObservedObject var storage: TextStorage
    let content: Content
    var body: some View { content }
}
#endif
