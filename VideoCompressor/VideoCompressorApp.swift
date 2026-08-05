import SwiftUI

@main
struct VideoCompressorApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AccountStore.shared)
                .environmentObject(HistoryStore.shared)
        }
    }
}
