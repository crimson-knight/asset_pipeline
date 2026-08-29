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
            "VOYAGER_RESET_PREFS": "1", // known default (voice ON) regardless of prior runs
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

    /// Proves UI::Preferences (NSUserDefaults) genuinely persists across relaunch:
    /// mute the agent, terminate + relaunch the app, and assert the control comes
    /// back MUTED — only true if AgentChatController persisted speak_replies and
    /// State.new read it back on the next launch. (Functional outcome, not a flag.)
    func testVoicePreferencePersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-agent-chat",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()

        let voice = app.buttons["voyager-agent-chat-voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 10), "Voice control missing.")
        // Normalize to a known ON state (a prior run may have left it muted).
        if voice.label == "Unmute agent voice" { voice.tap() }
        XCTAssertEqual(app.buttons["voyager-agent-chat-voice"].label, "Mute agent voice")

        // Mute → should persist.
        app.buttons["voyager-agent-chat-voice"].tap()
        XCTAssertEqual(app.buttons["voyager-agent-chat-voice"].label, "Unmute agent voice")

        // Relaunch the app fresh.
        app.terminate()
        app.launch()

        // The muted choice must have survived (NSUserDefaults read in State.new).
        let after = app.buttons["voyager-agent-chat-voice"]
        XCTAssertTrue(after.waitForExistence(timeout: 10), "Voice control missing after relaunch.")
        XCTAssertEqual(after.label, "Unmute agent voice",
            "Voice preference did NOT persist across relaunch — UI::Preferences didn't store/read it.")

        // Restore ON so reruns start clean.
        after.tap()
    }
}
