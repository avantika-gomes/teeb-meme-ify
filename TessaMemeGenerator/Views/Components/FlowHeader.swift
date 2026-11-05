import SwiftUI

/// Shared header for the Caption → Place → Done flow: back arrow, three step dashes, close.
struct FlowHeader: View {
    /// Which dash is current, matching Home's 01 SNAP / 02 CAPTION / 03 SEND. Captions is 2 (the
    /// photo is already taken), Place is 3, and Done passes 4 so all three read as finished.
    let step: Int
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BrandTheme.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { index in
                    stepDash(dashState(for: index))
                }
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BrandTheme.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 6)
    }

    private enum DashState {
        case done, current, upcoming
    }

    private func dashState(for index: Int) -> DashState {
        if index < step { return .done }
        if index == step { return .current }
        return .upcoming
    }

    private func stepDash(_ state: DashState) -> some View {
        let fill: Color
        switch state {
        case .done: fill = BrandTheme.ink
        case .current: fill = BrandTheme.orange
        case .upcoming: fill = BrandTheme.background
        }

        return Capsule()
            .fill(fill)
            .frame(width: 26, height: 7)
            .overlay(
                Capsule()
                    .stroke(BrandTheme.ink, lineWidth: state == .done ? 0 : 1)
            )
    }
}
