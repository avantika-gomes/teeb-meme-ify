import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @Binding var path: NavigationPath
    @State private var recentMemes: [SavedMeme] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var errorMessage: String?

    private let tileSpacing: CGFloat = 12
    private let gridSpacing: CGFloat = 10

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                brandBar
                captureTiles
                greatestHitsSection

                if let errorMessage {
                    Text(errorMessage)
                        .font(BrandTheme.bodyFont(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
        }
        .background(BrandTheme.background.ignoresSafeArea())
        .onAppear {
            reloadRecentsIfNeeded()
        }
        .onChange(of: path.count) { _, _ in
            if path.isEmpty {
                reloadRecentsIfNeeded()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                isPresented: $showCamera,
                onImagePicked: { image in
                    handleNewImage(image, captured: .now)
                },
                onCaptureFailed: { message in
                    errorMessage = message
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    // Downsampled straight from the data so the full-size photo is never decoded.
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let image = ImageDownsampler.downsample(data: data) else {
                        await MainActor.run {
                            errorMessage = "Could not load that photo."
                            selectedPhotoItem = nil
                        }
                        return
                    }
                    // Read EXIF from the original data; the downsampled image has already dropped it.
                    let captured = PhotoMetadata.capture(from: data)
                    await MainActor.run {
                        handleNewImage(image, captured: captured)
                        selectedPhotoItem = nil
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = AppEnvironment.isRunningInPreview
                            ? "Photo library is not available in canvas preview. Run the app with ⌘R instead."
                            : "Could not open the photo library."
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }

    // MARK: - Brand bar

    private var brandBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FETCH")
                    .font(BrandTheme.displayFont(size: 34))
                Text(BrandTheme.tagline.uppercased())
                    .font(BrandTheme.bodyFont(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(BrandTheme.ink.opacity(0.65))
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text("01 SNAP")
                Text("02 CAPTION")
                Text("03 SEND")
            }
            .font(BrandTheme.bodyFont(size: 11, weight: .bold))
            .tracking(0.6)
        }
        .foregroundStyle(BrandTheme.ink)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BrandTheme.lime)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BrandTheme.ink, lineWidth: 2)
        )
    }

    // MARK: - Capture tiles

    @ViewBuilder
    private var captureTiles: some View {
        HStack(spacing: tileSpacing) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                cameraTile
            }
            libraryTile
        }
    }

    private var cameraTile: some View {
        Button {
            showCamera = true
        } label: {
            captureTileContent(fill: BrandTheme.ink, labelColor: BrandTheme.lime, hasShadow: true) {
                ZStack {
                    Circle()
                        .stroke(BrandTheme.lime, lineWidth: 3)
                        .frame(width: 44, height: 44)
                    Circle()
                        .fill(BrandTheme.lime)
                        .frame(width: 14, height: 14)
                }
            } label: {
                Text("CAMERA")
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Take a photo")
    }

    private var libraryTile: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            captureTileContent(fill: BrandTheme.surface, labelColor: BrandTheme.ink, hasShadow: false) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach([34, 27, 20, 13], id: \.self) { width in
                        Capsule()
                            .fill(BrandTheme.ink)
                            .frame(width: CGFloat(width), height: 4)
                    }
                }
            } label: {
                Text("LIBRARY")
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose a photo")
    }

    @ViewBuilder
    private func captureTileContent(
        fill: Color,
        labelColor: Color,
        hasShadow: Bool,
        @ViewBuilder glyph: () -> some View,
        @ViewBuilder label: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            glyph()
            Spacer(minLength: 12)
            label()
                .font(BrandTheme.bodyFont(size: 13, weight: .bold))
                .foregroundStyle(labelColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BrandTheme.ink, lineWidth: 2)
                )
                .compositingGroup()
                .shadow(color: hasShadow ? BrandTheme.ink : .clear, radius: 0, x: hasShadow ? 4 : 0, y: hasShadow ? 4 : 0)
        }
    }

    // MARK: - Your Greatest Hits

    private var greatestHitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("YOUR GREATEST HITS")
                    .font(BrandTheme.displayFont(size: 19))
                    .foregroundStyle(BrandTheme.ink)
                    .fixedSize()
                Rectangle()
                    .fill(BrandTheme.orange)
                    .frame(height: 2)
            }

            if recentMemes.isEmpty {
                emptyHitsBox
            } else {
                LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                    ForEach(recentMemes) { meme in
                        memeTile(meme)
                    }
                }

                Text("TAP TO EDIT OR RE-SHARE")
                    .font(BrandTheme.bodyFont(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(BrandTheme.hint)
            }
        }
    }

    private var emptyHitsBox: some View {
        VStack(spacing: 6) {
            Text("NO MEMES YET")
                .font(BrandTheme.bodyFont(size: 13, weight: .bold))
                .foregroundStyle(BrandTheme.ink)
            Text("Take a photo to get started.")
                .font(BrandTheme.bodyFont(size: 12))
                .foregroundStyle(BrandTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(BrandTheme.ink, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        )
    }

    private func memeTile(_ meme: SavedMeme) -> some View {
        Button {
            open(meme)
        } label: {
            // Color.clear (not the image directly) drives the aspect ratio — LazyVGrid's flexible
            // columns don't give raw image content a definite size to fit within, and the tiles
            // end up overlapping instead of sitting in their own grid cell. The badge is its own
            // trailing .overlay rather than nested in a ZStack, so it positions off the tile's
            // final clipped frame instead of an intermediate, less predictable layout pass.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    MemeThumbnail(meme: meme)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    reshareBadge
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BrandTheme.ink, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private var reshareBadge: some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(BrandTheme.ink)
            .frame(width: 26, height: 26)
            .background(Circle().fill(BrandTheme.lime))
            .overlay(Circle().stroke(BrandTheme.ink, lineWidth: 2))
            .padding(6)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3)
    }

    // MARK: - Data

    private static var isRunningInPreview: Bool {
        AppEnvironment.isRunningInPreview
    }

    private func reloadRecentsIfNeeded() {
        guard !Self.isRunningInPreview else { return }
        reloadRecents()
    }

    private func reloadRecents() {
        recentMemes = MemeStore.loadAll()
    }

    /// Opens a saved meme on the Done screen to re-share or save. Memes that remember their photo
    /// get the rest of the flow stacked underneath, so Back walks into the editor and then the
    /// captions to change it; older ones open on their own.
    private func open(_ meme: SavedMeme) {
        var stack = NavigationPath()

        if let photo = meme.photo,
           let layout = meme.layout,
           FileManager.default.fileExists(atPath: photo.fileURL.path) {
            let caption = meme.caption ?? ""
            stack.append(AppRoute.captions(photo, editing: meme))
            stack.append(AppRoute.editor(caption: caption, photo: photo, layout: layout, editing: meme))
            stack.append(AppRoute.preview(caption: caption, photo: photo, layout: layout, editing: meme))
        } else {
            stack.append(AppRoute.savedMeme(meme))
        }

        path = stack
    }

    private func handleNewImage(_ image: UIImage, captured: PhotoCapture?) {
        do {
            let saved = try PhotoStore.save(image, captured: captured)
            reloadRecents()
            path.append(AppRoute.captions(saved))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// A grid tile's image, decoded off the main thread at tile size. Saved memes can be full camera
/// resolution, and decoding every one of those at full size is what ran the app out of memory.
private struct MemeThumbnail: View {
    let meme: SavedMeme

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    /// Memes never change once saved, so a thumbnail stays valid for as long as it's cached.
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    BrandTheme.skeleton
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task(id: geometry.size.width) {
                await loadThumbnail(side: max(geometry.size.width, geometry.size.height))
            }
        }
    }

    private func loadThumbnail(side: CGFloat) async {
        guard side > 0 else { return }
        let pixelSize = (side * displayScale).rounded(.up)
        let key = "\(meme.fileName)@\(Int(pixelSize))" as NSString

        if let cached = Self.cache.object(forKey: key) {
            image = cached
            return
        }

        let url = meme.fileURL
        let thumbnail = await Task.detached(priority: .userInitiated) {
            ImageDownsampler.thumbnail(contentsOf: url, filling: pixelSize)
        }.value

        guard let thumbnail, !Task.isCancelled else { return }
        let cost = thumbnail.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        Self.cache.setObject(thumbnail, forKey: key, cost: cost)
        image = thumbnail
    }
}

#Preview("Home") {
    ContentView()
}
