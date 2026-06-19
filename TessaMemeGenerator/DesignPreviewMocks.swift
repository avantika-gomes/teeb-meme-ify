#if DEBUG
import SwiftUI

// MARK: - Proposed design tokens (preview only — not wired into the app yet)

enum DesignPreviewTokens {
    static let gridSpacing: CGFloat = 2
    static let screenPadding: CGFloat = 16
    static let thumbRadius: CGFloat = 10
    static let toolbarHeight: CGFloat = 52
    static let photoMaxHeight: CGFloat = 240

    static let surfaceMuted = Color(red: 0.96, green: 0.96, blue: 0.96)
    static let placeholder = Color(red: 0.92, green: 0.92, blue: 0.92)

    static func largeTitle() -> Font { .largeTitle.weight(.bold) }
    static func screenTitle() -> Font { .title2.weight(.semibold) }
    static func rowTitle() -> Font { .body }
    static func meta() -> Font { .subheadline }
}

// MARK: - Shared components

private struct DesignBrandMark: View {
    var size: CGFloat = 22

    var body: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

private struct DesignBottomToolbar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignPreviewTokens.toolbarHeight)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct DesignToolbarIconButton: View {
    let systemName: String
    var tint: Color = BrandTheme.ink
    var label: String

    var body: some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.body.weight(.medium))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(label)
    }
}

private struct DesignPlaceholderTile: View {
    var caption: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DesignPreviewTokens.placeholder

                if let caption {
                    Text(caption)
                        .font(.system(size: geo.size.width * 0.11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(6)
                        .shadow(color: .black.opacity(0.6), radius: 0, x: 1, y: 1)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DesignPreviewTokens.thumbRadius, style: .continuous))
    }
}

private struct DesignPhotoPlaceholder: View {
    var maxHeight: CGFloat = DesignPreviewTokens.photoMaxHeight

    var body: some View {
        RoundedRectangle(cornerRadius: DesignPreviewTokens.thumbRadius, style: .continuous)
            .fill(DesignPreviewTokens.placeholder)
            .aspectRatio(4 / 3, contentMode: .fit)
            .frame(maxHeight: maxHeight)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(BrandTheme.muted.opacity(0.7))
            }
    }
}

// MARK: - Mock screens

struct DesignMockHomeView: View {
    private let mockCaptions = [
        "MONDAY MOOD",
        "NOT TODAY",
        "VIBES",
        "SEND HELP",
        "NO THOUGHTS",
        "OK BOOMER",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: DesignPreviewTokens.gridSpacing), count: 3),
                    spacing: DesignPreviewTokens.gridSpacing
                ) {
                    ForEach(Array(mockCaptions.enumerated()), id: \.offset) { index, caption in
                        DesignPlaceholderTile(caption: caption)
                    }
                }
                .padding(.horizontal, DesignPreviewTokens.screenPadding)
                .padding(.top, 8)
            }
            .background(BrandTheme.background)
            .navigationTitle("Meme-ify")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DesignBrandMark()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: {
                        Image(systemName: "camera")
                            .font(.body.weight(.medium))
                    }
                    .tint(BrandTheme.accent)
                }
            }
            .safeAreaInset(edge: .bottom) {
                DesignBottomToolbar {
                    DesignToolbarIconButton(systemName: "camera", tint: BrandTheme.accent, label: "Take photo")
                    DesignToolbarIconButton(systemName: "photo.on.rectangle", label: "Choose photo")
                }
            }
        }
        .tint(BrandTheme.accent)
    }
}

struct DesignMockHomeEmptyView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer()

                DesignBrandMark(size: 40)

                Text("No memes yet")
                    .font(DesignPreviewTokens.screenTitle())
                    .foregroundStyle(BrandTheme.ink)

                Text("Snap or upload a photo to get started.")
                    .font(DesignPreviewTokens.meta())
                    .foregroundStyle(BrandTheme.muted)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(DesignPreviewTokens.screenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandTheme.background)
            .navigationTitle("Meme-ify")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DesignBrandMark()
                }
            }
            .safeAreaInset(edge: .bottom) {
                DesignBottomToolbar {
                    DesignToolbarIconButton(systemName: "camera", tint: BrandTheme.accent, label: "Take photo")
                    DesignToolbarIconButton(systemName: "photo.on.rectangle", label: "Choose photo")
                }
            }
        }
        .tint(BrandTheme.accent)
    }
}

struct DesignMockCaptionView: View {
    private let captions = [
        "When Monday hits different",
        "Living my best life",
        "Not today, human",
        "Send snacks immediately",
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer(minLength: 0)
                        DesignPhotoPlaceholder()
                        Spacer(minLength: 0)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack(spacing: 10) {
                        TextField("Steer captions…", text: .constant(""))
                            .textFieldStyle(.plain)

                        Button {} label: {
                            Image(systemName: "sparkle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(BrandTheme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ForEach(Array(captions.enumerated()), id: \.offset) { index, caption in
                        HStack {
                            Text(caption)
                                .font(DesignPreviewTokens.rowTitle())
                                .foregroundStyle(BrandTheme.ink)

                            Spacer(minLength: 8)

                            if index == 1 {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(BrandTheme.accent)
                            }
                        }
                    }

                    HStack {
                        Text("Write your own…")
                            .font(DesignPreviewTokens.rowTitle())
                            .foregroundStyle(BrandTheme.muted)
                        Spacer()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(BrandTheme.background)
            .navigationTitle("Caption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Next") {}
                        .font(.body.weight(.semibold))
                        .tint(BrandTheme.accent)
                }
            }
        }
        .tint(BrandTheme.accent)
    }
}

struct DesignMockEditorView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                DesignPreviewTokens.placeholder
                    .ignoresSafeArea()

                Text("WHEN MONDAY\nHITS DIFFERENT")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.8), radius: 0, x: 2, y: 2)
                    .padding()
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {}
                        .font(.body.weight(.semibold))
                        .tint(BrandTheme.accent)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Picker("Alignment", selection: .constant(0)) {
                        Image(systemName: "text.alignleft").tag(0)
                        Image(systemName: "text.aligncenter").tag(1)
                        Image(systemName: "text.alignright").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DesignPreviewTokens.screenPadding)

                    HStack(spacing: 12) {
                        Image(systemName: "textformat.size.smaller")
                            .foregroundStyle(BrandTheme.muted)
                        Slider(value: .constant(0.65))
                            .tint(BrandTheme.accent)
                        Text("100%")
                            .font(DesignPreviewTokens.meta())
                            .foregroundStyle(BrandTheme.muted)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.horizontal, DesignPreviewTokens.screenPadding)
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .tint(BrandTheme.accent)
    }
}

struct DesignMockMemePreviewView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)

                DesignPlaceholderTile(caption: "WHEN MONDAY\nHITS DIFFERENT")
                    .padding(.horizontal, DesignPreviewTokens.screenPadding)
                    .frame(maxWidth: 320)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandTheme.background)
            .navigationTitle("Meme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {}
                        .font(.body.weight(.semibold))
                        .tint(BrandTheme.accent)
                }
            }
            .safeAreaInset(edge: .bottom) {
                DesignBottomToolbar {
                    DesignToolbarIconButton(systemName: "square.and.arrow.down", label: "Save")
                    DesignToolbarIconButton(systemName: "square.and.arrow.up", tint: BrandTheme.accent, label: "Share")
                }
            }
        }
        .tint(BrandTheme.accent)
    }
}

// MARK: - Design system reference

struct DesignSystemReferenceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Colors")
                        .font(DesignPreviewTokens.screenTitle())

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        colorSwatch("Accent", BrandTheme.accent, textColor: .white)
                        colorSwatch("Ink", BrandTheme.ink, textColor: .white)
                        colorSwatch("Background", BrandTheme.background, textColor: BrandTheme.ink)
                        colorSwatch("Surface", BrandTheme.surface, textColor: BrandTheme.ink)
                        colorSwatch("Muted", BrandTheme.muted, textColor: .white)
                        colorSwatch("Placeholder", DesignPreviewTokens.placeholder, textColor: BrandTheme.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Typography")
                        .font(DesignPreviewTokens.screenTitle())

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meme-ify")
                            .font(DesignPreviewTokens.largeTitle())
                        Text("Screen title")
                            .font(DesignPreviewTokens.screenTitle())
                        Text("Body — caption options and labels")
                            .font(DesignPreviewTokens.rowTitle())
                        Text("Meta — secondary hints")
                            .font(DesignPreviewTokens.meta())
                            .foregroundStyle(BrandTheme.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Brand mark")
                        .font(DesignPreviewTokens.screenTitle())

                    HStack(spacing: 16) {
                        DesignBrandMark(size: 22)
                        DesignBrandMark(size: 32)
                        DesignBrandMark(size: 44)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Components")
                        .font(DesignPreviewTokens.screenTitle())

                    VStack(spacing: 0) {
                        HStack {
                            Text("Selected caption row")
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(BrandTheme.accent)
                        }
                        .padding()
                        .background(DesignPreviewTokens.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        HStack {
                            Text("Default caption row")
                            Spacer()
                        }
                        .padding()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(BrandTheme.border, lineWidth: 1)
                    }

                    DesignBottomToolbar {
                        DesignToolbarIconButton(systemName: "camera", tint: BrandTheme.accent, label: "Take photo")
                        DesignToolbarIconButton(systemName: "photo.on.rectangle", label: "Choose photo")
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(DesignPreviewTokens.screenPadding)
        }
        .background(BrandTheme.background)
        .navigationTitle("Design System")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorSwatch(_ name: String, _ color: Color, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(height: 56)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BrandTheme.border, lineWidth: color == BrandTheme.background ? 1 : 0)
                }

            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(BrandTheme.ink)
        }
    }
}

// MARK: - Gallery (browse all mocks)

struct DesignPreviewGallery: View {
    private enum MockScreen: String, CaseIterable, Identifiable {
        case home = "Home"
        case homeEmpty = "Home (empty)"
        case caption = "Caption"
        case editor = "Editor"
        case preview = "Preview"
        case system = "Tokens"

        var id: String { rawValue }
    }

    @State private var selection: MockScreen = .home

    var body: some View {
        VStack(spacing: 0) {
            Picker("Screen", selection: $selection) {
                ForEach(MockScreen.allCases) { screen in
                    Text(screen.rawValue).tag(screen)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch selection {
                case .home:
                    DesignMockHomeView()
                case .homeEmpty:
                    DesignMockHomeEmptyView()
                case .caption:
                    DesignMockCaptionView()
                case .editor:
                    DesignMockEditorView()
                case .preview:
                    DesignMockMemePreviewView()
                case .system:
                    NavigationStack {
                        DesignSystemReferenceView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BrandTheme.background)
    }
}

// MARK: - Previews

#Preview("Gallery — browse all mocks") {
    DesignPreviewGallery()
}

#Preview("Home") {
    DesignMockHomeView()
}

#Preview("Home — empty") {
    DesignMockHomeEmptyView()
}

#Preview("Caption") {
    DesignMockCaptionView()
}

#Preview("Editor") {
    DesignMockEditorView()
}

#Preview("Preview") {
    DesignMockMemePreviewView()
}

#Preview("Design system") {
    NavigationStack {
        DesignSystemReferenceView()
    }
}
#endif
