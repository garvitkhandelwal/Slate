import SwiftUI

@main
struct SlateApp: App {
    private enum Bootstrap {
        case ready(PlannerViewModel, AppLifecycleCoordinator)
        case failed(PlannerError)
        /// Hosted unit tests need the module, not the planner surface or its store.
        case unitTestHost
    }

    private let bootstrap: Bootstrap

    init() {
        #if DEBUG
        if NSClassFromString("XCTestCase") != nil {
            bootstrap = .unitTestHost
            return
        }
        #endif
        do {
            let environment = try AppEnvironment.production()
            let lifecycle = AppLifecycleCoordinator(
                retentionService: environment.retentionService,
                dateProvider: environment.dateProvider,
                calendarService: environment.calendarService
            )
            lifecycle.registerBackgroundTask()
            bootstrap = .ready(PlannerViewModel(environment: environment), lifecycle)
        } catch {
            bootstrap = .failed(.unavailableStore)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .ready(let model, let lifecycle):
                PlannerRootView(model: model, lifecycle: lifecycle)
                    .modifier(TestAppearance())
            case .failed(let error):
                Text(error.localizedDescription)
                    .padding()
            case .unitTestHost:
                Text("Slate")
            }
        }
    }
}

/// DEBUG-only forced appearance for UI-test launches; a no-op in release builds.
private struct TestAppearance: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        if UITestBootstrap.isEnabled, let scheme = UITestBootstrap.forcedColorScheme {
            content.preferredColorScheme(scheme)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
