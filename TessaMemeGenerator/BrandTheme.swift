import SwiftUI

enum BrandTheme {
    static let accent = Color(red: 1.0, green: 0.302, blue: 0.553)
    static let ink = Color(red: 0.051, green: 0.051, blue: 0.051)
    static let background = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let surface = Color.white
    static let muted = Color(red: 0.541, green: 0.541, blue: 0.541)
    static let border = Color(red: 0.91, green: 0.91, blue: 0.91)
    static let accentSoft = Color(red: 1.0, green: 0.941, blue: 0.953)

    static let cornerRadius: CGFloat = 14
    static let photoCornerRadius: CGFloat = 12
    static let appName = "Teeb Meme-ify"
    static let tagline = "Snap it. Caption it. Meme it."

    static func displayFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}

enum AppEnvironment {
    static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }
}

struct PrimaryBrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: BrandTheme.cornerRadius)
                    .fill(BrandTheme.ink.opacity(configuration.isPressed ? 0.85 : 1))
            )
    }
}

struct SecondaryBrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(BrandTheme.ink)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: BrandTheme.cornerRadius)
                    .fill(BrandTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandTheme.cornerRadius)
                    .stroke(BrandTheme.ink.opacity(configuration.isPressed ? 0.5 : 1), lineWidth: 1.5)
            )
    }
}

struct GhostBrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .textCase(.uppercase)
            .foregroundStyle(BrandTheme.muted.opacity(configuration.isPressed ? 0.7 : 1))
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
    }
}

struct BrandIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(BrandTheme.ink)
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
                    .fill(BrandTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
                    .stroke(BrandTheme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct BrandScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(BrandTheme.background.ignoresSafeArea())
    }
}

extension View {
    func brandScreen() -> some View {
        modifier(BrandScreenBackground())
    }

    func brandConfirmationToast(message: Binding<String?>) -> some View {
        overlay(alignment: .bottom) {
            if let text = message.wrappedValue {
                BrandConfirmationToast(message: text)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: message.wrappedValue)
    }

    func brandActionBarToast(message: Binding<String?>, above barHeight: CGFloat) -> some View {
        overlay(alignment: .bottom) {
            if let text = message.wrappedValue {
                BrandFlatToast(message: text)
                    .padding(.horizontal, 16)
                    .padding(.bottom, barHeight + 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: message.wrappedValue)
    }
}

struct BrandFlatToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(BrandTheme.accent)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandTheme.ink)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: BrandTheme.photoCornerRadius, style: .continuous)
                .stroke(BrandTheme.border, lineWidth: 1)
        }
    }
}

struct BrandConfirmationToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(BrandTheme.accent)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandTheme.ink)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: BrandTheme.cornerRadius, style: .continuous)
                .fill(BrandTheme.surface)
                .shadow(color: BrandTheme.ink.opacity(0.08), radius: 12, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: BrandTheme.cornerRadius, style: .continuous)
                .stroke(BrandTheme.border, lineWidth: 1)
        }
    }
}

// Deprecated alias kept for any stale references.
extension View {
    func topConfirmationBanner(message: Binding<String?>) -> some View {
        brandConfirmationToast(message: message)
    }
}

struct TopConfirmationBanner: View {
    let message: String

    var body: some View {
        BrandConfirmationToast(message: message)
    }
}
