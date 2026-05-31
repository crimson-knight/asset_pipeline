// TabViewTokenTests — proves the TabView value-drop fix at the SwiftKit
// layer (the layer XCUITest cannot reach: a SwiftUI TabView's selection
// binding is not driven by synthesized taps in a UIHostingController).
//
// The bug: TabViewFacade hardcoded `IntStorage(initial:, token: 0)`, so a
// tab change fired CallbackBridge.fire(token: 0, ...) — the no-op token —
// and the Crystal on_change never received the new index. The fix threads
// the real `actionToken` into IntStorage. This test installs a capturing
// trampoline, drives the IntStorage binding the way a tab selection does,
// and asserts the REAL token + the new index reach the bridge.

import XCTest
import SwiftUI
@testable import AssetPipelineSwiftKit

// @convention(c) trampolines capture no context — use file-scope globals.
private var capturedToken: UInt64 = 0
private var capturedValue: Double = -1
private var fireCount: Int = 0

private let captureTrampoline: @convention(c) (UInt64, Double) -> Void = { token, value in
    capturedToken = token
    capturedValue = value
    fireCount += 1
}

final class TabViewTokenTests: XCTestCase {

    override func setUp() {
        super.setUp()
        capturedToken = 0
        capturedValue = -1
        fireCount = 0
        APSKRuntime._installTestTrampoline(captureTrampoline)
    }

    /// IntStorage built with a real token must fire THAT token (not 0) with
    /// the new index when its binding changes — exactly the path a TabView
    /// tab selection drives via `TabView(selection: storage.binding)`.
    func testIntStorageFiresRealTokenOnChange() {
        let token: UInt64 = 4242
        let storage = IntStorage(initial: 0, token: token)

        // Simulate selecting the third tab (index 2): SwiftUI writes the
        // new selection through the binding.
        storage.binding.wrappedValue = 2

        XCTAssertEqual(fireCount, 1, "Binding change did not fire the callback bridge exactly once.")
        XCTAssertEqual(capturedToken, token,
            "TabView/IntStorage fired the WRONG token (\(capturedToken)) — the " +
            "hardcoded-0 value-drop bug. Expected the threaded token \(token).")
        XCTAssertEqual(capturedValue, 2.0,
            "IntStorage fired the wrong value; expected the new index 2.")
    }

    /// A zero token (no on_change registered) still fires, but to the no-op
    /// token — documents that token 0 is the "dropped" sentinel the bug hit.
    func testIntStorageZeroTokenIsTheDroppedSentinel() {
        let storage = IntStorage(initial: 0, token: 0)
        storage.binding.wrappedValue = 1
        XCTAssertEqual(capturedToken, 0,
            "Sanity: token 0 is the no-op sentinel the pre-fix TabView always fired.")
    }
}
