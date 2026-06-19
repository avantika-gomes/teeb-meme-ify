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

    static func save(_ image: UIImage, caption: String?) throws -> SavedMeme {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let fileURL = memesDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw MemeStoreError.encodingFailed
        }

        try data.write(to: fileURL, options: .atomic)

        let meme = SavedMeme(id: id, fileName: fileName, caption: caption, createdAt: Date())
        var all = loadAll()
        all.insert(meme, at: 0)
        try saveMetadata(all)
        return meme
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
