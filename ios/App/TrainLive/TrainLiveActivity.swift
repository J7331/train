import ActivityKit
import SwiftUI
import WidgetKit

private let accent = Color(red: 0.36, green: 0.49, blue: 0.98)
private let card = Color(red: 0.086, green: 0.098, blue: 0.118)
private let muted = Color(white: 0.6)

private extension TrainActivityAttributes.ContentState {
    func resting(_ stale: Bool) -> Bool {
        guard let end = restEnd, restStart != nil else { return false }
        return !stale && end > Date()
    }
    var restRange: ClosedRange<Date> {
        let s = restStart ?? Date(), e = max(restEnd ?? s, s.addingTimeInterval(1))
        return s...e
    }
    var setsText: String { "\(setsDone)/\(setsTotal) sets" }
}

private struct WorkoutClock: View {
    let st: TrainActivityAttributes.ContentState
    var body: some View {
        if st.paused {
            let t = Int(st.elapsed)
            Text(t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60))
        } else {
            Text(st.startedAt, style: .timer)
        }
    }
}

private struct RestTimer: View {
    let st: TrainActivityAttributes.ContentState
    var body: some View {
        Text(timerInterval: st.restRange, countsDown: true)
    }
}

struct TrainLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainActivityAttributes.self) { context in
            let st = context.state
            let resting = st.resting(context.isStale)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(st.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if !st.next.isEmpty {
                            Text(st.next)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                            Text(st.nextDetail)
                                .font(.system(size: 13))
                                .foregroundStyle(muted)
                                .lineLimit(1)
                        } else {
                            Text(st.setsText).font(.system(size: 13)).foregroundStyle(muted)
                        }
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 2) {
                        if resting {
                            Text(st.restLabel.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(accent)
                            RestTimer(st: st)
                                .font(.system(size: 36, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120, alignment: .trailing)
                        } else {
                            Text(context.isStale && st.restEnd != nil ? "GO" : st.setsText.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(context.isStale && st.restEnd != nil ? accent : muted)
                            WorkoutClock(st: st)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 130, alignment: .trailing)
                        }
                    }
                }
                if resting {
                    ProgressView(timerInterval: st.restRange, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                        .tint(accent)
                } else {
                    ProgressView(value: Double(st.setsDone), total: Double(max(st.setsTotal, 1)))
                        .tint(accent)
                }
            }
            .padding(16)
            .activityBackgroundTint(card)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let st = context.state
            let resting = st.resting(context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(st.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text(st.setsText).font(.system(size: 12)).foregroundStyle(muted)
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(resting ? st.restLabel.uppercased() : "TIME").font(.system(size: 11, weight: .bold)).foregroundStyle(resting ? accent : muted)
                        Group {
                            if resting { RestTimer(st: st) } else { WorkoutClock(st: st) }
                        }
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                    }
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !st.next.isEmpty {
                            HStack {
                                Text(st.next).font(.system(size: 14, weight: .medium)).lineLimit(1)
                                Spacer()
                                Text(st.nextDetail).font(.system(size: 13)).foregroundStyle(muted).lineLimit(1)
                            }
                        }
                        if resting {
                            ProgressView(timerInterval: st.restRange, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                                .tint(accent)
                        }
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: resting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(accent)
            } compactTrailing: {
                Group {
                    if resting { RestTimer(st: st) } else { WorkoutClock(st: st) }
                }
                .monospacedDigit()
                .foregroundStyle(resting ? accent : .white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 52)
            } minimal: {
                if resting {
                    RestTimer(st: st).monospacedDigit().foregroundStyle(accent).frame(maxWidth: 40)
                } else {
                    Image(systemName: "dumbbell.fill").foregroundStyle(accent)
                }
            }
            .keylineTint(accent)
        }
    }
}
