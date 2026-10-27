#if canImport(UIKit)
import UIKit

struct SystemHapticClient: HapticClient {
    @MainActor func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @MainActor func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
#else
import AppKit

/// Force Touch trackpads give the same light/medium distinction; other input devices stay silent.
struct SystemHapticClient: HapticClient {
    @MainActor func light() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    @MainActor func medium() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
#endif
