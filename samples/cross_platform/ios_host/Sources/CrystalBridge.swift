import UIKit

// Swift wrapper around the Crystal C-ABI bridge functions.
// Pattern mirrors happy_coach/mobile/ios/Sources/CrystalBridge.swift.

enum CrystalBridge {
    private static var didInit = false

    static func initialize() {
        guard !didInit else { return }
        crystal_init()
        didInit = true
    }

    /// Render a HIG component by slug and return the resulting UIView.
    /// Crystal returns a retained UIView*; ownership transfers here.
    static func render(slug: String) -> UIView? {
        initialize()
        return slug.withCString { ptr in
            guard let raw = crystal_render_slug(ptr) else { return nil }
            let view = Unmanaged<UIView>.fromOpaque(raw).takeRetainedValue()
            view.accessibilityIdentifier = "hig-component-root"
            // Ensure the view is exposed as an accessibility element so
            // XCUITest can locate it by identifier. Container views like
            // UIStackView default to isAccessibilityElement=false.
            view.isAccessibilityElement = true
            view.accessibilityLabel = "HIG \(slug) root"
            return view
        }
    }
}
