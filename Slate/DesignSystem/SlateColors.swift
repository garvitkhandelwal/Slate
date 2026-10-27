import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// One hue at different luminance levels. Ground and ink are the system roles; the intermediate grays follow
/// the DESIGN.md tonal ramp, invert exactly between appearances, and every text role keeps at least
/// WCAG AA (4.5:1) contrast against the ground so completed tasks and `+ add` stay legible.
enum SlateColors {
    #if canImport(UIKit)
    static let ground = Color(uiColor: .systemBackground)
    static let ink = Color(uiColor: .label)

    /// Inactive day labels, week-picker context, completed-task text. #666666 light / #999999 dark.
    static let secondary = Color(uiColor: UIColor { traits in
        switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
        case (.dark, .high): UIColor(white: 0.75, alpha: 1)
        case (.dark, _): UIColor(white: 0.60, alpha: 1)
        case (_, .high): UIColor(white: 0.30, alpha: 1)
        default: UIColor(white: 0.40, alpha: 1)
        }
    })

    /// `+ add` and the quietest nonessential copy, held at the AA minimum. #767676 light / #777777 dark.
    static let placeholder = Color(uiColor: UIColor { traits in
        switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
        case (.dark, .high): UIColor(white: 0.62, alpha: 1)
        case (.dark, _): UIColor(white: 0.467, alpha: 1)
        case (_, .high): UIColor(white: 0.36, alpha: 1)
        default: UIColor(white: 0.463, alpha: 1)
        }
    })

    /// Only where a system sheet or destructive swipe needs separation; ordinary sections use none.
    static let divider = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.10, alpha: 1) : UIColor(white: 0.94, alpha: 1)
    })
    #else
    // macOS mirrors iOS exactly: pure white/black ground and ink rather than AppKit's tinted window grays,
    // so the menu bar panel and the window read as the same surface as the phone.
    static let ground = Color(nsColor: gray(light: 1, dark: 0))
    static let ink = Color(nsColor: gray(light: 0, dark: 1))
    static let secondary = Color(nsColor: gray(light: 0.40, dark: 0.60, highContrastLight: 0.30, highContrastDark: 0.75))
    static let placeholder = Color(nsColor: gray(light: 0.463, dark: 0.467, highContrastLight: 0.36, highContrastDark: 0.62))
    static let divider = Color(nsColor: gray(light: 0.94, dark: 0.10))

    private static func gray(light: CGFloat, dark: CGFloat, highContrastLight: CGFloat? = nil, highContrastDark: CGFloat? = nil) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            let white = switch match {
            case .accessibilityHighContrastDarkAqua: highContrastDark ?? dark
            case .darkAqua: dark
            case .accessibilityHighContrastAqua: highContrastLight ?? light
            default: light
            }
            return NSColor(white: white, alpha: 1)
        }
    }
    #endif
}
