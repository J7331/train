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
