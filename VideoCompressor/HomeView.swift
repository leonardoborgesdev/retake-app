import SwiftUI

struct HomeView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                NavigationLink {
                    CompressOnlyView()
                } label: {
                    FeatureCard(
                        systemImage: "arrow.down.right.and.arrow.up.left",
                        title: "Comprimir vídeo",
                        subtitle: "Reduz o tamanho do arquivo mantendo a qualidade, usando o encoder de hardware do iPhone."
                    )
                }

                NavigationLink {
                    CutOnlyView()
                } label: {
                    FeatureCard(
                        systemImage: "scissors",
                        title: "Cortar silêncios e retakes",
                        subtitle: "Remove pausas longas e repetições de fala automaticamente (usa a AssemblyAI, precisa de internet)."
                    )
                }

                Spacer()
                Spacer()
            }
            .padding()
            .navigationTitle("VideoCompressor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

private struct FeatureCard: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .frame(width: 44)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.primary)
    }
}

#Preview {
    HomeView()
}
