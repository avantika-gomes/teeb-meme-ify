import SwiftUI

enum AppRoute: Hashable {
    case captions(SavedPhoto)
    case editor(caption: String, photo: SavedPhoto)
    case preview(caption: String, photo: SavedPhoto, layout: MemeTextLayout)
}

struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .captions(let photo):
                        CaptionView(photo: photo, path: $path)
                    case .editor(let caption, let photo):
                        MemeEditorView(caption: caption, photo: photo, path: $path)
                    case .preview(let caption, let photo, let layout):
                        MemePreviewView(caption: caption, photo: photo, layout: layout, path: $path)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .toolbarBackground(.hidden, for: .navigationBar)
                .ignoresSafeArea(edges: .top)
        }
    }
}

#if DEBUG
struct TeebMemifyAppPreview: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .captions(let photo):
                        CaptionView(photo: photo, path: $path)
                    case .editor(let caption, let photo):
                        MemeEditorView(caption: caption, photo: photo, path: $path)
                    case .preview(let caption, let photo, let layout):
                        MemePreviewView(caption: caption, photo: photo, layout: layout, path: $path)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .toolbarBackground(.hidden, for: .navigationBar)
                .ignoresSafeArea(edges: .top)
        }
        .tint(BrandTheme.accent)
    }
}

#Preview("Teeb Meme-ify") {
    TeebMemifyAppPreview()
}
#endif
