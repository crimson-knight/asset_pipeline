import SwiftUI
import XCTest
@testable import AssetPipelineSwiftKit

#if canImport(UIKit) && !os(watchOS)
import UIKit

@MainActor
final class HostingHelpersTests: XCTestCase {
    func testUIKitHostReturnsTheControllerOwnedRoot() {
        let platformView = HostingHelpers.host(Text("Hosted content"))
        guard let controller = platformView.next as? APSKAttachingHostingController else {
            return XCTFail("hosted root must retain its APSKAttachingHostingController responder")
        }

        XCTAssertTrue(controller.view === platformView)
        XCTAssertFalse(platformView.isAccessibilityElement)
    }

    func testUIKitHostAttachesDetachesAndReattachesController() {
        let firstOwner = UIViewController()
        let firstWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        firstWindow.rootViewController = firstOwner
        firstWindow.makeKeyAndVisible()

        let hostedView = HostingHelpers.host(Text("Lifecycle"))
        let controller = hostedView.next as! APSKAttachingHostingController
        hostedView.frame = firstOwner.view.bounds
        firstOwner.view.addSubview(hostedView)
        firstOwner.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertTrue(controller.parent === firstOwner)

        hostedView.removeFromSuperview()
        XCTAssertNil(controller.parent)

        let secondOwner = UIViewController()
        let secondWindow = UIWindow(frame: firstWindow.frame)
        secondWindow.rootViewController = secondOwner
        secondWindow.makeKeyAndVisible()
        hostedView.frame = secondOwner.view.bounds
        secondOwner.view.addSubview(hostedView)
        secondOwner.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertTrue(controller.parent === secondOwner)

        hostedView.removeFromSuperview()
        XCTAssertNil(controller.parent)
        firstWindow.isHidden = true
        secondWindow.isHidden = true
    }
}
#endif
