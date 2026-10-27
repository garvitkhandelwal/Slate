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
            #if os(iOS)
            .photosPicker(isPresented: $model.isPhotoPickerPresented, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                selectedItem = nil
                Task { await model.importWallpaper(item) }
            }
            #else
            .onChange(of: model.isPhotoPickerPresented) { _, isPresented in
                guard isPresented else { return }
                model.isPhotoPickerPresented = false
                WallpaperOpenPanel.present { data in
                    Task { await model.importWallpaper(data: data) }
                }
            }
            #endif
    }
}

#if os(macOS)
import AppKit

/// The Mac picker: a standard open panel limited to images. The sandbox grants read access to the chosen
/// file only, so — like the iOS picker — Slate never sees anything the user did not pick.
@MainActor
enum WallpaperOpenPanel {
    static func present(onPick: @escaping @MainActor (Data) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = AccessibilityLabels.choosePhoto
        // A menu bar app is not frontmost when the panel opens; bring it forward so the panel is key.
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        onPick(data)
    }
}
#endif

extension View {
    func wallpaperActionDialog(model: PlannerViewModel) -> some View {
        modifier(WallpaperActionDialog(model: model))
    }
}
