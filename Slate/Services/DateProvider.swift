import Foundation

/// Injectable clock so views and state never call `Date()` directly.
protocol DateProviding: Sendable {
    func now() -> Date
}

struct SystemDateProvider: DateProviding {
    func now() -> Date { Date() }
}
