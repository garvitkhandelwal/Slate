import SwiftUI

enum WeekSwipeDecision: Equatable {
    case previous, next, none
}

/// Pure decision for a completed horizontal drag: at least 60 points, predominantly horizontal,
/// mirrored for right-to-left layout. Actual (not predicted) translation is used so a task swipe
/// can never accidentally cross the week threshold.
enum WeekSwipeGesture {
    static let threshold: CGFloat = 60
    static let horizontalDominance: CGFloat = 1.25

    static func decision(width: CGFloat, height: CGFloat, direction: LayoutDirection) -> WeekSwipeDecision {
        guard abs(width) >= threshold, abs(width) > abs(height) * horizontalDominance else { return .none }
        let physicalLeft = width < 0
        switch (physicalLeft, direction) {
        case (true, .leftToRight), (false, .rightToLeft): return .next
        case (false, .leftToRight), (true, .rightToLeft): return .previous
        @unknown default: return .none
        }
    }
}

/// Attaches the week-change drag to weekly ground and label rows without touching task rows.
struct WeekSwipeModifier: ViewModifier {
    let isEnabled: Bool
    let onDecision: (WeekSwipeDecision) -> Void
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    guard isEnabled else { return }
                    let decision = WeekSwipeGesture.decision(
                        width: value.translation.width,
                        height: value.translation.height,
                        direction: layoutDirection
                    )
                    if decision != .none { onDecision(decision) }
                }
        )
    }
}

extension View {
    func weekSwipe(isEnabled: Bool, onDecision: @escaping (WeekSwipeDecision) -> Void) -> some View {
        modifier(WeekSwipeModifier(isEnabled: isEnabled, onDecision: onDecision))
    }
}
