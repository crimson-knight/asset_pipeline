import XCTest
import SwiftUI
#if SWIFT_PACKAGE
@testable import AssetPipelineSwiftKit
#endif

#if canImport(AppKit)
import AppKit

final class HostedLabelSizingTests: XCTestCase {
    private func label(overrides: LabelOverrides, text: String) -> APSKPlatformView {
        LabelFacade.makeLabel(text: text, overrides: overrides)
    }

    func testWrappedLabelGrowsPastItsMinimumHeight() {
        let overrides = LabelOverrides()
        overrides.minHeight = 18
        overrides.preferredMaxLayoutWidth = 180
        let text = String(repeating: "A complete answer remains readable in its conversation. ", count: 8)
        XCTAssertGreaterThan(label(overrides: overrides, text: text).fittingSize.height, 18)
    }

    func testShortLabelRetainsItsMinimumHeight() {
        let overrides = LabelOverrides()
        overrides.minHeight = 44
        XCTAssertEqual(label(overrides: overrides, text: "Ready").fittingSize.height, 44, accuracy: 1)
    }

    func testExactLabelHeightRemainsExact() {
        let overrides = LabelOverrides()
        overrides.minHeight = 18
        overrides.maxHeight = 18
        overrides.preferredMaxLayoutWidth = 180
        let text = String(repeating: "An explicitly capped label. ", count: 10)
        XCTAssertEqual(label(overrides: overrides, text: text).fittingSize.height, 18, accuracy: 1)
    }

    func testLabelMaximumHeightRemainsCapped() {
        let overrides = LabelOverrides()
        overrides.maxHeight = 18
        overrides.preferredMaxLayoutWidth = 180
        let text = String(repeating: "An explicitly capped label. ", count: 10)
        XCTAssertLessThanOrEqual(label(overrides: overrides, text: text).fittingSize.height, 19)
    }

    func testButtonRetainsItsExistingMinimumTargetHeight() {
        let overrides = ButtonOverrides()
        overrides.minHeight = 44
        let button = ButtonFacade.makeButton(label: "Save", overrides: overrides, actionToken: 0)
        XCTAssertEqual(button.fittingSize.height, 44, accuracy: 1)
    }

    static let allTests = [
        ("testWrappedLabelGrowsPastItsMinimumHeight", testWrappedLabelGrowsPastItsMinimumHeight),
        ("testShortLabelRetainsItsMinimumHeight", testShortLabelRetainsItsMinimumHeight),
        ("testExactLabelHeightRemainsExact", testExactLabelHeightRemainsExact),
        ("testLabelMaximumHeightRemainsCapped", testLabelMaximumHeightRemainsCapped),
        ("testButtonRetainsItsExistingMinimumTargetHeight", testButtonRetainsItsExistingMinimumTargetHeight),
    ]
}
#endif
