import SwiftUI
import PhotosUI
import UIKit

enum ThreadMode: Hashable { case answer, prompt, media }

struct ChatScreen: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @State private var showCapabilities = false
    @State private var showTiers = false
    @State private var attachments: [ChatAttachment] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var mode: ThreadMode = .answer
    @FocusState private var composerFocused: Bool

    private var inThread: Bool { !(model.currentChat?.messages.isEmpty ?? true) }
    private var hasText: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var uploading: Bool { attachments.contains { $0.uploading } }

    var body: some View {
        ZStack(alignment: .top) {
            NX.C.bg.ignoresSafeArea()

            Group {
                if let chat = model.currentChat, inThread {
                    ThreadView(chat: chat, stage: model.streamingStage, mode: mode)
                } else {
                    EmptyChatView(
                        onIdea: { text in
                            draft = text
                            composerFocused = true
                        },
                        onSeeAll: { showCapabilities = true }
                    )
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 60) }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }

            header
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.currentChat?.messages.count ?? 0)
        .onChange(of: model.currentChatID) { _, _ in mode = .answer }
        .task(id: model.pendingAttachments.count) {
            guard !model.pendingAttachments.isEmpty else { return }
            let items = model.pendingAttachments
            model.pendingAttachments = []
            for item in items {
                attachments.append(ChatAttachment(previewURL: item.previewURL, uploading: false, url: item.url?.absoluteString))
            }
            composerFocused = true
        }
        .onAppear {
            if model.launchSheet == "capabilities" {
                Task {
                    try? await Task.sleep(for: .milliseconds(1200))
                    if model.launchSheet == "capabilities" { showCapabilities = true }
                }
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
            .onAppear { model.launchSheet = nil }
        }
        .onChange(of: pickerItems) { _, items in
            pickerItems = []
            for item in items { Task { await add(item) } }
        }
    }

    // MARK: Header

    private var header: some View {
        FloatingHeader {
            ChamferIconButton(systemName: "line.3.horizontal", label: "Menu") {
                withAnimation(NX.Motion.pop) { model.sidebarOpen = true }
            }
        } center: {
            if inThread {
                PillTabs(items: [
                    .init(value: ThreadMode.answer, icon: "text.alignleft", accessibility: "Answer"),
                    .init(value: ThreadMode.prompt, icon: "text.quote", accessibility: "Prompts"),
                    .init(value: ThreadMode.media, icon: "photo.on.rectangle", accessibility: "Media"),
                ], selection: $mode)
            } else {
                Button { showTiers.toggle() } label: {
                    HStack(spacing: 8) {
                        Text("NXOR").font(NX.F.display(16))
                        Text((model.tier?.title ?? "Fast").uppercased()).font(NX.F.mono(11)).tracking(1.8).foregroundStyle(NX.C.accent)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(NX.C.ink2)
                    }
                    .foregroundStyle(NX.C.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(NX.C.raised)
                    .overlay(Rectangle().strokeBorder(showTiers ? NX.C.accent : NX.C.line, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Mode: \(model.tier?.title ?? "Fast"). Change")
                .popover(isPresented: $showTiers, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                    TierPicker { showTiers = false }
                        .presentationCompactAdaptation(.popover)
                }
            }
        } trailing: {
            if inThread {
                Menu {
                    Button { model.openChat(nil) } label: { Label("New chat", systemImage: "square.and.pencil") }
                    Picker("Mode", selection: Binding(get: { model.selectedTier }, set: { model.selectedTier = $0 })) {
                        ForEach(model.tiers) { tier in Text(tier.title).tag(tier.tier) }
                    }
                    Button { showCapabilities = true } label: { Label("What can NXOR do?", systemImage: "sparkles") }
                    if let id = model.currentChatID {
                        Button(role: .destructive) { Task { await model.deleteChat(id) } } label: { Label("Delete chat", systemImage: "trash") }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(NX.C.inkSoft)
                        .frame(width: 44, height: 44)
                        .background(NX.C.raised, in: CutCorner(cut: 9))
                        .overlay(CutCorner(cut: 9).strokeBorder(NX.C.line, lineWidth: 1))
                }
                .accessibilityLabel("More")
            } else {
                Button { model.showAccount = true } label: { HatchAvatar(size: 44) }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Account")
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { item in
                            Group {
                                if let image = item.image {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else {
                                    AsyncImage(url: item.previewURL) { phase in
                                        if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                                    }
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipped()
                            .overlay { if item.uploading { ZStack { Color.black.opacity(0.5); ProgressView().tint(NX.C.accent) } } }
                            .overlay(alignment: .topTrailing) {
                                Button { attachments.removeAll { $0.id == item.id } } label: {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(NX.C.ink).frame(width: 18, height: 18).background(Color.black.opacity(0.7))
                                }
                                .accessibilityLabel("Remove photo")
                            }
                            .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                CapsuleField(text: $draft, placeholder: inThread ? "Ask a follow up…" : "Ask anything or describe a shot", focused: $composerFocused) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 4, matching: .images) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(NX.C.ink2)
                            .frame(width: 40, height: 52)
                    }
                    .accessibilityLabel("Attach photos")
                } accessory: {
                    ComposerIcon(systemName: "mic", label: "Dictate") { composerFocused = true }
                }

                if model.isStreaming {
                    ChamferIconButton(systemName: "stop.fill", label: "Stop", size: 54) { model.stop() }
                } else if inThread && !hasText {
                    MetalSquareButton(systemName: "square.and.pencil", label: "New chat") { model.openChat(nil) }
                } else {
                    MetalSquareButton(systemName: "arrow.up", label: "Send", enabled: hasText && !uploading) { send() }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            LinearGradient(stops: [.init(color: NX.C.bg.opacity(0), location: 0), .init(color: NX.C.bg, location: 0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func send() {
        let text = draft
        let urls = attachments.compactMap(\.url)
        draft = ""
        attachments = []
        mode = .answer
        model.send(text, attachments: urls)
    }

    @MainActor
    private func add(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        let attachment = ChatAttachment(image: image, uploading: model.auth == .live)
        attachments.append(attachment)
        guard model.auth == .live else { return }
        let jpeg = image.jpegData(compressionQuality: 0.85) ?? data
        let url = try? await NXORService.uploadChatAttachment(data: jpeg)
        if let i = attachments.firstIndex(where: { $0.id == attachment.id }) {
            if let url {
                attachments[i].url = url
                attachments[i].uploading = false
            } else {
                attachments.remove(at: i)
                model.errorMessage = "Couldn't upload the photo. Try again."
            }
        }
    }
}

struct EmptyChatView: View {
    @Environment(AppModel.self) private var model
    let onIdea: (String) -> Void
    let onSeeAll: () -> Void

    private var ideas: [(String, String)] {
        [
            ("video", "Make a 5-second video from a photo"),
            ("photo", "Make an image from a few words"),
            ("sparkle", "Show me trending presets"),
            ("globe", "What's new in AI video this week?"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            ZStack {
                SpectrumGlow()
                VStack(spacing: 22) {
                    NXMark().fill(NX.G.logo).frame(width: 60, height: 60)
                    VStack(spacing: 2) {
                        DisplayTitle("Ask, then render.", size: 26)
                        GradientText(text: "Every engine, one chat.", size: 26)
                    }
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                }
            }
            Spacer(minLength: 20)

            VStack(spacing: 0) {
                ForEach(Array(ideas.enumerated()), id: \.offset) { _, idea in
                    Button { onIdea(idea.1) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: idea.0).font(.system(size: 16)).foregroundStyle(NX.C.accent).frame(width: 22)
                            Text(idea.1).font(NX.F.body(15)).foregroundStyle(NX.C.inkSoft).multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(NX.C.ink3)
                        }
                        .frame(minHeight: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onSeeAll) {
                    HStack(spacing: 8) {
                        Text("SEE EVERYTHING NXOR CAN DO").font(NX.F.mono(11)).tracking(1.8)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(NX.C.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .scrollDismissesKeyboard(.interactively)
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

struct ChatAttachment: Identifiable {
    let id = UUID()
    var image: UIImage? = nil
    var previewURL: URL? = nil
    var uploading: Bool
    var url: String? = nil
}
