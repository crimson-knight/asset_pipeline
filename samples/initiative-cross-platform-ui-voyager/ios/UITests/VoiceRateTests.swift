import XCTest

/// VoiceRateTests — the Settings "Voice speed" slider drives UI::Speech rate.
/// Regression guard for the class-init-gap crash: dragging the slider used to
/// route through Float#to_s / String#to_f? (FastFloat tables uninitialized under
/// the Swift @main embedding) → SIGSEGV. The integer-percent transport fixed it.
/// This drives the real slider and asserts the readout updates (functional
/// outcome) — which also proves the app didn't crash.
final class VoiceRateTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testVoiceSpeedSliderUpdatesReadout() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-settings",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
            "VOYAGER_RESET_PREFS": "1", // start at the 50% default
        ]
        app.launch()

        let readout = app.staticTexts["voyager-settings-speech-rate-readout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 10), "Voice speed readout missing — Settings didn't mount.")
        XCTAssertEqual(readout.label, "Voice speed: 50%", "Default voice speed should be 50%.")

        // Drag the slider to its max — range is 0.35–0.65, so position 1.0 → 65%.
        // This is the exact interaction that used to SIGSEGV (Float#to_s in on_change
        // + String#to_f? in the controller). If the app crashes here, the next query
        // fails the test.
        let slider = app.sliders["voyager-settings-speech-rate"]
        XCTAssertTrue(slider.waitForExistence(timeout: 4), "Voice speed slider missing.")
        slider.adjust(toNormalizedSliderPosition: 1.0)

        // Functional outcome: the readout moved UP from the 50% default — proving the
        // slider value reached state via the integer-percent path AND (critically)
        // that the app did NOT crash on it (pre-fix this SIGSEGV'd in FastFloat).
        // We assert "increased" rather than an exact value: XCUITest's slider adjust
        // doesn't drag a custom UISlider to a precise position, but any upward move
        // exercises the same on_change → dispatch → parse path.
        let maxed = app.staticTexts["voyager-settings-speech-rate-readout"]
        XCTAssertTrue(maxed.waitForExistence(timeout: 6))
        let pct = Int(maxed.label.filter { $0.isNumber }) ?? -1
        XCTAssertGreaterThan(pct, 50,
            "Readout was \"\(maxed.label)\" after dragging up — the slider value did " +
            "not reach state (or the app crashed on the float-parse path).")

        // Preview button must also run the speak path without crashing.
        let preview = app.buttons["voyager-settings-preview-voice"]
        XCTAssertTrue(preview.waitForExistence(timeout: 4), "Preview voice button missing.")
        preview.tap()
        // Still responsive afterwards → no crash.
        XCTAssertTrue(app.staticTexts["voyager-settings-speech-rate-readout"].waitForExistence(timeout: 4),
            "App became unresponsive after Preview voice — possible crash in the speak path.")
    }
}
