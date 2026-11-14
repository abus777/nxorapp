import SwiftUI
import UIKit

// MARK: - Shape

/// NXOR parallelogram: skewX(-16°) with 6 pt rounded corners. Text inside stays upright.
struct Parallelogram: InsettableShape {
    var slant: CGFloat = 0.2867 // tan(16°)
    var radius: CGFloat = 6
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard r.width > 0, r.height > 0 else { return Path() }
        let s = min(r.height * slant, r.width / 3)
        let pts = [
            CGPoint(x: r.minX + s, y: r.minY),
            CGPoint(x: r.maxX, y: r.minY),
            CGPoint(x: r.maxX - s, y: r.maxY),
            CGPoint(x: r.minX, y: r.maxY),
        ]
        var p = Path()
        p.move(to: CGPoint(x: (pts[3].x + pts[0].x) / 2, y: (pts[3].y + pts[0].y) / 2))
        for i in 0..<4 {
            p.addArc(tangent1End: pts[i], tangent2End: pts[(i + 1) % 4], radius: radius)
        }
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> Parallelogram {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

// MARK: - Fills

enum SkewStyle {
    case metal   // the one primary action
    case dark    // secondary (M) with soft glow
    case glass   // soft fill, no frame (chips, header links)
    case danger
}

enum SkewSize {
    case l, m, s, field

    var height: CGFloat {
        switch self {
        case .l: return 52
        case .m: return 44
        case .s: return 32
        case .field: return 40
        }
    }
}

struct SkewFill: View {
    let style: SkewStyle
    var selected = false

    var body: some View {
        let shape = Parallelogram()
        switch style {
        case .metal:
            shape.fill(NX.G.silver)
                .shadow(color: NX.C.blue.opacity(0.28), radius: 14, y: 8)
                .shadow(color: NX.C.violet.opacity(0.18), radius: 11)
                .overlay(shape.strokeBorder(NX.C.tint.opacity(0.35), lineWidth: 1))
        case .dark:
            shape.fill(LinearGradient(colors: [Color(hex: 0x181C22), Color(hex: 0x0F1216)], startPoint: .top, endPoint: .bottom))
                .overlay(shape.strokeBorder(NX.C.tint.opacity(0.08), lineWidth: 1))
                .shadow(color: NX.C.blue.opacity(0.14), radius: 9, y: 6)
        case .glass:
            shape.fill(NX.C.tint.opacity(selected ? 0.16 : 0.06))
                .shadow(color: selected ? Color(hex: 0xE2E9F0).opacity(0.14) : .clear, radius: 8)
        case .danger:
            shape.fill(NX.C.danger.opacity(0.12))
                .overlay(shape.strokeBorder(NX.C.danger.opacity(0.4), lineWidth: 1))
        }
    }
}

// MARK: - Buttons

/// The parallelogram button family: L 52 (metal, one per screen), M 44 (dark), S 32 (glass links and tags).
struct SkewButton: View {
    let title: String
    var icon: String? = nil
    var size: SkewSize = .m
    var style: SkewStyle = .dark
    var fullWidth = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.system(size: size == .s ? 11 : 13, weight: .semibold))
                }
                Text(title.uppercased())
                    .font(style == .metal ? NX.F.display(size == .l ? 15 : 13) : NX.F.mono(size == .s ? 11 : 10))
                    .tracking(style == .metal ? 0.3 : 1.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, size == .s ? 14 : 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .background(SkewFill(style: style))
            .contentShape(Rectangle().inset(by: size == .s ? -6 : 0))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private var foreground: Color {
        switch style {
        case .metal: return NX.C.btnInk
        case .dark: return NX.C.inkSoft
        case .glass: return NX.C.ink2
        case .danger: return NX.C.danger
        }
    }
}

/// Small metal "Done" and glass "✕ Cancel" header buttons used on every sheet.
struct SheetCancelButton: View {
    var title = "Cancel"
    let action: () -> Void

    var body: some View {
        SkewButton(title: title, icon: "xmark", size: .s, style: .glass, action: action)
    }
}

struct SheetDoneButton: View {
    var title = "Done"
    var enabled = true
    let action: () -> Void

    var body: some View {
        SkewButton(title: title, size: .s, style: .metal, enabled: enabled, action: action)
    }
}

/// Square icon button tilted like the rest (≡, ⋯, ↑ Import, ☑ Select).
struct SkewIconButton: View {
    let systemName: String
    var label: String
    var size: CGFloat = 44
    var metal = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { SkewIconFace(systemName: systemName, size: size, metal: metal) }
            .buttonStyle(PressStyle())
            .accessibilityLabel(label)
    }
}

struct SkewIconFace: View {
    let systemName: String
    var size: CGFloat = 44
    var metal = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(metal ? NX.C.btnInk : NX.C.inkSoft)
            .frame(width: size, height: size)
            .background(SkewFill(style: metal ? .metal : .glass))
            .contentShape(Rectangle())
    }
}

/// Filter / option tag (S 32, 44 pt hit area).
struct SkewTag: View {
    let title: String
    var icon: String? = nil
    var selected = false
    var trailingChevron = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { SkewTagFace(title: title, icon: icon, selected: selected, trailingChevron: trailingChevron) }
            .buttonStyle(PressStyle())
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SkewTagFace: View {
    let title: String
    var icon: String? = nil
    var selected = false
    var trailingChevron = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
            Text(title.uppercased()).font(NX.F.mono(10)).tracking(1.4).lineLimit(1)
            if trailingChevron { Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
        }
        .foregroundStyle(selected ? NX.C.ink : NX.C.ink2)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(SkewFill(style: .glass, selected: selected))
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .fixedSize()
    }
}

/// Segmented switch: selected segment is platinum.
struct SkewSegment<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let on = item.0 == selection
                Button {
                    withAnimation(NX.Motion.hover) { selection = item.0 }
                } label: {
                    Text(item.1.uppercased())
                        .font(NX.F.mono(11))
                        .tracking(1.8)
                        .foregroundStyle(on ? NX.C.btnInk : NX.C.ink3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(on ? AnyView(Parallelogram().fill(NX.G.silver)) : AnyView(SkewFill(style: .glass)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Selectable card tilted -8° (tariffs, credit packs, project type).
struct SkewCard<Content: View>: View {
    var selected = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = Parallelogram(slant: 0.07, radius: 8)
                if selected {
                    shape.fill(NX.C.tint.opacity(0.07))
                        .overlay(shape.strokeBorder(NX.C.accent.opacity(0.85), lineWidth: 1.5))
                        .shadow(color: NX.C.accent.opacity(0.22), radius: 12)
                } else {
                    shape.fill(NX.C.tint.opacity(0.035))
                }
            }
    }
}

// MARK: - Glass

struct GlassBackground: View {
    var opacity: Double = 0.72

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            NX.C.surface.opacity(opacity)
        }
    }
}

extension View {
    /// Frosted layer for sheets, menus, the drawer and the composer.
    func nxSheetBackground() -> some View {
        self.presentationBackground {
            GlassBackground(opacity: 0.78)
        }
    }
}

// MARK: - Aura (spectrum glow under the composer)

struct Aura: View {
    var active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let period = active ? 3.0 : 7.0
            let shift = sin(t / period * .pi * 2)
            let breath = (sin(t / (active ? 2.2 : 4) * .pi * 2) + 1) / 2
            let colors = [NX.C.blue, NX.C.accent, NX.C.orchid, NX.C.pink, NX.C.blue]
            ZStack(alignment: .bottom) {
                LinearGradient(colors: colors, startPoint: UnitPoint(x: -0.6 + shift * 0.6, y: 0.5), endPoint: UnitPoint(x: 1.6 + shift * 0.6, y: 0.5))
                    .frame(height: active ? 96 : 70)
                    .padding(.horizontal, active ? -16 : 28)
                    .blur(radius: 34)
                    .opacity((active ? 0.42 : 0.32) + breath * 0.16)
                    .scaleEffect(x: 1 + breath * 0.06, y: 1)
                    .offset(y: active ? 34 : 26)
                LinearGradient(colors: [Color.clear] + Array(colors.dropLast()) + [Color.clear], startPoint: UnitPoint(x: -0.3 + shift * 0.3, y: 0.5), endPoint: UnitPoint(x: 1.3 + shift * 0.3, y: 0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 14)
                    .opacity(0.7)
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Glass composer container with the NXOR spectrum breathing under it.
    func auraComposer(active: Bool, highlighted: Bool = false) -> some View {
        self
            .padding(12)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    NX.C.surface.opacity(0.86)
                }
            )
            .overlay(Rectangle().strokeBorder(highlighted ? NX.C.accent.opacity(0.6) : NX.C.tint.opacity(active ? 0.14 : 0.10), lineWidth: 1))
            .shadow(color: highlighted ? NX.C.accent.opacity(0.18) : .clear, radius: 10)
            .background(alignment: .bottom) { Aura(active: active || highlighted) }
    }
}

/// Faint background shimmer for hero/empty screens.
struct BackgroundAura: View {
    var body: some View {
        ZStack {
            NX.C.bg
            RadialGradient(colors: [NX.C.blue.opacity(0.18), NX.C.accent.opacity(0.05), .clear], center: UnitPoint(x: 0.2, y: 0.35), startRadius: 10, endRadius: 360)
            RadialGradient(colors: [NX.C.pink.opacity(0.08), .clear], center: UnitPoint(x: 0.9, y: 0.75), startRadius: 10, endRadius: 300)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Create mode key (IMG / VID / AUD / CHAT)

enum CreateMode: String, CaseIterable, Identifiable, Hashable {
    case chat, image, video, audio

    var id: String { rawValue }

    var short: String {
        switch self {
        case .chat: return "CHAT"
        case .image: return "IMG"
        case .video: return "VID"
        case .audio: return "AUD"
        }
    }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .image: return "Image"
        case .video: return "Video"
        case .audio: return "Audio"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left"
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        }
    }

    var placeholder: String {
        switch self {
        case .chat: return "Ask about this project…"
        case .image: return "Describe the picture"
        case .video: return "Describe the video"
        case .audio: return "What should the voice say?"
        }
    }

    var generationKind: GenerationCard.Kind? {
        switch self {
        case .image: return .image
        case .video: return .video
        default: return nil
        }
    }
}

/// Works like the keyboard's language key: tap = next mode, hold = list of modes.
struct ModeKey: View {
    @Binding var mode: CreateMode
    var modes: [CreateMode] = [.image, .video, .audio]

    var body: some View {
        Menu {
            ForEach(modes) { m in
                Button { mode = m } label: {
                    if m == mode { Label(m.title, systemImage: "checkmark") } else { Label(m.title, systemImage: m.icon) }
                }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: mode.icon).font(.system(size: 12, weight: .medium))
                Text(mode.short).font(NX.F.mono(8)).tracking(1.2)
                Rectangle().fill(NX.G.credits).frame(width: 18, height: 2)
            }
            .foregroundStyle(NX.C.inkSoft)
            .frame(width: 46, height: 40)
            .background(SkewFill(style: .glass))
            .contentShape(Rectangle())
        } primaryAction: {
            guard let i = modes.firstIndex(of: mode) else { mode = modes.first ?? .image; return }
            mode = modes[(i + 1) % modes.count]
        }
        .sensoryFeedback(.selection, trigger: mode)
        .accessibilityLabel("Mode: \(mode.title)")
        .accessibilityHint("Tap for the next mode, hold for the list")
        .accessibilityAdjustableAction { direction in
            guard let i = modes.firstIndex(of: mode) else { return }
            switch direction {
            case .increment: mode = modes[(i + 1) % modes.count]
            case .decrement: mode = modes[(i - 1 + modes.count) % modes.count]
            @unknown default: break
            }
        }
    }
}

/// Send button with the price inside: "↑ 25 CR". The arrow stays upright.
struct SendPriceButton: View {
    var price: Int?
    var loading = false
    var enabled = true
    var icon = "arrow.up"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading {
                    ProgressView().controlSize(.small).tint(NX.C.btnInk)
                } else {
                    Image(systemName: icon).font(.system(size: 13, weight: .bold))
                }
                if let price {
                    Text("\(price) CR").font(NX.F.display(13)).lineLimit(1).fixedSize()
                }
            }
            .foregroundStyle(NX.C.btnInk)
            .padding(.horizontal, price == nil ? 0 : 16)
            .frame(minWidth: 48)
            .frame(height: 40)
            .background(Parallelogram().fill(enabled ? AnyShapeStyle(NX.G.silver) : AnyShapeStyle(NX.G.sendIdle)))
            .shadow(color: enabled ? NX.C.blue.opacity(0.28) : .clear, radius: 10, y: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled || loading)
        .accessibilityLabel(price.map { "Send, \($0) credits" } ?? "Send")
    }
}

/// Field chip inside composers: "NANO BANANA PRO · 1:1 ▴".
struct FieldChip: View {
    let title: String
    var chevron = "chevron.up"

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased()).font(NX.F.mono(10)).tracking(1.4).lineLimit(1).truncationMode(.tail)
            Image(systemName: chevron).font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(NX.C.ink2)
        .padding(.horizontal, 14)
        .frame(height: 40)
        .frame(maxWidth: 190)
        .background(SkewFill(style: .glass))
        .contentShape(Rectangle())
    }
}

// MARK: - Headers

/// Screen header bar (custom so skewed controls never sit inside system toolbar bubbles).
struct NavHeader<Leading: View, Title: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var title: Title
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            leading
            title.frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(
            LinearGradient(stops: [.init(color: NX.C.bg, location: 0.55), .init(color: NX.C.bg.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                .padding(.bottom, -16)
                .ignoresSafeArea(edges: .top)
        )
    }
}

/// Native-looking back link: "‹ Studio".
struct BackLink: View {
    let title: String
    var action: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            if let action { action() } else { dismiss() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                Text(title).font(NX.F.body(16)).lineLimit(1)
            }
            .foregroundStyle(NX.C.inkSoft)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to \(title)")
    }
}

/// Archivo 900 italic caps title with an optional subtitle line.
struct ScreenTitle: View {
    let text: String
    var subtitle: String? = nil
    var size: CGFloat = 18
    var centered = false

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 1) {
            Text(text.uppercased())
                .font(NX.F.display(size))
                .tracking(-0.4)
                .foregroundStyle(NX.C.inkSoft)
                .lineLimit(1)
                .truncationMode(.tail)
            if let subtitle {
                Text(subtitle).font(NX.F.body(12)).foregroundStyle(NX.C.ink3).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

/// Mono uppercase section label.
struct SectionLabel: View {
    let text: String
    var color: Color = NX.C.muted

    init(_ text: String, color: Color = NX.C.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(NX.F.mono(10))
            .tracking(1.8)
            .foregroundStyle(color)
    }
}

/// Gradient placeholder tile like the canvas (blue / violet / graphite).
struct TilePlaceholder: View {
    var seed: Int = 0

    var body: some View {
        let palettes: [[Color]] = [
            [Color(hex: 0x1C2433), Color(hex: 0x0F131A), Color(hex: 0x0B0D10)],
            [Color(hex: 0x2A1B3D), Color(hex: 0x14122B), Color(hex: 0x0B0D10)],
            [Color(hex: 0x2B2F36), Color(hex: 0x171A1F), Color(hex: 0x0B0D10)],
        ]
        let colors = palettes[abs(seed) % palettes.count]
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [(seed % 4 == 3 ? NX.C.pink : NX.C.blue).opacity(0.2), .clear], center: seed % 4 == 3 ? UnitPoint(x: 0.2, y: 0.9) : UnitPoint(x: 0.8, y: 0.1), startRadius: 2, endRadius: 160)
        }
    }
}

/// Small badge on tiles: "▶ 0:05", "AA FROM CHAT", "REF".
struct TileBadge: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 7, weight: .bold)) }
            Text(text.uppercased()).font(NX.F.mono(9)).tracking(1.2)
        }
        .foregroundStyle(NX.C.inkSoft)
        .padding(.horizontal, 6)
        .frame(height: 20)
        .background(Color.black.opacity(0.55))
    }
}

// MARK: - Swipe back with hidden navigation bars

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
