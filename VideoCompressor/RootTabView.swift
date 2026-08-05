import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                AccountView()
            }
            .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(Theme.ink)
    }
}

#Preview {
    RootTabView().environmentObject(AccountStore.shared).environmentObject(HistoryStore.shared)
}
