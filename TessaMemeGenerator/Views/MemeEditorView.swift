import SwiftUI

struct MemeEditorView: View {
    let caption: String
    let photo: SavedPhoto
    @Binding var path: NavigationPath

    @AppStorage("hasSeenMemeEditorHint") private var hasSeenMemeEditorHint = false

    @State private var layout = MemeTextLayout.default
    @State private var pinchBaseScale: CGFloat = 1.0
    @State private var showPositionHint = false

    private var image: UIImage? {
        PhotoStore.loadImage(for: photo)
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                if let image {
                    let displayRect = aspectFitRect(imageSize: image.size, in: geometry.size)

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        textOverlay(image: image, displayRect: displayRect)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 12)

            if showPositionHint {
                VStack {
                    Spacer()
                    positionHint
                        .padding(.bottom, 16)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            editorBottomSheet
        }
        .brandScreen()
        .navigationTitle("Position Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BrandTheme.background, for: .navigationBar)
        .onAppear {
            pinchBaseScale = layout.fontScale
            layout = clampedLayout(layout)
            if !hasSeenMemeEditorHint {
                showPositionHint = true
            }
        }
        .animation(.easeOut(duration: 0.2), value: showPositionHint)
    }

    private var positionHint: some View {
        Button {
            dismissPositionHint()
        } label: {
            Text("Drag to move · Pinch to resize")
                .font(.footnote.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(BrandTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(BrandTheme.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Dismisses this tip")
    }

    private var editorBottomSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Alignment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.muted)
                    .textCase(.uppercase)

                Picker("Alignment", selection: $layout.alignment) {
                    ForEach(MemeTextAlignment.allCases, id: \.self) { option in
                        Image(systemName: option.iconName)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Text size")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.muted)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(Int(layout.fontScale * 100))%")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(BrandTheme.muted)
                }

                Slider(
                    value: $layout.fontScale,
                    in: 0.4...2.5,
                    step: 0.05
                )
                .tint(BrandTheme.accent)
            }

            Button {
                path.append(AppRoute.preview(caption: caption, photo: photo, layout: layout))
            } label: {
                Text("Create Meme")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryBrandButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandTheme.border.opacity(0.6), lineWidth: 1)
        }
        .padding(.horizontal, 12)
    }

    private func dismissPositionHint() {
        hasSeenMemeEditorHint = true
        showPositionHint = false
    }

    private func clampedLayout(_ value: MemeTextLayout) -> MemeTextLayout {
        var layout = value
        layout.centerX = min(max(layout.centerX, 0.08), 0.92)
        layout.centerY = min(max(layout.centerY, 0.08), 0.92)
        layout.fontScale = min(max(layout.fontScale, 0.4), 2.5)
        return layout
    }

    @ViewBuilder
    private func textOverlay(image: UIImage, displayRect: CGRect) -> some View {
        let maxTextWidth = displayRect.width * 0.92
        let baseFontSize = displayRect.width * 0.11 * layout.fontScale
        let center = CGPoint(
            x: displayRect.minX + layout.centerX * displayRect.width,
            y: displayRect.minY + layout.centerY * displayRect.height
        )

        MemeStyleText(text: caption, fontSize: baseFontSize, alignment: layout.alignment)
            .frame(width: maxTextWidth, alignment: layout.alignment.frameAlignment)
            .position(center)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dismissPositionHint()
                        let nx = (value.location.x - displayRect.minX) / displayRect.width
                        let ny = (value.location.y - displayRect.minY) / displayRect.height
                        layout.centerX = min(max(nx, 0.08), 0.92)
                        layout.centerY = min(max(ny, 0.08), 0.92)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        dismissPositionHint()
                        layout.fontScale = min(max(pinchBaseScale * value, 0.4), 2.5)
                    }
                    .onEnded { _ in
                        pinchBaseScale = layout.fontScale
                    }
            )
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
