import XCTest

/// VoiceToggleTests — proves the Agent Chat header's voice mute/unmute control is
/// FUNCTIONAL (per the interactive-view Definition of Done): tapping it mutates
/// Voyager.state.speak_replies and the screen rebuilds with the new glyph/label.
/// The control gates UI::Speech (the agent's spoken replies) — the gate's speech
/// effect is proven on the watch (real-path muted/unmuted speaking check); here we
/// prove the visible iOS control flips state via the accessibility tree the user sees.
final class VoiceToggleTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testVoiceToggleFlipsState() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-agent-chat",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()

        // Defaults to ON: the control offers to MUTE.
        let voice = app.buttons["voyager-agent-chat-voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 10), "Voice control missing — screen didn't mount.")
        XCTAssertEqual(voice.label, "Mute agent voice",
            "Voice control should start in the speaking state (offering to mute).")

        // Tap → mutes → control now offers to UNMUTE (state mutated + screen rebuilt).
        voice.tap()
        let unmuted = app.buttons["voyager-agent-chat-voice"]
        XCTAssertTrue(unmuted.waitForExistence(timeout: 6))
        XCTAssertEqual(unmuted.label, "Unmute agent voice",
            "After tapping, the control did not flip — toggle_voice never reached state / no rebuild.")

        // Tap again → back to speaking.
        unmuted.tap()
        let remuted = app.buttons["voyager-agent-chat-voice"]
        XCTAssertTrue(remuted.waitForExistence(timeout: 6))
        XCTAssertEqual(remuted.label, "Mute agent voice",
            "Second tap did not restore the speaking state.")
    }
}
