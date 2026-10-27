import AppKit
import SwiftUI

/// What the menu bar glyph drops down: the phone-sized planner, unchanged, over a single quiet footer row
/// in the same metadata style as `PHOTO` and `DARK` — one control to pop out into a window, one to quit.
struct MenuBarPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.openWindow) private var openWindow

    static var size: CGSize { CGSize(width: 380, height: 640) }

    var body: some View {
        VStack(spacing: 0) {
            content()
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            FooterControl(text: AccessibilityLabels.openWindow, systemImage: "macwindow", identifier: "open-window") {
                PlannerWindowScene.open(with: openWindow)
            }
            .accessibilityHint(AccessibilityLabels.openWindowHint)
            Spacer(minLength: SlateSpacing.compact)
            FooterControl(text: AccessibilityLabels.quit, systemImage: nil, identifier: "quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .accessibilityLabel(AccessibilityLabels.quitSlate)
        }
        .padding(.horizontal, SlateSpacing.contentEdge)
        .frame(height: 36)
        .background(SlateColors.ground)
        .overlay(alignment: .top) {
            SlateColors.divider.frame(height: 1)
        }
    }
}

/// A metadata-styled text control matching the planner's quick switches.
private struct FooterControl: View {
    let text: String
    let systemImage: String?
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(text)
                    .tracking(SlateTypography.metadataTracking)
                    .textCase(.uppercase)
            }
            .font(SlateTypography.metadata)
            .foregroundStyle(SlateColors.secondary)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
