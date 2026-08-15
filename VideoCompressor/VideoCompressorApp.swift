import SwiftUI

@main
struct VideoCompressorApp: App {
    init() {
#if DEBUG
        // Debug-only: `defaults write <bundle-id> debugAssemblyAIKey -string "<key>"`
        // seeds the Keychain on launch so simulator/CI testing doesn't need to type a
        // key by hand. Compiled out of Release entirely.
        if let key = UserDefaults.standard.string(forKey: "debugAssemblyAIKey"), !key.isEmpty {
            try? APIKeyStore.save(key)
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AccountStore.shared)
                .environmentObject(HistoryStore.shared)
        }
    }
}
