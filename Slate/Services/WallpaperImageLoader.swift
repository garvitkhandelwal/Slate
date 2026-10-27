#if canImport(UIKit)
import UIKit

/// The decoded, display-ready wallpaper each platform renders.
typealias WallpaperImage = UIImage

/// Decodes stored wallpaper data off the main actor and returns a display-ready image.
struct WallpaperImageLoader: Sendable {
    func image(from data: Data) async throws -> UIImage {
        try await Task.detached(priority: .utility) {
            guard let image = UIImage(data: data) else { throw PlannerError.wallpaperImport }
            return image.preparingForDisplay() ?? image
        }.value
    }
}
#else
import Foundation
import ImageIO

/// macOS keeps the decoded bitmap itself: `CGImage` is sendable and SwiftUI draws it directly.
typealias WallpaperImage = CGImage

/// Decodes stored wallpaper data off the main actor and returns a display-ready image.
struct WallpaperImageLoader: Sendable {
    func image(from data: Data) async throws -> CGImage {
        try await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
            else { throw PlannerError.wallpaperImport }
            return image
        }.value
    }
}
#endif
