import SwiftUI

enum TaskRowMode {
    /// One truncated line; tapping the row toggles completion.
    case week
    /// Wrapping text; a leading 44-point region toggles, tapping text edits.
    case day
}

/// Bindings the day view supplies so an edited row can show the inline field in place of its text.
struct TaskRowEditing {
    var draft: Binding<String>
    var focus: FocusState<CaptureTarget?>.Binding
    var onSubmit: () -> Void
    var onDismiss: () -> Void
}

/// Text-first task presentation with completion, native swipe deletion, and named accessibility actions.
/// It performs no persistence; every action is a callback.
struct TaskRow: View {
    let task: TaskSnapshot
    let mode: TaskRowMode
    var isEditing = false
    var editing: TaskRowEditing? = nil
    let onToggle: () -> Void
    let onDelete: () -> Void
    var onEdit: (() -> Void)? = nil

    var body: some View {
        row
            .frame(minHeight: SlateSpacing.minimumTarget)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDelete) {
                    Text(AccessibilityLabels.delete)
                }
                .tint(SlateColors.ink)
            }
            .modifier(RowAccessibility(task: task, mode: mode, isEditing: isEditing, onToggle: onToggle, onDelete: onDelete, onEdit: onEdit))
    }

    @ViewBuilder
    private var row: some View {
        switch mode {
        case .week:
            Button(action: onToggle) {
                text
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .day:
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Button(action: onToggle) {
                    Color.clear
                        .frame(width: SlateSpacing.minimumTarget, height: SlateSpacing.minimumTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)

                if isEditing, let editing {
                    InlineTaskField(
                        text: editing.draft,
                        target: .editing(task.id),
                        accessibilityIdentifier: "capture-field",
                        onSubmit: editing.onSubmit,
                        onDismiss: editing.onDismiss,
                        focus: editing.focus
                    )
                } else if let onEdit {
                    Button(action: onEdit) {
                        text
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    text
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var text: some View {
        Text(task.text)
            .font(SlateTypography.body)
            .strikethrough(task.isCompleted)
            .foregroundStyle(task.isCompleted ? SlateColors.secondary : SlateColors.ink)
            .multilineTextAlignment(.leading)
    }
}

/// One combined VoiceOver element per row: label = task text, value = completion, named actions for
/// completion, edit (day view only), and delete. Suppressed while the row hosts the live edit field.
private struct RowAccessibility: ViewModifier {
    let task: TaskSnapshot
    let mode: TaskRowMode
    let isEditing: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: (() -> Void)?

    func body(content: Content) -> some View {
        if isEditing {
            content
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(task.text))
                .accessibilityValue(Text(AccessibilityLabels.taskValue(isCompleted: task.isCompleted)))
                .accessibilityHint(mode == .day && onEdit != nil ? Text(AccessibilityLabels.editHint) : Text(""))
                .accessibilityAction {
                    if mode == .day, let onEdit { onEdit() } else { onToggle() }
                }
                .accessibilityAction(named: Text(AccessibilityLabels.toggleActionName(isCompleted: task.isCompleted)), onToggle)
                .modifier(EditAction(onEdit: mode == .day ? onEdit : nil))
                .accessibilityAction(named: Text(AccessibilityLabels.delete), onDelete)
        }
    }
}

private struct EditAction: ViewModifier {
    let onEdit: (() -> Void)?

    func body(content: Content) -> some View {
        if let onEdit {
            content.accessibilityAction(named: Text(AccessibilityLabels.edit), onEdit)
        } else {
            content
        }
    }
}
