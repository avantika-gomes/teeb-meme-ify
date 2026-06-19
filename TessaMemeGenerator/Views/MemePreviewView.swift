import SwiftUI
import Photos
import UIKit

struct MemePreviewView: View {
    let caption: String
    let photo: SavedPhoto
    let layout: MemeTextLayout
    @Binding var path: NavigationPath

    @State private var memeImage: UIImage?
    @State private var didPersistMeme = false
    @State private var confirmationMessage: String?
    @State private var errorMessage: String?
    @State private var showSaveError = false
    @State private var shareItem: ShareImageItem?
    @State private var confirmationDismissTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let memeImage {
                    Image(uiImage: memeImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius))
                } else {
                    ProgressView("Rendering meme...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }

                VStack(spacing: 12) {
                    Button {
                        saveToPhotos()
                    } label: {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryBrandButtonStyle())
                    .disabled(memeImage == nil)

                    Button {
                        if let memeImage {
                            shareItem = ShareImageItem(image: memeImage)
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryBrandButtonStyle())
                    .disabled(memeImage == nil)

                    Button {
                        path = NavigationPath()
                    } label: {
                        Label("Done", systemImage: "house.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryBrandButtonStyle())
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .brandScreen()
        .brandConfirmationToast(message: $confirmationMessage)
        .navigationTitle("Your Meme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BrandTheme.background, for: .navigationBar)
        .onAppear {
            renderMeme()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(
                items: [item.image],
                onComplete: {
                    showConfirmation("Shared!")
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

    private func showConfirmation(_ message: String) {
        confirmationDismissTask?.cancel()
        confirmationMessage = message
        confirmationDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if confirmationMessage == message {
                    confirmationMessage = nil
                }
            }
        }
    }

    private func renderMeme() {
        guard let image = PhotoStore.loadImage(for: photo) else { return }
        let rendered = MemeRenderer.render(image: image, caption: caption, layout: layout)
        memeImage = rendered

        guard !didPersistMeme else { return }
        didPersistMeme = true
        _ = try? MemeStore.save(rendered, caption: caption)
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
                        showConfirmation("Saved to Photos!")
                    } else {
                        errorMessage = error?.localizedDescription ?? "Save failed."
                        showSaveError = true
                    }
                }
            }
        }
    }
}
