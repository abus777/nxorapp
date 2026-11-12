import SwiftUI

struct AccountSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var memoryOn = true
    @State private var memoryLoaded = false
    @State private var confirmSignOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    HatchAvatar(size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.account.name).font(NX.F.body(18, .semibold)).foregroundStyle(NX.C.ink)
                        Text(model.account.email).font(NX.F.body(13)).foregroundStyle(NX.C.ink2)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16)).foregroundStyle(NX.C.inkSoft).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.top, 8)

                HStack(spacing: 2) {
                    stat("Balance", Int(model.account.available).formatted(), gradient: true)
                    stat("Reserved", Int(model.account.reserved).formatted(), gradient: false)
                    stat("Monthly", Int(model.account.monthlyGrant).formatted(), gradient: false)
                }
                .background(NX.C.lineSoft)
                .overlay(Rectangle().strokeBorder(NX.C.lineSoft, lineWidth: 1))

                Button {
                    dismiss()
                    model.open(.billing)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            MetaLabel("\(model.account.planName) · plan", color: NX.C.ink, size: 11)
                            Text("Plans and credit packs are managed on nxor.ai").font(NX.F.body(12)).foregroundStyle(NX.C.ink2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(NX.C.inkSoft)
                    }
                    .padding(14)
                    .background(NX.G.featured)
                    .overlay(Rectangle().strokeBorder(Color(hex: 0x3A3560), lineWidth: 1))
                }
                .buttonStyle(PressStyle())

                VStack(spacing: 0) {
                    Toggle(isOn: $memoryOn) {
                        VStack(alignment: .leading, spacing: 4) {
                            MetaLabel("Memory", color: NX.C.ink, size: 11)
                            Text("Keep short notes from chats to personalise answers").font(NX.F.body(12)).foregroundStyle(NX.C.ink2)
                        }
                    }
                    .tint(NX.C.accent)
                    .padding(14)
                    .overlay(alignment: .bottom) { Rectangle().fill(NX.C.lineSoft).frame(height: 1) }
                    .onChange(of: memoryOn) { _, on in
                        guard memoryLoaded, model.auth == .live else { return }
                        Task { try? await NXORService.setMemory(enabled: on) }
                    }

                    row("Invite friends · 300 cr each") { dismiss(); model.open(.settings) }
                    row("Settings") { dismiss(); model.open(.settings) }
                    row("Help center") { dismiss(); model.open(.help) }
                    row("Terms & privacy", last: true) { if let u = URL(string: "https://nxor.ai/legal/terms") { openURL(u) } }
                }
                .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))

                Button {
                    if model.isDemo {
                        dismiss()
                        Task { await model.signOut() }
                    } else {
                        confirmSignOut = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: model.isDemo ? "person.crop.circle.badge.plus" : "rectangle.portrait.and.arrow.right")
                        Text((model.isDemo ? "Sign in to NXOR" : "Sign out").uppercased()).font(NX.F.mono(12, .semibold)).tracking(2.2)
                    }
                    .foregroundStyle(model.isDemo ? NX.C.ink : NX.C.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(Rectangle().strokeBorder(model.isDemo ? NX.C.line2 : NX.C.danger.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(PressStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(NX.C.surface)
        .confirmationDialog("Sign out of NXOR?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                dismiss()
                Task { await model.signOut() }
            }
        }
        .task {
            guard model.auth == .live else { memoryLoaded = true; return }
            if let m = try? await NXORService.memory() { memoryOn = m.enabled }
            memoryLoaded = true
            await model.refreshBalance()
        }
    }

    private func stat(_ title: String, _ value: String, gradient: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(title, color: NX.C.ink2, size: 10)
            Text(value)
                .font(NX.F.display(22))
                .foregroundStyle(gradient ? AnyShapeStyle(NX.G.heroInk) : AnyShapeStyle(NX.C.ink))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(NX.C.card)
    }

    private func row(_ title: String, last: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(NX.C.ink2)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { if !last { Rectangle().fill(NX.C.lineSoft).frame(height: 1) } }
        }
        .buttonStyle(.plain)
    }
}
