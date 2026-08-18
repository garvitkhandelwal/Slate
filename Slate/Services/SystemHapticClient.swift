import UIKit

struct SystemHapticClient: HapticClient {
    @MainActor func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @MainActor func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
