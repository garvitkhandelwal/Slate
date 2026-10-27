import AppKit
import SwiftUI

/// Calls `onActivate` each time the hosting window becomes key.
///
/// `MenuBarExtra(.window)` keeps its view hierarchy alive between opens, so `onAppear` fires only once and
/// `scenePhase` does not track the panel. Key-window changes fire on every open of the panel and on every
/// return to the planner window.
struct WindowActivationObserver: NSViewRepresentable {
    let onActivate: @MainActor () -> Void

    func makeNSView(context: Context) -> ObserverView {
        ObserverView(onActivate: onActivate)
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onActivate = onActivate
    }

    final class ObserverView: NSView {
        var onActivate: @MainActor () -> Void
        private var observation: NSObjectProtocol?

        init(onActivate: @escaping @MainActor () -> Void) {
            self.onActivate = onActivate
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observation { NotificationCenter.default.removeObserver(observation) }
            observation = nil
            guard let window else { return }
            observation = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.onActivate() }
            }
        }
    }
}
