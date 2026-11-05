import Foundation

struct SavedMeme: Identifiable, Hashable, Codable {
    let id: UUID
    let fileName: String
    let caption: String?
    let createdAt: Date

    /// The photo and text placement it was made from, so it can be reopened and edited. Nil for
    /// memes saved before these were recorded, which can only be re-shared or saved.
    var photo: SavedPhoto?
    var layout: MemeTextLayout?

    var fileURL: URL {
        MemeStore.memesDirectory.appendingPathComponent(fileName)
    }
}
