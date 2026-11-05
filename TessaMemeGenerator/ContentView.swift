import SwiftUI

enum AppRoute: Hashable {
    /// `editing` is the saved meme being reopened from the grid, carried through each step so a
    /// re-made meme updates it rather than adding a copy.
    case captions(SavedPhoto, editing: SavedMeme? = nil)
    case editor(caption: String, photo: SavedPhoto, layout: MemeTextLayout = .default, editing: SavedMeme? = nil)
    case preview(caption: String, photo: SavedPhoto, layout: MemeTextLayout, editing: SavedMeme? = nil)
    /// A saved meme with no photo on record to re-render or edit from.
    case savedMeme(SavedMeme)
}

struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .captions(let photo, let editing):
                        CaptionView(photo: photo, editing: editing, path: $path)
                    case .editor(let caption, let photo, let layout, let editing):
                        MemeEditorView(
                            caption: caption,
                            photo: photo,
                            initialLayout: layout,
                            editing: editing,
                            path: $path
                        )
                    case .preview(let caption, let photo, let layout, let editing):
                        MemePreviewView(
                            source: .render(caption: caption, photo: photo, layout: layout, editing: editing),
                            path: $path
                        )
                    case .savedMeme(let meme):
                        MemePreviewView(source: .saved(meme), path: $path)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(BrandTheme.orange)
    }
}

#Preview("Fetch") {
    ContentView()
}
