import CoreLocation
import Foundation

/// Turns a photo's own coordinates into a place name.
///
/// Reverse geocoding a coordinate the app already holds needs no location authorization, so this
/// works on library photos without ever prompting for location access.
enum PlaceLookup {
    /// The city the photo was taken in, or the nearest administrative equivalent.
    ///
    /// Deliberately city-level. Earlier blind testing showed that feeding venue and street detail
    /// made the model name-drop the address instead of writing a joke, and it scored worse than
    /// supplying no location at all.
    static func cityName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        guard let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
              let placemark = placemarks.first else {
            return nil
        }

        return placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.country
    }
}
