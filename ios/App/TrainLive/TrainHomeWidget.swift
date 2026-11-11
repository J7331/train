import SwiftUI
import WidgetKit
import UIKit

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

private func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
}

private let bg = dyn(0xFFFFFF, 0x16191E)
private let ink = dyn(0x15171C, 0xECEEF2)
private let soft = dyn(0x646B78, 0x8C94A2)
private let blue = dyn(0x2446D8, 0x5C7CFA)
private let track = dyn(0xE9EBEF, 0x2A2F37)

struct TrainEntry: TimelineEntry {
    let date: Date
    let s: WidgetSummary
}

private extension WidgetSummary {
    static var sample: WidgetSummary {
        var s = WidgetSummary()
        s.goal = 4; s.next = "Lower S"; s.nextDetail = "5 exercises · 14 sets"
        s.lastName = "Upper S"; s.lastAt = Date().addingTimeInterval(-86400).timeIntervalSince1970 * 1000; s.lastSets = 19; s.lastMin = 62
        s.recent = [Date().timeIntervalSince1970 * 1000]
        return s
    }
}

struct TrainProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainEntry { TrainEntry(date: Date(), s: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (TrainEntry) -> Void) {
        completion(TrainEntry(date: Date(), s: WidgetSummary.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainEntry>) -> Void) {
        let s = WidgetSummary.load() ?? WidgetSummary()
        let now = Date(), cal = Calendar.current
        let nextWeek = cal.date(byAdding: .day, value: 7, to: s.weekStart(for: now)) ?? now.addingTimeInterval(7 * 86400)
        let midnight = cal.startOfDay(for: now).addingTimeInterval(86400)
        var entries = [TrainEntry(date: now, s: s)]
        if midnight < nextWeek { entries.append(TrainEntry(date: midnight, s: s)) }
        entries.append(TrainEntry(date: nextWeek, s: s))
        completion(Timeline(entries: entries, policy: .after(nextWeek)))
    }
}

private struct GoalBars: View {
    let done: Int, goal: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(goal, done, 1), id: \.self) { i in
                Capsule().fill(i < done ? blue : track).frame(height: 6)
            }
        }
    }
}

private func dayText(_ ms: Double, now: Date) -> String {
    let d = Date(timeIntervalSince1970: ms / 1000), cal = Calendar.current
    if cal.isDateInToday(d) { return "Today" }
    if cal.isDateInYesterday(d) { return "Yesterday" }
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: now)).day ?? 0
    let f = DateFormatter()
    f.dateFormat = days < 7 ? "EEEE" : "MMM d"
    return f.string(from: d)
}

private extension View {
    @ViewBuilder func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(bg, for: .widget)
        } else {
            self.padding(16).background(bg)
        }
    }
}

private struct WeekHeader: View {
    let done: Int, goal: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("THIS WEEK").font(.system(size: 11, weight: .bold)).foregroundStyle(soft)
                Spacer(minLength: 4)
                Text("\(done)/\(goal)").font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(ink)
            }
            GoalBars(done: done, goal: goal)
        }
    }
}

private struct UpNext: View {
    let s: WidgetSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !s.active.isEmpty {
                Text("IN PROGRESS").font(.system(size: 11, weight: .bold)).foregroundStyle(blue)
                Text(s.active).font(.system(size: 18, weight: .semibold)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(Date(timeIntervalSince1970: s.activeStart / 1000), style: .timer)
                    .font(.system(size: 13, weight: .medium)).monospacedDigit().foregroundStyle(soft)
            } else if !s.next.isEmpty {
                Text("UP NEXT").font(.system(size: 11, weight: .bold)).foregroundStyle(blue)
                Text(s.next).font(.system(size: 20, weight: .semibold)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(s.nextDetail).font(.system(size: 12)).foregroundStyle(soft).lineLimit(1).minimumScaleFactor(0.8)
            } else {
                Text("Train").font(.system(size: 20, weight: .semibold)).foregroundStyle(ink)
            }
        }
    }
}

private struct LastWorkout: View {
    let s: WidgetSummary, now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("LAST").font(.system(size: 11, weight: .bold)).foregroundStyle(soft)
            if s.lastAt > 0 {
                Text(s.lastName).font(.system(size: 17, weight: .semibold)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(dayText(s.lastAt, now: now)).font(.system(size: 13, weight: .medium)).foregroundStyle(ink.opacity(0.85))
                Text("\(s.lastSets) sets" + (s.lastMin > 0 ? " · \(s.lastMin) min" : ""))
                    .font(.system(size: 12)).monospacedDigit().foregroundStyle(soft).lineLimit(1)
            } else {
                Text("No workouts yet").font(.system(size: 13)).foregroundStyle(soft)
            }
        }
    }
}

struct TrainHomeView: View {
    @Environment(\.widgetFamily) var family
    let entry: TrainEntry

    var body: some View {
        let s = entry.s, done = s.doneThisWeek(at: entry.date)
        Group {
            if family == .systemMedium {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        WeekHeader(done: done, goal: s.goal)
                        Spacer(minLength: 8)
                        UpNext(s: s)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(track).frame(width: 1)
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 0)
                        LastWorkout(s: s, now: entry.date)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    WeekHeader(done: done, goal: s.goal)
                    Spacer(minLength: 8)
                    UpNext(s: s)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetBackground()
    }
}

struct TrainHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TrainHome", provider: TrainProvider()) { entry in
            TrainHomeView(entry: entry)
        }
        .configurationDisplayName("Train")
        .description("Your week, what’s next, and your last workout.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
