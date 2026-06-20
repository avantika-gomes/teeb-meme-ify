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

    private let actionBarHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    if let memeImage {
                        Image(uiImage: memeImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                    } else {
                        ProgressView("Rendering meme...")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
            }
            .scrollContentBackground(.hidden)

            previewActionBar
        }
        .brandScreen()
        .brandActionBarToast(message: $confirmationMessage, above: actionBarHeight)
        .navigationTitle("Your Meme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BrandTheme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    path = NavigationPath()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(BrandTheme.ink)
                }
                .accessibilityLabel("Close")
            }
        }
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

    private var previewActionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(BrandTheme.border)

            HStack(spacing: 12) {
                Button(action: saveToPhotos) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryBrandButtonStyle())
                .disabled(memeImage == nil)

                Button {
                    if let memeImage {
                        shareItem = ShareImageItem(image: memeImage)
                    }
                } label: {
                    Text("Share")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryBrandButtonStyle())
                .disabled(memeImage == nil)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .fixedSize(horizontal: false, vertical: true)
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
