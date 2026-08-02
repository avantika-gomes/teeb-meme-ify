import Foundation

/// Ambient context handed to the model alongside the photo.
///
/// Everything here comes from the photo itself where possible: the day and time from its EXIF
/// timestamp, and the city reverse-geocoded from its own GPS. Kept to city level on purpose —
/// blind testing showed that feeding venue and street detail made the model name-drop the address
/// instead of writing a joke, and it scored worse than supplying no location at all.
struct CaptionContext {
    let moment: CaptureMoment

    /// City from the photo's own coordinates. Authoritative when present.
    let placeName: String?

    /// Fallback for photos with no GPS, inferred from the phone's current zone.
    let deviceCityName: String?

    static func forCapture(_ moment: CaptureMoment, placeName: String?) -> CaptionContext {
        CaptionContext(
            moment: moment,
            placeName: placeName,
            deviceCityName: currentCityName()
        )
    }

    /// The device time zone doubles as a coarse city hint: "America/New_York" becomes "New York".
    private static func currentCityName() -> String? {
        guard let component = TimeZone.current.identifier.split(separator: "/").last else {
            return nil
        }
        let city = component.replacingOccurrences(of: "_", with: " ")
        return city.isEmpty ? nil : city
    }

    var promptLine: String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        if let zone = moment.timeZone {
            formatter.timeZone = zone
        }

        var line = "\(formatter.string(from: moment.date)) \(timeOfDay)"
        if let city = resolvedCity {
            line += ", \(city)"
        }
        return line
    }

    /// The photo's own city wins. Without GPS all we have is where the phone is now, which only
    /// describes the photo if it was taken recently and in this zone; naming a city for last
    /// year's holiday snap would just be wrong, so leave it out rather than guess.
    private var resolvedCity: String? {
        if let placeName { return placeName }

        if let zone = moment.timeZone, zone.secondsFromGMT() != TimeZone.current.secondsFromGMT() {
            return nil
        }
        guard abs(moment.date.timeIntervalSinceNow) < 36 * 60 * 60 else { return nil }
        return deviceCityName
    }

    private var timeOfDay: String {
        var calendar = Calendar.current
        if let zone = moment.timeZone {
            calendar.timeZone = zone
        }

        switch calendar.component(.hour, from: moment.date) {
        case 5..<9: return "early morning"
        case 9..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        case 21..<24: return "night"
        default: return "late night"
        }
    }
}
