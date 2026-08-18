import CoreGraphics

enum SlateSpacing {
    /// Horizontal reading edge for all planner content.
    static let contentEdge: CGFloat = 20
    /// Vertical rhythm between task rows.
    static let row: CGFloat = 16
    /// Vertical rhythm between day sections.
    static let section: CGFloat = 32
    /// Compact spacing inside a heading block.
    static let compact: CGFloat = 8
    /// Minimum interactive target in both dimensions.
    static let minimumTarget: CGFloat = 44
    /// Empty ground below the last section that stays available for the wallpaper long press.
    static let groundHeight: CGFloat = 160
}
