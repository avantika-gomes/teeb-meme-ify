import Foundation
import ImageIO

struct Coordinate: Hashable, Codable {
    let latitude: Double
    let longitude: Double
}

/// When a photo was taken, in its own local terms.
struct CaptureMoment {
    let date: Date

    /// The zone the photo was taken in. Read from EXIF where recorded, otherwise derived by
    /// comparing the local timestamp against the GPS timestamp, which is always UTC.
    let timeZone: TimeZone?

    static var now: CaptureMoment {
        CaptureMoment(date: Date(), timeZone: .current)
    }
}

/// Everything the file itself can tell us about where and when it was taken.
struct PhotoCapture {
    let moment: CaptureMoment
    let coordinate: Coordinate?

    static var now: PhotoCapture {
        PhotoCapture(moment: .now, coordinate: nil)
    }
}

enum PhotoMetadata {
    /// Reads the capture time and location out of a photo's EXIF.
    ///
    /// Must run on the original file data: `UIImage(data:)` drops metadata, so anything downstream
    /// of that has already lost both and can only report when the user picked the photo.
    static func capture(from data: Data) -> PhotoCapture? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return nil
        }

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]

        let coordinate = gps.flatMap(coordinate(fromGPS:))

        let stamp = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (exif?[kCGImagePropertyExifDateTimeDigitized] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)

        guard let stamp else {
            // No timestamp, but coordinates alone are still worth keeping.
            guard let coordinate else { return nil }
            return PhotoCapture(moment: .now, coordinate: coordinate)
        }

        // Prefer the zone the camera recorded; failing that, derive it from the GPS clock.
        let zone = (exif?[kCGImagePropertyExifOffsetTimeOriginal] as? String)
            .flatMap(timeZone(fromOffset:))
            ?? gps.flatMap { derivedTimeZone(localStamp: stamp, gps: $0) }

        // EXIF timestamps are bare local wall-clock text with no zone attached, so they have to be
        // interpreted in the photo's own zone, falling back to the phone's current one.
        let formatter = exifFormatter(zone: zone ?? .current)

        guard let date = formatter.date(from: stamp) else { return nil }
        return PhotoCapture(
            moment: CaptureMoment(date: date, timeZone: zone),
            coordinate: coordinate
        )
    }

    private static func exifFormatter(zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = zone
        return formatter
    }

    private static func coordinate(fromGPS gps: [CFString: Any]) -> Coordinate? {
        guard let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let longitude = gps[kCGImagePropertyGPSLongitude] as? Double else {
            return nil
        }

        // EXIF stores magnitudes plus a hemisphere reference rather than signed values.
        let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String
        let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String

        return Coordinate(
            latitude: latitudeRef == "S" ? -latitude : latitude,
            longitude: longitudeRef == "W" ? -longitude : longitude
        )
    }

    /// Parses an EXIF offset such as "+05:30" or "-08:00".
    private static func timeZone(fromOffset text: String) -> TimeZone? {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return nil
        }
        let sign = text.hasPrefix("-") ? -1 : 1
        return TimeZone(secondsFromGMT: hours * 3600 + sign * minutes * 60)
    }

    /// Recovers the capture zone for cameras that record GPS but no offset tag.
    ///
    /// The GPS timestamp is UTC while `DateTimeOriginal` is local, so reading the local stamp as if
    /// it were UTC and taking the difference gives the offset that was in force at capture.
    private static func derivedTimeZone(localStamp: String, gps: [CFString: Any]) -> TimeZone? {
        guard let dateStamp = gps[kCGImagePropertyGPSDateStamp] as? String,
              let timeStamp = gps[kCGImagePropertyGPSTimeStamp] as? String else {
            return nil
        }

        let utc = exifFormatter(zone: TimeZone(secondsFromGMT: 0)!)
        // GPS times sometimes carry fractional seconds.
        let seconds = String(timeStamp.prefix(8))

        guard let actual = utc.date(from: "\(dateStamp) \(seconds)"),
              let asIfUTC = utc.date(from: localStamp) else {
            return nil
        }

        let offset = asIfUTC.timeIntervalSince(actual)
        guard abs(offset) <= 15 * 3600 else { return nil }

        // Real zones land on quarter hours; the GPS and camera clocks drift by a few seconds.
        let quarterHours = (offset / 900).rounded() * 900
        return TimeZone(secondsFromGMT: Int(quarterHours))
    }
}
