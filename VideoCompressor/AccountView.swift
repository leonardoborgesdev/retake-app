import SwiftUI
import StoreKit

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, pt
    var id: String { rawValue }
    var label: String {
        switch self {
        case .en: return "English"
        case .pt: return "Português (Brasil)"
        }
    }

    /// Feeds `.environment(\.locale, ...)` at the app root - this is what actually makes
    /// switching this picker change displayed text, independent of the device's own
    /// Settings > Language.
    var localeIdentifier: String {
        switch self {
        case .en: return "en"
        case .pt: return "pt"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AccountView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var usageLimiter: UsageLimiter

    @State private var apiKey: String = APIKeyStore.load() ?? ""
    @State private var savedConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteErrorMessage: String?
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    @AppStorage("compressionTier") private var tierRawValue = CompressionTier.balanced.rawValue
    @AppStorage("appLanguage") private var languageRawValue = AppLanguage.en.rawValue
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Theme.board)
                        .frame(width: 64, height: 64)
                        .overlay(Text(initials).font(.headline.weight(.heavy)).foregroundStyle(Theme.accent))

                    VStack(spacing: 2) {
                        Text(accountStore.session?.name ?? "").font(.headline)
                        Text(accountStore.session?.email ?? "").font(.caption).foregroundStyle(Theme.inkSoft)
                        if let createdAt = accountStore.session?.createdAt {
                            Text("Member since \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }

                    if subscriptionStore.isSubscribed {
                        Text("UNLIMITED")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Theme.accentSoft)
                            .clipShape(Capsule())
                            .foregroundStyle(Theme.accent)
                    } else {
                        (Text("FREE") + Text(" · \(usageLimiter.remainingToday)/\(UsageLimiter.dailyFreeLimit) ") + Text("LEFT TODAY"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .foregroundStyle(Theme.inkSoft)
                            .floatingGlassSurface(in: Capsule(), fallbackFill: Theme.surface2)
                    }

                    HStack(spacing: 10) {
                        stat(value: "\(historyStore.entries.count)", label: "videos edited")
                        stat(value: "\(compressCount)", label: "compressed")
                        stat(value: "\(cutCount)", label: "cut")
                        stat(value: "\(splitCount)", label: "split")
                    }
                    HStack(spacing: 10) {
                        stat(value: ByteFormatting.humanReadableSize(historyStore.totalBytesSaved), label: "space saved")
                        stat(value: lastActivityLabel, label: "last activity")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                if subscriptionStore.isSubscribed {
                    Button("Manage subscription") {
                        showManageSubscriptions = true
                    }
                } else {
                    Button("Upgrade to Unlimited") {
                        showPaywall = true
                    }
                    Button("Restore purchases") {
                        Task { try? await subscriptionStore.restore() }
                    }
                }
            } header: {
                Text("Subscription")
            } footer: {
                Text(subscriptionStore.isSubscribed
                     ? "Unlimited Compress & Cut, plus Find Duplicates and Split for Stories."
                     : "Compress & Cut are free up to \(UsageLimiter.dailyFreeLimit) videos a day. Find Duplicates and Split for Stories need Unlimited.")
            }

            Section {
                SecureField("AssemblyAI API key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Save API key") {
                    try? APIKeyStore.save(apiKey)
                    savedConfirmation = true
                }
                .disabled(apiKey.isEmpty)

                if savedConfirmation {
                    Label("API key saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
            } header: {
                Text("Cut silence & retakes")
            } footer: {
                Text("The API key is only used to transcribe audio for silence/retake detection. It stays in the iPhone Keychain.")
            }

            Section("Preferences") {
                Picker("Language", selection: $languageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.label).tag(language.rawValue)
                    }
                }
                Picker("Appearance", selection: $appearanceRawValue) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.label).tag(appearance.rawValue)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default compression quality")
                    Picker("Default compression quality", selection: $tierRawValue) {
                        ForEach(CompressionTier.allCases) { tier in
                            Text(tier.label).tag(tier.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0").foregroundStyle(Theme.inkSoft)
                }
                HStack {
                    Text("Support")
                    Spacer()
                    Text("retake@devtrip.shop").foregroundStyle(Theme.inkSoft)
                }
            }

            Section {
                Button("Sign out", role: .destructive) {
                    accountStore.signOut()
                }
            }

            Section {
                if isDeletingAccount {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    Button("Delete account", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            } footer: {
                Text("Permanently deletes your account and login. Videos already saved to your Photos library are not affected.")
            }
        }
        .navigationTitle("Account")
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone. Your login and account data will be permanently removed.")
        }
        .alert("Could not delete account", isPresented: .constant(deleteErrorMessage != nil), actions: {
            Button("OK") { deleteErrorMessage = nil }
        }, message: {
            Text(deleteErrorMessage ?? "")
        })
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: "Unlock unlimited Compress & Cut, Find Duplicates, and Split for Stories.")
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await accountStore.deleteAccount()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }

    private var initials: String {
        let parts = (accountStore.session?.name ?? "").split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        let text = String(letters).uppercased()
        return text.isEmpty ? "?" : text
    }

    private var compressCount: Int {
        historyStore.entries.filter { $0.kind == .compress }.count
    }

    private var cutCount: Int {
        historyStore.entries.filter { $0.kind == .cut }.count
    }

    private var splitCount: Int {
        historyStore.entries.filter { $0.kind == .split }.count
    }

    private var lastActivityLabel: String {
        guard let mostRecent = historyStore.entries.first else { return "None yet" }
        return mostRecent.date.formatted(date: .abbreviated, time: .omitted)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.heavy)).monospacedDigit()
            // label is a String (set from a literal at each call site) - Text(String)
            // doesn't auto-localize the way Text(literal) does, so wrap it back into
            // LocalizedStringKey to actually hit Localizable.xcstrings. value is left
            // as-is since it's already-formatted data (a count or byte size), not prose.
            Text(LocalizedStringKey(label)).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .cardGlassSurface(cornerRadius: 12)
    }
}

#Preview {
    NavigationStack { AccountView() }.environmentObject(AccountStore.shared).environmentObject(HistoryStore.shared)
}
