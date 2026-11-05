import SwiftUI
import Photos
import UIKit

struct MemePreviewView: View {
    enum Source {
        /// Rendered from the flow. `editing` is the saved meme this was reopened from, if any.
        case render(caption: String, photo: SavedPhoto, layout: MemeTextLayout, editing: SavedMeme?)
        /// An older saved meme with no photo on record, shown as saved.
        case saved(SavedMeme)
    }

    let source: Source
    @Binding var path: NavigationPath

    @State private var memeImage: UIImage?
    @State private var didPersistMeme = false
    @State private var toastMessage: ToastMessage?
    @State private var errorMessage: String?
    @State private var showSaveError = false
    @State private var shareItem: ShareImageItem?

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(
                step: 4,
                onBack: { path.removeLast() },
                onClose: { path = NavigationPath() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("THERE. A MEME.")
                        .font(BrandTheme.displayFont(size: 26))
                        .foregroundStyle(BrandTheme.ink)

                    memeFrame

                    HStack(spacing: 10) {
                        Button(action: saveToPhotos) {
                            Text("Save")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryBrandButtonStyle())

                        Button {
                            if let memeImage {
                                shareItem = ShareImageItem(image: memeImage)
                            }
                        } label: {
                            Text("Share")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryBrandButtonStyle())
                    }
                    .disabled(memeImage == nil)

                    startOverLink
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
            }
        }
        .background(BrandTheme.background.ignoresSafeArea())
        .brandToast(message: $toastMessage)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loadMeme()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(
                items: [item.image],
                onComplete: {
                    toastMessage = isNewMeme ? "Shared — and added to your greatest hits." : "Shared."
                },
                onDismiss: {
                    shareItem = nil
                }
            )
        }
        .alert("Could not save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please allow photo library access in Settings.")
        }
    }

    @ViewBuilder
    private var memeFrame: some View {
        // Whole meme, never cropped, but height-capped so tall photos don't push Save/Share
        // down under the toast.
        if let memeImage {
            Image(uiImage: memeImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BrandTheme.ink, lineWidth: 2)
                )
                .frame(maxWidth: .infinity, maxHeight: Self.maxMemeHeight)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BrandTheme.skeleton)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BrandTheme.ink, lineWidth: 2)
                )
                .frame(height: Self.maxMemeHeight)
        }
    }

    private static let maxMemeHeight: CGFloat = 420

    private var startOverLink: some View {
        Button {
            path = NavigationPath()
        } label: {
            VStack(spacing: 6) {
                Text("Start over")
                    .font(BrandTheme.bodyFont(size: 13, weight: .medium))
                    .foregroundStyle(BrandTheme.muted)
                Capsule()
                    .fill(BrandTheme.skeletonStrong)
                    .frame(width: 66, height: 2)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Whether this screen added a meme to the grid, rather than reopening one already there.
    private var isNewMeme: Bool {
        if case .render(_, _, _, nil) = source { return true }
        return false
    }

    private func loadMeme() {
        switch source {
        case .saved(let meme):
            memeImage = MemeStore.loadImage(for: meme)

        case .render(let caption, let photo, let layout, let editing):
            guard let image = PhotoStore.loadImage(for: photo) else { return }
            let rendered = MemeRenderer.render(image: image, caption: caption, layout: layout)
            memeImage = rendered

            guard !didPersistMeme else { return }
            didPersistMeme = true

            guard let editing else {
                _ = try? MemeStore.save(rendered, caption: caption, photo: photo, layout: layout)
                return
            }

            // Reopened from the grid: write only if something changed, and update that meme in
            // place rather than adding a copy.
            let unchanged = caption == editing.caption
                && layout == editing.layout
                && photo.id == editing.photo?.id
            guard !unchanged else { return }
            _ = try? MemeStore.replace(editing.id, with: rendered, caption: caption, photo: photo, layout: layout)
        }
    }

    private func saveToPhotos() {
        guard let memeImage else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    errorMessage = "Photo library access denied."
                    showSaveError = true
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: memeImage)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        toastMessage = "Saved to your photos."
                    } else {
                        errorMessage = error?.localizedDescription ?? "Save failed."
                        showSaveError = true
                    }
                }
            }
        }
    }
}
