// IconButtonFacade — SwiftUI Button(action:) with an icon label.
//
// The icon `source` is resolved the same way ImageFacade resolves an image:
//   1. an absolute file path  → load the PNG/JPG off disk (NSImage/UIImage
//      contentsOfFile) — lets a NON-bundled dev binary use real artwork by path;
//   2. an asset-catalog name  → Image(source);
//   3. otherwise              → Image(systemName: source)  (SF Symbol).
//
// A real raster (file path / asset) renders at an EXACT icon_size box with its
// baked-in colors (`.renderingMode(.original)`), so custom button artwork
// (chevron-down, sliders, play/pause, repeat — the Expo "Listen" player glyphs)
// is shown verbatim and NOT recolored by the IconButton tint. Only the SF-Symbol
// fallback uses the font-sized, tintable glyph. The tap callback is identical in
// all three cases, so an IconButton with an absolute-path icon is a fully
// functional image button.

import SwiftUI
import Foundation

@objc(APSKIconButtonFacade)
public class IconButtonFacade: NSObject {
    @objc public static func makeIconButton(
        icon: String,
        overrides: IconButtonOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let action: () -> Void = {
            CallbackBridge.fire(token: actionToken, value: 0)
        }
        let size = CGFloat(overrides.iconSize?.doubleValue ?? 24.0)
        let label = overrides.label

        // A real image (file path / asset catalog) → render verbatim at an exact
        // size. nil ⇒ the source is an SF Symbol name (font-sized, tintable).
        let customImage: Image? = resolveImage(icon)

        var content: AnyView
        if let lbl = label, !lbl.isEmpty {
            // Labeled icon button.
            if let img = customImage {
                content = AnyView(Button(action: action) {
                    HStack(spacing: 6) {
                        img.resizable()
                            .renderingMode(.original)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size, height: size)
                        Text(lbl)
                    }
                })
            } else {
                content = AnyView(Button(action: action) {
                    Label(lbl, systemImage: icon)
                })
            }
        } else if let img = customImage {
            // Icon-only image button. An exact frame ⇒ the intrinsic size is
            // unambiguous, so the iOS hosting-constraint crash that the SF-Symbol
            // branch guards against does not apply here. `.contentShape` makes the
            // whole box tappable.
            content = AnyView(Button(action: action) {
                img.resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .contentShape(Rectangle())
            })
        } else {
            // Icon-only SF Symbol. Give the label an explicit, HIG-minimum (44pt)
            // tappable frame + a content shape. Without an explicit size, an
            // icon-only SwiftUI Button can report an ambiguous/zero intrinsic
            // content size, which crashes the iOS UIHostingController constraint
            // solver (hosted with sizingOptions [.intrinsicContentSize]); macOS
            // NSHostingView tolerates it. The explicit frame fixes the iOS crash
            // and is also the correct minimum hit target.
            let tap = max(size + 16, 44)
            let symbol = Image(systemName: icon).font(.system(size: size))
            content = AnyView(Button(action: action) {
                symbol
                    .frame(minWidth: tap, minHeight: tap)
                    .contentShape(Rectangle())
            })
        }

        if let disabled = overrides.disabled, disabled.boolValue {
            content = AnyView(content.disabled(true))
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(content)
    }

    /// Resolve a source string to a SwiftUI `Image` when it names a real raster
    /// (absolute file path → asset-catalog entry). Returns nil for SF-Symbol
    /// names so the caller renders a font-sized `Image(systemName:)`. Mirrors
    /// ImageFacade's resolution order.
    private static func resolveImage(_ source: String) -> Image? {
        #if canImport(UIKit)
        if source.hasPrefix("/"), let img = UIImage(contentsOfFile: source) {
            return Image(uiImage: img)
        }
        if UIImage(named: source) != nil {
            return Image(source)
        }
        return nil
        #else
        if source.hasPrefix("/"), let img = NSImage(contentsOfFile: source) {
            return Image(nsImage: img)
        }
        if NSImage(named: NSImage.Name(source)) != nil {
            return Image(source)
        }
        return nil
        #endif
    }
}
