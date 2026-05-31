import XCTest

/// GalleryTextInputTests — value-fidelity behavior tests for the text
/// inputs that shared the SecureField bug class (the renderer registered
/// the change callback on the NUMERIC channel and called the handler with
/// a hard-coded "", dropping every keystroke). After the fix (register on
/// the STRING channel), these prove the REAL typed text reaches the
/// Crystal handler.
///
/// Pattern (capture-then-reveal, focus-safe):
///   1. Each input's on_change stores "<Kind>: <typed text>" into
///      GalleryState.captured_text WITHOUT rerendering — so typing keeps
///      keyboard focus and the FULL word lands. (Rerendering per keystroke
///      destroys focus; that's a separate known issue.)
///   2. We type a full word into the field.
///   3. We scroll back to the top and tap the live "Tap me" button, which
///      triggers a single Rerender that surfaces GalleryState.captured_text
///      in the `voyager-gallery-captured-text` readout (no accessibility_-
///      label, so XCUIElement.label is its text).
///   4. We assert the readout equals what we typed.
///
/// Definition-of-Done shape: drive the real control via the accessibility
/// API, supply real input, assert the functional outcome.
final class GalleryTextInputTests: XCTestCase {

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

    /// Resolve an input by identifier across the element types SwiftUI may
    /// surface it as (TextField -> textField, TextEditor -> textView).
    private func input(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        for el in [app.textFields[id], app.textViews[id], app.searchFields[id]]
            where el.exists { return el }
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    private func scroll(_ app: XCUIApplication, to element: XCUIElement,
                        up: Bool, max: Int = 16) -> Bool {
        for _ in 0..<max {
            if element.exists && element.isHittable { return true }
            if up { app.swipeDown() } else { app.swipeUp() }
        }
        return element.exists && element.isHittable
    }

    /// Type `text` into the resolved field, then trigger a rerender via the
    /// top "Tap me" button and assert the captured-text readout == expected.
    private func typeAndAssert(_ app: XCUIApplication,
                               fieldId: String,
                               label: String,
                               text: String,
                               expected: String) {
        let field = input(app, fieldId)
        XCTAssertTrue(scroll(app, to: field, up: false),
            "\(label) (\(fieldId)) not reachable in the gallery scroll view.")
        field.tap()
        field.typeText(text)

        // Scroll back to the top (also dismisses the keyboard — the host
        // scroll view uses .keyboardDismissMode = .onDrag) and trigger a
        // single rerender to surface the captured value.
        let tapButton = app.buttons["voyager-gallery-live-tap-button"]
        XCTAssertTrue(scroll(app, to: tapButton, up: true),
            "Live 'Tap me' button not reachable after typing into \(label).")
        tapButton.tap()

        let readout = app.staticTexts["voyager-gallery-captured-text"]
        XCTAssertTrue(readout.waitForExistence(timeout: 4),
            "Captured-text readout missing for \(label).")
        let deadline = Date().addingTimeInterval(5)
        while readout.label != expected && Date() < deadline {
            usleep(150_000)
        }
        XCTAssertEqual(readout.label, expected,
            "\(label): the typed text did not round-trip to the Crystal " +
            "handler. Expected the readout to show '\(expected)' but got " +
            "'\(readout.label)'. This is the SecureField value-drop bug " +
            "class — the string channel is not carrying the real text.")
    }

    func testTextFieldDeliversTypedText() throws {
        let app = launchGallery()
        XCTAssertTrue(app.staticTexts["voyager-gallery-title"].waitForExistence(timeout: 10))
        typeAndAssert(app, fieldId: "voyager-gallery-textfield",
            label: "TextField", text: "alpha", expected: "TextField: alpha")
    }

    func testSearchFieldDeliversTypedText() throws {
        let app = launchGallery()
        XCTAssertTrue(app.staticTexts["voyager-gallery-title"].waitForExistence(timeout: 10))
        typeAndAssert(app, fieldId: "voyager-gallery-searchfield",
            label: "SearchField", text: "bravo", expected: "Search: bravo")
    }

    func testTextAreaDeliversTypedText() throws {
        let app = launchGallery()
        XCTAssertTrue(app.staticTexts["voyager-gallery-title"].waitForExistence(timeout: 10))
        typeAndAssert(app, fieldId: "voyager-gallery-textarea",
            label: "TextArea", text: "charlie", expected: "TextArea: charlie")
    }

    func testTextEditorDeliversTypedText() throws {
        let app = launchGallery()
        XCTAssertTrue(app.staticTexts["voyager-gallery-title"].waitForExistence(timeout: 10))
        typeAndAssert(app, fieldId: "voyager-gallery-texteditor",
            label: "TextEditor", text: "delta", expected: "TextEditor: delta")
    }

    /// ComboBox value-drop fix: on_change was never wired (iOS). The combo
    /// renders as a raw UITextField; the fix attaches a target-action that
    /// routes the field text through the raw string channel. Typing must
    /// now reach the Crystal handler.
    func testComboBoxDeliversTypedText() throws {
        let app = launchGallery()
        XCTAssertTrue(app.staticTexts["voyager-gallery-title"].waitForExistence(timeout: 10))
        typeAndAssert(app, fieldId: "voyager-gallery-combobox",
            label: "ComboBox", text: "echo", expected: "ComboBox: echo")
    }
}
