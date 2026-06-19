import Foundation
import SwiftUI

enum MemeTextAlignment: String, Hashable, Codable, CaseIterable {
    case left
    case center
    case right

    var textAlignment: TextAlignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }

    var iconName: String {
        switch self {
        case .left: "text.alignleft"
        case .center: "text.aligncenter"
        case .right: "text.alignright"
        }
    }
}

struct MemeTextLayout: Hashable, Codable {
    /// Horizontal center of the text block, 0–1 across image width.
    var centerX: CGFloat
    /// Vertical center of the text block, 0–1 across image height.
    var centerY: CGFloat
    /// Multiplier applied to the auto-sized meme font.
    var fontScale: CGFloat
    var alignment: MemeTextAlignment

    static let `default` = MemeTextLayout(
        centerX: 0.5,
        centerY: 0.17,
        fontScale: 1.0,
        alignment: .center
    )
}
