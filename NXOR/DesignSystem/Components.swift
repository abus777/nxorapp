import SwiftUI

struct NXLogo: View {
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: size * 0.45) {
            NXMark()
                .fill(NX.G.logo)
                .frame(width: size * 1.15, height: size * 1.15)
            Text("NXOR")
                .font(NX.F.display(size))
                .foregroundStyle(NX.C.ink)
        }
    }
}

struct MetaLabel: View {
    let text: String
    var color: Color = NX.C.muted
    var size: CGFloat = 11

    init(_ text: String, color: Color = NX.C.muted, size: CGFloat = 11) {
        self.text = text
        self.color = color
        self.size = size
    }

    var body: some View {
        Text(text.uppercased())
            .font(NX.F.mono(size))
            .tracking(size * 0.2)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

struct DisplayTitle: View {
    let text: String
    var size: CGFloat = 28

    init(_ text: String, size: CGFloat = 28) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text.uppercased())
            .font(NX.F.display(size))
            .tracking(-size * 0.03)
            .foregroundStyle(NX.C.ink)
    }
}

struct NXIconButton: View {
    let systemName: String
    var size: CGFloat = 44
    var tint: Color = NX.C.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(NX.C.raised, in: CutCorner(cut: size * 0.18))
                .overlay(CutCorner(cut: size * 0.18).strokeBorder(NX.C.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct NXPrimaryButton: View {
    let title: String
    var height: CGFloat = 54
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(NX.F.display(17))
                .foregroundStyle(NX.C.btnInk)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(NX.G.silver, in: CutCorner(cut: 14))
        }
        .buttonStyle(PressStyle())
    }
}

struct NXSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title.uppercased()).font(NX.F.mono(13, .semibold)).tracking(2.4)
            }
            .foregroundStyle(NX.C.ink)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct SendButton: View {
    var enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(enabled ? NX.C.btnInk : NX.C.ink.opacity(0.85))
                .frame(width: 52, height: 46)
                .background(enabled ? AnyShapeStyle(NX.G.silver) : AnyShapeStyle(NX.G.sendIdle), in: CutCorner(cut: 12))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

struct NXChip: View {
    let title: String
    var selected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(NX.F.mono(12, .semibold))
                .tracking(2.2)
                .foregroundStyle(selected ? NX.C.ink : NX.C.ink2)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(selected ? NX.C.raised : Color.clear)
                .overlay(Rectangle().strokeBorder(selected ? NX.C.inkSoft.opacity(0.8) : NX.C.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct NXSegmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let (value, label) = option
                Button {
                    withAnimation(NX.Motion.hover) { selection = value }
                } label: {
                    Text(label.uppercased())
                        .font(NX.F.mono(12, .semibold))
                        .tracking(2.2)
                        .foregroundStyle(selection == value ? NX.C.ink : NX.C.ink2)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(selection == value ? NX.C.raised : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
    }
}

struct GradientText: View {
    let text: String
    var size: CGFloat

    var body: some View {
        Text(text.uppercased())
            .font(NX.F.display(size))
            .tracking(-size * 0.03)
            .foregroundStyle(NX.G.heroInk)
    }
}

struct StripedAvatar: View {
    var size: CGFloat = 48

    var body: some View {
        Canvas { ctx, sz in
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(Color(hex: 0x1A1E23)))
            var x: CGFloat = -sz.height
            while x < sz.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: sz.height))
                p.addLine(to: CGPoint(x: x + sz.height, y: 0))
                ctx.stroke(p, with: .color(Color(hex: 0x2A2F36)), lineWidth: 4)
                x += 8
            }
        }
        .frame(width: size, height: size)
    }
}

struct Skeleton: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            NX.C.raised
                .overlay(
                    LinearGradient(colors: [.clear, Color(hex: 0x22262C), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width)
                )
                .clipped()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1.4 }
        }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(NX.Motion.press, value: configuration.isPressed)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(NX.C.line).frame(height: 1)
    }
}
