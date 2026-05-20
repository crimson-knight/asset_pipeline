// SheetFacade — SwiftUI .sheet(isPresented:) bridge.
//
// Crystal hands ONE child: the sheet content. The facade renders an
// invisible 1x1 host that owns the .sheet modifier; the modifier's
// `isPresented` binding starts at the overrides value and is owned by
// a `BoolStorage` so dismissing the sheet fires the dismiss action
// token.
//
// Default behavior (no overrides):
//   - SwiftUI default presentation detents.
//   - System drag indicator visible at the top of the sheet.
//   - Brand tint cascade flows into sheet content automatically.

import SwiftUI
import Foundation

@objc(APSKSheetFacade)
public class SheetFacade: NSObject {
    @objc public static func makeSheet(
        childViews: [APSKPlatformView],
        overrides: SheetOverrides,
        dismissToken: UInt64
    ) -> APSKPlatformView {
        let isPresented = overrides.isPresented?.boolValue ?? false
        let storage = BoolStorage(initial: isPresented, token: dismissToken)

        let sheetBody: AnyView
        if let first = childViews.first {
            sheetBody = AnyView(APSKHostedChild(view: first))
        } else {
            sheetBody = AnyView(EmptyView())
        }

        var content: AnyView = AnyView(
            Color.clear
                .frame(width: 1, height: 1)
                .sheet(isPresented: storage.binding, onDismiss: {
                    CallbackBridge.fire(token: dismissToken, value: 0.0)
                }) {
                    applyDetents(sheetBody, overrides: overrides)
                }
        )

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(SheetHost(storage: storage, content: content))
    }

    private static func applyDetents(_ v: AnyView, overrides: SheetOverrides) -> AnyView {
        guard !overrides.detents.isEmpty else { return v }
        if #available(iOS 16.0, macOS 13.0, *) {
            #if canImport(UIKit)
            let detents: [PresentationDetent] = overrides.detents.compactMap { name in
                switch name {
                case "small":  return .height(160)
                case "medium": return .medium
                case "large":  return .large
                default:       return nil
                }
            }
            if !detents.isEmpty {
                return AnyView(v.presentationDetents(Set(detents)))
            }
            #endif
        }
        return v
    }
}

private struct SheetHost<Content: View>: View {
    @ObservedObject var storage: BoolStorage
    let content: Content
    var body: some View { content }
}
