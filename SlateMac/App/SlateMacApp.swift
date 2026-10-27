import AppKit
import SwiftUI

/// The macOS entry point. Slate lives in the menu bar by default (`LSUIElement`): clicking the slate glyph drops
/// the same planner the phone shows. `Window` opens it as an ordinary app window, with a Dock icon, ⌘-Tab, and
/// the standard menus, for as long as that window stays open.
///
/// Both surfaces render one shared `PlannerViewModel`, so a task added in either is already in the other.
@main
struct SlateMacApp: App {
    private enum Bootstrap {
        case ready(PlannerViewModel, AppLifecycleCoordinator)
        case failed(PlannerError)
    }

    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    private let bootstrap: Bootstrap

    init() {
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
        MenuBarExtra {
            MenuBarPanel { planner }
        } label: {
            Image("MenuBarIcon")
                .accessibilityLabel(Text(verbatim: "Slate"))
                // The label is mounted for the app's whole lifetime, so this is the one place that can hand
                // `openWindow` to AppKit callbacks (a Finder or Dock reopen) before the panel is ever shown.
                .background(OpenWindowCapture { appDelegate.openPlannerWindow = $0 })
        }
        .menuBarExtraStyle(.window)

        Window(Text(verbatim: "Slate"), id: PlannerWindowScene.id) {
            PlannerWindow { planner }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(PlannerWindowScene.defaultSize)
        .windowResizability(.contentMinSize)
        // Launching only puts the glyph in the menu bar; the window appears when asked for.
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }

    @ViewBuilder
    private var planner: some View {
        switch bootstrap {
        case .ready(let model, let lifecycle):
            PlannerRootView(model: model, lifecycle: lifecycle)
                .background(WindowActivationObserver {
                    // Opening the panel or focusing the window is the Mac's "became active": purge once per
                    // day, pick up a changed locale or day, and reload what the other surface may have changed.
                    lifecycle.handleBecameActive()
                    model.handleSceneActivation()
                })
                // `preferredColorScheme` does not reach a menu bar panel, so the in-app LIGHT/DARK choice is
                // applied app-wide: the panel and the window always share one appearance.
                .onChange(of: model.appearanceOverride, initial: true) { _, scheme in
                    NSApp.appearance = scheme.map { NSAppearance(named: $0 == .dark ? .darkAqua : .aqua) } ?? nil
                }
        case .failed(let error):
            Text(error.localizedDescription)
                .padding()
        }
    }
}

/// AppKit hooks SwiftUI scenes do not expose: reopening from Finder or the Dock, and staying alive (in the menu
/// bar) after the last window closes.
@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    var openPlannerWindow: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openPlannerWindow?() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

/// Zero-size view that hands SwiftUI's `openWindow` action to code outside a view hierarchy.
private struct OpenWindowCapture: View {
    let onCapture: (@escaping () -> Void) -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                onCapture { PlannerWindowScene.open(with: openWindow) }
            }
    }
}
