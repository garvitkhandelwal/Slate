import SwiftUI

/// One day within the weekly list: a tappable label row, task rows, and the inline add affordance.
/// It emits separate list rows so each task keeps its native swipe action, and decides nothing itself:
/// today, labels, snapshots, capture state, and callbacks all arrive from the weekly view.
struct DaySectionView: View {
    let day: LocalDay
    let dayLabel: String
    let accessibilityDayLabel: String
    let isToday: Bool
    let tasks: [TaskSnapshot]
    let isAdding: Bool
    @Binding var draft: String
    var focus: FocusState<CaptureTarget?>.Binding
    let onOpen: () -> Void
    let onAdd: () -> Void
    let onToggle: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onSubmit: () -> Void
    let onDismiss: () -> Void
    var onTapGround: (() -> Void)? = nil
    var onLongPressGround: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                Text(dayLabel)
                    .font(SlateTypography.dayLabel.weight(isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? SlateColors.ink : SlateColors.secondary)
                    .frame(minHeight: SlateSpacing.minimumTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityDayLabel)
            .accessibilityIdentifier("day-label-\(day.year)-\(day.month)-\(day.day)")
            .accessibilityAddTraits(.isHeader)
            EmptyGround(onTap: onTapGround, onLongPress: onLongPressGround)
        }
        .padding(.top, SlateSpacing.section - SlateSpacing.compact)
        .slateRow()

        ForEach(tasks) { task in
            TaskRow(
                task: task,
                mode: .week,
                onToggle: { onToggle(task.id) },
                onDelete: { onDelete(task.id) }
            )
            .slateRow()
        }

        HStack(spacing: 0) {
            if isAdding {
                InlineTaskField(
                    text: $draft,
                    target: .adding(day),
                    accessibilityIdentifier: "capture-field",
                    onSubmit: onSubmit,
                    onDismiss: onDismiss,
                    focus: focus
                )
            } else {
                Button(action: onAdd) {
                    Text(AccessibilityLabels.add)
                        .font(SlateTypography.body)
                        .foregroundStyle(SlateColors.placeholder)
                        .frame(minHeight: SlateSpacing.minimumTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("add-\(day.year)-\(day.month)-\(day.day)")
                EmptyGround(onTap: onTapGround, onLongPress: onLongPressGround)
            }
        }
        .slateRow()
    }
}

/// Genuine empty ground beside a label or below the last section: transparent and non-accessible.
/// A tap ends the current capture (commit-then-exit); a long press is the only route to wallpaper options.
struct EmptyGround: View {
    var onTap: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: SlateSpacing.minimumTarget)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
            .onLongPressGesture(minimumDuration: 0.5) { onLongPress?() }
            .accessibilityHidden(true)
    }
}

extension View {
    /// Flat list row: no separator, no background, the shared reading edge.
    func slateRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: SlateSpacing.contentEdge, bottom: 0, trailing: SlateSpacing.contentEdge))
    }
}
