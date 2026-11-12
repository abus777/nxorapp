import SwiftUI

/// Floating square button with the NXOR chamfer (menu, more, library…).
struct ChamferIconButton: View {
    let systemName: String
    var label: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(NX.C.inkSoft)
                .frame(width: size, height: size)
                .background(NX.C.raised, in: CutCorner(cut: 9))
                .overlay(CutCorner(cut: 9).strokeBorder(NX.C.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// Platinum metal square — the single primary action next to the composer.
struct MetalSquareButton: View {
    let systemName: String
    var label: String
    var enabled = true
    var size: CGFloat = 54
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NX.C.btnInk)
                .frame(width: size, height: size)
                .background(enabled ? AnyShapeStyle(NX.G.silver) : AnyShapeStyle(NX.G.sendIdle), in: CutCorner(cut: 12))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// Floating pill of tabs in the header centre (Answer · Prompt · Media, Image · Video).
struct PillTabs<T: Hashable>: View {
    struct Item {
        let value: T
        let icon: String
        var title: String? = nil
        var accessibility: String
    }

    let items: [Item]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let on = item.value == selection
                Button {
                    withAnimation(NX.Motion.hover) { selection = item.value }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon).font(.system(size: 14, weight: .medium))
                        if let title = item.title {
                            Text(title.uppercased()).font(NX.F.mono(11)).tracking(1.8)
                        }
                    }
                    .foregroundStyle(on ? NX.C.ink : NX.C.ink3)
                    .padding(.horizontal, item.title == nil ? 0 : 12)
                    .frame(minWidth: 44, minHeight: 32)
                    .background(on ? AnyShapeStyle(NX.G.selected) : AnyShapeStyle(Color.clear))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibility)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(NX.C.raised)
        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
    }
}

/// Header that floats over content: left button, centre, right button.
struct FloatingHeader<Leading: View, Center: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            leading.frame(width: 44)
            Spacer(minLength: 0)
            center
            Spacer(minLength: 0)
            trailing.frame(width: 44)
        }
        .padding(.horizontal, 12)
        .frame(height: 60)
        .background(
            LinearGradient(stops: [.init(color: NX.C.bg, location: 0.6), .init(color: NX.C.bg.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
    }
}

/// The capsule composer: + and mic inside, one square action beside it.
struct CapsuleField<Leading: View, Accessory: View>: View {
    @Binding var text: String
    var placeholder: String
    var focused: FocusState<Bool>.Binding
    @ViewBuilder var leading: Leading
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            leading
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(NX.C.ink3), axis: .vertical)
                .font(NX.F.body(16))
                .foregroundStyle(NX.C.ink)
                .lineLimit(1...5)
                .focused(focused)
                .padding(.vertical, 15)
            accessory
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 54)
        .background(NX.C.raised, in: CutCorner(cut: 12))
        .overlay(CutCorner(cut: 12).strokeBorder(focused.wrappedValue ? NX.C.line2.opacity(1) : NX.C.line2, lineWidth: 1))
    }
}

struct ComposerIcon: View {
    let systemName: String
    var label: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(NX.C.ink2)
                .frame(width: 40, height: 46)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Soft spectrum glow behind empty states (brand: conic glow, low opacity).
struct SpectrumGlow: View {
    var body: some View {
        AngularGradient(colors: [NX.C.blue, NX.C.accent, NX.C.orchid, NX.C.pink, NX.C.blue], center: UnitPoint(x: 0.3, y: 0.4))
            .frame(width: 320, height: 260)
            .blur(radius: 80)
            .opacity(0.12)
            .allowsHitTesting(false)
    }
}

struct HatchAvatar: View {
    var size: CGFloat = 44

    var body: some View {
        StripedAvatar(size: size)
            .clipShape(CutCorner(cut: 9))
            .overlay(CutCorner(cut: 9).strokeBorder(NX.C.line, lineWidth: 1))
    }
}

/// Mono uppercase eyebrow used for section labels.
struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(NX.F.mono(11))
            .tracking(2.2)
            .foregroundStyle(NX.C.ink2)
    }
}
