#if os(macOS)
import SwiftUI

/// The day view's way back to the week on macOS, where the menu bar panel has no navigation bar to host the
/// system control. Metadata-styled like the quick switches so the top row stays one quiet line; ⌘[ also works.
struct BackControl: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.backward")
                    .font(SlateTypography.metadata.weight(.semibold))
                Text(AccessibilityLabels.week)
                    .font(SlateTypography.metadata)
                    .tracking(SlateTypography.metadataTracking)
                    .textCase(.uppercase)
            }
            .foregroundStyle(SlateColors.secondary)
            .frame(minHeight: SlateSpacing.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("[", modifiers: .command)
        .accessibilityLabel(AccessibilityLabels.back)
        .accessibilityIdentifier("back-to-week")
    }
}
#endif
