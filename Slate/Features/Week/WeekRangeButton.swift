import SwiftUI

/// Compact monospaced week-range metadata that discloses the inline week picker.
struct WeekRangeButton: View {
    let text: String
    let accessibilityText: String
    let isExpanded: Bool
    let action: () -> Void
    var onTapGround: (() -> Void)? = nil
    var onWallpaperOptions: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                Text(text)
                    .font(SlateTypography.metadata)
                    .tracking(SlateTypography.metadataTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(SlateColors.secondary)
                    .frame(minHeight: SlateSpacing.minimumTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityText)
            .accessibilityValue(isExpanded ? AccessibilityLabels.expanded : AccessibilityLabels.collapsed)
            .accessibilityHint(AccessibilityLabels.weekRange)
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
