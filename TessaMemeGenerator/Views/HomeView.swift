import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @Binding var path: NavigationPath
    @State private var recentMemes: [SavedMeme] = []
    @State private var recentPhotos: [SavedPhoto] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var errorMessage: String?
    @State private var shareItem: ShareImageItem?

    private static let mastheadAspectRatio: CGFloat = 768.0 / 599.0
    private static let mastheadFadeOverlap: CGFloat = 64
    private let memeThumbSize: CGFloat = 108
    private let photoThumbSize: CGFloat = 88

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let topInset = geo.safeAreaInsets.top

            VStack(spacing: 0) {
                homeMasthead(width: width, topInset: topInset)
                    .padding(.bottom, -Self.mastheadFadeOverlap)

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showCamera = true
                                } label: {
                                    Label("Take Photo", systemImage: "camera.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrimaryBrandButtonStyle())
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label("Choose Photo", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryBrandButtonStyle())

                            if AppEnvironment.isRunningInPreview, AppEnvironment.samplePhoto != nil {
                                Button {
                                    if let sample = AppEnvironment.samplePhoto {
                                        handleNewImage(sample)
                                    }
                                } label: {
                                    Label("Use Sample Photo (Preview)", systemImage: "photo.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SecondaryBrandButtonStyle())
                            }
                        }

                        if !recentMemes.isEmpty {
                            carouselSection(
                                title: "Recent Memes",
                                subtitle: "Tap to share again"
                            ) {
                                ForEach(recentMemes) { meme in
                                    Button {
                                        if let image = MemeStore.loadImage(for: meme) {
                                            shareItem = ShareImageItem(image: image)
                                        }
                                    } label: {
                                        memeThumb(for: meme)
                                    }
                                }
                            }
                        }

                        if !recentPhotos.isEmpty {
                            carouselSection(
                                title: "Recent Photos",
                                subtitle: "Tap to caption again"
                            ) {
                                ForEach(recentPhotos) { photo in
                                    Button {
                                        path.append(AppRoute.captions(photo))
                                    } label: {
                                        if let image = PhotoStore.loadImage(for: photo) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: photoThumbSize, height: photoThumbSize)
                                                .clipShape(RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius))
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius)
                                                        .stroke(BrandTheme.border, lineWidth: 1)
                                                }
                                        }
                                    }
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom)
                    .frame(width: width)
                }
                .scrollContentBackground(.hidden)
            }
            .frame(width: width, height: geo.size.height, alignment: .top)
        }
        .background(BrandTheme.background)
        .onAppear {
            reloadRecentsIfNeeded()
        }
        .onChange(of: path.count) { _, _ in
            if path.isEmpty {
                reloadRecentsIfNeeded()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                handleNewImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(
                items: [item.image],
                onDismiss: {
                    shareItem = nil
                }
            )
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        await MainActor.run {
                            errorMessage = "Could not load that photo."
                            selectedPhotoItem = nil
                        }
                        return
                    }
                    await MainActor.run {
                        handleNewImage(image)
                        selectedPhotoItem = nil
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = AppEnvironment.isRunningInPreview
                            ? "Photo library is not available in canvas preview. Use “Use Sample Photo (Preview)” or run the app with ⌘R."
                            : "Could not open the photo library."
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }

    /// Full-width cropped banner; `scaledToFill` preserves aspect ratio (no stretch).
    private func homeMasthead(width: CGFloat, topInset: CGFloat) -> some View {
        let imageHeight = width / Self.mastheadAspectRatio
        let fadeHeight = Self.mastheadFadeOverlap
        let totalHeight = imageHeight + fadeHeight

        return VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image("TessaMasthead")
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: imageHeight + topInset)
                    .frame(width: width, height: imageHeight, alignment: .top)
                    .clipped()
                    .overlay {
                        BrandTheme.background.opacity(0.14)
                    }

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: BrandTheme.background.opacity(0.08), location: 0.3),
                        .init(color: BrandTheme.background.opacity(0.28), location: 0.55),
                        .init(color: BrandTheme.background.opacity(0.58), location: 0.78),
                        .init(color: BrandTheme.background.opacity(0.88), location: 0.94),
                        .init(color: BrandTheme.background, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: width, height: imageHeight * 0.62)
                .frame(width: width, height: imageHeight, alignment: .bottom)
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    Text(BrandTheme.appName)
                        .font(BrandTheme.displayFont(size: 20))
                        .foregroundStyle(BrandTheme.ink)

                    Text(BrandTheme.tagline)
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.muted)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(width: width, height: imageHeight)

            LinearGradient(
                colors: [
                    BrandTheme.background.opacity(0.95),
                    BrandTheme.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: fadeHeight)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: totalHeight, alignment: .top)
    }

    private func carouselSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(BrandTheme.ink)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.muted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    content()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func memeThumb(for meme: SavedMeme) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = MemeStore.loadImage(for: meme) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: memeThumbSize, height: memeThumbSize)
                    .clipShape(RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius)
                            .stroke(BrandTheme.border, lineWidth: 1)
                    }
            }

            Image(systemName: "square.and.arrow.up")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BrandTheme.ink)
                .frame(width: 22, height: 22)
                .background(BrandTheme.surface)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(BrandTheme.border, lineWidth: 1)
                }
                .padding(6)
        }
    }

    private static var isRunningInPreview: Bool {
        AppEnvironment.isRunningInPreview
    }

    private func reloadRecentsIfNeeded() {
        guard !Self.isRunningInPreview else { return }
        reloadRecents()
    }

    private func reloadRecents() {
        recentMemes = MemeStore.loadAll()
        recentPhotos = PhotoStore.loadAll()
    }

    private func handleNewImage(_ image: UIImage) {
        do {
            let saved = try PhotoStore.save(image)
            reloadRecents()
            path.append(AppRoute.captions(saved))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Teeb Meme-ify") {
    TeebMemifyAppPreview()
}
