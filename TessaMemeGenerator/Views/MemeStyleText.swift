import SwiftUI

struct MemeStyleText: View {
    let text: String
    let fontSize: CGFloat
    var alignment: MemeTextAlignment = .center

    var body: some View {
        let display = text.uppercased()
        let font = memeFont(size: fontSize)

        ZStack {
            Text(display)
                .font(font)
                .foregroundStyle(.black)
                .offset(x: -2, y: -2)
            Text(display)
                .font(font)
                .foregroundStyle(.black)
                .offset(x: 2, y: -2)
            Text(display)
                .font(font)
                .foregroundStyle(.black)
                .offset(x: -2, y: 2)
            Text(display)
                .font(font)
                .foregroundStyle(.black)
                .offset(x: 2, y: 2)
            Text(display)
                .font(font)
                .foregroundStyle(.white)
        }
        .multilineTextAlignment(alignment.textAlignment)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func memeFont(size: CGFloat) -> Font {
        if UIFont(name: "Impact", size: size) != nil {
            return .custom("Impact", size: size)
        }
        return .system(size: size, weight: .black)
    }
}
