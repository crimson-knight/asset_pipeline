import XCTest

final class PropertyMeasurementTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    // MapKit exposes its identified MKMapView as an Other container on iOS26,
    // with an unlabelled Map child. Target the actual stable view identity,
    // independent of the OS's accessibility element classification.
    private func map(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["property-map"]
    }

    private func launch(fresh: Bool = true, dark: Bool = false, refreshOnDraft: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (fresh ? ["--fresh-fixture"] : []) + (dark ? ["--dark"] : []) + (refreshOnDraft ? ["--refresh-on-draft"] : [])
        app.launch()
        XCTAssertTrue(map(app).waitForExistence(timeout: 15), app.debugDescription)
        return app
    }

    private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) {
        map(app).coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
    }

    private func square(_ app: XCUIApplication, inset: CGFloat) {
        point(app, inset, inset); point(app, 1 - inset, inset)
        point(app, 1 - inset, 1 - inset); point(app, inset, 1 - inset)
    }

    private func valid(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["property-save"].isEnabled, app.staticTexts["property-validation"].label)
        XCTAssertEqual(app.staticTexts["property-validation"].value as? String, "valid")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func refreshReceipt(_ app: XCUIApplication) throws -> String {
        app.buttons["fixture-refresh"].tap()
        let value = try XCTUnwrap(app.staticTexts["fixture-receipt"].value as? String)
        XCTAssertTrue(value.contains("same-native-view=true"))
        return value
    }

    private func longitude(_ receipt: String) throws -> Double {
        let camera = try XCTUnwrap(receipt.components(separatedBy: ";").first { $0.hasPrefix("camera=") })
        return try XCTUnwrap(Double(try XCTUnwrap(camera.components(separatedBy: ",").last)))
    }

    private func keyboardAction(_ app: XCUIApplication, _ title: String) {
        let button = app.toolbars.buttons[title]
        XCTAssertTrue(button.exists, title)
        XCTAssertTrue(button.isHittable, title)
        // The accessory belongs to the keyboard window, not the alert subtree.
        // XCUIElement.tap() otherwise auto-cancels the expected app alert as an
        // interruption. Anchor the observed control center to the expected
        // alert so XCTest does not auto-dismiss it before sending the tap.
        // The actual focused field is independently verified with typed input.
        let alert = app.alerts["Edit point"]
        let target = button.frame
        let origin = alert.frame
        alert.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: target.midX - origin.minX, dy: target.midY - origin.minY)).tap()
    }

    func testNativeControlsHaveUsableTouchTargets() {
        let app = launch()
        for id in ["property-ring", "property-point", "property-save", "property-undo", "property-reset"] {
            let control = app.buttons[id]
            XCTAssertTrue(control.exists, id)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44, id)
            XCTAssertGreaterThanOrEqual(control.frame.width, 44, id)
        }
        for (id, count) in [("property-mode", 3), ("property-imagery", 2)] {
            let buttons = app.segmentedControls[id].buttons
            XCTAssertEqual(buttons.count, count, id)
            for button in buttons.allElementsBoundByIndex {
                XCTAssertGreaterThanOrEqual(button.frame.height, 44, id)
                XCTAssertGreaterThanOrEqual(button.frame.width, 44, id)
            }
        }
        XCTAssertGreaterThanOrEqual(map(app).frame.height, 220)
        capture(app, "property-outline-ready-touch-targets")
    }

    func testDraftCallbacksCanRefreshWithoutReplacingNativeMap() throws {
        let app = launch(refreshOnDraft: true)
        square(app, inset: 0.25)
        valid(app)
        XCTAssertEqual(app.buttons["property-ring"].value as? String, "4 points")
        let before = try refreshReceipt(app)
        XCTAssertEqual(try refreshReceipt(app), before)
        app.buttons["property-undo"].tap()
        valid(app)
        XCTAssertEqual(app.buttons["property-ring"].value as? String, "3 points")
        XCTAssertTrue(try refreshReceipt(app).contains("same-native-view=true"))
    }

    func testDrawExcludeUndoSaveAndRestoreFromDisk() throws {
        var app = launch()
        XCTAssertFalse(app.buttons["property-save"].isEnabled)
        point(app, 0.2, 0.2); point(app, 0.8, 0.2)
        XCTAssertFalse(app.buttons["property-save"].isEnabled)
        point(app, 0.8, 0.8); point(app, 0.2, 0.8)
        valid(app)
        app.buttons["property-ring"].tap(); app.buttons["Add exclusion"].tap()
        XCTAssertFalse(app.buttons["property-save"].isEnabled)
        square(app, inset: 0.4)
        valid(app)
        capture(app, "property-outline-light-with-exclusion")
        app.buttons["property-undo"].tap()
        XCTAssertEqual(app.buttons["property-ring"].value as? String, "3 points")
        valid(app)
        app.buttons["property-save"].tap()
        let receipt = app.staticTexts["fixture-receipt"]
        XCTAssertEqual(receipt.label, "Outline saved on this device")
        let saved = try XCTUnwrap(receipt.value as? String)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(saved.utf8)) as? [String: Any])
        XCTAssertEqual(object["schema"] as? String, "ap.property-outline.v1")
        XCTAssertEqual((object["ring_ids"] as? [String])?.count, 2)
        XCTAssertEqual((object["measurement"] as? [String: Any])?["method"] as? String, "spherical_cylindrical_equal_area_v1")
        app.terminate()
        app = launch(fresh: false)
        XCTAssertEqual(app.staticTexts["fixture-receipt"].label, "Saved outline restored from this device")
        XCTAssertEqual(app.staticTexts["fixture-receipt"].value as? String, saved)
        valid(app)
        app.buttons["property-reset"].tap(); app.alerts.buttons["Reset outline"].tap()
        XCTAssertFalse(app.buttons["property-save"].isEnabled)
        app.buttons["property-undo"].tap(); valid(app)
    }

    func testCrossedOutlineCannotSaveAndUndoRecovers() {
        let app = launch(dark: true)
        point(app, 0.2, 0.2); point(app, 0.8, 0.8); point(app, 0.8, 0.2); point(app, 0.2, 0.8)
        XCTAssertFalse(app.buttons["property-save"].isEnabled)
        XCTAssertTrue(app.staticTexts["property-validation"].label.contains("cross"))
        capture(app, "property-outline-dark-crossing-error")
        app.buttons["property-undo"].tap(); valid(app)
        capture(app, "property-outline-dark-valid")
    }

    func testCameraDraftAndOverlayIdentitySurviveRefreshAndImagerySwitch() throws {
        let app = launch()
        square(app, inset: 0.25); valid(app)
        let original = try refreshReceipt(app)
        app.segmentedControls["property-mode"].buttons["Pan"].tap()
        map(app).swipeLeft()
        // A swipe legitimately keeps decelerating after the gesture. Wait for
        // two observed stable samples; a reset-to-center cannot satisfy the
        // independent displacement assertion. No fixed sleep or loose camera
        // tolerance replaces the subsequent exact identity/draft comparison.
        var before = ""
        var stableSamples = 0
        for _ in 0..<12 {
            let current = try refreshReceipt(app)
            stableSamples = current == before ? stableSamples + 1 : 0
            before = current
            if stableSamples >= 2 { break }
        }
        XCTAssertGreaterThanOrEqual(stableSamples, 2, "Map camera did not settle")
        XCTAssertGreaterThan(abs(try longitude(before) - longitude(original)), 0.0001, "Pan must not reset to the configured center")
        XCTAssertEqual(try refreshReceipt(app), before)
        valid(app)
        app.segmentedControls["property-imagery"].buttons["Satellite"].tap()
        app.buttons["fixture-refresh"].tap()
        let after = try XCTUnwrap(app.staticTexts["fixture-receipt"].value as? String)
        XCTAssertTrue(after.contains("same-native-view=true"))
        XCTAssertEqual(after.components(separatedBy: ";draft=").first, before.components(separatedBy: ";draft=").first)
        capture(app, "property-outline-satellite-panned")
    }

    func testCoordinateKeyboardNavigationAndPointMoveRemove() {
        let app = launch()
        square(app, inset: 0.2); valid(app)
        app.buttons["property-point"].tap(); app.buttons["Select next point"].tap()
        app.buttons["property-point"].tap(); app.buttons["Edit selected coordinates"].tap()
        let longitude = app.textFields["property-longitude"]
        XCTAssertTrue(longitude.waitForExistence(timeout: 5))
        longitude.tap()
        XCTAssertTrue(app.buttons["Next"].exists)
        let latitude = app.textFields["property-latitude"]
        let originalLatitude = latitude.value as? String ?? ""
        keyboardAction(app, "Next")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.alerts["Edit point"].typeText("0")
        XCTAssertEqual(latitude.value as? String, originalLatitude + "0", "Next must focus latitude")
        keyboardAction(app, "Previous")
        let existing = longitude.value as? String ?? ""
        app.alerts["Edit point"].typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + "1000")
        XCTAssertEqual(longitude.value as? String, "1000", "Previous must focus longitude")
        XCTAssertEqual(latitude.value as? String, originalLatitude + "0")
        XCTAssertFalse(app.alerts.buttons["Move point"].isEnabled, "Invalid coordinates must visibly disable the action while typing")
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "finite longitude")).firstMatch.exists)
        capture(app, "property-coordinate-keyboard-navigation")
        keyboardAction(app, "Done")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertFalse(app.alerts.buttons["Move point"].isEnabled)
        longitude.tap()
        app.alerts["Edit point"].typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        XCTAssertFalse(app.alerts.buttons["Move point"].isEnabled, "An empty coordinate cannot be applied")
        app.alerts["Edit point"].typeText(existing)
        XCTAssertTrue(app.alerts.buttons["Move point"].isEnabled, "Correcting the value must enable the action again")
        keyboardAction(app, "Done")
        app.alerts.buttons["Move point"].tap()
        valid(app)
        app.buttons["property-point"].tap(); app.buttons["Remove selected point"].tap()
        valid(app)
        XCTAssertEqual(app.buttons["property-ring"].value as? String, "3 points")
        app.buttons["property-undo"].tap(); valid(app)
        XCTAssertEqual(app.buttons["property-ring"].value as? String, "4 points")
        // Real map gesture edits a selected vertex; a normal screen update
        // must not discard the edited polygon or turn it into a fresh draft.
        app.segmentedControls["property-mode"].buttons["Edit"].tap()
        point(app, 0.2, 0.2); point(app, 0.3, 0.3)
        valid(app)
        app.buttons["fixture-refresh"].tap()
        XCTAssertTrue((app.staticTexts["fixture-receipt"].value as? String ?? "").contains("same-native-view=true"))
    }
}
