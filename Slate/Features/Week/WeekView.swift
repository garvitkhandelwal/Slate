import SwiftUI

/// The root planning surface: week range, seven day sections, and empty ground, on the wallpaper layer.
/// It owns only ephemeral focus state and forwards every intent to the shared view model.
struct WeekView: View {
    @Bindable var model: PlannerViewModel
    @FocusState private var focus: CaptureTarget?
    /// Return resigns focus before rapid entry continues; ignore that transient loss.
    @State private var isSubmitting = false

    private var draftBinding: Binding<String> {
        Binding(get: { model.capture.draft }, set: { model.updateDraft($0) })
    }

    var body: some View {
        List {
            WeekRangeButton(
                text: model.calendarService.weekRangeText(model.displayedWeek),
                accessibilityText: AccessibilityLabels.weekRange(
                    model.displayedWeek,
                    calendarService: model.calendarService,
                    isCurrentWeek: model.displayedWeek == model.currentWeek
                ),
                isExpanded: model.isWeekPickerExpanded,
                action: { model.isWeekPickerExpanded.toggle() },
                onTapGround: endCapture
            )
            .padding(.top, SlateSpacing.compact)
            .slateRow()

            ForEach(model.displayedWeek.days, id: \.self) { day in
                DaySectionView(
                    day: day,
                    dayLabel: model.calendarService.dayLabel(day),
                    accessibilityDayLabel: AccessibilityLabels.day(day, calendarService: model.calendarService, isToday: model.isToday(day)),
                    isToday: model.isToday(day),
                    tasks: model.tasks(on: day),
                    isAdding: model.capture.isAdding(on: day),
                    draft: draftBinding,
                    focus: $focus,
                    onOpen: { model.openDay(day) },
                    onAdd: { model.beginAdding(on: day) },
                    onToggle: { model.toggleTask($0) },
                    onDelete: { model.deleteTask($0) },
                    onSubmit: submitAndKeepFocus,
                    onDismiss: { model.dismissCapture(committing: false) },
                    onTapGround: endCapture
                )
            }

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
        .background(SlateColors.ground.ignoresSafeArea())
        .navigationTitle(AccessibilityLabels.week)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("planner-root")
        .onChange(of: model.capture.target) { _, target in
            syncFocus(to: target)
        }
        .onChange(of: focus) { previous, current in
            // Losing focus by an outside tap or keyboard dismissal commits a valid draft, then exits.
            if current == nil, !isSubmitting, let previous, previous == model.capture.target {
                model.dismissCapture(committing: true)
            }
        }
    }

    /// Return commits the draft; a session that stays active (rapid entry or a failed commit) keeps focus.
    private func submitAndKeepFocus() {
        isSubmitting = true
        model.submitCapture(keepAdding: true)
        let target = model.capture.target
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            if let target, model.capture.target == target { focus = target }
            isSubmitting = false
        }
    }

    /// An outside tap drops focus; the focus change then commits any valid draft and exits capture.
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
        // The field must exist before it can take focus; defer one turn past the transition that inserted it.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            if model.capture.target == target { focus = target }
        }
    }
}
