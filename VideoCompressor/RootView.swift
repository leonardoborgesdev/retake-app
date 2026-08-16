import SwiftUI

struct RootView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @State private var showingSplash = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @AppStorage("appLanguage") private var languageRawValue = AppLanguage.en.rawValue

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
        .preferredColorScheme((AppAppearance(rawValue: appearanceRawValue) ?? .system).colorScheme)
        // Drives the in-app Language picker independent of the device's own Settings >
        // Language - Text() still resolves against Localizable.xcstrings, just against
        // this locale instead of the system one.
        .environment(\.locale, Locale(identifier: (AppLanguage(rawValue: languageRawValue) ?? .en).localeIdentifier))
    }
}

#Preview {
    RootView().environmentObject(AccountStore.shared).environmentObject(HistoryStore.shared)
}
