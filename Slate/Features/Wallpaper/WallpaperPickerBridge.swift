import Foundation
import PhotosUI
import SwiftUI

/// The single seam between the out-of-process `PhotosPicker` selection and raw image data.
struct WallpaperPickerBridge: Sendable {
    func data(from item: PhotosPickerItem) async throws -> Data {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PlannerError.wallpaperImport
        }
        return data
    }
}
