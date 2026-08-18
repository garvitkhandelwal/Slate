import UIKit

/// Decodes stored wallpaper data off the main actor and returns a display-ready image.
struct WallpaperImageLoader: Sendable {
    func image(from data: Data) async throws -> UIImage {
        try await Task.detached(priority: .utility) {
            guard let image = UIImage(data: data) else { throw PlannerError.wallpaperImport }
            return image.preparingForDisplay() ?? image
        }.value
    }
}
