import SwiftUI
import Photos

/// A group of videos that are probably duplicates of each other - same length, recorded
/// the same day. Common in retake.'s own users: every Compress run leaves the original
/// behind, so a camera roll after a few edits often has several near-identical copies of
/// the same clip.
private struct DuplicateGroup: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
    let durationSeconds: Double
}

struct DuplicateFinderView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var showPaywall = false
    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var groups: [DuplicateGroup] = []
    @State private var selectedIdentifiers: Set<String> = []
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var deletedCount = 0

    var body: some View {
        Group {
            if isScanning {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Scanning your library…")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasScanned {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.inkSoft)
                        Text("Find duplicate videos")
                            .font(.headline)
                        Text("Scans for videos with the same length recorded the same day - the copies Compress and re-imports tend to leave behind.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    FeatureInfoCard(rows: [
                        .init(icon: "magnifyingglass", label: "What it does", value: "Groups same-length, same-day videos"),
                        .init(icon: "checkmark.seal", label: "You decide", value: "Nothing deletes until you confirm"),
                        .init(icon: "lock.shield", label: "Privacy", value: "Scan happens entirely on-device"),
                    ])
                    Button {
                        if subscriptionStore.isSubscribed {
                            Task { await scan() }
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if !subscriptionStore.isSubscribed {
                                Image(systemName: "lock.fill")
                            }
                            Text(subscriptionStore.isSubscribed ? "Scan library" : "Scan library (Unlimited)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.board)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                    }
                }
                .padding()
            } else if groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.accent)
                    Text(deletedCount > 0 ? "\(deletedCount) duplicate\(deletedCount == 1 ? "" : "s") removed" : "No duplicates found")
                        .font(.headline)
                    Button {
                        hasScanned = false
                        deletedCount = 0
                    } label: {
                        Text("Scan again")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
                    }
                    .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultsList
            }
        }
        .background(Theme.paper)
        .navigationTitle("Find Duplicates")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: "Find Duplicates is part of retake. Unlimited.")
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(Array(group.assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                            assetRow(asset, isSuggestedKeep: index == group.assets.count - 1)
                        }
                    } header: {
                        Text("\(Int(group.durationSeconds))s · \(group.assets.count) copies")
                    }
                }
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: 10) {
                Text("\(selectedIdentifiers.count) selected for deletion")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                Button(role: .destructive) {
                    Task { await deleteSelected() }
                } label: {
                    if isDeleting {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.discard)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                    } else {
                        Text("Delete selected")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.discard)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                    }
                }
                .disabled(selectedIdentifiers.isEmpty || isDeleting)
            }
            .padding()
            .background(Theme.paper)
        }
    }

    private func assetRow(_ asset: PHAsset, isSuggestedKeep: Bool) -> some View {
        let identifier = asset.localIdentifier
        let isSelected = selectedIdentifiers.contains(identifier)
        return Button {
            if isSelected {
                selectedIdentifiers.remove(identifier)
            } else {
                selectedIdentifiers.insert(identifier)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.discard : Theme.inkSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                        .font(.caption.weight(.semibold))
                    Text("\(asset.pixelWidth)×\(asset.pixelHeight)")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                if isSuggestedKeep {
                    Text("SUGGESTED KEEP")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.accentSoft)
                        .foregroundStyle(Theme.accent)
                        .clipShape(Capsule())
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .listRowBackground(Theme.surface2)
    }

    private func scan() async {
        isScanning = true
        defer { isScanning = false }

        let authorized = await PhotoLibrarySaver.requestReadWriteAuthorization()
        guard authorized else {
            errorMessage = "Photos access is needed to scan for duplicates. Enable it in Settings > retake."
            hasScanned = true
            return
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetchResult = PHAsset.fetchAssets(with: .video, options: options)

        var byKey: [String: [PHAsset]] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            let roundedDuration = Int(asset.duration.rounded())
            let day = asset.creationDate.map { Calendar.current.startOfDay(for: $0) } ?? Date.distantPast
            let key = "\(roundedDuration)-\(day.timeIntervalSince1970)"
            byKey[key, default: []].append(asset)
        }

        groups = byKey.values
            .filter { $0.count > 1 }
            .map { assets in
                // Sort so the largest-resolution asset (best proxy for "keep this one"
                // without needing file size, which PHAsset does not expose publicly)
                // sorts last - that's the one marked SUGGESTED KEEP.
                let sorted = assets.sorted { ($0.pixelWidth * $0.pixelHeight) < ($1.pixelWidth * $1.pixelHeight) }
                return DuplicateGroup(assets: sorted, durationSeconds: sorted.first?.duration ?? 0)
            }
            .sorted { $0.assets.count > $1.assets.count }

        hasScanned = true
    }

    private func deleteSelected() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await PhotoLibrarySaver.deleteAssets(identifiers: Array(selectedIdentifiers))
            deletedCount = selectedIdentifiers.count
            groups = groups.compactMap { group in
                let remaining = group.assets.filter { !selectedIdentifiers.contains($0.localIdentifier) }
                guard remaining.count > 1 else { return nil }
                return DuplicateGroup(assets: remaining, durationSeconds: group.durationSeconds)
            }
            selectedIdentifiers.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { DuplicateFinderView() }
}
