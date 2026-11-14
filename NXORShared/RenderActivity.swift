import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Live Activity for a render in progress (Lock Screen + Dynamic Island). Shared by the app and the widget extension.
struct RenderActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var progress: Double
        var done: Bool
        var minutesLeft: Int
    }

    var title: String
    var model: String
    var kind: String
}
#endif
