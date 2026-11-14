import WidgetKit
import SwiftUI
import ActivityKit

@main
struct NXORWidgetBundle: WidgetBundle {
    var body: some Widget {
        NXORQuickWidget()
        RenderLiveActivity()
    }
}

// MARK: - Colors (fonts and tokens of the app aren't available in the extension)

private enum W {
    static let bg = Color(red: 0.031, green: 0.035, blue: 0.039)
    static let panel = Color(red: 0.043, green: 0.051, blue: 0.063)
    static let ink = Color(red: 0.933, green: 0.945, blue: 0.961)
    static let ink3 = Color(red: 0.541, green: 0.576, blue: 0.627)
    static let cyan = Color(red: 0.071, green: 0.878, blue: 1)
    static let metal = LinearGradient(colors: [Color(red: 0.99, green: 1, blue: 1), Color(red: 0.89, green: 0.91, blue: 0.94), Color(red: 0.78, green: 0.81, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let spectrum = LinearGradient(colors: [Color(red: 0.18, green: 0.36, blue: 1), Color(red: 0.07, green: 0.88, blue: 1), Color(red: 0.78, green: 0.42, blue: 0.78), Color(red: 1, green: 0.24, blue: 0.82)], startPoint: .leading, endPoint: .trailing)
}

private struct Slant: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.height * 0.2867
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + s, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - s, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - R14 home widget: + New / Ask

struct QuickEntry: TimelineEntry {
    let date: Date
}

struct QuickProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickEntry { QuickEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (QuickEntry) -> Void) { completion(QuickEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickEntry>) -> Void) {
        completion(Timeline(entries: [QuickEntry(date: .now)], policy: .never))
    }
}

struct NXORQuickWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NXORQuick", provider: QuickProvider()) { _ in
            QuickWidgetView()
                .containerBackground(W.bg, for: .widget)
        }
        .configurationDisplayName("NXOR")
        .description("Start a picture, a video or a question in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NXOR")
                .font(.system(size: 15, weight: .black).italic())
                .foregroundStyle(W.ink)
            if family == .systemSmall {
                Spacer()
                Text("ASK, THEN RENDER.")
                    .font(.system(size: 13, weight: .black).italic())
                    .foregroundStyle(W.cyan)
                Text("+ NEW")
                    .font(.system(size: 14, weight: .black).italic())
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Slant().fill(W.metal))
            } else {
                Spacer()
                HStack(spacing: 8) {
                    Link(destination: URL(string: "nxor://create?mode=image")!) {
                        Text("+ NEW")
                            .font(.system(size: 15, weight: .black).italic())
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Slant().fill(W.metal))
                    }
                    Link(destination: URL(string: "nxor://ask")!) {
                        Text("ASK")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(W.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Slant().fill(Color.white.opacity(0.08)))
                    }
                }
            }
        }
        .widgetURL(URL(string: "nxor://create?mode=image"))
    }
}

// MARK: - 15 Live Activity: render progress on the Lock Screen and in the Dynamic Island

struct RenderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RenderActivityAttributes.self) { context in
            LockScreenRenderView(context: context)
                .activityBackgroundTint(W.panel)
                .activitySystemActionForegroundColor(W.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("NXOR", systemImage: context.attributes.kind == "video" ? "play.fill" : "photo")
                        .font(.system(size: 13, weight: .black).italic())
                        .foregroundStyle(W.ink)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.done ? "Ready" : "\(Int(context.state.progress * 100))%")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(context.state.done ? W.cyan : W.ink)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.title).font(.system(size: 13)).foregroundStyle(W.ink).lineLimit(1)
                        ProgressBar(progress: context.state.done ? 1 : context.state.progress)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.kind == "video" ? "play.fill" : "photo").foregroundStyle(W.cyan)
            } compactTrailing: {
                Text(context.state.done ? "✓" : "\(Int(context.state.progress * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(W.ink)
            } minimal: {
                Image(systemName: context.state.done ? "checkmark" : "sparkle").foregroundStyle(W.cyan)
            }
            .widgetURL(URL(string: "nxor://studio"))
        }
    }
}

struct LockScreenRenderView: View {
    let context: ActivityViewContext<RenderActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(red: 0.11, green: 0.14, blue: 0.2), W.bg], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: context.attributes.kind == "video" ? "play.fill" : "photo").foregroundStyle(W.ink))
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.done
                     ? "NXOR · Your \(context.attributes.kind) is ready"
                     : "Rendering \(context.attributes.kind) · \(Int(context.state.progress * 100))%")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(W.ink)
                Text(context.state.done
                     ? "\(context.attributes.title) · tap to open"
                     : "\(context.attributes.model) · about \(max(1, context.state.minutesLeft)) min left")
                    .font(.system(size: 12))
                    .foregroundStyle(W.ink3)
                    .lineLimit(1)
                if !context.state.done { ProgressBar(progress: context.state.progress) }
            }
        }
        .padding(14)
    }
}

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.14))
                Rectangle().fill(W.spectrum).frame(width: geo.size.width * min(max(progress, 0.03), 1))
            }
        }
        .frame(height: 4)
    }
}
