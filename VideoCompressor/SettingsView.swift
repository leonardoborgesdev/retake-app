import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = APIKeyStore.load() ?? ""
    @State private var savedConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Chave de API", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("AssemblyAI")
                } footer: {
                    Text("Usada só pra transcrever o áudio e detectar silêncios/retakes. Fica guardada de forma segura no Keychain do iPhone.")
                }

                if savedConfirmation {
                    Section {
                        Label("Chave salva", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Configurações")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        try? APIKeyStore.save(apiKey)
                        savedConfirmation = true
                    }
                    .disabled(apiKey.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
