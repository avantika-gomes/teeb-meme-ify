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
                    captionSkeletonSection
                } else if hasGenerated && !captions.isEmpty {
                    captionSelectionSection
                }

                if usingFallbackCaptions && !isLoading {
                    Text("Couldn't reach AI right now — here are some starters. Tap Regenerate to try again.")
                        .font(.footnote)
                        .foregroundStyle(BrandTheme.muted)
                        .multilineTextAlignment(.leading)
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
        HStack(spacing: 12) {
            Button {
                Task { await generateCaptions() }
            } label: {
                Label(
                    hasGenerated ? "Regenerate" : "Generate Captions",
                    systemImage: "sparkles"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryBrandButtonStyle())
            .disabled(isLoading || image == nil)

            if isLoading {
                ProgressView()
                    .controlSize(.regular)
                    .tint(BrandTheme.accent)
            }
        }
    }

    private var captionSkeletonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a caption")
                .font(.headline)
                .foregroundStyle(BrandTheme.ink)

            VStack(spacing: 10) {
                ForEach(CaptionSkeletonRow.placeholderHeights, id: \.self) { height in
                    CaptionSkeletonRow(height: height)
                }
            }
        }
    }

    private var captionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a caption")
                .font(.headline)
                .foregroundStyle(BrandTheme.ink)

            VStack(spacing: 10) {
                ForEach(captions, id: \.self) { caption in
                    Button {
                        selectedCaption = caption
                        useCustomCaption = false
                    } label: {
                        CaptionPill(
                            text: caption,
                            isSelected: !useCustomCaption && selectedCaption == caption
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var customCaptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or write your own caption")
                .font(.headline)
                .foregroundStyle(BrandTheme.ink)

            TextField("Enter your meme text", text: $customCaption)
                .font(.subheadline.weight(useCustomCaption ? .semibold : .medium))
                .foregroundStyle(BrandTheme.ink)
                .textInputAutocapitalization(.characters)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
                        .fill(useCustomCaption ? BrandTheme.accentSoft : BrandTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
                        .stroke(useCustomCaption ? BrandTheme.accent : BrandTheme.border, lineWidth: 1)
                )
                .onChange(of: customCaption) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        useCustomCaption = true
                        selectedCaption = nil
                    } else if useCustomCaption {
                        useCustomCaption = false
                    }
                }
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

private struct CaptionPill: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(.subheadline.weight(isSelected ? .semibold : .medium))
            .foregroundStyle(BrandTheme.ink)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
                    .fill(isSelected ? BrandTheme.accentSoft : BrandTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
                    .stroke(isSelected ? BrandTheme.accent : BrandTheme.border, lineWidth: 1)
            )
    }
}

private struct CaptionSkeletonRow: View {
    static let placeholderHeights: [CGFloat] = [44, 52, 44, 48]

    let height: CGFloat
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
            .fill(BrandTheme.border.opacity(0.35))
            .frame(height: height)
            .overlay {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    BrandTheme.surface.opacity(0.75),
                                    .clear,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.45)
                        .offset(x: shimmerOffset * geometry.size.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.4
                }
            }
            .accessibilityLabel("Loading caption")
    }
}
