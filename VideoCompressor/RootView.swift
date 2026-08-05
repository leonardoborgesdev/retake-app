import SwiftUI

struct RootView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @State private var showingSplash = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if showingSplash {
                SplashView { showingSplash = false }
            } else if !hasSeenOnboarding {
                OnboardingView { hasSeenOnboarding = true }
            } else if accountStore.isLoggedIn {
                RootTabView()
            } else {
                AuthView()
            }
        }
    }
}

#Preview {
    RootView().environmentObject(AccountStore.shared).environmentObject(HistoryStore.shared)
}
