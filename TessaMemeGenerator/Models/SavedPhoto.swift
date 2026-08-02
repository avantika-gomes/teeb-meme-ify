import Foundation

struct SavedPhoto: Identifiable, Hashable, Codable {
    let id: UUID
    let fileName: String

    /// When the photo entered the app. Drives recents ordering.
    let createdAt: Date

    /// When the shutter actually fired, when the file's EXIF recorded it. Nil for screenshots and
    /// other images with no timestamp, and for photos imported before this was tracked.
    var capturedAt: Date?

    /// Seconds from GMT at the moment of capture, from the EXIF offset tag or the GPS clock.
    var captureZoneOffset: Int?

    /// Where the photo was taken, from its own GPS.
    var coordinate: Coordinate?

    /// City resolved from `coordinate`. Cached because reverse geocoding is a network call.
    var placeName: String?

    var fileURL: URL {
        PhotoStore.photosDirectory.appendingPathComponent(fileName)
    }

    /// Best available answer to "when was this taken", falling back to import time.
    var captureMoment: CaptureMoment {
        CaptureMoment(
            date: capturedAt ?? createdAt,
            timeZone: captureZoneOffset.flatMap { TimeZone(secondsFromGMT: $0) }
        )
    }
}
