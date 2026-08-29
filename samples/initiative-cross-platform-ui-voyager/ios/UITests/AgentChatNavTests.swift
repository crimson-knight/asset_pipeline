import XCTest

/// AgentChatNavTests — proves the cross-platform Agent Chat surface is reachable
/// from the live app by DRIVING the real control (per the interactive-view
/// Definition of Done: discoverability is necessary but never sufficient — tap the
/// button and assert the functional outcome).
///
/// Flow: launch at Todos → tap the "Agent" header button → assert the Agent chat
/// mounted (its compose field + send button exist) → tap Back → assert we returned
/// to Todos. This exercises the full Navigate(:agent_chat) + Pop round-trip through
/// the ActionDispatcher + NavigationCoordinator, not just element presence on one
/// screen.
final class AgentChatNavTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTodosAgentButtonNavigatesToAgentChatAndBack() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-todos",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()

        // Todos mounted — the Agent entry point exists.
        let agentButton = app.buttons["voyager-todos-agent"]
        XCTAssertTrue(agentButton.waitForExistence(timeout: 10),
            "Agent button not found on the Todos header.")

        // Tap it — this dispatches :open_agent_chat -> Navigate(:agent_chat).
        agentButton.tap()

        // Functional outcome: the Agent chat screen mounted. Assert on its Back +
        // send buttons (plain Button identifiers surface reliably in the AX tree,
        // like the Agent button just did; SwiftUI-hosted TextFields don't always
        // expose their identifier via app.textFields["id"], so we don't gate on it).
        let back = app.buttons["voyager-agent-chat-back"]
        XCTAssertTrue(back.waitForExistence(timeout: 6),
            "Agent chat did not mount after tapping Agent — Back button never appeared.")
        let send = app.buttons["voyager-agent-chat-send"]
        XCTAssertTrue(send.waitForExistence(timeout: 2),
            "Agent chat send button missing after navigation.")

        // Back pops to Todos (the reverse half of the round-trip).
        back.tap()
        XCTAssertTrue(agentButton.waitForExistence(timeout: 6),
            "Did not return to Todos after tapping Back.")
    }

    /// Proves the compose path works with REAL input + a functional OUTCOME (per the
    /// interactive-view Definition of Done): type a message, tap Send, and assert
    /// the typed text appears as a new bubble in the transcript (the controller
    /// appended it to Voyager::State and the Rerender rebuilt the screen).
    func testTypingAndSendingAppendsMessageToTranscript() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-agent-chat",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()

        // Compose field present (queried by type, like SignInTests — SwiftUI-hosted
        // fields don't always expose their test_id via textFields["id"]).
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10),
            "Agent chat compose field not found.")

        let unique = "Reschedule lunch to 1pm"
        field.tap()
        field.typeText(unique)

        // Send.
        let send = app.buttons["voyager-agent-chat-send"]
        XCTAssertTrue(send.waitForExistence(timeout: 4), "Send button missing.")
        send.tap()

        // Functional outcome: the typed text now appears as a transcript bubble.
        let appended = app.staticTexts[unique]
        XCTAssertTrue(appended.waitForExistence(timeout: 6),
            "Typed message did not appear in the transcript after Send — the input never reached state / the screen did not rebuild.")
    }
}
