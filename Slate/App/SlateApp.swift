import SwiftUI

@main
struct SlateApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Slate")
                .accessibilityIdentifier("planner-root")
        }
    }
}
