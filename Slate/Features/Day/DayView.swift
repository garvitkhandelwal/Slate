import SwiftUI

/// The focused day: date heading, subordinate weekday, wrapping task rows with inline editing, and `+ add`.
/// It filters the shared `tasksByDay` state and never creates a second view model or repository.
struct DayView: View {
    @Bindable var model: PlannerViewModel
    let day: LocalDay
    @FocusState private var focus: CaptureTarget?
    /// Return resigns focus before rapid entry continues; ignore that transient loss.
    @State private var isSubmitting = false

    private var draftBinding: Binding<String> {
        Binding(get: { model.capture.draft }, set: { model.updateDraft($0) })
    }

    private var editing: TaskRowEditing {
        TaskRowEditing(
            draft: draftBinding,
            focus: $focus,
            onSubmit: { submit(keepAdding: false) },
            onDismiss: { model.dismissCapture(committing: false) }
        )
    }

    var body: some View {
        ZStack {
            WallpaperLayer(image: model.wallpaperImage)
            list
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("day-root")
        .onChange(of: model.capture.target) { _, target in
            syncFocus(to: target)
        }
        .onChange(of: focus) { previous, current in
            if current == nil, !isSubmitting, let previous, previous == model.capture.target {
                model.dismissCapture(committing: true)
            }
        }
        .onDisappear {
            // Leaving the screen commits a valid draft before navigation completes.
            model.dismissCapture(committing: true)
        }
    }

    private var list: some View {
        List {
            // The quick switches sit at the trailing end of the top row, under the native back control.
            HStack(spacing: 0) {
                EmptyGround(onTap: endCapture)
                QuickSwitchControls(model: model)
            }
            .slateRow()

            heading
                .padding(.bottom, SlateSpacing.section - SlateSpacing.compact)
                .slateRow()

            ForEach(model.tasks(on: day)) { task in
                TaskRow(
                    task: task,
                    mode: .day,
                    isEditing: model.capture.isEditing(task.id),
                    editing: editing,
                    onToggle: { model.toggleTask(task.id) },
                    onDelete: { model.deleteTask(task.id) },
                    onEdit: { model.beginEditing(task) }
                )
                .slateRow()
            }

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: SlateSpacing.minimumTarget, height: SlateSpacing.minimumTarget)
                    .accessibilityHidden(true)
                if model.capture.isAdding(on: day) {
                    InlineTaskField(
                        text: draftBinding,
                        target: .adding(day),
                        accessibilityIdentifier: "capture-field",
                        onSubmit: { submit(keepAdding: true) },
                        onDismiss: { model.dismissCapture(committing: false) },
                        focus: $focus
                    )
                } else {
                    Text(AccessibilityLabels.add)
                        .font(SlateTypography.body)
                        .foregroundStyle(SlateColors.placeholder)
                        .frame(minHeight: SlateSpacing.minimumTarget)
                        .layoutPriority(1)
                        .contentShape(Rectangle())
                        .onTapGesture { model.beginAdding(on: day) }
                        .accessibilityElement()
                        .accessibilityLabel(AccessibilityLabels.add)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { model.beginAdding(on: day) }
                        .accessibilityIdentifier("add-\(day.year)-\(day.month)-\(day.day)")
                    EmptyGround(onTap: endCapture)
                }
            }
            .slateRow()

            EmptyGround(onTap: endCapture)
                .frame(height: SlateSpacing.groundHeight)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, SlateSpacing.minimumTarget)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var heading: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: SlateSpacing.compact) {
                Text(model.calendarService.dayHeading(day))
                    .font(SlateTypography.heading)
                    .foregroundStyle(SlateColors.ink)
                Text(model.calendarService.weekdayText(day))
                    .font(SlateTypography.metadata)
                    .tracking(SlateTypography.metadataTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(SlateColors.secondary)
            }
            .layoutPriority(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityLabels.day(day, calendarService: model.calendarService, isToday: model.isToday(day)))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("day-heading")
            EmptyGround(onTap: endCapture)
        }
    }

    /// Return commits the draft; a session that stays active (rapid entry or a failed commit) keeps focus.
    private func submit(keepAdding: Bool) {
        isSubmitting = true
        model.submitCapture(keepAdding: keepAdding)
        let target = model.capture.target
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            if let target, model.capture.target == target { focus = target }
            isSubmitting = false
        }
    }

    private func endCapture() {
        if focus != nil {
            focus = nil
        } else if model.capture.isActive {
            model.dismissCapture(committing: true)
        }
    }

    private func syncFocus(to target: CaptureTarget?) {
        guard let target else {
            focus = nil
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            if model.capture.target == target { focus = target }
        }
    }
}
