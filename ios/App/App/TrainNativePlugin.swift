import Foundation
import Capacitor
import AVFoundation
import ActivityKit
import WidgetKit

@objc(TrainNativePlugin)
public class TrainNativePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "TrainNativePlugin"
    public let jsName = "TrainNative"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "liveUpdate", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "liveEnd", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "widgetUpdate", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "play", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "say", returnType: CAPPluginReturnPromise)
    ]

    // Sounds and voice play through the app's own audio session: loud, heard with the ringer switch on silent,
    // and other audio (music, podcasts) dips under the cues that matter, then comes back.
    private var players: [String: AVAudioPlayer] = [:]
    private let voice = AVSpeechSynthesizer()
    private var duckUntil = Date.distantPast
    private var releaseWork: DispatchWorkItem?

    private func activate(duck: Bool, for seconds: Double) {
        let s = AVAudioSession.sharedInstance()
        let now = Date()
        if duck { duckUntil = max(duckUntil, now.addingTimeInterval(seconds)) }
        let ducking = duckUntil > now
        try? s.setCategory(.playback, mode: .default, options: ducking ? [.duckOthers] : [.mixWithOthers])
        try? s.setActive(true)
        scheduleRelease(after: seconds + 0.2)
    }

    private func scheduleRelease(after seconds: Double) {
        releaseWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.voice.isSpeaking || self.players.values.contains(where: { $0.isPlaying }) { self.scheduleRelease(after: 0.3); return }
            self.duckUntil = .distantPast
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        releaseWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: w)
    }

    @objc func play(_ call: CAPPluginCall) {
        let name = call.getString("name") ?? ""
        let duck = call.getBool("duck") ?? false
        DispatchQueue.main.async {
            var p = self.players[name]
            if p == nil, let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "public/snd") {
                p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                self.players[name] = p
            }
            guard let player = p else { call.reject("No sound named \(name)"); return }
            self.activate(duck: duck, for: player.duration)
            player.volume = 1
            player.currentTime = 0
            player.play()
            call.resolve()
        }
    }

    @objc func say(_ call: CAPPluginCall) {
        let text = call.getString("text") ?? ""
        DispatchQueue.main.async {
            guard !text.isEmpty else { call.resolve(); return }
            self.activate(duck: true, for: 1.0)
            let u = AVSpeechUtterance(string: text)
            u.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
            u.volume = 1
            u.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
            if self.voice.isSpeaking { self.voice.stopSpeaking(at: .immediate) }
            self.voice.speak(u)
            call.resolve()
        }
    }

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
