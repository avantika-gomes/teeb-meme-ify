import SwiftUI
import PhotosUI
import UIKit

struct CaptionView: View {
    let photo: SavedPhoto
    @Binding var path: NavigationPath

    @State private var currentPhoto: SavedPhoto
    @State private var steeringText = ""
    @State private var captions: [String] = []
    @State private var selectedCaption: String?
    @State private var customCaption = ""
    @State private var useCustomCaption = false
    @State private var isLoading = false
    @State private var usingFallbackCaptions = false
    @State private var hasGenerated = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(photo: SavedPhoto, path: Binding<NavigationPath>) {
        self.photo = photo
        self._path = path
        self._currentPhoto = State(initialValue: photo)
    }

    private var image: UIImage? {
        PhotoStore.loadImage(for: currentPhoto)
    }

    private var activeCaption: String? {
        if useCustomCaption {
            let trimmed = customCaption.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return selectedCaption
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photoSection
                steeringSection
                generateSection

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Generating captions...")
                        Spacer()
                    }
                }

                if usingFallbackCaptions {
                    Text("Couldn't reach AI right now — here are some starters. Tap Regenerate to try again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if hasGenerated && !captions.isEmpty {
                    captionSelectionSection
                }

                customCaptionSection
                createMemeButton
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .brandScreen()
        .navigationTitle(hasGenerated ? "Captions" : "Your Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BrandTheme.background, for: .navigationBar)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                isPresented: $showCamera,
                onImagePicked: { image in
                    replacePhoto(with: image)
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        return
                    }
                    await MainActor.run {
                        replacePhoto(with: image)
                        selectedPhotoItem = nil
                    }
                } catch {
                    await MainActor.run {
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        Group {
            if let image {
                HStack {
                    Spacer(minLength: 0)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 340)
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: 10) {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    Button {
                                        showCamera = true
                                    } label: {
                                        photoOverlayIcon("camera.fill")
                                    }
                                    .accessibilityLabel("Retake photo")
                                }

                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    photoOverlayIcon("photo.on.rectangle")
                                }
                                .accessibilityLabel("Change photo")
                            }
                            .padding(10)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func photoOverlayIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background {
                Circle()
                    .fill(BrandTheme.ink.opacity(0.62))
            }
    }

    private var steeringSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Steer the captions (optional)")
                .font(.headline)
            TextField("e.g. make it about Monday mornings", text: $steeringText)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var generateSection: some View {
        Button {
            Task { await generateCaptions() }
        } label: {
            Label(
                hasGenerated ? "Regenerate Captions" : "Generate Captions",
                systemImage: "sparkles"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryBrandButtonStyle())
        .disabled(isLoading || image == nil)
    }

    private var captionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a caption")
                .font(.headline)

            ForEach(captions, id: \.self) { caption in
                Button {
                    selectedCaption = caption
                    useCustomCaption = false
                } label: {
                    Text(caption)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius)
                                .fill(BrandTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius)
                                        .stroke(
                                            !useCustomCaption && selectedCaption == caption
                                                ? BrandTheme.accent
                                                : BrandTheme.border,
                                            lineWidth: !useCustomCaption && selectedCaption == caption ? 3 : 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var customCaptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or write your own caption")
                .font(.headline)
            TextField("Enter your meme text", text: $customCaption)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .onChange(of: customCaption) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        useCustomCaption = true
                        selectedCaption = nil
                    } else if useCustomCaption {
                        useCustomCaption = false
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            useCustomCaption ? BrandTheme.accent : Color.clear,
                            lineWidth: 2
                        )
                )
        }
    }

    private var createMemeButton: some View {
        Button {
            createMeme()
        } label: {
            Label("Next: Position Text", systemImage: "text.below.photo")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryBrandButtonStyle())
        .disabled(activeCaption == nil || image == nil)
    }

    private func replacePhoto(with image: UIImage) {
        guard let saved = try? PhotoStore.save(image) else { return }
        currentPhoto = saved
        resetCaptionState()
    }

    private func resetCaptionState() {
        captions = []
        selectedCaption = nil
        customCaption = ""
        useCustomCaption = false
        hasGenerated = false
        usingFallbackCaptions = false
    }

    private func generateCaptions() async {
        guard let image else {
            captions = CaptionFallback.generate(steeringText: steeringText)
            usingFallbackCaptions = true
            hasGenerated = true
            return
        }

        isLoading = true
        usingFallbackCaptions = false
        if !useCustomCaption {
            selectedCaption = nil
        }

        do {
            let service = try OpenAIService()
            let results = try await service.generateCaptions(for: image, steeringText: steeringText)
            captions = results
            hasGenerated = true
            usingFallbackCaptions = false
        } catch {
            captions = CaptionFallback.generate(steeringText: steeringText)
            usingFallbackCaptions = true
            hasGenerated = true
        }

        isLoading = false
    }

    private func createMeme() {
        guard let activeCaption else { return }
        path.append(AppRoute.editor(caption: activeCaption, photo: currentPhoto))
    }
}
