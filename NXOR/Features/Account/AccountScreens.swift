import SwiftUI
import UIKit

/// R2: account — profile, plan and credits, app settings, support, sign out, delete (R3).
struct AccountScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var confirmDelete = false
    @State private var confirmSignOut = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            NavHeader {
                BackLink(title: "Back")
            } title: {
                ScreenTitle(text: "Account", centered: true)
            } trailing: {
                Color.clear.frame(width: 60, height: 1)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Profile") {
                        row(model.account.name, subtitle: model.isDemo ? "Demo · not signed in" : "Signed in with email · \(model.account.email)", value: nil) {}
                    }
                    section("Plan and credits") {
                        row(model.account.planName, subtitle: "Monthly credits \(Int(model.account.monthlyGrant).formatted())", value: "Manage") { model.showPlans = true }
                        row("Credits", subtitle: nil, value: Int(model.account.available).formatted()) { model.showCredits = true }
                    }
                    section("App") {
                        row("Notifications", subtitle: "When a video is ready", value: nil) {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                        row("Language", subtitle: nil, value: Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en")?.capitalized) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        Menu {
                            Picker("Appearance", selection: $model.appearance) {
                                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                            }
                        } label: {
                            rowLabel("Appearance", subtitle: nil, value: model.appearance.title, chevron: "chevron.up.chevron.down")
                        }
                        .buttonStyle(.plain)
                        Toggle(isOn: Binding(get: { model.memoryOn }, set: { on in
                            model.memoryOn = on
                            if model.auth == .live { Task { try? await NXORService.setMemory(enabled: on) } }
                        })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Memory").font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                                Text("Keep short notes from chats to personalise answers").font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                            }
                        }
                        .tint(NX.C.accent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 56)
                    }
                    section("Support") {
                        row("Help", subtitle: nil, value: nil) { model.push(.help) }
                        row("Terms of Use", subtitle: nil, value: nil) { openURL(URL(string: "https://nxor.ai/legal/terms")!) }
                        row("Privacy Policy", subtitle: nil, value: nil) { openURL(URL(string: "https://nxor.ai/legal/privacy")!) }
                    }
                    VStack(spacing: 0) {
                        Button { if model.isDemo { Task { await model.signOut() } } else { confirmSignOut = true } } label: {
                            Text(model.isDemo ? "Sign in" : "Sign out").font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).frame(minHeight: 52)
                        }
                        if !model.isDemo {
                            Button { confirmDelete = true } label: {
                                Text("Delete account").font(NX.F.body(15)).foregroundStyle(NX.C.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).frame(minHeight: 52)
                            }
                        }
                    }
                    .background(NX.C.tint.opacity(0.035))
                }
                .padding(16)
            }
        }
        .background(NX.C.bg.ignoresSafeArea())
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                // The API has no delete endpoint yet: account deletion finishes on nxor.ai, then we sign out here.
                openURL(URL(string: "https://nxor.ai/settings")!)
                Task { await model.signOut() }
            }
            Button("Manage subscription") {
                openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All chats, media and remaining credits are deleted for good. An active subscription keeps renewing until you cancel it in Apple ID settings.")
        }
        .confirmationDialog("Sign out of NXOR?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await model.signOut() } }
        }
        .task { await model.refreshBalance() }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            VStack(spacing: 0) { content() }.background(NX.C.tint.opacity(0.035))
        }
    }

    private func row(_ title: String, subtitle: String?, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(title, subtitle: subtitle, value: value, chevron: "chevron.right") }
            .buttonStyle(.plain)
    }

    private func rowLabel(_ title: String, subtitle: String?, value: String?, chevron: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                if let subtitle { Text(subtitle).font(NX.F.body(12)).foregroundStyle(NX.C.ink3).lineLimit(1) }
            }
            Spacer()
            if let value { Text(value).font(NX.F.body(14)).foregroundStyle(NX.C.ink3) }
            Image(systemName: chevron).font(.system(size: 11, weight: .semibold)).foregroundStyle(NX.C.ink3)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// 14: credits — App Store only, with Restore Purchases.
struct CreditsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var pack = 1

    private let amounts = [1000, 3000, 10000]

    var body: some View {
        let store = model.store
        VStack(spacing: 16) {
            HStack {
                SkewIconButton(systemName: "xmark", label: "Close") { dismiss() }
                Spacer()
                Text("CREDITS").font(NX.F.display(18)).foregroundStyle(NX.C.inkSoft)
                Spacer()
                SkewButton(title: "History", size: .s, style: .glass) { openURL(URL(string: "https://nxor.ai/billing")!) }
            }
            VStack(spacing: 4) {
                Text(Int(model.account.available).formatted()).font(NX.F.display(40)).foregroundStyle(NX.C.inkSoft)
                Text("≈ \(Int(model.account.available) / 40) pictures or \(Int(model.account.available) / 350) videos · \(model.account.planName)")
                    .font(NX.F.body(13)).foregroundStyle(NX.C.ink3)
            }
            HStack(spacing: 6) {
                ForEach(amounts.indices, id: \.self) { i in
                    let id = Store.creditPackIDs[i]
                    Button { pack = i } label: {
                        VStack(spacing: 4) {
                            Text(amounts[i].formatted()).font(NX.F.display(18)).foregroundStyle(pack == i ? NX.C.btnInk : NX.C.inkSoft)
                            Text("credits").font(NX.F.body(11)).foregroundStyle(pack == i ? NX.C.btnInk.opacity(0.7) : NX.C.ink3)
                            Text(store.price(id) ?? "—").font(NX.F.body(13, .semibold)).foregroundStyle(pack == i ? NX.C.btnInk : NX.C.ink)
                                .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            let shape = Parallelogram(slant: 0.07, radius: 8)
                            if pack == i { shape.fill(NX.G.silver) } else { shape.fill(NX.C.tint.opacity(0.04)) }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(pack == i ? .isSelected : [])
                }
            }
            SkewButton(title: store.purchasing ? "Buying…" : "Buy \(amounts[pack].formatted()) credits", size: .l, style: .metal, fullWidth: true, enabled: !store.purchasing) {
                Task {
                    if await store.buy(Store.creditPackIDs[pack]) {
                        await model.refreshBalance()
                        dismiss()
                    }
                }
            }
            SkewButton(title: "See plans", size: .m, style: .dark, fullWidth: true) {
                dismiss()
                model.showPlans = true
            }
            HStack(spacing: 4) {
                Text("Paid with your Apple Account ·")
                Button("Restore Purchases") { Task { await store.restore() } }.underline()
                Text("·")
                Link("Terms", destination: URL(string: "https://nxor.ai/legal/terms")!).underline()
                Text("·")
                Link("Privacy", destination: URL(string: "https://nxor.ai/legal/privacy")!).underline()
            }
            .font(NX.F.body(11))
            .foregroundStyle(NX.C.ink3)
            .tint(NX.C.ink2)
            Spacer()
        }
        .padding(16)
        .task { await store.load() }
        .alert("App Store", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.message ?? "") }
    }
}

/// R4: plans — price, period, auto-renewal terms and Restore before the button.
struct PlansSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selected = 0

    private struct PlanRow {
        let title: String
        let price: String
        let note: String
        let detail: String
    }

    private var rows: [PlanRow] {
        let store = model.store
        func plan(_ slug: String) -> Plan? { model.plans.first { $0.slug.contains(slug) || $0.name.lowercased().contains(slug) } }
        return [
            PlanRow(title: "Try → Starter", price: store.price(Store.planIDs[0]).map { "\($0) / month" } ?? "$\(plan("starter")?.priceMonthlyUsd ?? "9.99") / month",
                    note: "3-day trial · cancel anytime", detail: "\((plan("starter")?.monthlyTokenGrant ?? 4000).formatted()) credits a month · Fast and Genius chat"),
            PlanRow(title: "Professional", price: store.price(Store.planIDs[1]).map { "\($0) / month" } ?? "$\(plan("pro")?.priceMonthlyUsd ?? "22.99") / month",
                    note: "billed monthly", detail: "\((plan("pro")?.monthlyTokenGrant ?? 12700).formatted()) credits a month · parallel generations"),
            PlanRow(title: "Power User", price: store.price(Store.planIDs[2]).map { "\($0) / month" } ?? "$\(plan("expert")?.priceMonthlyUsd ?? "58.90") / month",
                    note: "billed monthly", detail: "\((plan("expert")?.monthlyTokenGrant ?? 34400).formatted()) credits a month · lowest cost per credit"),
        ]
    }

    var body: some View {
        let store = model.store
        VStack(spacing: 14) {
            HStack {
                SheetCancelButton { dismiss() }
                Spacer()
                Text("PLANS").font(NX.F.display(18)).foregroundStyle(NX.C.inkSoft)
                Spacer()
                Color.clear.frame(width: 80, height: 1)
            }
            ScrollView {
                VStack(spacing: 10) {
                    VStack(spacing: 4) {
                        Text("TRY EVERYTHING").font(NX.F.display(24)).foregroundStyle(NX.C.inkSoft)
                        Text("Every model, one balance").font(NX.F.body(13)).foregroundStyle(NX.C.ink3)
                    }
                    .padding(.bottom, 6)
                    ForEach(rows.indices, id: \.self) { i in
                        Button { selected = i } label: {
                            SkewCard(selected: selected == i) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(rows[i].title.uppercased()).font(NX.F.display(15)).foregroundStyle(NX.C.inkSoft)
                                        Spacer()
                                        Text(rows[i].price).font(NX.F.body(14, .semibold)).foregroundStyle(NX.C.ink)
                                    }
                                    Text(rows[i].note).font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                                    Text(rows[i].detail).font(NX.F.body(12)).foregroundStyle(NX.C.ink2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == i ? .isSelected : [])
                    }
                    Text("The subscription renews automatically at the price shown each month until cancelled. Cancel at least 24 hours before renewal in Apple ID settings. Prices come from the App Store in your currency.")
                        .font(NX.F.body(11)).foregroundStyle(NX.C.ink3)
                    HStack(spacing: 16) {
                        Button("Restore Purchases") { Task { await store.restore() } }
                        Link("Terms", destination: URL(string: "https://nxor.ai/legal/terms")!)
                        Link("Privacy", destination: URL(string: "https://nxor.ai/legal/privacy")!)
                    }
                    .font(NX.F.body(12)).underline().foregroundStyle(NX.C.ink2)
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, 6)
            }
            SkewButton(title: store.purchasing ? "Subscribing…" : (selected == 0 ? "Start free trial" : "Subscribe"), size: .l, style: .metal, fullWidth: true, enabled: !store.purchasing) {
                Task {
                    if await store.buy(Store.planIDs[selected]) {
                        await model.refreshBalance()
                        dismiss()
                    }
                }
            }
        }
        .padding(16)
        .task { await store.load() }
        .alert("App Store", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.message ?? "") }
    }
}

/// R5: ask for notifications right after the first video starts.
struct NotifyPromptSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                SheetCancelButton { model.notifyAsked = true; dismiss() }
                Spacer()
            }
            TilePlaceholder(seed: 0).frame(width: 52, height: 52)
            Text("GET A PING WHEN IT'S READY?").font(NX.F.display(20)).foregroundStyle(NX.C.inkSoft).multilineTextAlignment(.center)
            Text("Videos take 1–3 minutes. We'll notify you and show progress on the Lock Screen. Nothing else.")
                .font(NX.F.body(14)).foregroundStyle(NX.C.ink3).multilineTextAlignment(.center)
            Spacer(minLength: 0)
            SkewButton(title: "Notify me", size: .l, style: .metal, fullWidth: true) {
                Task {
                    await model.requestNotifications()
                    dismiss()
                }
            }
            SkewButton(title: "Not now", size: .m, style: .dark, fullWidth: true) {
                model.notifyAsked = true
                dismiss()
            }
        }
        .padding(20)
    }
}

/// R6: no access to Photos — a way to Settings and an alternative.
struct PhotosDeniedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                SheetCancelButton { dismiss() }
                Spacer()
            }
            Spacer()
            TilePlaceholder(seed: 0).frame(width: 52, height: 52)
            Text("NXOR CAN'T SAVE TO YOUR PHOTOS").font(NX.F.display(20)).foregroundStyle(NX.C.inkSoft).multilineTextAlignment(.center)
            Text("Allow “Add Photos Only” in Settings to save pictures and videos. Picking references doesn't need access.")
                .font(NX.F.body(14)).foregroundStyle(NX.C.ink3).multilineTextAlignment(.center)
            SkewButton(title: "Open Settings", size: .l, style: .metal) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Use Share instead") { dismiss() }
                .font(NX.F.body(14)).underline().foregroundStyle(NX.C.inkSoft).frame(minHeight: 44)
            Spacer()
        }
        .padding(20)
        .background(BackgroundAura())
    }
}

struct HelpScreen: View {
    private let faq: [(String, String)] = [
        ("What is a credit?", "Credits pay for pictures, videos and chat. Each model shows its price before you run it; the price is on the send button."),
        ("Do failed generations cost credits?", "No. If a generation fails or is refused, the credits come back automatically."),
        ("Where are my files?", "Everything you make is in Studio. Things made in a chat are there too, marked “Aa from chat”."),
        ("What is a project?", "A project keeps chats, generations, files and instructions together. NXOR reads the instructions and brand kit in every project chat."),
        ("How do I cancel my plan?", "Open Settings → Apple ID → Subscriptions on your iPhone."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            NavHeader {
                BackLink(title: "Back")
            } title: {
                ScreenTitle(text: "Help", centered: true)
            } trailing: {
                Color.clear.frame(width: 60, height: 1)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(faq, id: \.0) { item in
                        DisclosureGroup {
                            Text(item.1).font(NX.F.body(14)).foregroundStyle(NX.C.ink2).padding(.top, 6)
                        } label: {
                            Text(item.0).font(NX.F.body(15, .semibold)).foregroundStyle(NX.C.ink)
                        }
                        .tint(NX.C.ink3)
                        .padding(14)
                        .background(NX.C.tint.opacity(0.035))
                    }
                    Link("Contact support", destination: URL(string: "mailto:support@nxor.ai")!)
                        .font(NX.F.body(15)).foregroundStyle(NX.C.accent).frame(minHeight: 44)
                }
                .padding(16)
            }
        }
        .background(NX.C.bg.ignoresSafeArea())
    }
}
