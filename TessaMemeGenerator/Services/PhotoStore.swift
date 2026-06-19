import UIKit

enum PhotoStore {
    static var photosDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photos = documents.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        return photos
    }

    static func save(_ image: UIImage) throws -> SavedPhoto {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        let prepared = image.normalizedForSaving()

        guard let data = prepared.jpegData(compressionQuality: 0.85) else {
            throw PhotoStoreError.encodingFailed
        }

        try data.write(to: fileURL, options: .atomic)

        return SavedPhoto(id: id, fileName: fileName, createdAt: Date())
    }

    static func loadAll() -> [SavedPhoto] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: photosDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .compactMap { url -> SavedPhoto? in
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                    return nil
                }
                let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                return SavedPhoto(id: id, fileName: url.lastPathComponent, createdAt: createdAt)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func loadImage(for photo: SavedPhoto) -> UIImage? {
        UIImage(contentsOfFile: photo.fileURL.path)
    }
}

private extension UIImage {
    func normalizedForSaving() -> UIImage {
        if cgImage == nil || imageOrientation != .up {
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            return UIGraphicsImageRenderer(size: size, format: format).image { _ in
                draw(in: CGRect(origin: .zero, size: size))
            }
        }
        return self
    }
}

enum PhotoStoreError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Could not save the photo."
        }
    }
}
