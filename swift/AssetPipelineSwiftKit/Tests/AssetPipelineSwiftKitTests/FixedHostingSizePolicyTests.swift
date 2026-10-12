import XCTest
import SwiftUI
#if SWIFT_PACKAGE
@testable import AssetPipelineSwiftKit
#endif

#if os(macOS)
import AppKit

final class FixedHostingSizePolicyTests: XCTestCase {
    func testFixedPlainHostPreservesGeometryAndRestoresOriginalPolicy() {
        let host = NSHostingView(rootView: AnyView(Text("Blue").frame(width: 180, height: 30)))
        let originalOptions = host.sizingOptions
        let originalSize = host.fittingSize
        let previous = FixedHostingSizePolicy.apply(to: host, width: 180, height: 30)
        XCTAssertEqual(previous, Int(originalOptions.rawValue))
        XCTAssertEqual(host.sizingOptions, [.intrinsicContentSize])
        XCTAssertEqual(host.fittingSize.width, originalSize.width, accuracy: 0.5)
        XCTAssertEqual(host.fittingSize.height, originalSize.height, accuracy: 0.5)
        XCTAssertTrue(FixedHostingSizePolicy.restore(view: host, options: previous))
        XCTAssertEqual(host.sizingOptions, originalOptions)
    }

    func testWrappingHostRetainsItsHeightForWidthPolicy() {
        let host = APSKWrappingTextHostingView(rootView: AnyView(Text("A wrapped explanation")))
        let original = host.sizingOptions
        XCTAssertEqual(FixedHostingSizePolicy.apply(to: host, width: 180, height: 30), -1)
        XCTAssertEqual(host.sizingOptions, original)
        XCTAssertFalse(FixedHostingSizePolicy.restore(view: host, options: 7))
    }

    func testUnconstrainedOrInvalidGeometryRetainsOriginalPolicy() {
        let host = NSHostingView(rootView: AnyView(Text("Blue")))
        let original = host.sizingOptions
        for pair in [(0.0, 30.0), (180.0, 0.0), (Double.nan, 30.0), (180.0, Double.infinity)] {
            XCTAssertEqual(FixedHostingSizePolicy.apply(to: host, width: pair.0, height: pair.1), -1)
            XCTAssertEqual(host.sizingOptions, original)
        }
        XCTAssertFalse(FixedHostingSizePolicy.restore(view: host, options: 8))
        XCTAssertEqual(host.sizingOptions, original)
    }

    func testOrdinaryAppKitViewRetainsItsFrame() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 30))
        XCTAssertEqual(FixedHostingSizePolicy.apply(to: view, width: 180, height: 30), -1)
        XCTAssertEqual(view.frame.size.width, 180)
        XCTAssertFalse(FixedHostingSizePolicy.restore(view: view, options: 7))
    }

    static let allTests = [
        ("testFixedPlainHostPreservesGeometryAndRestoresOriginalPolicy", testFixedPlainHostPreservesGeometryAndRestoresOriginalPolicy),
        ("testWrappingHostRetainsItsHeightForWidthPolicy", testWrappingHostRetainsItsHeightForWidthPolicy),
        ("testUnconstrainedOrInvalidGeometryRetainsOriginalPolicy", testUnconstrainedOrInvalidGeometryRetainsOriginalPolicy),
        ("testOrdinaryAppKitViewRetainsItsFrame", testOrdinaryAppKitViewRetainsItsFrame),
    ]
}
#endif
