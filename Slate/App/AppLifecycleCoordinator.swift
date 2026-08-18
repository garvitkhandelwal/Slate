import BackgroundTasks
import Foundation
import OSLog

/// The subset of `BGAppRefreshTask` the coordinator needs, so tests can supply a fake task.
protocol BackgroundRefreshTask: AnyObject {
    var expirationHandler: (() -> Void)? { get set }
    func setTaskCompleted(success: Bool)
}

extension BGAppRefreshTask: BackgroundRefreshTask {}

/// Coordinates scene activation purges and supplementary background refresh.
/// Foreground purge is authoritative; background refresh is best-effort.
@MainActor
final class AppLifecycleCoordinator {
    /// Injectable seams around `BGTaskScheduler`; unit tests never touch the real scheduler.
    struct BackgroundScheduling: Sendable {
        var register: @MainActor @Sendable (_ identifier: String, _ launchHandler: @escaping @MainActor @Sendable (any BackgroundRefreshTask) -> Void) -> Bool
        var submit: @MainActor @Sendable (_ identifier: String, _ earliestBeginDate: Date) throws -> Void

        static let system = BackgroundScheduling(
            register: { identifier, launchHandler in
                BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
                    MainActor.assumeIsolated {
                        guard let refresh = task as? BGAppRefreshTask else {
                            task.setTaskCompleted(success: false)
                            return
                        }
                        launchHandler(refresh)
                    }
                }
            },
            submit: { identifier, earliestBeginDate in
                let request = BGAppRefreshTaskRequest(identifier: identifier)
                request.earliestBeginDate = earliestBeginDate
                try BGTaskScheduler.shared.submit(request)
            }
        )
    }

    static let refreshInterval: TimeInterval = 24 * 60 * 60

    let backgroundIdentifier: String

    private let retentionService: RetentionService
    private let dateProvider: any DateProviding
    private let calendarService: CalendarService
    private let scheduling: BackgroundScheduling
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Slate", category: "retention")
    private var hasRegistered = false

    init(
        retentionService: RetentionService,
        dateProvider: any DateProviding,
        calendarService: CalendarService,
        scheduling: BackgroundScheduling = .system,
        backgroundIdentifier: String = (Bundle.main.bundleIdentifier ?? "com.garvit.Slate") + ".retention"
    ) {
        self.retentionService = retentionService
        self.dateProvider = dateProvider
        self.calendarService = calendarService
        self.scheduling = scheduling
        self.backgroundIdentifier = backgroundIdentifier
    }

    /// Registers the refresh launch handler. Must run during application launch, before any scheduling.
    func registerBackgroundTask() {
        guard !hasRegistered else { return }
        hasRegistered = true
        let registered = scheduling.register(backgroundIdentifier) { [weak self] task in
            self?.handle(task)
        }
        if registered {
            logger.info("background refresh registered")
        } else {
            logger.error("background refresh registration failed")
        }
    }

    /// Purges once per local day on activation, then schedules the next supplementary refresh.
    func handleBecameActive() {
        do {
            try retentionService.purgeIfNeeded(now: dateProvider.now())
            logger.info("purge succeeded")
            scheduleBackgroundRefresh()
        } catch {
            logger.error("purge failed")
        }
    }

    func scheduleBackgroundRefresh() {
        do {
            try scheduling.submit(backgroundIdentifier, dateProvider.now().addingTimeInterval(Self.refreshInterval))
            logger.info("background refresh scheduled")
        } catch {
            logger.error("background refresh scheduling failed")
        }
    }

    private func handle(_ task: any BackgroundRefreshTask) {
        scheduleBackgroundRefresh()
        let work = Task { @MainActor [retentionService, dateProvider, logger] in
            guard !Task.isCancelled else {
                task.setTaskCompleted(success: false)
                return
            }
            do {
                try retentionService.purgeIfNeeded(now: dateProvider.now())
                logger.info("purge succeeded")
                task.setTaskCompleted(success: true)
            } catch {
                logger.error("purge failed")
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = { work.cancel() }
    }
}
