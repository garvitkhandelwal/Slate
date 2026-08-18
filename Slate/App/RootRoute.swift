import Foundation

/// The only navigation destination: one focused day pushed onto the weekly root.
enum RootRoute: Hashable {
    case day(LocalDay)
}
