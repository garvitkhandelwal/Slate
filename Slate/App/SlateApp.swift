import SwiftUI

@main
struct SlateApp: App {
    private let bootstrap: Result<(PlannerViewModel, AppLifecycleCoordinator), PlannerError>

    init() {
        do {
            let environment = try AppEnvironment.production()
            let lifecycle = AppLifecycleCoordinator(
                retentionService: environment.retentionService,
                dateProvider: environment.dateProvider,
                calendarService: environment.calendarService
            )
            lifecycle.registerBackgroundTask()
            bootstrap = .success((PlannerViewModel(environment: environment), lifecycle))
        } catch {
            bootstrap = .failure(.unavailableStore)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .success:
                Text("Slate")
                    .accessibilityIdentifier("planner-root")
            case .failure(let error):
                Text(error.localizedDescription)
                    .padding()
            }
        }
    }
}
