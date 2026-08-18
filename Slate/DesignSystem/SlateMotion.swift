import SwiftUI

/// Restrained, functional motion. Reduce Motion replaces every slide with a short opacity change.
enum SlateMotion {
    static let standard = Animation.easeInOut(duration: 0.22)
    static let reduced = Animation.linear(duration: 0.12)

    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : standard
    }

    /// Travel direction of a week change, already resolved for layout direction.
    enum WeekTravel {
        case forward, backward
    }

    /// Slide in the travel direction plus opacity; opacity only when Reduce Motion is enabled.
    static func weekTransition(travel: WeekTravel, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let insertion: Edge = travel == .forward ? .trailing : .leading
        let removal: Edge = travel == .forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: removal).combined(with: .opacity)
        )
    }
}
