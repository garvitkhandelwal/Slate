import SwiftUI
import UIKit

/// One hue at different luminance levels. Ground and ink are the system roles; the intermediate grays follow
/// the DESIGN.md tonal ramp, invert exactly between appearances, and every text role keeps at least
/// WCAG AA (4.5:1) contrast against the ground so completed tasks and `+ add` stay legible.
enum SlateColors {
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
}
