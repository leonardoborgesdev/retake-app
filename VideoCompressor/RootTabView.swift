import SwiftUI

struct RootTabView: View {
#if DEBUG
    // Debug-only screenshot/QA helper, compiled out of Release entirely (#if DEBUG):
    // `defaults write <bundle-id> debugPushScreen -string "compress"` (or "cut"/"split")
    // lands directly on that screen with no taps; `defaults write <bundle-id> debugTab
    // -int 1` (0=Home, 1=History, 2=Account) preselects a tab; `defaults write
    // <bundle-id> debugVideoPath -string "/path/to/video.mov"` preloads a real file so
    // the tool can be exercised end-to-end without driving the Photos picker.
    @State private var homePath = NavigationPath()
    @State private var selectedTab = UserDefaults.standard.integer(forKey: "debugTab")
#endif

    var body: some View {
#if DEBUG
        TabView(selection: $selectedTab) {
            homeTab.tag(0)
            NavigationStack { HistoryView() }.tabItem { Label("History", systemImage: "clock.arrow.circlepath") }.tag(1)
            NavigationStack { AccountView() }.tabItem { Label("Account", systemImage: "person.crop.circle") }.tag(2)
        }
        .tint(Theme.ink)
#else
        TabView {
            homeTab
            NavigationStack { HistoryView() }.tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            NavigationStack { AccountView() }.tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(Theme.ink)
#endif
    }

    private var homeTab: some View {
#if DEBUG
        NavigationStack(path: $homePath) {
            HomeView()
                .navigationDestination(for: String.self) { screen in
                    let debugURL = UserDefaults.standard.string(forKey: "debugVideoPath").map { URL(fileURLWithPath: $0) }
                    switch screen {
                    case "compress": CompressOnlyView(initialURL: debugURL)
                    case "cut": CutOnlyView(initialURL: debugURL)
                    case "split": StorySplitView(initialURL: debugURL)
                    case "duplicates": DuplicateFinderView()
                    default: EmptyView()
                    }
                }
                .onAppear {
                    guard let screen = UserDefaults.standard.string(forKey: "debugPushScreen") else { return }
                    homePath.append(screen)
                }
        }
        .tabItem { Label("Home", systemImage: "house") }
#else
        NavigationStack {
            HomeView()
        }
        .tabItem { Label("Home", systemImage: "house") }
#endif
    }
}

#Preview {
    RootTabView().environmentObject(AccountStore.shared).environmentObject(HistoryStore.shared)
}
