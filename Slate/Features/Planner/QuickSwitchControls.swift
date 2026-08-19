import SwiftUI

/// The two quiet wayfinding controls at the top of the week and day surfaces, in the metadata style:
/// `PHOTO` / `1/3` cycles stored wallpapers, and `LIGHT` / `DARK` names the appearance a tap switches to.
struct QuickSwitchControls: View {
    @Bindable var model: PlannerViewModel

    var body: some View {
        HStack(spacing: SlateSpacing.compact) {
            WallpaperSwitchControl(model: model)
            AppearanceSwitchControl(model: model)
        }
    }
}

/// `PHOTO` when nothing is showing, else `n/N`; taps cycle stored wallpapers or open the picker when none exist.
struct WallpaperSwitchControl: View {
    @Bindable var model: PlannerViewModel

    var body: some View {
        SwitchLabel(
            text: model.wallpaperSwitchLabel,
            accessibilityLabel: accessibilityLabel,
            hint: model.wallpapers.isEmpty ? AccessibilityLabels.choosePhoto : AccessibilityLabels.wallpaperSwitchHint,
            identifier: "wallpaper-switch",
            action: model.cycleWallpaper
        )
    }

    private var accessibilityLabel: String {
        if let index = model.selectedWallpaperIndex, model.wallpapers.indices.contains(index) {
            return AccessibilityLabels.wallpaperPosition(index: index + 1, count: model.wallpapers.count)
        }
        return AccessibilityLabels.photo
    }
}

/// Names the appearance a tap switches to and persists the choice.
struct AppearanceSwitchControl: View {
    @Bindable var model: PlannerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SwitchLabel(
            text: model.appearanceSwitchLabel(current: colorScheme),
            accessibilityLabel: colorScheme == .dark ? AccessibilityLabels.switchToLight : AccessibilityLabels.switchToDark,
            hint: nil,
            identifier: "appearance-switch",
            action: { model.toggleAppearance(current: colorScheme) }
        )
    }
}

/// One quiet metadata-style control: a tap-gesture text with button traits and a 44-point target.
private struct SwitchLabel: View {
    let text: String
    let accessibilityLabel: String
    let hint: String?
    let identifier: String
    let action: () -> Void

    var body: some View {
        Text(text)
            .font(SlateTypography.metadata)
            .tracking(SlateTypography.metadataTracking)
            .textCase(.uppercase)
            .foregroundStyle(SlateColors.secondary)
            .frame(minWidth: SlateSpacing.minimumTarget, minHeight: SlateSpacing.minimumTarget)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
            .accessibilityIdentifier(identifier)
    }
}
