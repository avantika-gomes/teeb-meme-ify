import UIKit

enum MemeStore {
    static var memesDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let memes = documents.appendingPathComponent("memes", isDirectory: true)
        try? FileManager.default.createDirectory(at: memes, withIntermediateDirectories: true)
        return memes
    }

    private static var metadataURL: URL {
        memesDirectory.appendingPathComponent("index.json")
    }

    static func save(
        _ image: UIImage,
        caption: String?,
        photo: SavedPhoto? = nil,
        layout: MemeTextLayout? = nil
    ) throws -> SavedMeme {
        let id = UUID()
        let fileName = try writeImage(image, named: id.uuidString)

        let meme = SavedMeme(
            id: id,
            fileName: fileName,
            caption: caption,
            createdAt: Date(),
            photo: photo,
            layout: layout
        )
        var all = loadAll()
        all.insert(meme, at: 0)
        try saveMetadata(all)
        return meme
    }

    /// Swaps in a re-edited version of meme `id`, keeping its place in the grid. Falls back to
    /// saving it as new if the original has since gone.
    static func replace(
        _ id: UUID,
        with image: UIImage,
        caption: String?,
        photo: SavedPhoto,
        layout: MemeTextLayout
    ) throws -> SavedMeme {
        var all = loadAll()
        guard let index = all.firstIndex(where: { $0.id == id }) else {
            return try save(image, caption: caption, photo: photo, layout: layout)
        }

        // A new file name rather than overwriting, so anything keyed by the old name doesn't keep
        // showing the old image.
        let previous = all[index]
        let fileName = try writeImage(image, named: UUID().uuidString)

        let meme = SavedMeme(
            id: id,
            fileName: fileName,
            caption: caption,
            createdAt: previous.createdAt,
            photo: photo,
            layout: layout
        )
        all[index] = meme
        try saveMetadata(all)
        try? FileManager.default.removeItem(at: previous.fileURL)
        return meme
    }

    private static func writeImage(_ image: UIImage, named name: String) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw MemeStoreError.encodingFailed
        }
        let fileName = "\(name).jpg"
        try data.write(to: memesDirectory.appendingPathComponent(fileName), options: .atomic)
        return fileName
    }

    static func loadAll() -> [SavedMeme] {
        guard let data = try? Data(contentsOf: metadataURL),
              let memes = try? JSONDecoder().decode([SavedMeme].self, from: data) else {
            return []
        }

        return memes.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }

    static func loadImage(for meme: SavedMeme) -> UIImage? {
        UIImage(contentsOfFile: meme.fileURL.path)
    }

    private static func saveMetadata(_ memes: [SavedMeme]) throws {
        let data = try JSONEncoder().encode(memes)
        try data.write(to: metadataURL, options: .atomic)
    }
}

enum MemeStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Could not save the meme."
        }
    }
}
