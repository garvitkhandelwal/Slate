import SwiftUI

/// Compact monospaced week-range metadata that discloses the inline week picker.
/// A tap-gesture element rather than a `Button` so a horizontal week swipe over it never reads as a tap.
struct WeekRangeButton: View {
    let text: String
    let accessibilityText: String
    let isExpanded: Bool
    let action: () -> Void
    var onTapGround: (() -> Void)? = nil
    var onWallpaperOptions: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(SlateTypography.metadata)
                .tracking(SlateTypography.metadataTracking)
                .textCase(.uppercase)
                .foregroundStyle(SlateColors.secondary)
                .frame(minHeight: SlateSpacing.minimumTarget)
                .layoutPriority(1)
                .contentShape(Rectangle())
                .onTapGesture(perform: action)
                .accessibilityElement()
                .accessibilityLabel(accessibilityText)
                .accessibilityValue(isExpanded ? AccessibilityLabels.expanded : AccessibilityLabels.collapsed)
                .accessibilityHint(AccessibilityLabels.weekRange)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, action)
                .accessibilityIdentifier("week-range")
                .modifier(WallpaperOptionsAction(action: onWallpaperOptions))
            EmptyGround(onTap: onTapGround, onLongPress: onWallpaperOptions)
        }
    }
}

private struct WallpaperOptionsAction: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.accessibilityAction(named: Text(AccessibilityLabels.wallpaperOptions), action)
        } else {
            content
        }
    }
}
