import SwiftUI

/// The three persistent type levels: date, task, and metadata. All are semantic system styles so
/// Dynamic Type scales them; the DESIGN.md point values are visual references only.
enum SlateTypography {
    /// Task content and inline capture.
    static let body = Font.body
    /// Day-view date heading (display role).
    static let heading = Font.title.weight(.semibold)
    /// Weekly day labels; weight is applied per today state.
    static let dayLabel = Font.title2
    /// Week range and weekday wayfinding metadata.
    static let metadata = Font.footnote.monospaced().weight(.medium)
    /// Modest tracking for uppercase metadata.
    static let metadataTracking: CGFloat = 1
}
