import Foundation
import ActivityKit

/// Starts and updates the render Live Activity (15). Progress is estimated from elapsed time;
/// the API reports only "running" / "done".
enum RenderActivities {
    private static var running: [String: (activity: Activity<RenderActivityAttributes>, started: Date, expected: Double)] = [:]

    static func start(id: String, title: String, model: String, kind: GenerationCard.Kind) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, running[id] == nil else { return }
        let expected: Double = kind == .video ? 120 : 30
        let attributes = RenderActivityAttributes(title: title, model: model, kind: kind.rawValue)
        let state = RenderActivityAttributes.ContentState(progress: 0.03, done: false, minutesLeft: Int(expected / 60))
        if let activity = try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil)) {
            running[id] = (activity, .now, expected)
        }
    }

    /// Call on each poll while the job is still rendering.
    static func tick(id: String) {
        guard let entry = running[id] else { return }
        let elapsed = Date.now.timeIntervalSince(entry.started)
        let progress = min(0.95, elapsed / entry.expected)
        let left = Int(max(0, entry.expected - elapsed) / 60)
        let state = RenderActivityAttributes.ContentState(progress: progress, done: false, minutesLeft: left)
        Task { await entry.activity.update(.init(state: state, staleDate: nil)) }
    }

    static func finish(id: String, success: Bool) {
        guard let entry = running.removeValue(forKey: id) else { return }
        let state = RenderActivityAttributes.ContentState(progress: 1, done: success, minutesLeft: 0)
        Task {
            await entry.activity.end(.init(state: state, staleDate: nil), dismissalPolicy: success ? .after(.now.addingTimeInterval(60 * 10)) : .immediate)
        }
    }
}
