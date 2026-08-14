import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, pt, es
    var id: String { rawValue }
    var label: String {
        switch self {
        case .en: return "English"
        case .pt: return "Português (Brasil)"
        case .es: return "Español"
        }
    }
}

struct AccountView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var historyStore: HistoryStore

    @State private var apiKey: String = APIKeyStore.load() ?? ""
    @State private var savedConfirmation = false
    @AppStorage("compressionTier") private var tierRawValue = CompressionTier.balanced.rawValue
    @AppStorage("appLanguage") private var languageRawValue = AppLanguage.en.rawValue

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Theme.board)
                        .frame(width: 64, height: 64)
                        .overlay(Text(initials).font(.headline.weight(.heavy)).foregroundStyle(Theme.accent))

                    VStack(spacing: 2) {
                        Text(accountStore.session?.name ?? "-").font(.headline)
                        Text(accountStore.session?.email ?? "").font(.caption).foregroundStyle(Theme.inkSoft)
                        if let createdAt = accountStore.session?.createdAt {
                            Text("Member since \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }

                    Text("FREE PLAN")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.surface2)
                        .clipShape(Capsule())
                        .foregroundStyle(Theme.inkSoft)

                    HStack(spacing: 10) {
                        stat(value: "\(historyStore.entries.count)", label: "videos edited")
                        stat(value: "\(compressCount)", label: "compressed")
                        stat(value: "\(cutCount)", label: "cut")
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
                SecureField("AssemblyAI API key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
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
                HStack {
                    Text("Default compression quality")
                    Spacer()
                    Text((CompressionTier(rawValue: tierRawValue) ?? .balanced).label)
                        .foregroundStyle(Theme.inkSoft)
                }
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
                    Text("leooborges27@gmail.com").foregroundStyle(Theme.inkSoft)
                }
            }

            if savedConfirmation {
                Section {
                    Label("API key saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
            }

            Section {
                Button("Save API key") {
                    try? APIKeyStore.save(apiKey)
                    savedConfirmation = true
                }
                .disabled(apiKey.isEmpty)

                Button("Sign out", role: .destructive) {
                    accountStore.signOut()
                }
            }
        }
        .navigationTitle("Account")
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

    private var lastActivityLabel: String {
        guard let mostRecent = historyStore.entries.first else { return "-" }
        return mostRecent.date.formatted(date: .abbreviated, time: .omitted)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.heavy)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack { AccountView() }.environmentObject(AccountStore.shared).environmentObject(HistoryStore.shared)
}
