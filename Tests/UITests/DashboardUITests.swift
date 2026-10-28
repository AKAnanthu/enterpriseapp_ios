import XCTest

@MainActor
final class DashboardUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func signedInApp(_ scenario: UITestApp.Scenario = .standard) -> XCUIApplication {
        let app = UITestApp.launch(scenario)
        LoginScreen(app: app).waitUntilVisible().signIn()
        XCTAssertTrue(app.tab("Home").waitForExistence(timeout: UITestApp.timeout))
        return app
    }

    func testDashboardLoadsMetricsAndActivity() {
        let app = signedInApp()

        XCTAssertTrue(app.element("metric.revenue").waitForExistence(timeout: UITestApp.timeout))
        XCTAssertTrue(app.element("metric.transactions").exists)
        XCTAssertTrue(app.element("home.activity.row.act-1001").waitForExistence(timeout: UITestApp.timeout))
    }

    func testDashboardEmptyState() {
        let app = signedInApp(.emptyDashboard)

        XCTAssertTrue(app.element("home.activity.empty").waitForExistence(timeout: UITestApp.timeout))
        XCTAssertTrue(app.element("home.metrics.empty").exists)
    }

    func testDashboardFailureShowsRetry() {
        let app = signedInApp(.dashboardFailure)

        XCTAssertTrue(app.element("state.error").waitForExistence(timeout: UITestApp.timeout))
        XCTAssertTrue(app.buttons["state.retryButton"].exists)
    }

    func testTabNavigation() {
        let app = signedInApp()

        app.tab("Analytics").tap()
        XCTAssertTrue(app.element("analytics.chart.revenue").waitForExistence(timeout: UITestApp.timeout))

        app.tab("Notifications").tap()
        XCTAssertTrue(app.element("notifications.row.ntf-1").waitForExistence(timeout: UITestApp.timeout))

        app.tab("Profile").tap()
        XCTAssertTrue(app.element("profile.header").waitForExistence(timeout: UITestApp.timeout))

        app.tab("Home").tap()
        XCTAssertTrue(app.element("home.greeting").waitForExistence(timeout: UITestApp.timeout))
    }

    func testQuickActionOpensActivityList() {
        let app = signedInApp()

        let quickAction = app.buttons["home.quickAction.activity"]
        XCTAssertTrue(quickAction.waitForExistence(timeout: UITestApp.timeout))
        quickAction.tap()

        XCTAssertTrue(app.element("activity.list").waitForExistence(timeout: UITestApp.timeout))
    }

    func testLogoutReturnsToLogin() {
        let app = signedInApp()
        app.tab("Profile").tap()

        let signOut = app.buttons["profile.signOutButton"]
        XCTAssertTrue(signOut.waitForExistence(timeout: UITestApp.timeout))
        signOut.tap()

        // The dialog can expose the action more than once (popover + sheet), so take the first match.
        var confirm = app.buttons.matching(identifier: "profile.confirmSignOut").firstMatch
        if !confirm.waitForExistence(timeout: 3) {
            // Fallback for dialog presentations that don't surface the identifier.
            confirm = app.buttons.matching(NSPredicate(format: "label == 'Sign Out' AND identifier != 'profile.signOutButton'")).firstMatch
        }
        XCTAssertTrue(confirm.waitForExistence(timeout: UITestApp.timeout))
        confirm.tap()

        XCTAssertTrue(app.buttons["login.submitButton"].waitForExistence(timeout: UITestApp.timeout))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }
}
