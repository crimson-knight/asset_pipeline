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

        // Custom font cascade (mirrors LabelFacade / ButtonFacade): custom
        // registered family → system size(+weight) → weight-only. Applied to the
        // editor content so the typed text + placeholder share the face. Without
        // this a Crystal-side `text_area.font = Font.new(...)` was dropped.
        if let fam = overrides.fontFamily, fam != "system", !fam.isEmpty {
            let sz = (overrides.fontSize?.doubleValue).flatMap { $0 > 0 ? $0 : nil } ?? 17.0
            content = AnyView(content.font(.custom(fam, size: CGFloat(sz))))
        } else if let sz = overrides.fontSize, sz.doubleValue > 0 {
            let weight = (overrides.fontWeight.flatMap { Font.Weight(rawValue: $0.intValue) }) ?? .regular
            content = AnyView(content.font(.system(size: CGFloat(sz.doubleValue), weight: weight)))
        } else if let w = overrides.fontWeight {
            content = AnyView(content.fontWeight(Font.Weight(rawValue: w.intValue) ?? .regular))
        }

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

// Local `Font.Weight` rawValue init — matches LabelFacade / ButtonFacade.
private extension Font.Weight {
    init?(rawValue: Int) {
        switch rawValue {
        case -3: self = .ultraLight
        case -2: self = .thin
        case -1: self = .light
        case 0: self = .regular
        case 1: self = .medium
        case 2: self = .semibold
        case 3: self = .bold
        case 4: self = .heavy
        case 5: self = .black
        default: return nil
        }
    }
}
#endif
