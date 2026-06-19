import UIKit

enum MemeRenderer {
    static func render(image: UIImage, caption: String, layout: MemeTextLayout = .default) -> UIImage {
        let text = caption.uppercased()
        let size = image.size

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))

            let maxTextWidth = size.width * 0.92
            let maxTextHeight = size.height * 0.5

            let baseFont = memeFont(
                for: text,
                maxWidth: maxTextWidth,
                maxHeight: maxTextHeight,
                imageWidth: size.width,
                alignment: layout.alignment
            )
            let font = baseFont.withSize(baseFont.pointSize * layout.fontScale)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = layout.alignment.nsTextAlignment
            paragraphStyle.lineBreakMode = .byWordWrapping

            let fillAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let attributed = NSAttributedString(string: text, attributes: fillAttributes)
            let boundingRect = attributed.boundingRect(
                with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            let textHeight = ceil(boundingRect.height)
            let centerX = layout.centerX * size.width
            let centerY = layout.centerY * size.height

            let drawRect = CGRect(
                x: centerX - (maxTextWidth / 2),
                y: centerY - (textHeight / 2),
                width: maxTextWidth,
                height: textHeight
            )

            drawMemeText(text, in: drawRect, font: font, paragraphStyle: paragraphStyle)
        }
    }

    private static func drawMemeText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        paragraphStyle: NSParagraphStyle
    ) {
        let outlineWidth = min(max(4, font.pointSize * 0.06), 18)

        let outlineAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.clear,
            .strokeColor: UIColor.black,
            .strokeWidth: outlineWidth,
            .paragraphStyle: paragraphStyle
        ]

        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

        NSAttributedString(string: text, attributes: outlineAttributes)
            .draw(with: rect, options: options, context: nil)
        NSAttributedString(string: text, attributes: fillAttributes)
            .draw(with: rect, options: options, context: nil)
    }

    private static func memeFont(
        for text: String,
        maxWidth: CGFloat,
        maxHeight: CGFloat,
        imageWidth: CGFloat,
        alignment: MemeTextAlignment
    ) -> UIFont {
        let fontNames = ["Impact", "Arial-BoldMT", "Helvetica-Bold"]
        var baseFont = UIFont.boldSystemFont(ofSize: 48)

        for name in fontNames {
            if let font = UIFont(name: name, size: 48) {
                baseFont = font
                break
            }
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment
        paragraphStyle.lineBreakMode = .byWordWrapping

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
}
