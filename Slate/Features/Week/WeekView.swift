import SwiftUI

/// The root planning surface: week range with its inline picker, then seven day sections and empty
/// ground on the wallpaper layer. It owns only ephemeral focus, gesture, and animation state and
/// forwards every intent to the shared view model.
struct WeekView: View {
    @Bindable var model: PlannerViewModel
    @FocusState private var focus: CaptureTarget?
    /// Return resigns focus before rapid entry continues; ignore that transient loss.
    @State private var isSubmitting = false
    @State private var travel: SlateMotion.WeekTravel = .forward
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var draftBinding: Binding<String> {
        Binding(get: { model.capture.draft }, set: { model.updateDraft($0) })
    }

    /// Vertical scrolling, task swipes, text selection, and active capture take precedence.
    private var isWeekSwipeEnabled: Bool {
        !model.capture.isActive && !model.isWeekPickerExpanded && focus == nil
    }

    var body: some View {
        ZStack {
            WallpaperLayer(image: model.wallpaperImage)
            VStack(spacing: 0) {
                header
                ZStack {
                    weekList
                        .id(model.displayedWeek.start)
                        .transition(SlateMotion.weekTransition(travel: travel, reduceMotion: reduceMotion))
                }
            }
        }
        .wallpaperActionDialog(model: model)
        .navigationTitle(AccessibilityLabels.week)
        .toolbar(.hidden, for: .navigationBar)
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

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                WeekRangeButton(
                    text: model.calendarService.weekRangeText(model.displayedWeek),
                    accessibilityText: AccessibilityLabels.weekRange(
                        model.displayedWeek,
                        calendarService: model.calendarService,
                        isCurrentWeek: model.displayedWeek == model.currentWeek
                    ),
                    isExpanded: model.isWeekPickerExpanded,
                    action: togglePicker,
                    onTapGround: endCapture,
                    onWallpaperOptions: presentWallpaperOptions
                )
                QuickSwitchControls(model: model)
            }
            .padding(.top, SlateSpacing.compact)
            .weekSwipe(isEnabled: isWeekSwipeEnabled, onDecision: handleSwipe)

            if model.isWeekPickerExpanded {
                WeekPickerView(
                    weeks: model.pickerWeeks,
                    selected: model.displayedWeek,
                    label: pickerLabel,
                    accessibilityLabel: { week in
                        AccessibilityLabels.weekRange(week, calendarService: model.calendarService, isCurrentWeek: week == model.currentWeek)
                    },
                    onSelect: select
                )
                .transition(.opacity)
            }
        }
        .padding(.horizontal, SlateSpacing.contentEdge)
        // Empty ground is vertically greedy; the header only ever takes its ideal height.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func pickerLabel(_ week: WeekInterval) -> String {
        let range = model.calendarService.weekRangeText(week)
        return week == model.currentWeek ? range + "  ·  " + AccessibilityLabels.thisWeek : range
    }

    // MARK: Week content

    private var weekList: some View {
        List {
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
                    onTapGround: endCapture,
                    onLongPressGround: presentWallpaperOptions,
                    isWeekSwipeEnabled: isWeekSwipeEnabled,
                    onWeekSwipe: handleSwipe
                )
            }

            EmptyGround(onTap: endCapture, onLongPress: presentWallpaperOptions)
                .frame(height: SlateSpacing.groundHeight)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .weekSwipe(isEnabled: isWeekSwipeEnabled, onDecision: handleSwipe)
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, SlateSpacing.minimumTarget)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("planner-root")
    }

    // MARK: Wallpaper

    /// Long-pressing genuine empty ground (or the VoiceOver custom action) opens the wallpaper options.
    private func presentWallpaperOptions() {
        endCapture()
        model.isWallpaperDialogPresented = true
    }

    // MARK: Navigation

    private func togglePicker() {
        endCapture()
        withAnimation(SlateMotion.animation(reduceMotion: reduceMotion)) {
            model.isWeekPickerExpanded.toggle()
        }
    }

    private func select(_ week: WeekInterval) {
        travel = week.start < model.displayedWeek.start ? .backward : .forward
        withAnimation(SlateMotion.animation(reduceMotion: reduceMotion)) {
            model.selectWeek(containing: week.start)
        }
    }

    private func handleSwipe(_ decision: WeekSwipeDecision) {
        switch decision {
        case .next:
            travel = .forward
            withAnimation(SlateMotion.animation(reduceMotion: reduceMotion)) { model.showNextWeek() }
        case .previous:
            travel = .backward
            withAnimation(SlateMotion.animation(reduceMotion: reduceMotion)) { model.showPreviousWeek() }
        case .none:
            break
        }
    }

    // MARK: Capture focus

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
