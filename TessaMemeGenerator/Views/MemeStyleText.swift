import SwiftUI

struct MemeStyleText: View {
    let text: String
    let fontSize: CGFloat
    var alignment: MemeTextAlignment = .center

    var body: some View {
        let display = text.uppercased()
        let font = memeFont(size: fontSize)
        let outlineOffset = max(1, fontSize * 0.05)

        ZStack {
            Text(display)
                .font(font)
                .foregroundStyle(.black)
                .offset(x: -outlineOffset, y: -outlineOffset)
            Text(display)
                .font(font)
                .foregroundStyle(.black)
                .offset(x: outlineOffset, y: -outlineOffset)
            Text(display)
                .font(font)
                .foregroundStyle(.black)
                .offset(x: -outlineOffset, y: outlineOffset)
            Text(display)
                .font(font)
                .foregroundStyle(.black)
                .offset(x: outlineOffset, y: outlineOffset)
            Text(display)
                .font(font)
                .foregroundStyle(.white)
        }
        .multilineTextAlignment(alignment.textAlignment)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func memeFont(size: CGFloat) -> Font {
        // Kept in sync with MemeRenderer's fallback chain so the live preview never drifts from
        // the rendered/saved output (see commit 77ed0a1).
        for name in ["Anton-Regular", "Impact"] {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        return .system(size: size, weight: .black)
    }
}
