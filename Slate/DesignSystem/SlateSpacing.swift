import CoreGraphics

enum SlateSpacing {
    /// Horizontal reading edge for all planner content.
    static let contentEdge: CGFloat = 20
    /// The reading edge as a list row inset. AppKit's table view already pads every row by 8 points a side.
    #if os(macOS)
    static let listRowEdge: CGFloat = contentEdge - 8
    #else
    static let listRowEdge: CGFloat = contentEdge
    #endif
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
