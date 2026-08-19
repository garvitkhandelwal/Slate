import SwiftData
import UIKit
import XCTest
@testable import Slate

/// Aggregate timings only; generated data never includes real task text or photographs.
@MainActor
final class PerformanceTests: XCTestCase {
    private let calendarService = TestFixtures.gregorianCalendarService()

    private func seed(repository: SwiftDataPlannerRepository, days: Int, perDay: Int, endingAt end: LocalDay) throws {
        for offset in 0..<days {
            let day = calendarService.addingDays(-offset, to: end)
            for index in 0..<perDay {
                _ = try repository.addTask(text: "task \(index)", on: day, createdAt: Date(timeIntervalSince1970: Double(offset * 10 + index)))
            }
        }
    }

    /// The app-controlled part of cold launch: open the on-disk store, run retention, fetch the displayed week.
    func testStartupPathPerformance() throws {
        measure {
            do {
                let environment = try AppEnvironment.production()
                let model = PlannerViewModel(environment: environment)
                try environment.retentionService.purgeExpiredTasks(now: environment.dateProvider.now())
                model.reloadDisplayedWeek()
            } catch {
                XCTFail("startup path failed: \(error)")
            }
        }
    }

    func testOneWeekFetchPerformance() throws {
        let container = try ModelContainerFactory.inMemory()
        let repository = SwiftDataPlannerRepository(container: container)
        let today = LocalDay(year: 2026, month: 8, day: 19)
        try seed(repository: repository, days: 60, perDay: 8, endingAt: today)
        let week = calendarService.week(containing: today)
        measure {
            _ = try? repository.fetchTasks(in: week)
        }
    }

    func testRetentionOverMultiYearDataPerformance() throws {
        let today = LocalDay(year: 2026, month: 8, day: 19)
        let cutoff = RetentionPolicy().cutoff(today: today, calendarService: calendarService)
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(metrics: [XCTClockMetric()], options: options) {
            // Three years, five tasks a day (5,475 rows), rebuilt outside the measured region.
            let container = try! ModelContainerFactory.inMemory()
            let repository = SwiftDataPlannerRepository(container: container)
            try! seed(repository: repository, days: 3 * 365, perDay: 5, endingAt: today)
            startMeasuring()
            let removed = try! repository.deleteTasks(before: cutoff)
            stopMeasuring()
            XCTAssertEqual(removed, (3 * 365 - 31) * 5)
        }
    }

    func testWallpaperProcessingPerformance() throws {
        let input = try ImageFixtures.jpeg(width: 4096, height: 3072, includeGPS: true)
        measure {
            _ = try? WallpaperImageProcessor.processSynchronously(input)
        }
    }

    func testWallpaperDisplayDecodePerformance() throws {
        let processed = try WallpaperImageProcessor.processSynchronously(try ImageFixtures.jpeg(width: 4096, height: 3072))
        measure {
            _ = UIImage(data: processed)?.preparingForDisplay()
        }
    }
}
