import ImageIO
import UIKit

/// Decodes photos at a bounded size straight from their encoded data, so a camera original never
/// becomes a full-size bitmap. A 24 MP photo decodes to roughly 100 MB, and a handful of those
/// alive at once is enough for iOS to kill the app for exceeding its memory limit.
enum ImageDownsampler {
    /// Longest edge, in pixels, a photo is kept at once it's in the app. Sharp on any phone screen
    /// and in shared memes, at about a sixth of the memory of a 24 MP original.
    static let maxPhotoPixelSize: CGFloat = 2048

    /// Decodes picked photo data, upright and no larger than `maxPixelSize`. EXIF does not survive
    /// this, so read anything needed from it out of the original data first.
    static func downsample(data: Data, maxPixelSize: CGFloat = maxPhotoPixelSize) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        return downsample(source, maxPixelSize: maxPixelSize)
    }

    /// Decodes a saved file, no larger than `maxPixelSize`. Images already within the limit come
    /// back at their own size — ImageIO never scales up — so every screen that loads the same file
    /// this way sees the same dimensions.
    static func downsample(contentsOf url: URL, maxPixelSize: CGFloat = maxPhotoPixelSize) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        return downsample(source, maxPixelSize: maxPixelSize)
    }

    /// A thumbnail whose shorter edge still covers `minPixelSize`, for aspect-fill tiles.
    static func thumbnail(contentsOf url: URL, filling minPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }

        // The size limit applies to the longer edge, so widen it by the aspect ratio or the short
        // edge would come out smaller than the tile and look soft.
        var maxPixelSize = minPixelSize
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? Int,
           let height = properties[kCGImagePropertyPixelHeight] as? Int,
           min(width, height) > 0 {
            maxPixelSize *= CGFloat(max(width, height)) / CGFloat(min(width, height))
        }
        return downsample(source, maxPixelSize: maxPixelSize)
    }

    /// Stops ImageIO decoding the full image just to open the source.
    private static let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary

    private static func downsample(_ source: CGImageSource, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            // Always from the full image: the embedded EXIF thumbnail is tiny.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Bakes in the EXIF orientation, so the result is already upright.
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Decode now rather than lazily on first draw, which would land on the main thread.
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

extension UIImage {
    /// Redraws the image upright and no larger than `maxPixelSize` on its longest edge, or returns
    /// it untouched if it already is both. For images that arrive already decoded, like camera
    /// captures, where downsampling from the encoded data isn't an option.
    func preparedForStorage(maxPixelSize: CGFloat = ImageDownsampler.maxPhotoPixelSize) -> UIImage {
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        let longestEdge = max(pixelSize.width, pixelSize.height)

        guard cgImage == nil || imageOrientation != .up || longestEdge > maxPixelSize else {
            return self
        }

        let ratio = min(1, maxPixelSize / longestEdge)
        let targetSize = CGSize(
            width: (pixelSize.width * ratio).rounded(),
            height: (pixelSize.height * ratio).rounded()
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // The default on wide-color screens is a 16-bit-per-channel buffer, twice the memory.
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
