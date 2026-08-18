import SwiftUI

/// Owns the navigation path, the single planner alert, and scene-activation coordination.
struct PlannerRootView: View {
    @Bindable var model: PlannerViewModel
    let lifecycle: AppLifecycleCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasStarted = false

    private var isErrorPresented: Binding<Bool> {
        Binding(
            get: { model.presentedError != nil },
            set: { if !$0 { model.presentedError = nil } }
        )
    }

    var body: some View {
        NavigationStack(path: $model.route) {
            WeekView(model: model)
                .navigationDestination(for: RootRoute.self) { route in
                    switch route {
                    case .day(let day):
                        DayView(model: model, day: day)
                    }
                }
        }
        .tint(SlateColors.ink)
        .alert(isPresented: isErrorPresented, error: model.presentedError) { _ in
            Button(AccessibilityLabels.ok, role: .cancel) {}
        } message: { _ in
            EmptyView()
        }
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await model.start()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, hasStarted else { return }
            lifecycle.handleBecameActive()
            model.handleSceneActivation()
        }
    }
}
