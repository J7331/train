import ActivityKit
import Foundation

struct TrainActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var startedAt: Date
        var paused: Bool
        var elapsed: Double
        var setsDone: Int
        var setsTotal: Int
        var restStart: Date?
        var restEnd: Date?
        var restLabel: String
        var next: String
        var nextDetail: String
    }
    var name: String
}

let trainGroup = "group.com.j7331.train"

struct WidgetSummary: Codable {
    var goal: Int = 4
    var weekSun: Bool = false
    var recent: [Double] = []
    var next: String = ""
    var nextDetail: String = ""
    var lastName: String = ""
    var lastAt: Double = 0
    var lastSets: Int = 0
    var lastMin: Int = 0
    var active: String = ""
    var activeStart: Double = 0

    static func load() -> WidgetSummary? {
        guard let s = UserDefaults(suiteName: trainGroup)?.string(forKey: "summary"), let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: d)
    }

    func weekStart(for now: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = weekSun ? 1 : 2
        return cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }

    func doneThisWeek(at now: Date) -> Int {
        let start = weekStart(for: now).timeIntervalSince1970 * 1000
        return recent.filter { $0 >= start }.count
    }
}
