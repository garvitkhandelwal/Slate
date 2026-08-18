import Foundation

/// Injectable haptic contract. Haptics fire only after a persistence mutation succeeds.
protocol HapticClient: Sendable {
    @MainActor func light()
    @MainActor func medium()
}
