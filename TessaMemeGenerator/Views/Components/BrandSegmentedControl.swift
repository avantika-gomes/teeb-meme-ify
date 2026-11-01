import SwiftUI

/// Shared segmented control (handoff/HANDOFF.md §2.3): white track, 2px ink border, 4pt inset,
/// active segment lime. Used for the Caption mode toggle and, unmodified, the Place alignment
/// picker.
struct BrandSegmentedControl<Option: Hashable, SegmentLabel: View>: View {
    let options: [Option]
    @Binding var selection: Option
    @ViewBuilder let label: (Option, Bool) -> SegmentLabel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    label(option, isSelected)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isSelected ? BrandTheme.lime : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BrandTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BrandTheme.ink, lineWidth: 2)
        )
    }
}
