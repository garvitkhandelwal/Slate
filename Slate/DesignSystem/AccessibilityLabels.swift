import Foundation

/// Spoken and visible copy. Dates come from localized format styles; nothing here hard-codes month or weekday names.
enum AccessibilityLabels {
    // MARK: Product copy

    static var add: String { String(localized: "add", defaultValue: "+ add") }
    static var delete: String { String(localized: "delete", defaultValue: "Delete") }
    static var complete: String { String(localized: "complete", defaultValue: "Complete") }
    static var markIncomplete: String { String(localized: "mark_incomplete", defaultValue: "Mark incomplete") }
    static var edit: String { String(localized: "edit", defaultValue: "Edit") }
    static var completed: String { String(localized: "completed", defaultValue: "Completed") }
    static var notCompleted: String { String(localized: "not_completed", defaultValue: "Not completed") }
    static var editHint: String { String(localized: "edit_hint", defaultValue: "Double-tap to edit") }
    static var wallpaperOptions: String { String(localized: "wallpaper_options", defaultValue: "Wallpaper options") }
    static var choosePhoto: String { String(localized: "choose_photo", defaultValue: "Choose photo…") }
    static var removeWallpaper: String { String(localized: "remove_wallpaper", defaultValue: "Remove wallpaper") }
    static var today: String { String(localized: "today", defaultValue: "Today") }
    static var thisWeek: String { String(localized: "this_week", defaultValue: "this week") }
    static var weekRange: String { String(localized: "week_range", defaultValue: "Week range") }
    static var week: String { String(localized: "week", defaultValue: "Week") }
    static var newTask: String { String(localized: "new_task", defaultValue: "New task") }
    static var ok: String { String(localized: "ok", defaultValue: "OK") }
    static var expanded: String { String(localized: "expanded", defaultValue: "Expanded") }
    static var collapsed: String { String(localized: "collapsed", defaultValue: "Collapsed") }
    static var photo: String { String(localized: "photo", defaultValue: "Photo") }
    static var light: String { String(localized: "light", defaultValue: "Light") }
    static var dark: String { String(localized: "dark", defaultValue: "Dark") }
    static var switchToLight: String { String(localized: "switch_to_light", defaultValue: "Switch to light appearance") }
    static var switchToDark: String { String(localized: "switch_to_dark", defaultValue: "Switch to dark appearance") }
    static var wallpaperSwitchHint: String { String(localized: "wallpaper_switch_hint", defaultValue: "Shows the next wallpaper") }

    // MARK: macOS

    static var back: String { String(localized: "back", defaultValue: "Back to week") }
    static var openWindow: String { String(localized: "open_window", defaultValue: "Window") }
    static var openWindowHint: String { String(localized: "open_window_hint", defaultValue: "Opens Slate in its own window") }
    static var quit: String { String(localized: "quit", defaultValue: "Quit") }
    static var quitSlate: String { String(localized: "quit_slate", defaultValue: "Quit Slate") }

    static func wallpaperPosition(index: Int, count: Int) -> String {
        String(localized: "wallpaper_position", defaultValue: "Wallpaper \(index) of \(count)")
    }

    // MARK: Composed date labels

    /// Full localized date, followed by `Today` when applicable, e.g. `Wednesday, August 19, 2026, Today`.
    static func day(_ day: LocalDay, calendarService: CalendarService, isToday: Bool) -> String {
        let date = calendarService.fullDateText(day)
        return isToday ? date + ", " + today : date
    }

    /// Both range dates, followed by `this week` for the current real-world week.
    static func weekRange(_ week: WeekInterval, calendarService: CalendarService, isCurrentWeek: Bool) -> String {
        let range = calendarService.weekRangeAccessibilityText(week)
        return isCurrentWeek ? range + ", " + thisWeek : range
    }

    static func taskValue(isCompleted: Bool) -> String {
        isCompleted ? completed : notCompleted
    }

    static func toggleActionName(isCompleted: Bool) -> String {
        isCompleted ? markIncomplete : complete
    }
}
