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

// The shared container the app and its widgets both read. Sideloading tools often rename the
// app group, so use whichever group this copy was actually signed with.
let trainGroup: String = {
    let fallback = "group.com.j7331.train"
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let a = data.range(of: Data("<?xml".utf8)),
          let b = data.range(of: Data("</plist>".utf8), in: a.lowerBound..<data.endIndex),
          let plist = try? PropertyListSerialization.propertyList(from: data.subdata(in: a.lowerBound..<b.upperBound), format: nil) as? [String: Any],
          let ent = plist["Entitlements"] as? [String: Any],
          let groups = ent["com.apple.security.application-groups"] as? [String], !groups.isEmpty
    else { return fallback }
    return groups.first(where: { $0.lowercased().contains("train") }) ?? groups[0]
}()

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
