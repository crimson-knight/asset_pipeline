import XCTest

/// SignInTests — proves the sign-in form actually works end-to-end on
/// device: a typed email AND a typed password reach the controller via
/// FormState, and the controller's non-empty-credentials branch fires
/// (ReplaceRoot -> todos).
///
/// Regression guard for the SecureField bug: the UIKit/AppKit renderers
/// used to register the SecureField change token on the NUMERIC callback
/// channel and invoke the handler with a hard-coded "" — so the typed
/// password never reached FormState. SignInController#submit gates on a
/// non-empty password, so sign-in was IMPOSSIBLE: every submit hit the
/// "Please provide both email and password" branch. The fix registers
/// the SecureField token on the STRING channel (register_string) like
/// TextField, so the real cleartext flows through TextStorage.fireString.
final class SignInTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchSignIn() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VoyagerRoot", "voyager-sign-in"]
        app.launchEnvironment = [
            "VOYAGER_ROOT_SLUG": "voyager-sign-in",
            "VOYAGER_SKIP_NOTIF_PROMPT": "1",
        ]
        app.launch()
        return app
    }

    /// Type email + password, tap Sign in, assert we land on Todos.
    func testTypedCredentialsSignInReachesTodos() throws {
        let app = launchSignIn()

        // Sign-in button proves the screen mounted.
        let signIn = app.buttons["voyager-sign-in-submit"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10),
            "Sign-in screen did not mount.")

        // Resolve the two fields. The SwiftUI-hosted fields surface as
        // secureTextFields (password) and textFields (email) in the AX
        // tree; fall back to test_id lookups across all element types.
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 5),
            "Email text field not found in AX tree.")
        emailField.tap()
        emailField.typeText("captain@voyager.app")

        let passwordField = app.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5),
            "Secure password field not found in AX tree.")
        passwordField.tap()
        passwordField.typeText("hunter2")

        // Submit.
        signIn.tap()

        // Success = we navigated to Todos. The Add-Todo button's test_id
        // is unique to the Todos screen, so its presence proves the
        // ReplaceRoot(:todos) branch fired — which only happens when BOTH
        // email and password arrived non-empty in FormState.
        let addTodo = app.buttons["voyager-todos-add"]
        let settings = app.buttons["voyager-todos-settings"]
        let reachedTodos =
            addTodo.waitForExistence(timeout: 6) ||
            settings.waitForExistence(timeout: 2)

        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = "post-signin"
        att.lifetime = .keepAlways
        add(att)

        XCTAssertTrue(reachedTodos,
            "Sign-in did not reach the Todos screen. The typed password " +
            "likely did not reach FormState (SecureField string-channel " +
            "regression), so SignInController#submit hit the empty-field " +
            "branch and re-rendered sign-in instead of ReplaceRoot(:todos).")
    }
}
