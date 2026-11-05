import SwiftUI
import PhotosUI
import UIKit

struct CaptionView: View {
    let photo: SavedPhoto
    @Binding var path: NavigationPath

    @State private var currentPhoto: SavedPhoto
    @State private var mode: CaptionMode = .suggestions
    @State private var steeringText = ""
    @State private var captions: [String] = []
    @State private var selectedCaption: String?
    @State private var customCaption = ""
    @State private var isLoading = false
    @State private var isRefining = false
    @State private var usingFallbackCaptions = false
    @State private var hasGenerated = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var toastMessage: String?

    private let bottomBarHeight: CGFloat = 84

    init(photo: SavedPhoto, path: Binding<NavigationPath>) {
        self.photo = photo
        self._path = path
        self._currentPhoto = State(initialValue: photo)
    }

    private enum CaptionMode: Hashable {
        case suggestions
        case writeMyOwn

        var title: String {
            switch self {
            case .suggestions: "SUGGESTIONS"
            case .writeMyOwn: "WRITE MY OWN"
            }
        }
    }

    private var image: UIImage? {
        PhotoStore.loadImage(for: currentPhoto)
    }

    private var activeCaption: String? {
        switch mode {
        case .writeMyOwn:
            let trimmed = customCaption.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .suggestions:
            return selectedCaption
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(
                step: 2,
                onBack: { path.removeLast() },
                onClose: { path = NavigationPath() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("MAKE A BAD JOKE")
                        .font(BrandTheme.displayFont(size: 26))
                        .foregroundStyle(BrandTheme.ink)

                    photoFrame

                    BrandSegmentedControl(options: [CaptionMode.suggestions, .writeMyOwn], selection: $mode) { option, isSelected in
                        Text(option.title)
                            .font(BrandTheme.bodyFont(size: 13, weight: .bold))
                            .foregroundStyle(isSelected ? BrandTheme.ink : BrandTheme.muted)
                    }

                    if mode == .suggestions {
                        suggestionsSection
                    } else {
                        writeMyOwnSection
                    }
                }
                .padding(16)
                .padding(.bottom, bottomBarHeight)
            }

            bottomBar
        }
        .background(BrandTheme.background.ignoresSafeArea())
        .brandToast(message: $toastMessage, above: bottomBarHeight)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !hasGenerated {
                Task { await generateCaptions() }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                isPresented: $showCamera,
                onImagePicked: { image in
                    replacePhoto(with: image, captured: .now)
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
                    // Read EXIF from the original data; UIImage has already dropped it.
                    let captured = PhotoMetadata.capture(from: data)
                    await MainActor.run {
                        replacePhoto(with: image, captured: captured)
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

    // MARK: - Photo frame

    private var photoFrame: some View {
        GeometryReader { geo in
            let side = geo.size.width

            ZStack(alignment: .topLeading) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipped()
                } else {
                    BrandTheme.skeleton
                }

                if let activeCaption, !activeCaption.isEmpty {
                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            MemeStyleText(text: activeCaption, fontSize: side * 0.085, alignment: .left)
                                .frame(maxWidth: side * 0.88, alignment: .leading)
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(16)
                }

                VStack {
                    HStack {
                        Spacer(minLength: 0)
                        photoActionButtons
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BrandTheme.ink, lineWidth: 2)
        )
    }

    private var photoActionButtons: some View {
        HStack(spacing: 10) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    photoIconButton {
                        Circle()
                            .stroke(BrandTheme.ink, lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retake photo")
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                photoIconButton {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach([16, 12, 8], id: \.self) { width in
                            Capsule()
                                .fill(BrandTheme.ink)
                                .frame(width: CGFloat(width), height: 2.5)
                        }
                    }
                }
            }
            .accessibilityLabel("Change photo")
        }
    }

    private func photoIconButton(@ViewBuilder glyph: () -> some View) -> some View {
        glyph()
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BrandTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BrandTheme.ink, lineWidth: 2)
            )
    }

    // MARK: - Suggestions mode

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TAP TO SELECT")
                    .font(BrandTheme.bodyFont(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(BrandTheme.hint)

                captionDeck
            }

            if usingFallbackCaptions && !isLoading {
                Text("Couldn't reach AI right now — here are some starters. Tap ↻ to try again.")
                    .font(BrandTheme.bodyFont(size: 12))
                    .foregroundStyle(BrandTheme.muted)
                    .multilineTextAlignment(.leading)
            }

            steerRow
        }
    }

    /// Total captions OpenAIService aims to return, so the deck knows how many trailing skeleton
    /// slots to reserve while some are still streaming in.
    private var expectedCaptionCount: Int {
        OpenAIService.captionsPerStyle * CaptionStyle.allCases.count
    }

    private var isStillGenerating: Bool {
        isLoading || isRefining
    }

    /// One continuous horizontal row: loaded captions first, then shimmer placeholders for
    /// whatever's still streaming in. Scrolling to the end shows a real card once it arrives
    /// instead of a separate "writing a few more" indicator elsewhere on screen.
    private var captionDeck: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 10) {
                ForEach(captions, id: \.self) { caption in
                    captionCard(caption)
                }

                if isStillGenerating {
                    ForEach(0..<max(0, expectedCaptionCount - captions.count), id: \.self) { _ in
                        skeletonCard
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // Height is fixed so a card never resizes the row when it swaps from skeleton to real text;
    // width is free to grow with content — only the row's height has to stay put.
    private static let captionCardHeight: CGFloat = 60
    private static let captionCardMinWidth: CGFloat = 190

    private func captionCard(_ caption: String) -> some View {
        let isSelected = selectedCaption == caption
        return Button {
            selectedCaption = caption
        } label: {
            Text(caption)
                .font(BrandTheme.displayFont(size: 15))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(BrandTheme.ink)
                .frame(minWidth: Self.captionCardMinWidth, alignment: .leading)
                .frame(height: Self.captionCardHeight, alignment: .leading)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? BrandTheme.lime : BrandTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BrandTheme.ink, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    /// Same fixed height as `captionCard` — a slot that's still loading must be exactly as tall as
    /// its real card will be, or the deck's height shifts the moment it arrives. Width doesn't need
    /// to match since a loading slot has no content to size around.
    private var skeletonCard: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(BrandTheme.skeleton)
            .frame(width: Self.captionCardMinWidth, height: Self.captionCardHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BrandTheme.ink, lineWidth: 2)
            )
            .overlay {
                ShimmerSweep()
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var steerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STEER IT — OPTIONAL")
                .font(BrandTheme.bodyFont(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(BrandTheme.hint)

            HStack(spacing: 10) {
                TextField("e.g. make it about Mondays", text: $steeringText)
                    .font(BrandTheme.bodyFont(size: 14))
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(BrandTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(BrandTheme.ink, lineWidth: 2)
                    )

                Button {
                    Task { await generateCaptions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(BrandTheme.ink)
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(BrandTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(BrandTheme.ink, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isLoading || image == nil)
                .accessibilityLabel("Regenerate captions")
            }
        }
    }

    // MARK: - Write my own mode

    private var writeMyOwnSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR CAPTION")
                .font(BrandTheme.bodyFont(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(BrandTheme.hint)

            TextField("Fine. Write it yourself.", text: $customCaption)
                .font(BrandTheme.displayFont(size: 17))
                .textInputAutocapitalization(.characters)
                .foregroundStyle(BrandTheme.ink)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BrandTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BrandTheme.ink, lineWidth: 2)
                )
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        let hasCaption = activeCaption != nil

        return VStack(spacing: 0) {
            Rectangle()
                .fill(BrandTheme.ink)
                .frame(height: 2)

            Button {
                if let activeCaption {
                    path.append(AppRoute.editor(caption: activeCaption, photo: currentPhoto))
                } else {
                    toastMessage = "Pick a caption first."
                }
            } label: {
                HStack(spacing: 6) {
                    Text("PLACE THE TEXT")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .font(BrandTheme.displayFont(size: 17))
                .textCase(.uppercase)
                .foregroundStyle(hasCaption ? .white : BrandTheme.hint)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: BrandTheme.cornerRadius)
                        .fill(hasCaption ? BrandTheme.orange : BrandTheme.skeleton)
                        .overlay(
                            RoundedRectangle(cornerRadius: BrandTheme.cornerRadius)
                                .stroke(BrandTheme.ink, lineWidth: 2)
                        )
                        .compositingGroup()
                        .shadow(
                            color: hasCaption ? BrandTheme.ink : .clear,
                            radius: 0,
                            x: hasCaption ? 4 : 0,
                            y: hasCaption ? 4 : 0
                        )
                }
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .background(BrandTheme.background)
    }

    // MARK: - Data

    private func replacePhoto(with image: UIImage, captured: PhotoCapture?) {
        guard let saved = try? PhotoStore.save(image, captured: captured) else { return }
        currentPhoto = saved
        resetCaptionState()
        Task { await generateCaptions() }
    }

    private func resetCaptionState() {
        captions = []
        selectedCaption = nil
        customCaption = ""
        mode = .suggestions
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
        if mode == .suggestions {
            selectedCaption = nil
        }

        do {
            let service = try OpenAIService()
            let placeName = await PhotoStore.resolvedPlaceName(for: currentPhoto)
            let stream = service.captionStream(
                for: image,
                steeringText: steeringText,
                context: CaptionContext.forCapture(currentPhoto.captureMoment, placeName: placeName)
            )

            var received = false
            for await batch in stream {
                received = true
                captions = batch
                hasGenerated = true
                usingFallbackCaptions = false
                isLoading = false
                isRefining = true
            }
            isRefining = false

            // Both styles failed. Captions may still hold the previous run's results, so key the
            // fallback off whether anything arrived rather than off the array being empty.
            if !received {
                captions = CaptionFallback.generate(steeringText: steeringText)
                usingFallbackCaptions = true
                hasGenerated = true
            }
        } catch {
            captions = CaptionFallback.generate(steeringText: steeringText)
            usingFallbackCaptions = true
            hasGenerated = true
        }

        isLoading = false
        isRefining = false
    }
}

private struct ShimmerSweep: View {
    @State private var offset: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [.clear, BrandTheme.surface.opacity(0.75), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.5)
            .offset(x: offset * geometry.size.width)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                offset = 1.6
            }
        }
        .allowsHitTesting(false)
    }
}
