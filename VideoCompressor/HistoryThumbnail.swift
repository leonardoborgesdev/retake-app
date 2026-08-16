import SwiftUI
import Photos

/// Loads a real thumbnail for a History entry's saved Photos asset, if it still exists.
/// Falls back to the per-kind icon when there's no asset identifier (entries recorded
/// before this existed) or the asset was since deleted from Photos.
struct HistoryThumbnail: View {
    let assetIdentifier: String?
    let fallbackIcon: String
    var width: CGFloat = 44
    var height: CGFloat = 44
    var cornerRadius: CGFloat = 8
    var iconSize: Font = .caption

    @State private var image: UIImage?

    init(assetIdentifier: String?, fallbackIcon: String, size: CGFloat = 44, cornerRadius: CGFloat = 8, iconSize: Font = .caption) {
        self.assetIdentifier = assetIdentifier
        self.fallbackIcon = fallbackIcon
        self.width = size
        self.height = size
        self.cornerRadius = cornerRadius
        self.iconSize = iconSize
    }

    init(assetIdentifier: String?, fallbackIcon: String, width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 8, iconSize: Font = .system(size: 36)) {
        self.assetIdentifier = assetIdentifier
        self.fallbackIcon = fallbackIcon
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.iconSize = iconSize
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(colors: [Theme.surface3, Theme.board], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Image(systemName: fallbackIcon)
                    .font(iconSize)
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: assetIdentifier) {
            image = nil
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let assetIdentifier else { return }
        // Fetching/requesting an image implicitly triggers the system permission prompt
        // the first time it's called - Compress/Cut/Split never ask for Photos read
        // access at all (PHPicker needs none), so silently checking status first, instead
        // of just calling fetchAssets, keeps History from surprising those users with a
        // permission sheet the moment they open it. Thumbnails only appear once the user
        // has already granted read access some other way (e.g. via Find Duplicates).
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }

        let options = PHImageRequestOptions()
        // .highQualityFormat delivers exactly once (unlike .opportunistic, which can call
        // the handler twice - low-res then high-res - and would double-resume this
        // continuation).
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: max(width, height) * scale, height: max(width, height) * scale)

        let loaded: UIImage? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { img, _ in
                continuation.resume(returning: img)
            }
        }
        if let loaded {
            image = loaded
        }
    }
}
