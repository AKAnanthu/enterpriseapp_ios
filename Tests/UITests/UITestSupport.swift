import XCTest

/// Launches the app against the DEBUG demo backend (`-ui-testing`), which also uses an in-memory
/// token store, so every launch starts signed out and never touches real credentials or servers.
@MainActor
enum UITestApp {
    enum Scenario: String {
        case standard
        case emptyDashboard = "empty-dashboard"
        case dashboardFailure = "dashboard-failure"
        case slowLogin = "slow-login"
    }

    static let timeout: TimeInterval = 10

    static func launch(_ scenario: Scenario = .standard) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["MOCK_SCENARIO"] = scenario.rawValue
        app.launch()
        return app
    }
}

@MainActor
struct LoginScreen {
    let app: XCUIApplication

    var identifierField: XCUIElement { app.textFields["login.identifierField"] }
    var passwordField: XCUIElement { app.secureTextFields["login.passwordField"] }
    var submitButton: XCUIElement { app.buttons["login.submitButton"] }
    var errorBanner: XCUIElement { app.descendants(matching: .any)["login.errorBanner"] }

    @discardableResult
    func waitUntilVisible(file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(submitButton.waitForExistence(timeout: UITestApp.timeout), "Login screen did not appear", file: file, line: line)
        XCTAssertTrue(identifierField.waitUntilHittable(), "Login form is not interactive", file: file, line: line)
        return self
    }

    func type(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        // A tap right after a screen transition can land before the field accepts focus; retry briefly.
        for _ in 0..<3 where !field.hasKeyboardFocus {
            field.tap()
            _ = field.waitForKeyboardFocus(timeout: 2)
        }
        XCTAssertTrue(field.hasKeyboardFocus, "Field did not receive keyboard focus", file: file, line: line)
        field.typeText(text)
    }

    /// Dismisses the keyboard with the keyboard toolbar's Done button so the Sign In button is not covered.
    func dismissKeyboard() {
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 2) { done.tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    func signIn(email: String = "alex.morgan@example.com", password: String = "demo-password") {
        type(email, into: identifierField)
        type(password, into: passwordField)
        dismissKeyboard()
        submitButton.tap()
    }
}

extension XCUIElement {
    var hasKeyboardFocus: Bool {
        (value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    func waitForKeyboardFocus(timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitUntilHittable(timeout: TimeInterval = UITestApp.timeout) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

extension XCUIApplication {
    func tab(_ label: String) -> XCUIElement {
        tabBars.buttons[label]
    }

    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }
}
