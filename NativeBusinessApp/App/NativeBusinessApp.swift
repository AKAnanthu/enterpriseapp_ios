import SwiftUI

@main
struct NativeBusinessApp: App {
    @State private var bootstrap = AppBootstrap.make()

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .ready(let container):
                RootView(container: container)
                    .tint(AppColors.actionText)
            case .misconfigured(let error):
                ConfigurationErrorView(error: error)
            case .hostingUnitTests:
                Color.clear
            }
        }
    }
}
