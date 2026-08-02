import UIKit

enum PhotoStore {
    static var photosDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photos = documents.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        return photos
    }

    /// Saves a photo, keeping the moment it was taken separate from the moment it was imported.
    ///
    /// Re-encoding to JPEG strips EXIF, so the capture time has to be read from the original data
    /// by the caller and handed in here, then stored alongside rather than in the file.
    static func save(_ image: UIImage, captured: PhotoCapture? = nil) throws -> SavedPhoto {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        let prepared = image.normalizedForSaving()

        guard let data = prepared.jpegData(compressionQuality: 0.85) else {
            throw PhotoStoreError.encodingFailed
        }

        try data.write(to: fileURL, options: .atomic)

        let photo = SavedPhoto(
            id: id,
            fileName: fileName,
            createdAt: Date(),
            capturedAt: captured?.moment.date,
            captureZoneOffset: captured?.moment.timeZone?.secondsFromGMT(),
            coordinate: captured?.coordinate
        )

        if let captured {
            updateCaptureIndex(for: id) { record in
                CaptureRecord(
                    capturedAt: captured.moment.date,
                    zoneOffset: captured.moment.timeZone?.secondsFromGMT(),
                    coordinate: captured.coordinate,
                    placeName: record?.placeName
                )
            }
        }

        // Resolve the city up front so it is cached by the time captions are requested.
        if captured?.coordinate != nil {
            Task.detached { _ = await resolvedPlaceName(for: photo) }
        }

        return photo
    }

    /// The photo's city, geocoded from its own coordinates and cached after the first lookup.
    static func resolvedPlaceName(for photo: SavedPhoto) async -> String? {
        if let placeName = photo.placeName { return placeName }

        if let cached = loadCaptureIndex()[photo.id.uuidString]?.placeName {
            return cached
        }

        guard let coordinate = photo.coordinate
            ?? loadCaptureIndex()[photo.id.uuidString]?.coordinate else {
            return nil
        }

        guard let city = await PlaceLookup.cityName(for: coordinate) else { return nil }

        updateCaptureIndex(for: photo.id) { record in
            CaptureRecord(
                capturedAt: record?.capturedAt ?? photo.capturedAt ?? photo.createdAt,
                zoneOffset: record?.zoneOffset ?? photo.captureZoneOffset,
                coordinate: record?.coordinate ?? coordinate,
                placeName: city
            )
        }

        return city
    }

    static func loadAll() -> [SavedPhoto] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: photosDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let captures = loadCaptureIndex()

        return contents
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .compactMap { url -> SavedPhoto? in
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                    return nil
                }
                let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                let capture = captures[id.uuidString]
                return SavedPhoto(
                    id: id,
                    fileName: url.lastPathComponent,
                    createdAt: createdAt,
                    capturedAt: capture?.capturedAt,
                    captureZoneOffset: capture?.zoneOffset,
                    coordinate: capture?.coordinate,
                    placeName: capture?.placeName
                )
            }
            // Recents stay in import order: a newly added holiday photo should not sort to the
            // bottom just because it was taken years ago.
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func loadImage(for photo: SavedPhoto) -> UIImage? {
        UIImage(contentsOfFile: photo.fileURL.path)
    }

    private struct CaptureRecord: Codable {
        let capturedAt: Date
        let zoneOffset: Int?
        var coordinate: Coordinate?
        var placeName: String?
    }

    private static var captureIndexURL: URL {
        photosDirectory.appendingPathComponent("captures.json")
    }

    /// Serialises index writes; geocoding finishes on a background task and can otherwise race a
    /// concurrent save and clobber it.
    private static let indexQueue = DispatchQueue(label: "PhotoStore.captureIndex")

    private static func loadCaptureIndex() -> [String: CaptureRecord] {
        indexQueue.sync { readCaptureIndex() }
    }

    private static func updateCaptureIndex(
        for id: UUID,
        transform: (CaptureRecord?) -> CaptureRecord
    ) {
        indexQueue.sync {
            var index = readCaptureIndex()
            index[id.uuidString] = transform(index[id.uuidString])
            guard let data = try? JSONEncoder().encode(index) else { return }
            try? data.write(to: captureIndexURL, options: .atomic)
        }
    }

    private static func readCaptureIndex() -> [String: CaptureRecord] {
        guard let data = try? Data(contentsOf: captureIndexURL) else { return [:] }
        return (try? JSONDecoder().decode([String: CaptureRecord].self, from: data)) ?? [:]
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
