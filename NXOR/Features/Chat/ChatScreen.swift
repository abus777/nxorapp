import SwiftUI

struct ChatScreen: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @State private var showCapabilities = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let chat = model.currentChat, !chat.messages.isEmpty {
                ThreadView(chat: chat, stage: model.streamingStage)
            } else {
                EmptyChatView(
                    onCapability: { cap in
                        draft = cap.example
                        composerFocused = true
                    },
                    onSeeAll: { showCapabilities = true }
                )
            }

            Composer(text: $draft, focused: $composerFocused) {
                let text = draft
                draft = ""
                Task { await model.send(text) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .onAppear {
            if model.launchSheet == "capabilities" {
                model.launchSheet = nil
                showCapabilities = true
            }
        }
        .sheet(isPresented: $showCapabilities) {
            CapabilitiesSheet { cap in
                showCapabilities = false
                draft = cap.example
                composerFocused = true
            }
            .presentationDetents([.large])
            .presentationBackground(NX.C.surface)
        }
    }
}

struct EmptyChatView: View {
    @Environment(AppModel.self) private var model
    let onCapability: (Capability) -> Void
    let onSeeAll: () -> Void

    private var cards: [Capability] {
        let order = ["preset", "video", "image", "web_search"]
        return order.compactMap { id in model.capabilities.first { $0.id == id } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 60)
                NXMark()
                    .fill(NX.G.logo)
                    .frame(width: 84, height: 84)
                    .padding(.bottom, 26)

                VStack(spacing: 2) {
                    DisplayTitle("Ask, then render.", size: 30)
                    GradientText(text: "Every engine, one chat.", size: 30)
                }
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.bottom, 36)

                HStack {
                    MetaLabel("Start with", size: 12)
                    Spacer()
                    Button(action: onSeeAll) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                            Text("See all capabilities")
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        }
                        .font(NX.F.body(14))
                        .foregroundStyle(NX.C.ink2)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cards) { cap in
                            CapabilityCard(capability: cap) { onCapability(cap) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct CapabilityCard: View {
    let capability: Capability
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(capability.title).font(NX.F.body(18, .medium)).foregroundStyle(NX.C.ink)
                    Text(capability.summary).font(NX.F.body(14)).foregroundStyle(NX.C.ink3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: capability.systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(NX.C.accent)
                    .frame(width: 44, height: 44)
                    .background(NX.C.bg)
                    .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
            }
            .padding(18)
            .frame(width: 290, height: 120, alignment: .topLeading)
            .background(NX.C.surface)
            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct Composer: View {
    @Environment(AppModel.self) private var model
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let onSend: () -> Void
    @State private var showTiers = false

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("", text: $text, prompt: Text("Try: Show me trendy presets").foregroundColor(NX.C.muted), axis: .vertical)
                .font(NX.F.body(17))
                .foregroundStyle(NX.C.ink)
                .lineLimit(1...6)
                .focused(focused)

            HStack(spacing: 10) {
                Button {} label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(NX.C.ink)
                        .frame(width: 42, height: 42)
                        .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
                }
                .buttonStyle(PressStyle())

                Button { showTiers.toggle() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt").foregroundStyle(NX.C.accent)
                        Text(model.selectedTier.uppercased()).font(NX.F.mono(13, .semibold)).tracking(2.6)
                        Image(systemName: "chevron.up").font(.system(size: 10, weight: .semibold)).foregroundStyle(NX.C.ink3)
                    }
                    .foregroundStyle(NX.C.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .overlay(Capsule().strokeBorder(showTiers ? NX.C.accent : NX.C.line2, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
                .popover(isPresented: $showTiers, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                    TierPicker { showTiers = false }
                        .presentationCompactAdaptation(.popover)
                }

                Spacer()
                SendButton(enabled: canSend, action: onSend)
            }
        }
        .padding(16)
        .background(NX.C.surface)
        .overlay(Rectangle().strokeBorder(focused.wrappedValue ? NX.C.line2 : NX.C.line, lineWidth: 1))
    }
}

struct TierPicker: View {
    @Environment(AppModel.self) private var model
    let onPick: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.tiers) { tier in
                Button {
                    model.selectedTier = tier.tier
                    onPick()
                } label: {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(model.selectedTier == tier.tier ? NX.C.accent : .clear)
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tier.title).font(NX.F.body(17, .medium)).foregroundStyle(NX.C.ink)
                            MetaLabel(tier.subtitle, size: 9)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        Spacer(minLength: 0)
                        if tier.locked {
                            Image(systemName: "lock").foregroundStyle(NX.C.muted).padding(.trailing, 14)
                        }
                    }
                    .background(model.selectedTier == tier.tier ? NX.C.raised : NX.C.surface)
                }
                .buttonStyle(.plain)
                .disabled(tier.locked)
            }
        }
        .frame(width: 330)
        .background(NX.C.surface)
    }
}

struct CapabilitiesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let onTry: (Capability) -> Void

    private let groups: [(String, String)] = [
        ("create", "Create"), ("edit", "Edit"), ("presets", "Presets"), ("research", "Research"), ("files", "Files"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        DisplayTitle("What can I do?", size: 26)
                        Text("Everything this chat can do on your plan. Tap one to try it.")
                            .font(NX.F.body(15)).foregroundStyle(NX.C.ink3)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(NX.C.ink2)
                    }
                }
                .padding(.bottom, 24)

                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    let (key, title) = group
                    let items = model.capabilities.filter { $0.group == key }
                    if !items.isEmpty {
                        MetaLabel(title, size: 11).padding(.bottom, 10).padding(.top, 8)
                        ForEach(items) { cap in
                            HStack(spacing: 14) {
                                Image(systemName: cap.systemImage).foregroundStyle(NX.C.accent).frame(width: 22)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cap.title).font(NX.F.body(16, .medium)).foregroundStyle(NX.C.ink)
                                    Text(cap.summary).font(NX.F.body(13)).foregroundStyle(NX.C.ink3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                Button { onTry(cap) } label: {
                                    Text("TRY IT").font(NX.F.mono(11, .semibold)).tracking(2)
                                        .foregroundStyle(NX.C.ink)
                                        .padding(.horizontal, 14).frame(height: 38)
                                        .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
                                }
                                .buttonStyle(PressStyle())
                            }
                            .padding(16)
                            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(NX.C.surface)
    }
}
