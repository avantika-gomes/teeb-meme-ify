import Foundation

struct SavedPhoto: Identifiable, Hashable, Codable {
    let id: UUID
    let fileName: String
    let createdAt: Date

    var fileURL: URL {
        PhotoStore.photosDirectory.appendingPathComponent(fileName)
    }
}
