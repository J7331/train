import Foundation
import Capacitor
import ActivityKit
import WidgetKit

@objc(TrainNativePlugin)
public class TrainNativePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "TrainNativePlugin"
    public let jsName = "TrainNative"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "liveUpdate", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "liveEnd", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "widgetUpdate", returnType: CAPPluginReturnPromise)
    ]

    private func date(_ call: CAPPluginCall, _ key: String) -> Date? {
        let ms = call.getDouble(key) ?? 0
        return ms > 0 ? Date(timeIntervalSince1970: ms / 1000) : nil
    }

    @objc func liveUpdate(_ call: CAPPluginCall) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { call.resolve(["enabled": false]); return }
        let restEnd = date(call, "restEnd")
        let state = TrainActivityAttributes.ContentState(
            title: call.getString("title") ?? "Workout",
            startedAt: date(call, "startedAt") ?? Date(),
            paused: call.getBool("paused") ?? false,
            elapsed: call.getDouble("elapsed") ?? 0,
            setsDone: call.getInt("setsDone") ?? 0,
            setsTotal: call.getInt("setsTotal") ?? 0,
            restStart: date(call, "restStart"),
            restEnd: restEnd,
            restLabel: call.getString("restLabel") ?? "Rest",
            next: call.getString("next") ?? "",
            nextDetail: call.getString("nextDetail") ?? ""
        )
        let content = ActivityContent(state: state, staleDate: restEnd)
        Task {
            if let activity = Activity<TrainActivityAttributes>.activities.first {
                await activity.update(content)
            } else {
                _ = try? Activity.request(attributes: TrainActivityAttributes(name: state.title), content: content, pushType: nil)
            }
            call.resolve(["enabled": true])
        }
    }

    @objc func liveEnd(_ call: CAPPluginCall) {
        Task {
            for activity in Activity<TrainActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            call.resolve()
        }
    }

    @objc func widgetUpdate(_ call: CAPPluginCall) {
        if let json = call.getString("json") {
            UserDefaults(suiteName: trainGroup)?.set(json, forKey: "summary")
            WidgetCenter.shared.reloadAllTimelines()
        }
        call.resolve()
    }
}
