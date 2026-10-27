import AppKit
import SwiftUI

/// The planner as an ordinary window. While it is open Slate is a regular app — Dock icon, ⌘-Tab, menus —
/// and closing it returns Slate to the menu bar alone.
struct PlannerWindow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(minWidth: PlannerWindowScene.minimumSize.width, minHeight: PlannerWindowScene.minimumSize.height)
            .onAppear { NSApp.setActivationPolicy(.regular) }
            .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }
}

enum PlannerWindowScene {
    static let id = "planner"
    /// A phone-like column: the planner is a single reading width, not a wide canvas.
    static let defaultSize = CGSize(width: 420, height: 780)
    static let minimumSize = CGSize(width: 340, height: 460)

    /// Opens (or focuses) the window and brings Slate forward; a menu bar app is never frontmost on its own.
    @MainActor
    static func open(with openWindow: OpenWindowAction) {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: id)
        NSApp.activate()
    }
}
