import SwiftUI

#if os(macOS)
import AppKit

/// Applies intrinsic sizing to a plain hosting leaf whose two axes are fixed.
/// The caller supplies the declared bounds; wrapping text retains its policy.
@objc(APSKFixedHostingSizePolicy)
public final class FixedHostingSizePolicy: NSObject {
    @objc(applyToView:width:height:)
    public static func apply(to view: NSView, width: Double, height: Double) -> Int {
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              let host = view as? NSHostingView<AnyView>,
              !(host is APSKWrappingTextHostingView) else { return -1 }
        let previous = Int(host.sizingOptions.rawValue)
        host.sizingOptions = [.intrinsicContentSize]
        return previous
    }

    @objc(restoreView:options:)
    public static func restore(view: NSView, options: Int) -> Bool {
        guard options >= 0, options <= 7,
              let host = view as? NSHostingView<AnyView>,
              !(host is APSKWrappingTextHostingView) else { return false }
        host.sizingOptions = NSHostingSizingOptions(rawValue: options)
        return true
    }
}
#endif
