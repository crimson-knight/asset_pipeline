import XCTest
import SwiftUI
#if SWIFT_PACKAGE
@testable import AssetPipelineSwiftKit
#endif

#if os(macOS)
import AppKit

private final class HostingLifetimePayload {
    let title = "Hosted lifetime"
}

private struct HostingLifetimeContent: View {
    let payload: HostingLifetimePayload

    var body: some View { Text(payload.title) }
}

final class HostingLifetimeTests: XCTestCase {
    func testPlainHostReleasesItsViewAndCapturedContent() {
        weak var releasedHost: NSView?
        weak var releasedPayload: HostingLifetimePayload?
        autoreleasepool {
            let payload = HostingLifetimePayload()
            let host = HostingHelpers.host(HostingLifetimeContent(payload: payload))
            releasedHost = host
            releasedPayload = payload
            XCTAssertNotNil(releasedHost)
            XCTAssertNotNil(releasedPayload)
        }
        XCTAssertNil(releasedHost, "The AppKit hosting view owns its lifetime through its external owner")
        XCTAssertNil(releasedPayload, "The released root also releases its captured content")
    }

    func testWrappingHostReleasesItsViewAndCapturedContent() {
        weak var releasedHost: NSView?
        weak var releasedPayload: HostingLifetimePayload?
        autoreleasepool {
            let payload = HostingLifetimePayload()
            let host = HostingHelpers.host(HostingLifetimeContent(payload: payload), wrapsText: true)
            releasedHost = host
            releasedPayload = payload
            XCTAssertTrue(host is APSKWrappingTextHostingView)
        }
        XCTAssertNil(releasedHost)
        XCTAssertNil(releasedPayload)
    }

    func testParentRetainsHostUntilTheLastExternalOwnerReleasesIt() {
        var parent: NSView? = NSView(frame: .zero)
        weak var releasedHost: NSView?
        weak var releasedPayload: HostingLifetimePayload?
        autoreleasepool {
            let payload = HostingLifetimePayload()
            let host = HostingHelpers.host(HostingLifetimeContent(payload: payload))
            parent?.addSubview(host)
            releasedHost = host
            releasedPayload = payload
        }
        XCTAssertNotNil(releasedHost)
        XCTAssertNotNil(releasedPayload)
        autoreleasepool { parent = nil }
        XCTAssertNil(releasedHost)
        XCTAssertNil(releasedPayload)
    }

    func testCompressedWrappingHostReleasesItsMeasurementGraph() {
        weak var releasedHost: NSView?
        autoreleasepool {
            let content = Text("A long Preferences explanation wraps across several lines in a narrow column.")
                .fixedSize(horizontal: false, vertical: true)
            let host = HostingHelpers.host(content, wrapsText: true)
            let ideal = host.intrinsicContentSize
            XCTAssertGreaterThan(ideal.width, 40)
            host.frame = NSRect(x: 0, y: 0, width: 40, height: ideal.height)
            host.layoutSubtreeIfNeeded()
            let compressed = host.intrinsicContentSize
            XCTAssertGreaterThan(compressed.height, ideal.height)
            releasedHost = host
        }
        XCTAssertNil(releasedHost, "The compressed label also releases its separate measurement controller")
    }

    func testRepeatedHostCreationReleasesEveryRoot() {
        var listOfReleasedHosts: [() -> NSView?] = []
        for _ in 0..<20 {
            autoreleasepool {
                let host = HostingHelpers.host(Text("Preferences row"))
                listOfReleasedHosts.append({ [weak host] in host })
            }
        }
        XCTAssertEqual(listOfReleasedHosts.compactMap { $0() }.count, 0)
    }

    static let allTests = [
        ("testPlainHostReleasesItsViewAndCapturedContent", testPlainHostReleasesItsViewAndCapturedContent),
        ("testWrappingHostReleasesItsViewAndCapturedContent", testWrappingHostReleasesItsViewAndCapturedContent),
        ("testParentRetainsHostUntilTheLastExternalOwnerReleasesIt", testParentRetainsHostUntilTheLastExternalOwnerReleasesIt),
        ("testCompressedWrappingHostReleasesItsMeasurementGraph", testCompressedWrappingHostReleasesItsMeasurementGraph),
        ("testRepeatedHostCreationReleasesEveryRoot", testRepeatedHostCreationReleasesEveryRoot),
    ]
}
#endif
