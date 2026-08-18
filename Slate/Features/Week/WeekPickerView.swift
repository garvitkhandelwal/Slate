import SwiftUI

/// Exactly 17 plain text week choices, inline below the range label, in a bounded scrolling list.
/// Not a sheet, calendar grid, or modal.
struct WeekPickerView: View {
    let weeks: [WeekInterval]
    let selected: WeekInterval
    let label: (WeekInterval) -> String
    let accessibilityLabel: (WeekInterval) -> String
    let onSelect: (WeekInterval) -> Void

    static let maxHeight: CGFloat = 280

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(weeks.enumerated()), id: \.element.start) { index, week in
                        let isSelected = week == selected
                        Button {
                            onSelect(week)
                        } label: {
                            Text(label(week))
                                .font(SlateTypography.body.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? SlateColors.ink : SlateColors.secondary)
                                .frame(maxWidth: .infinity, minHeight: SlateSpacing.minimumTarget, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(week))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityIdentifier("week-option-\(index)")
                        .id(week.start)
                    }
                }
            }
            .frame(maxHeight: Self.maxHeight)
            .accessibilityIdentifier("week-picker")
            .onAppear {
                proxy.scrollTo(selected.start, anchor: .center)
            }
        }
    }
}
