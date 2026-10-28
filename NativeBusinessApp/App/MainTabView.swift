import SwiftUI

/// The authenticated shell: four tabs on the native `TabView`.
///
/// Built with the iOS 26 SDK, the system tab bar adopts Liquid Glass automatically. No custom
/// background or appearance override is applied so content scrolls legibly beneath the glass.
/// Each tab owns its own `NavigationStack`, and paths live in `AppRouter`, so switching tabs
/// preserves navigation state.
struct MainTabView: View {
    let user: User
    private let makeActivityListViewModel: () -> ActivityListViewModel

    @State private var router = AppRouter()
    @State private var homeViewModel: HomeViewModel
    @State private var analyticsViewModel: AnalyticsViewModel
    @State private var notificationsViewModel: NotificationsViewModel
    @State private var profileViewModel: ProfileViewModel

    init(container: AppContainer, user: User) {
        self.user = user
        makeActivityListViewModel = { [container] in container.makeActivityListViewModel() }
        _homeViewModel = State(initialValue: container.makeHomeViewModel())
        _analyticsViewModel = State(initialValue: container.makeAnalyticsViewModel())
        _notificationsViewModel = State(initialValue: container.makeNotificationsViewModel())
        _profileViewModel = State(initialValue: container.makeProfileViewModel(user: user))
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView(
                    viewModel: homeViewModel,
                    user: user,
                    unreadCount: notificationsViewModel.unreadCount,
                    makeActivityListViewModel: makeActivityListViewModel
                )
            }
            Tab("Analytics", systemImage: "chart.xyaxis.line", value: AppTab.analytics) {
                AnalyticsView(viewModel: analyticsViewModel)
            }
            Tab("Notifications", systemImage: "bell", value: AppTab.notifications) {
                NotificationsView(viewModel: notificationsViewModel)
            }
            .badge(notificationsViewModel.unreadCount)
            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView(viewModel: profileViewModel)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(router)
        .task { await notificationsViewModel.loadIfNeeded() }
    }
}
