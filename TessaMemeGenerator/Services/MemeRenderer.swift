import UIKit

enum MemeRenderer {
    static func render(image: UIImage, caption: String, layout: MemeTextLayout = .default) -> UIImage {
        let text = caption.uppercased()
        let size = image.size

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        // The default on wide-color screens is a 16-bit-per-channel buffer, twice the memory.
        format.preferredRange = .standard

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))

            let font = fittedFont(for: text, imageSize: size, layout: layout)
            let style = paragraphStyle(for: layout.alignment)
            let drawRect = textRect(text, font: font, paragraphStyle: style, imageSize: size, layout: layout)

            drawMemeText(text, in: drawRect, font: font, paragraphStyle: style)
        }
    }

    /// Point size the caption is drawn at, in the image's own coordinate space. The editor scales
    /// this down to its on-screen frame so the live preview matches the saved meme exactly.
    static func fittedFontSize(for caption: String, imageSize: CGSize, layout: MemeTextLayout) -> CGFloat {
        fittedFont(for: caption.uppercased(), imageSize: imageSize, layout: layout).pointSize
    }

    /// Where the caption block is drawn at `fontSize`, in the image's own coordinate space. The
    /// editor positions its live preview from this so placement matches the saved meme exactly.
    static func textRect(for caption: String, fontSize: CGFloat, imageSize: CGSize, layout: MemeTextLayout) -> CGRect {
        textRect(
            caption.uppercased(),
            font: baseMemeFont(ofSize: fontSize),
            paragraphStyle: paragraphStyle(for: layout.alignment),
            imageSize: imageSize,
            layout: layout
        )
    }

    /// The caption drawn exactly as `render` draws it, on a transparent layer covering its text
    /// block plus outline, rasterized at `pixelScale` pixels per image point. The editor shows this
    /// rather than laying the text out again in SwiftUI, whose line breaks can differ from UIKit's
    /// when a line is close to the width limit.
    static func textLayer(
        for caption: String,
        fontSize: CGFloat,
        imageSize: CGSize,
        layout: MemeTextLayout,
        pixelScale: CGFloat
    ) -> UIImage {
        let text = caption.uppercased()
        let font = baseMemeFont(ofSize: fontSize)
        let style = paragraphStyle(for: layout.alignment)
        let rect = textRect(text, font: font, paragraphStyle: style, imageSize: imageSize, layout: layout)
        let reach = outlineOffset(for: font)

        let format = UIGraphicsImageRendererFormat()
        format.scale = pixelScale
        format.opaque = false

        let size = CGSize(width: rect.width + reach * 2, height: rect.height + reach * 2)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let block = CGRect(x: reach, y: reach, width: rect.width, height: rect.height)
            drawMemeText(text, in: block, font: font, paragraphStyle: style)
        }
    }

    private static func textRect(
        _ text: String,
        font: UIFont,
        paragraphStyle: NSParagraphStyle,
        imageSize: CGSize,
        layout: MemeTextLayout
    ) -> CGRect {
        let maxTextWidth = imageSize.width * 0.92
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraphStyle],
            context: nil
        )
        let textWidth = min(ceil(bounds.width), maxTextWidth)
        let textHeight = ceil(bounds.height)

        // The stored center is where the user aimed the caption, but a tall block near an edge
        // would be drawn partly outside the image and cut off — so keep the whole block, outline
        // included, inside. Lines are aligned within the full-width rect, so the visible text
        // starts this far in from its left edge.
        let margin = outlineOffset(for: font)
        let glyphInset: CGFloat
        switch layout.alignment {
        case .left: glyphInset = 0
        case .center: glyphInset = (maxTextWidth - textWidth) / 2
        case .right: glyphInset = maxTextWidth - textWidth
        }

        let x = clamp(
            layout.centerX * imageSize.width - maxTextWidth / 2,
            between: margin - glyphInset,
            and: imageSize.width - margin - glyphInset - textWidth
        )
        let y = clamp(
            layout.centerY * imageSize.height - textHeight / 2,
            between: margin,
            and: imageSize.height - margin - textHeight
        )

        return CGRect(x: x, y: y, width: maxTextWidth, height: textHeight)
    }

    /// Clamps into `[lower, upper]`; if the block is bigger than the image, centers it instead.
    private static func clamp(_ value: CGFloat, between lower: CGFloat, and upper: CGFloat) -> CGFloat {
        guard lower <= upper else { return (lower + upper) / 2 }
        return min(max(value, lower), upper)
    }

    private static func paragraphStyle(for alignment: MemeTextAlignment) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment.nsTextAlignment
        style.lineBreakMode = .byWordWrapping
        return style
    }

    private static func outlineOffset(for font: UIFont) -> CGFloat {
        max(2, font.pointSize * 0.05)
    }

    private static func fittedFont(for text: String, imageSize: CGSize, layout: MemeTextLayout) -> UIFont {
        let baseFont = memeFont(
            for: text,
            maxWidth: imageSize.width * 0.92,
            maxHeight: imageSize.height * 0.5,
            imageWidth: imageSize.width,
            alignment: layout.alignment
        )
        return baseFont.withSize(baseFont.pointSize * layout.fontScale)
    }

    private static func drawMemeText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        paragraphStyle: NSParagraphStyle
    ) {
        // Match MemeStyleText: offset black copies + white fill.
        // NSAttributedString strokeWidth causes miter spikes on bold fonts.
        let reach = outlineOffset(for: font)
        let outlineOffsets: [(CGFloat, CGFloat)] = [
            (-reach, -reach),
            (reach, -reach),
            (-reach, reach),
            (reach, reach)
        ]

        let outlineAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let outline = NSAttributedString(string: text, attributes: outlineAttributes)
        let fill = NSAttributedString(string: text, attributes: fillAttributes)

        for (dx, dy) in outlineOffsets {
            outline.draw(with: rect.offsetBy(dx: dx, dy: dy), options: options, context: nil)
        }
        fill.draw(with: rect, options: options, context: nil)
    }

    private static func memeFont(
        for text: String,
        maxWidth: CGFloat,
        maxHeight: CGFloat,
        imageWidth: CGFloat,
        alignment: MemeTextAlignment
    ) -> UIFont {
        let baseFont = baseMemeFont(ofSize: 48)
        let paragraphStyle = paragraphStyle(for: alignment)

        let startSize = imageWidth * 0.11
        let minSize = max(24, imageWidth * 0.045)
        let step = max(1, imageWidth * 0.008)

        var fontSize = startSize
        var bestFont = baseFont.withSize(fontSize)

        while fontSize >= minSize {
            let font = baseFont.withSize(fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
            let boundingRect = (text as NSString).boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )

            if boundingRect.width <= maxWidth && boundingRect.height <= maxHeight {
                bestFont = font
                break
            }

            fontSize -= step
            bestFont = baseFont.withSize(fontSize)
        }

        return bestFont
    }

    private static func baseMemeFont(ofSize size: CGFloat) -> UIFont {
        for name in ["Anton-Regular", "Impact", "Arial-BoldMT", "Helvetica-Bold"] {
            if let font = UIFont(name: name, size: size) {
                return font
            }
        }
        return .boldSystemFont(ofSize: size)
    }
}
