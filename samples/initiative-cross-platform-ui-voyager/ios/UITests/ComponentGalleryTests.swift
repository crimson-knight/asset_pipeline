import XCTest

/// ComponentGalleryTests — proves the Component Gallery catalog renders
/// every widget section natively on-device.
///
/// Two kinds of evidence:
///   1. AX-tree assertions: a representative widget from EVERY section is
///      discoverable by accessibility label, which proves the Crystal
///      screen built and the UIKit renderer emitted a real native view
///      for each widget family (not a silent placeholder).
///   2. Visual capture: swipe through the gallery attaching a screenshot
///      at each scroll position so the lower sections are reviewable.
final class ComponentGalleryTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchGallery() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", "voyager-component-gallery"]
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-component-gallery",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()
        return app
    }

    /// Every section's representative widget must exist in the AX tree.
    func testAllSectionsRender() throws {
        let app = launchGallery()

        let title = app.staticTexts["voyager-gallery-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10),
            "Component Gallery did not mount within 10s.")

        // One representative AX label per section. `firstMatch` +
        // a scroll fallback: XCUITest can resolve off-screen elements in
        // a scroll view, but we swipe to be safe for the bottom-most ones.
        let expected: [(kind: String, id: String)] = [
            ("button",  "Prominent button sample"),
            ("button",  "Destructive button sample"),
            ("other",   "Toggle sample"),
            ("other",   "Segmented control sample"),
            ("other",   "Slider sample"),
            ("other",   "Stepper sample"),
            ("other",   "Text field sample"),
            ("other",   "Search field sample"),
            ("other",   "Linear progress sample"),
            ("other",   "Gauge sample"),
            ("image",   "leaf.fill symbol"),
            ("other",   "Card sample"),
            ("other",   "Time picker sample"),
            ("other",   "Disclosure group sample"),
            ("other",   "Page control sample"),
            ("other",   "Chart sample"),
            ("other",   "Activity rings sample"),
            ("other",   "Snackbar sample"),
            ("other",   "Canvas sample"),
            ("other",   "Path view sample"),
        ]

        var missing: [String] = []
        for item in expected {
            // Search across all element types by label/identifier.
            let byAny = app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@ OR identifier == %@", item.id, item.id)
            ).firstMatch
            if !byAny.waitForExistence(timeout: 2) {
                // Try scrolling it into view, then re-check.
                app.swipeUp()
                if !byAny.waitForExistence(timeout: 2) {
                    missing.append(item.id)
                }
            }
        }

        XCTAssertTrue(missing.isEmpty,
            "Gallery sections missing native widgets in AX tree: \(missing.joined(separator: ", ")). " +
            "Those widget families did not render.")
    }

    /// Visual capture: screenshot each scroll position for human review.
    func testCaptureScrollSequence() throws {
        let app = launchGallery()
        XCTAssertTrue(app.staticTexts["voyager-gallery-title"].waitForExistence(timeout: 10),
            "Gallery did not mount.")

        for i in 0..<9 {
            Thread.sleep(forTimeInterval: 0.4)
            let shot = XCUIScreen.main.screenshot()
            let att = XCTAttachment(screenshot: shot)
            att.name = "gallery-scroll-\(i)"
            att.lifetime = .keepAlways
            add(att)

            let dir = ProcessInfo.processInfo.environment["GALLERY_SHOT_DIR"]
            if let dir = dir {
                let url = URL(fileURLWithPath: "\(dir)/gallery-scroll-\(i).png")
                try? shot.pngRepresentation.write(to: url, options: .atomic)
            }
            app.swipeUp()
        }
    }
}
