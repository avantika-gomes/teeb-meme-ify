import SwiftUI

struct MemeEditorView: View {
    let caption: String
    let photo: SavedPhoto
    /// The saved meme being reopened from the grid, passed on to the preview.
    let editing: SavedMeme?
    @Binding var path: NavigationPath

    @Environment(\.displayScale) private var screenScale

    @State private var layout: MemeTextLayout
    @State private var pinchBaseScale: CGFloat = 1.0
    @State private var isPinching = false
    @State private var isDragging = false
    /// MemeRenderer's auto-fitted size at 100% scale, in image points. Cached because the fit is
    /// a measuring loop and the body re-renders on every drag frame.
    @State private var fittedBaseFontSize: CGFloat?
    /// The caption as MemeRenderer draws it. Re-rendered only when size or alignment change —
    /// dragging just moves it.
    @State private var textLayer: UIImage?

    private static let scaleRange: ClosedRange<CGFloat> = 0.4...2.2
    private static let positionRange: ClosedRange<CGFloat> = 0.08...0.92

    /// `initialLayout` lets a meme reopened from the grid start where its text was left.
    init(
        caption: String,
        photo: SavedPhoto,
        initialLayout: MemeTextLayout = .default,
        editing: SavedMeme? = nil,
        path: Binding<NavigationPath>
    ) {
        self.caption = caption
        self.photo = photo
        self.editing = editing
        self._path = path
        self._layout = State(initialValue: initialLayout)
    }

    private var image: UIImage? {
        PhotoStore.loadImage(for: photo)
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(
                step: 3,
                onBack: { path.removeLast() },
                onClose: { path = NavigationPath() }
            )

            // Aspect-fit rather than filling the frame: layout positions are fractions of the
            // whole image, so a cropped preview would place text somewhere other than where
            // MemeRenderer draws it.
            GeometryReader { geometry in
                if let image {
                    let displayRect = aspectFitRect(imageSize: image.size, in: geometry.size)
                    let preview = previewText(image: image, displayRect: displayRect)

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: displayRect.width, height: displayRect.height)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(BrandTheme.ink, lineWidth: 2)
                            )
                            .overlay(alignment: .bottom) {
                                // Steps aside when the caption sits on it — bottom text is the
                                // classic meme spot, and the pill would show through the letters.
                                positionHint
                                    .padding(.bottom, Self.hintBottomInset)
                                    .opacity(preview.rect.intersects(hintRect(in: displayRect)) ? 0 : 1)
                                    .animation(.easeOut(duration: 0.15), value: preview.rect.intersects(hintRect(in: displayRect)))
                            }
                            .position(x: displayRect.midX, y: displayRect.midY)

                        // Clipped to the photo because MemeRenderer only draws within the image.
                        textOverlay(preview, displayRect: displayRect)
                            .mask(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .frame(width: displayRect.width, height: displayRect.height)
                                    .offset(x: displayRect.minX, y: displayRect.minY)
                            }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            controls
        }
        .background(BrandTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            layout = clampedLayout(layout)
            pinchBaseScale = layout.fontScale
            refitFont()
        }
        .onChange(of: layout.alignment) { _, _ in
            refitFont()
        }
        .onChange(of: layout.fontScale) { _, _ in
            renderTextLayer()
        }
    }

    /// Phone-width target the text layer is rasterized for; the on-screen frame scales it to fit.
    private static let previewWidthHint: CGFloat = 430

    private func refitFont() {
        guard let image else { return }
        var unscaled = layout
        unscaled.fontScale = 1
        fittedBaseFontSize = MemeRenderer.fittedFontSize(for: caption, imageSize: image.size, layout: unscaled)
        renderTextLayer()
    }

    private func renderTextLayer() {
        guard let image, let fittedBaseFontSize else { return }
        textLayer = MemeRenderer.textLayer(
            for: caption,
            fontSize: fittedBaseFontSize * layout.fontScale,
            imageSize: image.size,
            layout: layout,
            pixelScale: screenScale * Self.previewWidthHint / image.size.width
        )
    }

    private var positionHint: some View {
        Text("DRAG TO MOVE · SLIDE TO RESIZE")
            .font(BrandTheme.bodyFont(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(BrandTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(BrandTheme.surface))
            .overlay(Capsule().stroke(BrandTheme.ink, lineWidth: 2))
            .allowsHitTesting(false)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                BrandSegmentedControl(options: MemeTextAlignment.allCases, selection: $layout.alignment) { option, isSelected in
                    alignmentGlyph(option, isSelected: isSelected)
                }

                Text("\(Int((layout.fontScale * 100).rounded()))%")
                    .font(BrandTheme.bodyFont(size: 13, weight: .bold))
                    .foregroundStyle(BrandTheme.muted)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }

            Slider(value: $layout.fontScale, in: Self.scaleRange, step: 0.05)
                .tint(BrandTheme.ink)
                .accessibilityLabel("Text size")

            Button {
                path.append(AppRoute.preview(caption: caption, photo: photo, layout: layout, editing: editing))
            } label: {
                Text("Make the meme")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryBrandButtonStyle())
        }
        .padding(16)
    }

    /// Two bars drawn left/center/right — the alignment picker's segment label.
    private func alignmentGlyph(_ alignment: MemeTextAlignment, isSelected: Bool) -> some View {
        VStack(alignment: alignment.horizontalAlignment, spacing: 4) {
            Capsule().frame(width: 34, height: 3)
            Capsule().frame(width: 22, height: 3)
        }
        .frame(width: 34)
        .foregroundStyle(isSelected ? BrandTheme.ink : BrandTheme.hint)
        .accessibilityElement()
        .accessibilityLabel("Align \(alignment.rawValue)")
    }

    // MARK: - Text

    private struct PreviewText {
        /// Where the caption block sits, in the GeometryReader's coordinates.
        let rect: CGRect
        /// On-screen points per image point.
        let displayScale: CGFloat
    }

    /// Places the caption exactly as MemeRenderer will, then maps image points onto the on-screen
    /// frame — including the renderer's nudge that keeps text inside the photo.
    private func previewText(image: UIImage, displayRect: CGRect) -> PreviewText {
        let displayScale = displayRect.width / image.size.width
        let imageFontSize = (fittedBaseFontSize ?? image.size.width * 0.11) * layout.fontScale
        let imageTextRect = MemeRenderer.textRect(
            for: caption,
            fontSize: imageFontSize,
            imageSize: image.size,
            layout: layout
        )
        return PreviewText(
            rect: CGRect(
                x: displayRect.minX + imageTextRect.minX * displayScale,
                y: displayRect.minY + imageTextRect.minY * displayScale,
                width: imageTextRect.width * displayScale,
                height: imageTextRect.height * displayScale
            ),
            displayScale: displayScale
        )
    }

    private static let hintBottomInset: CGFloat = 12

    /// Rough footprint of the hint pill, enough to tell whether the caption is sitting on it.
    private func hintRect(in displayRect: CGRect) -> CGRect {
        let size = CGSize(width: 240, height: 34)
        return CGRect(
            x: displayRect.midX - size.width / 2,
            y: displayRect.maxY - Self.hintBottomInset - size.height,
            width: size.width,
            height: size.height
        )
    }

    @ViewBuilder
    private func textOverlay(_ preview: PreviewText, displayRect: CGRect) -> some View {
        // The layer is centered on the text block (its outline margin is the same on every side),
        // so it lands exactly where the renderer draws.
        Group {
            if let textLayer {
                Image(uiImage: textLayer)
                    .resizable()
                    .frame(
                        width: textLayer.size.width * preview.displayScale,
                        height: textLayer.size.height * preview.displayScale
                    )
            }
        }
            .padding(6)
            .contentShape(Rectangle())
            .overlay {
                if isDragging {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(BrandTheme.ink, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
            }
            .position(x: preview.rect.midX, y: preview.rect.midY)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let nx = (value.location.x - displayRect.minX) / displayRect.width
                        let ny = (value.location.y - displayRect.minY) / displayRect.height
                        layout.centerX = nx.clamped(to: Self.positionRange)
                        layout.centerY = ny.clamped(to: Self.positionRange)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        // Re-read the base at the start of every pinch so a slider change in
                        // between isn't overwritten by a stale scale.
                        if !isPinching {
                            pinchBaseScale = layout.fontScale
                            isPinching = true
                        }
                        layout.fontScale = (pinchBaseScale * value).clamped(to: Self.scaleRange)
                    }
                    .onEnded { _ in
                        isPinching = false
                    }
            )
    }

    private func clampedLayout(_ value: MemeTextLayout) -> MemeTextLayout {
        var layout = value
        layout.centerX = layout.centerX.clamped(to: Self.positionRange)
        layout.centerY = layout.centerY.clamped(to: Self.positionRange)
        layout.fontScale = layout.fontScale.clamped(to: Self.scaleRange)
        return layout
    }

    private func aspectFitRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            let height = containerSize.width / imageAspect
            let y = (containerSize.height - height) / 2
            return CGRect(x: 0, y: y, width: containerSize.width, height: height)
        } else {
            let width = containerSize.height * imageAspect
            let x = (containerSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: containerSize.height)
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
