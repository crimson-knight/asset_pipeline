import SwiftUI
import XCTest
@testable import AssetPipelineSwiftKit

#if canImport(UIKit) && !os(watchOS)
import UIKit

@MainActor
final class HostingHelpersTests: XCTestCase {
    func testUIKitHostUsesExternalLifecycleContainer() {
        let platformView = HostingHelpers.host(Text("Hosted content"))
        guard let container = platformView as? APSKHostingContainerView else {
            return XCTFail("UIKit host must return APSKHostingContainerView")
        }

        let hostedView = container.hostingController.view!
        XCTAssertTrue(hostedView.superview === container)
        XCTAssertFalse(container.isAccessibilityElement)
        XCTAssertEqual(container.subviews.count, 1)
        XCTAssertTrue(container.subviews.first === hostedView)
    }

    func testUIKitHostAttachesDetachesAndReattachesController() {
        let firstOwner = UIViewController()
        let firstWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        firstWindow.rootViewController = firstOwner
        firstWindow.makeKeyAndVisible()

        let container = HostingHelpers.host(Text("Lifecycle")) as! APSKHostingContainerView
        container.frame = firstOwner.view.bounds
        firstOwner.view.addSubview(container)

        XCTAssertTrue(container.hostingController.parent === firstOwner)

        container.removeFromSuperview()
        XCTAssertNil(container.hostingController.parent)

        let secondOwner = UIViewController()
        let secondWindow = UIWindow(frame: firstWindow.frame)
        secondWindow.rootViewController = secondOwner
        secondWindow.makeKeyAndVisible()
        container.frame = secondOwner.view.bounds
        secondOwner.view.addSubview(container)

        XCTAssertTrue(container.hostingController.parent === secondOwner)

        container.removeFromSuperview()
        XCTAssertNil(container.hostingController.parent)
        firstWindow.isHidden = true
        secondWindow.isHidden = true
    }
}
#endif
