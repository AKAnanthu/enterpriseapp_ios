# Setup

## Xcode setup

1. Install **Xcode 26.2** or later with an iOS 26 simulator runtime (*Xcode › Settings › Components*).
2. `open NativeBusinessApp.xcodeproj`.
3. The project uses **file-system synchronized groups** (Xcode 16+ format): any file added under
   `NativeBusinessApp/` joins the app target automatically, and files under `Tests/UnitTests` or
   `Tests/IntegrationTests` join `NativeBusinessAppTests`. No project-file edits are needed for new sources.
4. There are no Swift Package dependencies. If you add one, use *File › Add Package Dependencies…*.

Key build settings (project level): `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 6.0`,
`SWIFT_STRICT_CONCURRENCY = complete`, `TARGETED_DEVICE_FAMILY = 1,2`.

## Bundle identifier

`Config/Shared.xcconfig`:

```
BASE_BUNDLE_IDENTIFIER = com.example.NativeBusinessApp   // placeholder: change to your reverse-DNS id
```

The effective identifier is `$(BASE_BUNDLE_IDENTIFIER)$(BUNDLE_ID_SUFFIX)`. That gives
`….dev` (Debug), `….staging` (Staging) and no suffix (Release), so all three can be installed side by side.
Update the test targets' identifiers (`com.example.NativeBusinessAppTests`, `…UITests`) in the target
build settings to match your organisation. The display name is `APP_DISPLAY_NAME` (default "Business").

## Environment setup

| Xcode build configuration | xcconfig | `APP_ENVIRONMENT` | Swift condition |
| --- | --- | --- | --- |
| Debug | `Config/Development.xcconfig` | `development` | `DEBUG` |
| Staging | `Config/Staging.xcconfig` | `staging` | `STAGING` |
| Release | `Config/Production.xcconfig` | `production` | none |

Values flow `xcconfig` → `Config/Info.plist` (`$(API_BASE_URL)` etc.) → `AppConfiguration.load(from:)`,
which validates them at launch. To run Staging from Xcode, duplicate the scheme and set *Run › Build
Configuration* to **Staging**.

DEBUG-only features (demo backend, UI-test mode, in-memory token store, verbose network logging)
are compiled out of Staging and Release with `#if DEBUG`.

## API base URL configuration

1. Edit the environment's xcconfig, or for local development create the git-ignored override:
   ```bash
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```
2. Set `API_BASE_URL`. In xcconfig files `//` starts a comment, so write:
   ```
   API_BASE_URL = https:/$()/api.yourcompany.com/v1
   ```
3. HTTPS is required. `http://localhost` is accepted only in development (ATS allows local hosts).
4. Clean build (⇧⌘K) after changing xcconfig values.

The app **will not start** in Staging/Release while the host is a reserved example domain. It shows
"Configuration required" instead, which prevents shipping placeholders.

**Do not put secrets in xcconfig or Info.plist.** They are readable by anyone with the app binary.

## Signing setup

No signing identity or team is hardcoded (`CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM` empty).

- Simulator: works out of the box ("Sign to Run Locally").
- Device / distribution: select your team in *Target › Signing & Capabilities* for the app and test
  targets, or set `DEVELOPMENT_TEAM` in a git-ignored xcconfig or on the command line:
  `xcodebuild … DEVELOPMENT_TEAM=ABCDE12345`.
- No extra capabilities are required. The Keychain works with the default access group.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "Configuration required" screen | `API_BASE_URL` missing, invalid, non-HTTPS or a placeholder in Staging/Release. The message names the setting |
| Login banner "API_BASE_URL … is a placeholder" | Expected in Debug until you set a real URL, or launch with `-demo-mode` |
| "Can't reach the server" | Wrong host, VPN or DNS issue, or the server is down. Check the URL in Profile › About |
| `Unable to find a device matching the provided destination` | Use the exact runtime (`OS=26.3.1`) or `-destination 'id=<UDID>'` from `xcrun simctl list devices` |
| Keychain tests fail with `-34018` | Tests were built with `CODE_SIGNING_ALLOWED=NO`. Run tests with default signing |
| Changes to xcconfig not picked up | Clean build folder |
| Previously signed-in session after reinstall | Should not happen: `FreshInstallGuard` clears it. If testing, delete the app and reinstall |
| Verbose network logs needed | DEBUG only: add launch argument `-network-verbose-logging` (headers and body are redacted) |

## Release build preparation

- [ ] Real `API_BASE_URL` in `Production.xcconfig` (and `Staging.xcconfig`)
- [ ] Real bundle identifier, display name, `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`
- [ ] Replace the placeholder app icon (`Assets.xcassets/AppIcon`) and `BrandLogo`
- [ ] Backend contract confirmed (see API_INTEGRATION.md checklist), DTOs and tests updated
- [ ] Decide on the Keychain accessibility class (AUTHENTICATION.md)
- [ ] Privacy manifest / App Store privacy answers reflect the backend's data collection (the app itself adds no tracking)
- [ ] `PASSWORD_RESET_URL` set, or confirm the "contact your administrator" message is acceptable
- [ ] Archive with the **Release** configuration (*Product › Archive*). Confirm demo mode is absent (it is `#if DEBUG`)
- [ ] Run the full test suite and a manual smoke test against staging
