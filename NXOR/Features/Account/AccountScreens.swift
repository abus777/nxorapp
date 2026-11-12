import SwiftUI

struct BillingScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var yearly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Plans and credit packs are managed on nxor.ai.")
                    .font(NX.F.body(16)).foregroundStyle(NX.C.ink2)

                HStack(spacing: 0) {
                    stat("Balance", Int(model.account.available).formatted(), unit: nil, gradient: true)
                    Rectangle().fill(NX.C.line).frame(width: 1)
                    stat("Reserved", Int(model.account.reserved).formatted(), unit: nil, gradient: false)
                    Rectangle().fill(NX.C.line).frame(width: 1)
                    stat("Monthly", Int(model.account.monthlyGrant).formatted(), unit: nil, gradient: false)
                }
                .frame(height: 96)
                .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))

                NXSegmented(options: [(false, "Monthly"), (true, "Annual · −22%")], selection: $yearly)

                ForEach(model.plans) { plan in
                    planCard(plan)
                }

                Button {
                    if let url = URL(string: "https://nxor.ai/billing") { openURL(url) }
                } label: {
                    HStack {
                        MetaLabel("Manage on nxor.ai", color: NX.C.ink)
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(NX.C.ink2)
                    }
                    .padding(16)
                    .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
            }
            .padding(16)
        }
    }

    private func stat(_ title: String, _ value: String, unit: String?, gradient: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(title, size: 9)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(NX.F.display(22))
                    .foregroundStyle(gradient ? AnyShapeStyle(NX.G.credits) : AnyShapeStyle(NX.C.ink))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let unit { MetaLabel(unit, size: 9) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private func planCard(_ plan: Plan) -> some View {
        let current = plan.slug == model.account.planSlug
        let monthly = yearly ? (Double(plan.priceYearlyUsd) ?? 0) / 12 : Double(plan.priceMonthlyUsd) ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                MetaLabel(plan.name, color: NX.C.ink, size: 13)
                Spacer()
                if current { MetaLabel("Current plan", color: NX.C.accent, size: 10) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let anchor = plan.anchorMonthlyUsd {
                    Text("$\(anchor)").font(NX.F.body(15)).strikethrough().foregroundStyle(NX.C.muted)
                }
                Text(String(format: "$%.2f", monthly)).font(NX.F.display(34)).foregroundStyle(NX.C.ink)
                MetaLabel("/ mo", size: 11)
            }
            VStack(alignment: .leading, spacing: 8) {
                feature("\(plan.monthlyTokenGrant.formatted()) credits / month")
                if plan.parallelGenerations { feature("Parallel generations") }
                if plan.prioritySupport { feature("Priority support") }
            }
        }
        .padding(18)
        .background(current ? NX.C.raised : NX.C.surface)
        .overlay(Rectangle().strokeBorder(current ? AnyShapeStyle(NX.G.frame) : AnyShapeStyle(NX.C.line), lineWidth: 1))
    }

    private func feature(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(NX.C.accent)
            MetaLabel(text, color: NX.C.ink2, size: 10)
        }
    }
}

struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var confirmSignOut = false
    @State private var memoryOn = true
    @State private var memoryText: String?
    @State private var memoryLoaded = false
    @State private var confirmClearMemory = false
    @State private var referral: ReferralInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                HStack(spacing: 16) {
                    StripedAvatar(size: 56)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.account.name).font(NX.F.body(20, .semibold)).foregroundStyle(NX.C.ink)
                        Text(model.account.email).font(NX.F.body(15)).foregroundStyle(NX.C.ink3)
                        MetaLabel("\(model.account.planName) · \(Int(model.account.available).formatted()) credits", color: NX.C.ink3, size: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    MetaLabel("Memory")
                    Toggle(isOn: $memoryOn) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Remember things about me").font(NX.F.body(16)).foregroundStyle(NX.C.ink)
                            Text("NXOR keeps short notes from your chats to personalise answers.")
                                .font(NX.F.body(13)).foregroundStyle(NX.C.ink3)
                        }
                    }
                    .tint(NX.C.accent)
                    .onChange(of: memoryOn) { _, on in
                        guard memoryLoaded, model.auth == .live else { return }
                        Task { try? await NXORService.setMemory(enabled: on) }
                    }
                    if let memoryText, !memoryText.isEmpty {
                        Text(memoryText).font(NX.F.mono(12)).foregroundStyle(NX.C.ink2).lineLimit(6)
                        Button("Clear memory", role: .destructive) { confirmClearMemory = true }
                            .font(NX.F.mono(12, .semibold))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))

                VStack(alignment: .leading, spacing: 12) {
                    MetaLabel("Invite friends")
                    if let referral {
                        Text(verbatim: referralPitch(referral))
                            .font(NX.F.body(15)).foregroundStyle(NX.C.ink2)
                        HStack(spacing: 0) {
                            refStat("Signups", "\(referral.signups)")
                            refStat("Paid", "\(referral.paid)")
                            refStat("Earned", "\(Int(referral.creditsEarned)) cr")
                        }
                        if let url = URL(string: referral.link) {
                            ShareLink(item: url, message: Text("Try NXOR — every AI model in one chat")) {
                                HStack {
                                    Text(referral.link).font(NX.F.mono(12)).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .foregroundStyle(NX.C.ink)
                                .padding(14)
                                .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
                            }
                        }
                    } else {
                        Text(model.isDemo ? "Sign in to get your invite link." : "Loading…")
                            .font(NX.F.body(14)).foregroundStyle(NX.C.ink3)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))

                VStack(spacing: 0) {
                    row("Manage plan", icon: "creditcard") { model.open(.billing) }
                    row("Help center", icon: "questionmark.circle") { model.open(.help) }
                    row("Open nxor.ai", icon: "safari") { if let u = URL(string: "https://nxor.ai") { openURL(u) } }
                    row("Terms", icon: "doc.text") { if let u = URL(string: "https://nxor.ai/legal/terms") { openURL(u) } }
                    row("Privacy", icon: "lock.shield") { if let u = URL(string: "https://nxor.ai/legal/privacy") { openURL(u) } }
                }
                .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))

                if model.isDemo {
                    NXPrimaryButton(title: "Sign in to NXOR") { Task { await model.signOut() } }
                } else {
                    NXSecondaryButton(title: "Sign out", icon: "rectangle.portrait.and.arrow.right") { confirmSignOut = true }
                        .frame(maxWidth: .infinity)
                }

                MetaLabel("NXOR for iOS · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")", size: 10)
            }
            .padding(16)
        }
        .confirmationDialog("Sign out of NXOR?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await model.signOut() } }
        }
        .confirmationDialog("Clear everything NXOR remembers?", isPresented: $confirmClearMemory, titleVisibility: .visible) {
            Button("Clear memory", role: .destructive) {
                memoryText = nil
                Task { try? await NXORService.clearMemory() }
            }
        }
        .task {
            guard model.auth == .live else { memoryLoaded = true; return }
            if let m = try? await NXORService.memory() {
                memoryOn = m.enabled
                memoryText = m.content
            }
            memoryLoaded = true
            referral = try? await NXORService.referral()
        }
    }

    private func referralPitch(_ r: ReferralInfo) -> String {
        var text = "Get \(Int(r.rewardPerReferral)) credits for every friend who joins"
        if let discount = r.discountPercent { text += " — they get \(discount)% off" }
        return text + "."
    }

    private func refStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(title, size: 9)
            Text(value).font(NX.F.display(20)).foregroundStyle(NX.C.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundStyle(NX.C.accent).frame(width: 22)
                Text(title).font(NX.F.body(16)).foregroundStyle(NX.C.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(NX.C.muted)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .overlay(alignment: .bottom) { Hairline() }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct HelpScreen: View {
    @Environment(\.openURL) private var openURL
    @State private var open: Int? = 0

    private let faq: [(String, String)] = [
        ("What are credits and how are they used?",
         "Credits meter your usage. Each chat reply, image, or video consumes credits based on the model and output — NXOR shows the estimated cost before you run a task and the actual cost after. Unused credits don't roll over between billing periods."),
        ("Am I charged for failed generations?",
         "No. Failed generations are never charged — reserved credits are returned to your balance."),
        ("How does billing work?",
         "Plans renew monthly or yearly. You can change or cancel your plan any time on nxor.ai; top-up packs add credits on top of your plan."),
        ("What happens to my images and videos?",
         "Everything you create is kept in your Library. You can download, move between projects or delete any item."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Answers on credits, billing, generation and your data.")
                    .font(NX.F.body(16)).foregroundStyle(NX.C.ink2)

                VStack(spacing: 0) {
                    ForEach(Array(faq.enumerated()), id: \.offset) { i, item in
                        Button {
                            withAnimation(NX.Motion.hover) { open = open == i ? nil : i }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    Text(item.0).font(NX.F.body(16, .medium)).foregroundStyle(NX.C.ink)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: open == i ? "minus" : "plus").foregroundStyle(NX.C.ink3)
                                }
                                if open == i {
                                    Text(item.1).font(NX.F.body(15)).foregroundStyle(NX.C.ink2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .padding(16)
                            .overlay(alignment: .bottom) { Hairline() }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))

                NXSecondaryButton(title: "Contact support", icon: "envelope") {
                    if let u = URL(string: "mailto:support@nxor.ai") { openURL(u) }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }
}
