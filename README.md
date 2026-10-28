# NativeBusinessApp

A production-oriented, native iOS 26 business dashboard template built with Swift 6 and SwiftUI.
It ships a secure email/password sign-in with JWT-style access and refresh tokens, a real
`URLSession` REST layer, a four-tab shell on the native Liquid Glass `TabView`, a reusable design
system, and unit, integration and UI tests.

> **The backend is not specified yet.** All endpoints, payloads and URLs in this repository are
> *illustrative placeholders* (`*.example.com`). No real server has been contacted or verified.
> See [Documentation/API_INTEGRATION.md](Documentation/API_INTEGRATION.md) for the contract to
> confirm or replace.

## Features

- **Authentication**: email *or* username login (configurable), inline validation, duplicate-submit
  protection, Keychain token storage, coalesced token refresh, session restoration, session-expiry
  handling and logout with best-effort server revocation.
- **Home dashboard**: personalised greeting, configurable KPI cards, a quick-action grid, recent
  activity, pull-to-refresh, and loading/empty/partial-failure/offline states.
- **Analytics**: range picker (7/30/90 days), KPI cards and Swift Charts line/bar series.
- **Notifications**: in-app list with read/unread state, optimistic "mark as read" with rollback, and an
  unread badge on the tab and Home toolbar.
- **Profile**: account details, app/environment info, and sign-out with confirmation.
- **Design system**: adaptive light/dark color tokens, a Dynamic Type scale, a spacing scale, the
  14 requested reusable components, and supporting pieces (status badge, inline banner, avatar,
  quick-action tile, skeleton variants).
- **Demo mode** (DEBUG only): an in-process mock backend for previews, manual testing and UI tests.

## Technology stack

| Area | Choice |
| --- | --- |
| Language | Swift 6 language mode (`SWIFT_VERSION = 6.0`, strict concurrency `complete`), Swift 6.2 toolchain |
| UI | SwiftUI, Observation (`@Observable`), Swift Charts |
| Concurrency | async/await, actors, structured concurrency, task cancellation |
| Networking | `URLSession` async APIs, `Codable` |
| Security | Keychain Services (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) |
| Logging | `os.Logger` with privacy annotations and a redactor |
| Tests | Swift Testing (unit/integration), XCTest + XCUIAutomation (UI) |
| Dependencies | None (no third-party packages) |

## Requirements

- macOS with **Xcode 26.2** or later (developed and verified with Xcode 26.2, build 17C52, Swift 6.2.3).
- iOS **26.0** minimum deployment target. iPhone and iPad.
- An iOS 26 simulator runtime (verified on iPhone 17 Pro, iOS 26.3.1).

## Open, build and run

```bash
open NativeBusinessApp.xcodeproj
```

Select the **NativeBusinessApp** scheme and an iOS 26 simulator, then press **Run**.

With the default placeholder URL, real sign-in cannot succeed (the login screen says so in DEBUG builds).
To explore the app without a backend, enable **demo mode**:

- Xcode: *Product › Scheme › Edit Scheme › Run › Arguments*, tick `-demo-mode`, or
- CLI: `xcrun simctl launch booted com.example.NativeBusinessApp.dev -demo-mode`

In demo mode, any email and password sign in. The password `wrong-password` shows the error path.

Command-line build (simulator, no signing):

```bash
xcodebuild -project NativeBusinessApp.xcodeproj -scheme NativeBusinessApp \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

## Environment configuration

Configuration is native to Xcode: `Config/*.xcconfig` → `Config/Info.plist` → `AppConfiguration`.

| Build configuration | xcconfig | Environment | Bundle id suffix |
| --- | --- | --- | --- |
| Debug | `Development.xcconfig` | development | `.dev` |
| Staging | `Staging.xcconfig` | staging | `.staging` |
| Release | `Production.xcconfig` | production | none |

Key settings: `API_BASE_URL`, `API_TIMEOUT_SECONDS`, `LOGIN_IDENTIFIER_KIND` (`email`/`username`),
`PASSWORD_RESET_URL`. Local overrides go in the git-ignored `Config/Local.xcconfig` (copy
`Config/Local.xcconfig.example`). Staging and Release builds **refuse to start** while the base URL is
an `example.com` placeholder. Details: [Documentation/SETUP.md](Documentation/SETUP.md).

No secrets belong in these files: everything in them is bundled into the app.

## Running tests

```bash
# Discover simulators
xcrun simctl list devices available

# All tests (unit + integration + UI)
xcodebuild -project NativeBusinessApp.xcodeproj -scheme NativeBusinessApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Unit + integration only
xcodebuild ... test -only-testing:NativeBusinessAppTests
```

Tests never contact a live server and need no real credentials. See
[Documentation/TESTING.md](Documentation/TESTING.md).

## Project structure

```
NativeBusinessApp/
├── NativeBusinessApp.xcodeproj      Xcode project (file-system synchronized groups) + shared scheme
├── NativeBusinessApp/               App target sources
│   ├── App/                         Entry point, composition root, coordinator, router, root views
│   ├── Core/
│   │   ├── Authentication/          AuthManager, TokenRefreshService, session types
│   │   ├── DesignSystem/            Tokens + Components/
│   │   ├── Logging/                 os.Logger categories, redaction, network logging
│   │   ├── Networking/              APIClient, HTTPClient, RequestBuilder, errors, retry, MockBackend/ (DEBUG)
│   │   ├── Security/                TokenStore, KeychainTokenStore, InMemoryTokenStore (DEBUG)
│   │   ├── SharedDomain/            Metric (used by Home and Analytics)
│   │   └── Utilities/               UserFacingError, LoadState, formatters, LossyArray
│   ├── Features/{Authentication,Home,Analytics,Notifications,Profile}/{Data,Domain,Presentation}
│   └── Resources/Assets.xcassets    Adaptive color tokens, placeholder app icon
├── Config/                          xcconfig files and Info.plist template
├── Tests/
│   ├── UnitTests/                   Swift Testing     ┐ NativeBusinessAppTests target
│   ├── IntegrationTests/            Swift Testing     ┘
│   └── UITests/                     XCTest/XCUIAutomation → NativeBusinessAppUITests target
└── Documentation/
```

## Documentation

- [ARCHITECTURE.md](Documentation/ARCHITECTURE.md): layers, data flow, DI, auth lifecycle
- [API_INTEGRATION.md](Documentation/API_INTEGRATION.md): API client, endpoint contracts, error mapping, integration checklist
- [AUTHENTICATION.md](Documentation/AUTHENTICATION.md): login, tokens, Keychain, refresh, restoration, logout
- [DESIGN_SYSTEM.md](Documentation/DESIGN_SYSTEM.md): tokens, components, Liquid Glass, accessibility
- [TESTING.md](Documentation/TESTING.md): test targets and how to run them
- [SETUP.md](Documentation/SETUP.md): Xcode, bundle id, signing, environments, release prep

## Known limitations

- **No verified backend.** Endpoint paths and payloads are assumptions until the real contract arrives.
- Forgot password opens `PASSWORD_RESET_URL` if configured; otherwise it shows an
  "ask your administrator" message. There is no in-app reset flow.
- Lists are not paginated (activity is capped at 50 items). Add pagination if the real API requires it.
- No offline cache: data is fetched live, and failures are shown as such. Stale data is kept only within a session.
- No push notifications, biometrics, registration or analytics/tracking SDKs (out of scope).
- The app icon and logo are placeholders.
- No localisations yet. Strings are localisable (String Catalog-ready) but only English exists.
