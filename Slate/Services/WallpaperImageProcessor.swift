import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The locked import pipeline: validate as an image, apply the EXIF orientation, downsample so the
/// longest edge is at most 4096 pixels, and re-encode with no source metadata. Runs off the main actor.
struct WallpaperImageProcessor: Sendable {
    static let maxPixelSize = 4096
    static let compressionQuality = 0.9

    func process(_ data: Data) async throws -> Data {
        try await Task.detached(priority: .utility) {
            try Self.processSynchronously(data)
        }.value
    }

    /// Synchronous body kept separate so tests and the detached task share one implementation.
    static func processSynchronously(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                  kCGImageSourceShouldCacheImmediately: false,
              ] as CFDictionary)
        else {
            throw PlannerError.wallpaperImport
        }

        // Prefer HEIC when the encoder is available; some environments list it but cannot finalize it.
        let supported = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        if supported.contains(UTType.heic.identifier), let heic = encode(image, as: UTType.heic) {
            return heic
        }
        guard let jpeg = encode(image, as: UTType.jpeg) else { throw PlannerError.wallpaperImport }
        return jpeg
    }

    /// Writes only pixels and a normalized orientation; never copies source property dictionaries.
    private static func encode(_ image: CGImage, as type: UTType) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return nil
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
            kCGImagePropertyOrientation: CGImagePropertyOrientation.up.rawValue,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length > 0 else { return nil }
        return output as Data
    }
}
