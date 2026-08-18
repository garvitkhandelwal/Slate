import SwiftUI

/// The locked render stack behind week and day content:
/// mode background → image aspect-filled beyond safe bounds → grayscale → 10pt blur → 32% opacity →
/// 50% mode-background scrim → planner content. A newly loaded image fades in only when Reduce Motion is off.
struct WallpaperLayer: View {
    let image: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let blurRadius: CGFloat = 10
    static let imageOpacity: Double = 0.32
    static let scrimOpacity: Double = 0.50

    var body: some View {
        ZStack {
            SlateColors.ground
            if let image {
                decorative(image)
                    .resizable()
                    .scaledToFill()
                    .saturation(0)
                    .blur(radius: Self.blurRadius)
                    .opacity(Self.imageOpacity)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .transition(.opacity)
                SlateColors.ground
                    .opacity(Self.scrimOpacity)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
        .clipped()
        .animation(reduceMotion ? nil : SlateMotion.standard, value: image.map(ObjectIdentifier.init))
        .accessibilityHidden(true)
    }

    /// A decorative image is never an accessibility element; the wallpaper is ground, not content.
    private func decorative(_ image: UIImage) -> Image {
        if let cgImage = image.cgImage {
            return Image(decorative: cgImage, scale: image.scale, orientation: .up)
        }
        return Image(uiImage: image)
    }
}
