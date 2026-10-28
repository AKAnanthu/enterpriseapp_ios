import XCTest

@MainActor
final class LoginUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testLoginScreenRenders() {
        let app = UITestApp.launch()
        let login = LoginScreen(app: app).waitUntilVisible()

        XCTAssertTrue(app.staticTexts["Welcome back"].exists)
        XCTAssertTrue(login.identifierField.exists)
        XCTAssertTrue(login.passwordField.exists)
        XCTAssertTrue(app.buttons["login.passwordField.visibilityToggle"].exists)
        XCTAssertTrue(app.buttons["login.forgotPasswordButton"].exists)
        XCTAssertTrue(login.submitButton.isEnabled)
    }

    func testEmptySubmissionShowsValidationErrors() {
        let app = UITestApp.launch()
        let login = LoginScreen(app: app).waitUntilVisible()

        login.submitButton.tap()

        XCTAssertTrue(app.element("login.identifierField.error").waitForExistence(timeout: UITestApp.timeout))
        XCTAssertTrue(app.element("login.passwordField.error").exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    func testInvalidEmailShowsFormatError() {
        let app = UITestApp.launch()
        let login = LoginScreen(app: app).waitUntilVisible()

        login.signIn(email: "not-an-email", password: "x")

        let error = app.element("login.identifierField.error")
        XCTAssertTrue(error.waitForExistence(timeout: UITestApp.timeout))
        XCTAssertTrue(error.label.contains("valid email"))
    }

    func testPasswordVisibilityToggle() {
        let app = UITestApp.launch()
        let login = LoginScreen(app: app).waitUntilVisible()
        login.type("secret", into: login.passwordField)

        app.buttons["login.passwordField.visibilityToggle"].tap()

        XCTAssertTrue(app.textFields["login.passwordField"].waitForExistence(timeout: UITestApp.timeout))
        XCTAssertEqual(app.textFields["login.passwordField"].value as? String, "secret")
    }

    func testRejectedCredentialsShowError() {
        let app = UITestApp.launch()
        let login = LoginScreen(app: app).waitUntilVisible()

        login.signIn(password: "wrong-password")

        XCTAssertTrue(login.errorBanner.waitForExistence(timeout: UITestApp.timeout))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    func testLoginShowsProgressWhileSigningIn() {
        let app = UITestApp.launch(.slowLogin)
        let login = LoginScreen(app: app).waitUntilVisible()

        login.signIn()

        XCTAssertTrue(app.element("login.progress").waitForExistence(timeout: 2))
        XCTAssertTrue(app.tab("Home").waitForExistence(timeout: UITestApp.timeout))
    }

    func testSuccessfulLoginOpensDashboard() {
        let app = UITestApp.launch()
        LoginScreen(app: app).waitUntilVisible().signIn()

        XCTAssertTrue(app.tab("Home").waitForExistence(timeout: UITestApp.timeout))
        XCTAssertTrue(app.element("home.greeting").waitForExistence(timeout: UITestApp.timeout))
        XCTAssertTrue(app.staticTexts["Alex Morgan"].exists)
    }
}
