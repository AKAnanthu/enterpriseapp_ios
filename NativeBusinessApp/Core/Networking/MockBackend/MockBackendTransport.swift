#if DEBUG
import Foundation

/// Scenarios for the DEBUG demo backend, selected with the `MOCK_SCENARIO` environment variable.
enum MockScenario: String, Sendable, CaseIterable {
    /// Populated dashboard, notifications and profile.
    case standard
    /// Every list endpoint returns an empty collection.
    case emptyDashboard = "empty-dashboard"
    /// Dashboard endpoints return 500 (other endpoints succeed).
    case dashboardFailure = "dashboard-failure"
    /// Login is slow (2 s) so the loading state can be observed.
    case slowLogin = "slow-login"
}

/// An in-process fake of the illustrative REST contract, compiled into DEBUG builds only.
///
/// It is a `HTTPTransport`, so requests still flow through `RequestBuilder`, `HTTPClient`,
/// `AuthenticatedAPIClient` and the real DTO decoding. It is NOT a description of a real backend.
///
/// Credentials: any identifier with any password signs in, except the password
/// `wrong-password`, which returns 401.
struct MockBackendTransport: HTTPTransport {
    static let rejectedPassword = "wrong-password"
    static let accessToken = "demo-access-token"
    static let refreshToken = "demo-refresh-token"

    let scenario: MockScenario
    var latency: Duration = .milliseconds(250)
    var now: @Sendable () -> Date = { Date() }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path() ?? ""
        let method = request.httpMethod ?? "GET"
        let isLogin = method == "POST" && path.hasSuffix("/auth/login")
        try await Task.sleep(for: isLogin && scenario == .slowLogin ? .seconds(2) : latency)

        let (status, body) = route(method: method, path: path, request: request)
        let url = request.url ?? URL(filePath: "/")
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Type": "application/json"]) else {
            throw URLError(.badServerResponse)
        }
        let data = try body.map { try JSONSerialization.data(withJSONObject: $0) } ?? Data()
        return (data, response)
    }

    // MARK: Routing

    private func route(method: String, path: String, request: URLRequest) -> (Int, Any?) {
        switch (method, path) {
        case ("POST", let p) where p.hasSuffix("/auth/login"):
            return login(request)
        case ("POST", let p) where p.hasSuffix("/auth/refresh"):
            return (200, tokens())
        case ("POST", let p) where p.hasSuffix("/auth/logout"):
            return (204, nil)
        default:
            break
        }

        guard request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.accessToken)" else {
            return (401, ["error": "unauthorized"])
        }

        switch (method, path) {
        case ("GET", let p) where p.hasSuffix("/auth/me"):
            return (200, user())
        case ("GET", let p) where p.hasSuffix("/dashboard/summary"):
            if scenario == .dashboardFailure { return (500, ["error": "internal"]) }
            return (200, ["metrics": scenario == .emptyDashboard ? [] : metrics(), "generatedAt": iso(now())])
        case ("GET", let p) where p.hasSuffix("/dashboard/activity"):
            if scenario == .dashboardFailure { return (500, ["error": "internal"]) }
            return (200, ["items": scenario == .emptyDashboard ? [] : activity()])
        case ("GET", let p) where p.hasSuffix("/analytics/overview"):
            let range = URLComponents(url: request.url ?? URL(filePath: "/"), resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "range" }?.value ?? "30d"
            return (200, scenario == .emptyDashboard ? ["metrics": [], "series": []] : analytics(range: range))
        case ("GET", let p) where p.hasSuffix("/notifications"):
            return (200, ["items": scenario == .emptyDashboard ? [] : notifications()])
        case ("PATCH", let p) where p.contains("/notifications/"),
             ("POST", let p) where p.hasSuffix("/notifications/read-all"):
            return (204, nil)
        case ("GET", let p) where p.hasSuffix("/profile"):
            return (200, profile())
        default:
            return (404, ["error": "not_found"])
        }
    }

    private func login(_ request: URLRequest) -> (Int, Any?) {
        guard
            let body = request.httpBody,
            let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
            let password = json["password"] as? String
        else {
            return (400, ["error": "invalid_request"])
        }
        guard password != Self.rejectedPassword else {
            return (401, ["error": "invalid_credentials"])
        }
        var response = tokens()
        response["user"] = user()
        return (200, response)
    }

    // MARK: Fixtures

    private func tokens() -> [String: Any] {
        ["accessToken": Self.accessToken, "refreshToken": Self.refreshToken, "expiresIn": 900, "tokenType": "Bearer"]
    }

    private func user() -> [String: Any] {
        ["id": "demo-user", "name": "Alex Morgan", "email": "alex.morgan@example.com"]
    }

    private func profile() -> [String: Any] {
        [
            "id": "demo-user", "name": "Alex Morgan", "email": "alex.morgan@example.com",
            "role": "Operations Manager", "organization": "Example Organization",
            "memberSince": iso(now().addingTimeInterval(-400 * 86_400)),
        ]
    }

    private func metrics() -> [[String: Any]] {
        [
            ["id": "transactions", "title": "Total transactions", "value": 1_284, "format": "count", "changePercent": 6.4],
            ["id": "revenue", "title": "Monthly revenue", "value": 48_250.75, "format": "currency", "currencyCode": "USD", "changePercent": 3.1],
            ["id": "pending", "title": "Pending items", "value": 17, "format": "count", "changePercent": -12.5],
            ["id": "completion", "title": "Completion rate", "value": 0.942, "format": "percentage", "changePercent": 0.8],
        ]
    }

    private func activity() -> [[String: Any]] {
        let entries: [(String, String, String, Double, String, Double?)] = [
            ("act-1001", "Invoice #1001 settled", "Billing", 0.2, "completed", 1_250),
            ("act-1002", "New client onboarded", "Accounts", 2, "completed", nil),
            ("act-1003", "Purchase order awaiting approval", "Procurement", 5, "pending", 3_400),
            ("act-1004", "Payment retry failed", "Billing", 26, "failed", 89.99),
            ("act-1005", "Quarterly report generated", "Reporting", 50, "completed", nil),
            ("act-1006", "Support ticket escalated", "Support", 75, "pending", nil),
        ]
        return entries.map { id, title, category, hoursAgo, status, amount in
            var item: [String: Any] = [
                "id": id, "title": title, "category": category, "status": status,
                "description": category, "occurredAt": iso(now().addingTimeInterval(-hoursAgo * 3_600)),
            ]
            if let amount {
                item["amount"] = amount
                item["currencyCode"] = "USD"
            }
            return item
        }
    }

    private func analytics(range: String) -> [String: Any] {
        let days = switch range {
        case "7d": 7
        case "90d": 90
        default: 30
        }
        let revenue = (0..<days).map { day -> [String: Any] in
            let wave: Double = 350 * sin(Double(day) / 4)
            let value: Double = 1_400 + wave + Double(day * 9)
            return ["date": daysAgo(days - 1 - day), "value": value.rounded()]
        }
        let orderDays = min(days, 14)
        let orders = (0..<orderDays).map { day -> [String: Any] in
            let value: Int = 30 + (day * 7) % 25
            return ["date": daysAgo(orderDays - 1 - day), "value": value]
        }
        return [
            "metrics": [
                ["id": "avg-order", "title": "Average order value", "value": 182.4, "format": "currency", "currencyCode": "USD", "changePercent": 2.2],
                ["id": "conversion", "title": "Conversion rate", "value": 0.037, "format": "percentage", "changePercent": -0.4],
            ],
            "series": [
                ["id": "revenue", "title": "Daily revenue", "chartType": "line", "points": revenue],
                ["id": "orders", "title": "Orders per day", "chartType": "bar", "points": orders],
            ],
        ]
    }

    private func notifications() -> [[String: Any]] {
        [
            ["id": "ntf-1", "title": "Approval requested", "message": "Purchase order #3400 needs your approval.",
             "createdAt": iso(now().addingTimeInterval(-900)), "isRead": false, "category": "Approvals"],
            ["id": "ntf-2", "title": "Weekly summary ready", "message": "Your weekly performance summary is available.",
             "createdAt": iso(now().addingTimeInterval(-7_200)), "isRead": false, "category": "Reports"],
            ["id": "ntf-3", "title": "Payment retry failed", "message": "An automatic payment retry did not succeed.",
             "createdAt": iso(now().addingTimeInterval(-90_000)), "isRead": true, "category": "Billing"],
        ]
    }

    private func daysAgo(_ days: Int) -> String {
        iso(now().addingTimeInterval(-Double(days) * 86_400))
    }

    private func iso(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
#endif
