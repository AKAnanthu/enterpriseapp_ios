import Foundation

/// Composition root: builds and wires every dependency exactly once. Views receive view models
/// from these factory methods; nothing in the view layer constructs services itself.
@MainActor
final class AppContainer {
    let configuration: AppConfiguration
    let authManager: AuthManager
    let coordinator: AppCoordinator

    private let dashboardRepository: any DashboardRepository
    private let analyticsRepository: any AnalyticsRepository
    private let notificationsRepository: any NotificationsRepository
    private let profileRepository: any ProfileRepository
    private let environmentNotice: String?

    init(
        configuration: AppConfiguration,
        transport: any HTTPTransport,
        tokenStore: any TokenStore,
        networkLogger: NetworkLogger = NetworkLogger(),
        environmentNotice: String? = nil
    ) {
        self.configuration = configuration
        self.environmentNotice = environmentNotice

        let httpClient = HTTPClient(configuration: configuration.apiConfiguration, transport: transport, logger: networkLogger)
        let tokenService = TokenRefreshService(store: tokenStore, refresher: RemoteTokenRefresher(httpClient: httpClient))
        let apiClient = AuthenticatedAPIClient(httpClient: httpClient, tokenProvider: tokenService)

        let authRepository = RemoteAuthRepository(apiClient: apiClient, identifierKind: configuration.loginIdentifierKind)
        authManager = AuthManager(repository: authRepository, tokenService: tokenService)
        coordinator = AppCoordinator(authManager: authManager)

        dashboardRepository = RemoteDashboardRepository(apiClient: apiClient)
        analyticsRepository = RemoteAnalyticsRepository(apiClient: apiClient)
        notificationsRepository = RemoteNotificationsRepository(apiClient: apiClient)
        profileRepository = RemoteProfileRepository(apiClient: apiClient)
    }

    // MARK: View model factories

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(
            authenticator: authManager,
            identifierKind: configuration.loginIdentifierKind,
            passwordResetURL: configuration.passwordResetURL,
            environmentNotice: environmentNotice
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(loadDashboard: LoadDashboardUseCase(repository: dashboardRepository))
    }

    func makeActivityListViewModel() -> ActivityListViewModel {
        ActivityListViewModel(repository: dashboardRepository)
    }

    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        AnalyticsViewModel(repository: analyticsRepository)
    }

    func makeNotificationsViewModel() -> NotificationsViewModel {
        NotificationsViewModel(repository: notificationsRepository)
    }

    func makeProfileViewModel(user: User) -> ProfileViewModel {
        ProfileViewModel(sessionUser: user, appInfo: appInfo, repository: profileRepository, session: authManager)
    }

    var appInfo: AppInfo {
        AppInfo(
            version: configuration.version,
            environmentName: configuration.environment.displayName,
            apiHost: configuration.environment == .production ? nil : configuration.apiBaseURL.host()
        )
    }
}

/// Decides how the app starts: normally, with a configuration error, or idle as a unit-test host.
enum AppBootstrap {
    case ready(AppContainer)
    case misconfigured(ConfigurationError)
    case hostingUnitTests

    @MainActor
    static func make(bundle: Bundle = .main, options: LaunchOptions = .current()) -> AppBootstrap {
        if options.isHostingUnitTests {
            return .hostingUnitTests
        }

        let configuration: AppConfiguration
        do {
            configuration = try AppConfiguration.load(from: bundle.infoDictionary ?? [:])
        } catch {
            AppLogger.app.fault("Invalid configuration: \(error.message, privacy: .public)")
            return .misconfigured(error)
        }
        let logger = NetworkLogger(isVerbose: options.verboseNetworkLogging)

        #if DEBUG
        if options.usesDemoBackend {
            let scenario = MockScenario(rawValue: options.mockScenario ?? "") ?? .standard
            AppLogger.app.notice("Demo backend enabled (scenario: \(scenario.rawValue, privacy: .public))")
            return .ready(AppContainer(
                configuration: configuration,
                transport: MockBackendTransport(scenario: scenario),
                tokenStore: InMemoryTokenStore(),
                networkLogger: logger,
                environmentNotice: options.isUITesting ? nil : String(localized: "Demo mode: data comes from a built-in mock backend, not a real server. Any email and password will sign in.")
            ))
        }
        #endif

        let tokenStore = KeychainTokenStore(service: "\(bundle.bundleIdentifier ?? "NativeBusinessApp").auth")
        FreshInstallGuard.clearStaleCredentialsIfNeeded(tokenStore: tokenStore)

        var notice: String?
        #if DEBUG
        if configuration.usesPlaceholderBaseURL {
            notice = String(localized: "Development build: API_BASE_URL (\(configuration.apiBaseURL.host() ?? "")) is a placeholder, so sign-in will fail. Set a real URL in Config/Local.xcconfig, or launch with -demo-mode to use the built-in demo backend.")
        }
        #endif

        return .ready(AppContainer(
            configuration: configuration,
            transport: URLSession(configuration: .api(timeout: configuration.requestTimeout)),
            tokenStore: tokenStore,
            networkLogger: logger,
            environmentNotice: notice
        ))
    }
}

/// Keychain items survive app deletion on iOS. Without this guard, reinstalling the app would
/// silently restore the previous user's session. A non-sensitive marker in `UserDefaults` (which
/// *is* removed on deletion) detects the first launch after install and clears stale tokens.
enum FreshInstallGuard {
    static let markerKey = "hasCompletedFirstLaunch"

    static func clearStaleCredentialsIfNeeded(tokenStore: any TokenStore, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: markerKey) else { return }
        do {
            try tokenStore.clear()
            defaults.set(true, forKey: markerKey)
        } catch {
            AppLogger.keychain.error("Clearing stale credentials failed: \(error.debugDescription, privacy: .public)")
        }
    }
}
