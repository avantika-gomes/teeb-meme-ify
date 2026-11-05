import SwiftUI
import UIKit

enum BrandTheme {
    // MARK: - Fetch design tokens (handoff/HANDOFF.md §2.1)

    static let ink = Color(red: 0.03922, green: 0.03922, blue: 0.03922)          // #0A0A0A
    static let background = Color(red: 0.98431, green: 0.98431, blue: 0.97647)  // paper #FBFBF9
    static let surface = Color.white                                            // #FFFFFF
    static let orange = Color(red: 1.0, green: 0.36078, blue: 0.21961)          // #FF5C38
    static let lime = Color(red: 0.85098, green: 1.0, blue: 0.23922)            // #D9FF3D
    static let muted = Color(red: 0.43137, green: 0.42745, blue: 0.4)           // #6E6D66
    static let hint = Color(red: 0.60784, green: 0.60392, blue: 0.57255)        // #9B9A92
    static let skeleton = Color(red: 0.93725, green: 0.93725, blue: 0.91373)    // #EFEFE9
    static let skeletonStrong = Color(red: 0.86275, green: 0.86275, blue: 0.83137) // #DCDCD4

    /// Button corner radius (HANDOFF §2.1: buttons 12, tiles/cards 14, controls 10).
    static let cornerRadius: CGFloat = 12
    static let tagline = "Good dog, bad jokes"

    enum BodyWeight {
        case regular, medium, bold
    }

    /// Anton — display, section heads, buttons (handoff/HANDOFF.md §2.2). Falls back to the
    /// system font if the wiring mistake ever leaves the font unavailable rather than crashing —
    /// same guard `MemeStyleText` uses for its Impact lookup.
    static func displayFont(size: CGFloat) -> Font {
        customFont("Anton-Regular", size: size, fallbackWeight: .bold)
    }

    /// Space Grotesk — UI, body, labels (handoff/HANDOFF.md §2.2).
    static func bodyFont(size: CGFloat, weight: BodyWeight = .regular) -> Font {
        let name: String
        let fallbackWeight: Font.Weight
        switch weight {
        case .regular: name = "SpaceGrotesk-Regular"; fallbackWeight = .regular
        case .medium: name = "SpaceGrotesk-Medium"; fallbackWeight = .medium
        case .bold: name = "SpaceGrotesk-Bold"; fallbackWeight = .bold
        }
        return customFont(name, size: size, fallbackWeight: fallbackWeight)
    }

    private static func customFont(_ name: String, size: CGFloat, fallbackWeight: Font.Weight) -> Font {
        guard UIFont(name: name, size: size) != nil else {
            return .system(size: size, weight: fallbackWeight)
        }
        return .custom(name, size: size)
    }
}

enum AppEnvironment {
    static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }
}

struct PrimaryBrandButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrandTheme.displayFont(size: 17))
            .textCase(.uppercase)
            .foregroundStyle(isEnabled ? .white : BrandTheme.hint)
            .padding(.vertical, 16)
            .background {
                // Shadow lives on this shape alone, not the whole label — otherwise SwiftUI also
                // casts a shadow of the text glyphs, producing a ghosted double-text look.
                // compositingGroup() flattens fill+stroke into one layer before the shadow is
                // computed — without it, the fill and the stroke overlay each cast their own
                // shadow copy, which don't quite align and read as a hairline double border.
                RoundedRectangle(cornerRadius: BrandTheme.cornerRadius)
                    .fill(isEnabled ? BrandTheme.orange.opacity(configuration.isPressed ? 0.85 : 1) : BrandTheme.skeleton)
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandTheme.cornerRadius)
                            .stroke(BrandTheme.ink, lineWidth: 2)
                    )
                    .compositingGroup()
                    .shadow(
                        color: isEnabled && !configuration.isPressed ? BrandTheme.ink : .clear,
                        radius: 0,
                        x: isEnabled && !configuration.isPressed ? 4 : 0,
                        y: isEnabled && !configuration.isPressed ? 4 : 0
                    )
            }
    }
}

struct SecondaryBrandButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BrandTheme.displayFont(size: 17))
            .textCase(.uppercase)
            .foregroundStyle(isEnabled ? BrandTheme.ink : BrandTheme.hint)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: BrandTheme.cornerRadius)
                    .fill(configuration.isPressed ? BrandTheme.skeleton : BrandTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandTheme.cornerRadius)
                    .stroke(BrandTheme.ink, lineWidth: 2)
            )
    }
}

extension View {
    /// Toast (handoff/HANDOFF.md §2.3). Setting `message` shows it; it dismisses itself after
    /// 2.6s. `barHeight` lifts it above a screen's bottom action bar.
    func brandToast(message: Binding<ToastMessage?>, above barHeight: CGFloat = 0) -> some View {
        overlay(alignment: .bottom) {
            if let toast = message.wrappedValue {
                BrandToast(message: toast)
                    .padding(.horizontal, 16)
                    .padding(.bottom, barHeight + 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: message.wrappedValue)
        .task(id: message.wrappedValue) {
            guard message.wrappedValue != nil else { return }
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            message.wrappedValue = nil
        }
    }
}

/// What a toast says, and whether it's confirming something or flagging a problem. A plain string
/// literal is a confirmation; use `.error(_:)` for anything the user needs to fix.
struct ToastMessage: Equatable, ExpressibleByStringLiteral {
    enum Kind {
        case success
        case error
    }

    let text: String
    var kind: Kind = .success

    init(_ text: String, kind: Kind = .success) {
        self.text = text
        self.kind = kind
    }

    init(stringLiteral text: String) {
        self.init(text)
    }

    static func error(_ text: String) -> ToastMessage {
        ToastMessage(text, kind: .error)
    }
}

struct BrandToast: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            // Orange ✓ is reserved for confirmations (HANDOFF §2.1); a problem gets an ink "!"
            // so it never reads as success.
            Image(systemName: message.kind == .error ? "exclamationmark" : "checkmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(message.kind == .error ? BrandTheme.ink : BrandTheme.orange))
                .overlay(Circle().stroke(BrandTheme.ink, lineWidth: 2))
                .accessibilityHidden(true)

            Text(message.text)
                .font(BrandTheme.bodyFont(size: 12, weight: .medium))
                .foregroundStyle(BrandTheme.ink)
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BrandTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BrandTheme.ink, lineWidth: 2)
        )
    }
}
