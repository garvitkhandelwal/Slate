import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import Slate

/// Generated in memory so no photographs are committed to the repository.
enum ImageFixtures {
    enum Pattern { case black, white, checkerboard, gradient }

    struct FixtureError: Error {}

    static func cgImage(width: Int, height: Int, pattern: Pattern = .gradient) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FixtureError() }

        switch pattern {
        case .black:
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        case .white:
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        case .checkerboard:
            let cell = max(1, min(width, height) / 16)
            for row in stride(from: 0, to: height, by: cell) {
                for column in stride(from: 0, to: width, by: cell) {
                    let isDark = ((row / cell) + (column / cell)) % 2 == 0
                    context.setFillColor(isDark ? CGColor(red: 0, green: 0, blue: 0, alpha: 1) : CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                    context.fill(CGRect(x: column, y: row, width: cell, height: cell))
                }
            }
        case .gradient:
            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [CGColor(red: 0.95, green: 0.4, blue: 0.2, alpha: 1), CGColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1)] as CFArray,
                locations: [0, 1]
            )!
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        }
        guard let image = context.makeImage() else { throw FixtureError() }
        return image
    }

    static func png(width: Int, height: Int, pattern: Pattern = .gradient) throws -> Data {
        try encode(try cgImage(width: width, height: height, pattern: pattern), type: .png, properties: [:])
    }

    /// JPEG with optional GPS metadata and a non-default EXIF orientation.
    static func jpeg(
        width: Int,
        height: Int,
        pattern: Pattern = .gradient,
        includeGPS: Bool = false,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> Data {
        var properties: [CFString: Any] = [kCGImagePropertyOrientation: orientation.rawValue]
        if includeGPS {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 37.3349,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 122.0090,
                kCGImagePropertyGPSLongitudeRef: "W",
            ] as [CFString: Any]
            properties[kCGImagePropertyTIFFDictionary] = [
                kCGImagePropertyTIFFMake: "Fixture Camera",
                kCGImagePropertyTIFFModel: "Fixture Model",
                kCGImagePropertyTIFFOrientation: orientation.rawValue,
            ] as [CFString: Any]
        }
        return try encode(try cgImage(width: width, height: height, pattern: pattern), type: .jpeg, properties: properties)
    }

    private static func encode(_ image: CGImage, type: UTType, properties: [CFString: Any]) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            throw FixtureError()
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw FixtureError() }
        return output as Data
    }
}

enum TestFixtures {
    /// Wednesday, 19 August 2026 at 10:00 UTC.
    static let august19 = Calendar.utcGregorian.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 10))!

    /// Saturday, 18 July 2026 at 09:00 UTC.
    static let july18 = Calendar.utcGregorian.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 9))!

    static func gregorianCalendarService(
        firstWeekday: Int = 2,
        timeZone: String = "UTC",
        locale: String = "en_US"
    ) -> CalendarService {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.firstWeekday = firstWeekday
        return CalendarService(calendar: calendar, locale: Locale(identifier: locale))
    }

    static func mondayFirstWeek(start: LocalDay) -> WeekInterval {
        gregorianCalendarService(firstWeekday: 2).week(containing: start)
    }

    static func isolatedDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "SlateTests." + name + "." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

extension TaskSnapshot {
    static func fixture(
        id: UUID = UUID(),
        text: String = "Task",
        day: LocalDay = LocalDay(year: 2026, month: 8, day: 19),
        isCompleted: Bool = false,
        createdAt: Date = TestFixtures.august19
    ) -> TaskSnapshot {
        TaskSnapshot(id: id, text: text, day: day, isCompleted: isCompleted, createdAt: createdAt)
    }
}
