import PhotosUI
import SwiftUI

/// The compact system dialog reached by long-pressing empty weekly ground or the VoiceOver custom action:
/// `Choose photo…`, `Remove wallpaper` when one exists, and the system cancel action. Photo selection uses
/// the out-of-process picker, so no Photos-library permission is ever requested.
struct WallpaperActionDialog: ViewModifier {
    @Bindable var model: PlannerViewModel
    @State private var selectedItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                AccessibilityLabels.wallpaperOptions,
                isPresented: $model.isWallpaperDialogPresented,
                titleVisibility: .visible
            ) {
                Button(AccessibilityLabels.choosePhoto) {
                    model.isPhotoPickerPresented = true
                }
                if model.wallpaperImage != nil {
                    Button(AccessibilityLabels.removeWallpaper, role: .destructive) {
                        Task { await model.removeWallpaper() }
                    }
                }
            }
            .photosPicker(isPresented: $model.isPhotoPickerPresented, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                selectedItem = nil
                Task { await model.importWallpaper(item) }
            }
    }
}

extension View {
    func wallpaperActionDialog(model: PlannerViewModel) -> some View {
        modifier(WallpaperActionDialog(model: model))
    }
}
