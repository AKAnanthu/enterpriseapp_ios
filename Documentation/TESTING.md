# Testing

No test contacts a live server or needs real credentials. Networking is exercised through
injected transports, a `URLProtocol` stub on a real `URLSession`, or the DEBUG demo backend.

## Test targets

| Target | Folder(s) | Framework | Contents |
| --- | --- | --- | --- |
| `NativeBusinessAppTests` (hosted by the app) | `Tests/UnitTests`, `Tests/IntegrationTests` | Swift Testing | Unit and integration tests |
| `NativeBusinessAppUITests` | `Tests/UITests` | XCTest + XCUIAutomation | End-to-end UI flows against the demo backend |

When the app hosts unit tests it detects `XCTestConfigurationFilePath` and renders an empty view, so
app startup never touches the Keychain or network during tests.

### Unit tests (`Tests/UnitTests`)

| Suite | Covers |
| --- | --- |
| `RequestBuilderTests` | URL joining, query items, headers, bearer token, JSON body, methods, timeouts, unsafe path rejection, segment encoding |
| `APIErrorMappingTests` | Status → error, URLError → error, `Retry-After` parsing, retry policy rules |
| `HTTPClientTests` | Success, 401, 5xx, malformed JSON, empty body, 204, timeout, offline, **cancellation**, bounded retry, no retry for POST, rate limiting |
| `AuthenticatedAPIClientTests` | Authorization header, refresh-and-retry, **no refresh loop**, **concurrent 401s share one refresh**, refresh failure, refresh endpoint is unauthenticated |
| `TokenRefreshServiceTests` | Proactive refresh, coalescing (8 concurrent callers → 1 refresh), stale-token shortcut, permanent vs transient failures, logout during refresh, Keychain errors |
| `AuthManagerTests` | Every state transition: restore paths (none, valid, rejected, offline, corrupt or locked Keychain), login, login failure, Keychain failure, logout + remote revoke, refresh events, session expiry, logout-during-restore race |
| `LoginFormValidatorTests`, `LoginViewModelTests` | Required fields, email format, trimming, password untouched, focus targeting, error messages, **duplicate submission** |
| `AuthMappingTests` | Login/refresh DTO encoding and decoding, token validation, redacted token descriptions, credential-rejection mapping, refresh-token retention |
| `DashboardMappingTests`, `HomeViewModelTests` | DTO → domain mapping, lossy decoding, status mapping, loaded/empty/partial/total failure, refresh keeps content, cancellation |
| `FeatureViewModelTests` | Notifications optimistic update and rollback, analytics range, profile fallback and sign-out |
| `LogRedactorTests`, `UserFacingErrorTests`, `AppConfigurationTests`, `AppFormattersTests` | Redaction of sensitive fields, error presentation, configuration validation, deterministic formatting |

### Integration tests (`Tests/IntegrationTests`)

| Suite | Covers |
| --- | --- |
| `KeychainTokenStoreTests` | **Real simulator Keychain**: save, load, update, clear, isolation, fresh-install guard |
| `NetworkingIntegrationTests` | Full `AppContainer` over a real `URLSession` + `StubURLProtocol`: login then dashboard, transparent refresh on launch, revoked refresh token → session expired, section failures |
| `DemoBackendIntegrationTests` | Full lifecycle against `MockBackendTransport` (the same backend the UI tests use) |

`StubURLProtocol` keys handlers by host, so suites can run in parallel.

### UI tests (`Tests/UITests`)

Launched with `-ui-testing` and `MOCK_SCENARIO=<scenario>` (DEBUG only): in-process mock backend and
in-memory tokens, so every run starts signed out and is deterministic.

| Test | Scenario |
| --- | --- |
| `testLoginScreenRenders` | Fields, toggle, forgot password and button present |
| `testEmptySubmissionShowsValidationErrors` / `testInvalidEmailShowsFormatError` | Inline validation |
| `testPasswordVisibilityToggle` | Secure ↔ plain text with the value kept |
| `testRejectedCredentialsShowError` | Password `wrong-password` → 401 → error banner |
| `testLoginShowsProgressWhileSigningIn` | `slow-login` scenario shows progress, then the dashboard |
| `testSuccessfulLoginOpensDashboard` | Login → tab shell + greeting |
| `testDashboardLoadsMetricsAndActivity` | KPI cards and activity rows |
| `testDashboardEmptyState` | `empty-dashboard` scenario |
| `testDashboardFailureShowsRetry` | `dashboard-failure` scenario → error state + retry |
| `testTabNavigation` | All four tabs |
| `testQuickActionOpensActivityList` | Quick action → pushed list |
| `testLogoutReturnsToLogin` | Profile → Sign Out → confirm → login |

Scenarios: `standard`, `empty-dashboard`, `dashboard-failure`, `slow-login` (see `MockScenario`).

## Running

```bash
# 1. Pick a simulator
xcrun simctl list devices available | grep -i iphone

# 2. Everything
xcodebuild -project NativeBusinessApp.xcodeproj -scheme NativeBusinessApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Unit + integration only
xcodebuild -project NativeBusinessApp.xcodeproj -scheme NativeBusinessApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:NativeBusinessAppTests

# UI tests only
xcodebuild ... test -only-testing:NativeBusinessAppUITests

# One suite / test
xcodebuild ... test -only-testing:NativeBusinessAppTests/TokenRefreshServiceTests
```

If a name-based destination is ambiguous (e.g. the runtime is `26.3.1`), use the device id:
`-destination 'id=<UDID>'`.

Swift Testing failure messages are not printed in `xcodebuild` logs. Read them from the result bundle:

```bash
R=$(ls -td ~/Library/Developer/Xcode/DerivedData/NativeBusinessApp-*/Logs/Test/*.xcresult | head -1)
xcrun xcresulttool get test-results summary --path "$R"
```

## Simulator requirements

- An iOS **26.x** simulator (deployment target 26.0). Verified on **iPhone 17 Pro, iOS 26.3.1**.
- Keychain integration tests need the hosted test bundle to be signed. The default "Sign to Run Locally"
  works in the simulator. Do not pass `CODE_SIGNING_ALLOWED=NO` when running tests.
- UI tests type into fields. If "Connect Hardware Keyboard" causes focus issues, turn it off in the
  Simulator's I/O menu (the helper already waits for keyboard focus and retries).

## Build verification checklist

- [ ] `xcodebuild -list -project NativeBusinessApp.xcodeproj` shows 3 targets, 3 configurations, 1 scheme
- [ ] Debug, Staging and Release simulator builds succeed with no Swift warnings
- [ ] `NativeBusinessAppTests` pass (unit + integration)
- [ ] `NativeBusinessAppUITests` pass
- [ ] Staging/Release launch shows "Configuration required" until real URLs are set (expected)
- [ ] With a real backend: manual login, refresh (shorten token lifetime), logout, relaunch restore
- [ ] `grep -rn "example.com" Config` is empty before a production release
