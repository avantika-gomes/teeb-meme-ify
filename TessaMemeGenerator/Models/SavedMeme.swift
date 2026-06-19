import Foundation

struct SavedMeme: Identifiable, Hashable, Codable {
    let id: UUID
    let fileName: String
    let caption: String?
    let createdAt: Date

    var fileURL: URL {
        MemeStore.memesDirectory.appendingPathComponent(fileName)
    }
}
