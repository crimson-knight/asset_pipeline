// ImageFacade — SwiftUI Image bridge.
//
// `source` is interpreted by SwiftUI:
//   - If the asset catalog resolves it, `Image(source)` shows that asset.
//   - Otherwise we fall back to `Image(systemName: source)` so SF Symbol
//     names work transparently.
//
// Default content mode is `.fit` (SwiftUI's `.aspectRatio(contentMode: .fit)`
// applied only when the override surfaces — Crystal's type default is
// ContentMode::Fit; the populator emits the override only when the value
// differs).

import SwiftUI
import Foundation

@objc(APSKImageFacade)
public class ImageFacade: NSObject {
    @objc public static func makeImage(
        source: String,
        overrides: ImageOverrides
    ) -> APSKPlatformView {
        let base: Image
        #if canImport(UIKit)
        if UIImage(named: source) != nil {
            base = Image(source)
        } else {
            base = Image(systemName: source)
        }
        #else
        if NSImage(named: NSImage.Name(source)) != nil {
            base = Image(source)
        } else {
            base = Image(systemName: source)
        }
        #endif

        var content: AnyView

        switch overrides.contentMode {
        case "fill":
            content = AnyView(base.resizable().aspectRatio(contentMode: .fill))
        case "stretch":
            content = AnyView(base.resizable())
        default:
            // "fit" OR nil — Fit is UI::Image's documented default content_mode,
            // and the Crystal populator omits content_mode when it equals the
            // default. Without resizing here, a default Image is NOT `.resizable()`
            // and renders at intrinsic size — a sized/hero image (frame via
            // minimum_width/height) stays tiny and can't scale. Treat default as Fit.
            content = AnyView(base.resizable().aspectRatio(contentMode: .fit))
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(content)
    }
}
