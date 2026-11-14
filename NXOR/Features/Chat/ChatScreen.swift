import SwiftUI

/// Chat root. Launch always opens a new chat (01); a picked chat opens its thread (05).
struct ChatScreen: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var confirmDelete = false

    var body: some View {
        let chat = model.currentChat.flatMap { $0.projectID == nil ? $0 : nil }
        VStack(spacing: 0) {
            header(chat)
            if model.offline { OfflineBanner() }
            if let chat {
                ChatMessagesView(chat: chat, onSuggestion: { send($0) })
            } else {
                ChatHome(onIdea: { idea in
                    if idea.contains("Studio") {
                        model.openInStudio(StudioDraft(prompt: "A product photo of ", mode: .image))
                    } else {
                        draft = idea
                    }
                })
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposer(placeholder: chat == nil ? "Try: Show me trendy presets" : "Reply…", chatID: chat?.id, draft: $draft) { text, urls in
                model.send(text, attachments: urls)
            }
        }
        .background(chat == nil ? AnyView(BackgroundAura()) : AnyView(NX.C.bg.ignoresSafeArea()))
        .alert("Rename chat", isPresented: $renaming) {
            TextField("Name", text: $newTitle)
            Button("Save") { if let id = chat?.id { model.renameChat(id, to: newTitle) } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this chat?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete chat", role: .destructive) { if let id = chat?.id { Task { await model.deleteChat(id) } } }
        } message: {
            Text("Its pictures and videos stay in Studio.")
        }
    }

    private func send(_ text: String) {
        if text == "Add to a project" {
            model.moveChatID = model.currentChatID
        } else {
            model.send(text)
        }
    }

    @ViewBuilder
    private func header(_ chat: ChatThread?) -> some View {
        NavHeader {
            SkewIconButton(systemName: "line.3.horizontal", label: "Menu") {
                withAnimation(NX.Motion.pop) { model.sidebarOpen = true }
            }
        } title: {
            if let chat {
                ScreenTitle(text: chat.title, subtitle: "\(tierTitle(chat.tier)) · not in a project")
            } else {
                NXLogo(size: 17).frame(maxWidth: .infinity).padding(.trailing, 54)
            }
        } trailing: {
            if let chat {
                Menu {
                    Button { model.newChat() } label: { Label("New chat", systemImage: "square.and.pencil") }
                    Button { model.moveChatID = chat.id } label: { Label("Add to project…", systemImage: "folder.badge.plus") }
                    Button { newTitle = chat.title; renaming = true } label: { Label("Rename", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete chat", systemImage: "trash") }
                } label: {
                    SkewIconFace(systemName: "ellipsis")
                }
                .accessibilityLabel("Chat actions")
            }
        }
    }

    private func tierTitle(_ tier: String) -> String {
        model.tiers.first { $0.tier == tier }?.title ?? tier.capitalized
    }
}

/// 01: hero + "Try" ideas.
struct ChatHome: View {
    let onIdea: (String) -> Void

    private let ideas = [
        "Write an Instagram caption in Arabic",
        "Plan a launch for my perfume brand",
        "Make a product photo → Studio",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 70)
                NXMark().fill(NX.G.logo).frame(width: 64, height: 64).padding(.bottom, 26)
                Text("ASK, THEN RENDER.").font(NX.F.display(30)).tracking(-0.8).foregroundStyle(NX.C.inkSoft)
                Text("EVERY ENGINE, ONE CHAT.").font(NX.F.display(30)).tracking(-0.8).foregroundStyle(NX.C.accent)
                    .multilineTextAlignment(.center)
                Text("IMAGE · VIDEO · VOICE → ONE QUEUE")
                    .font(NX.F.mono(10)).tracking(1.8).foregroundStyle(NX.C.accent)
                    .padding(.top, 18)
                Spacer(minLength: 60)
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Try")
                    ForEach(ideas, id: \.self) { idea in
                        SkewButton(title: idea, size: .m, style: .dark, fullWidth: true) { onIdea(idea) }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// R10: offline notice.
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(NX.C.btnInk).frame(width: 8, height: 8)
            Text("You're offline. Messages will send when you're back.")
                .font(NX.F.body(14))
                .foregroundStyle(NX.C.btnInk)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(NX.G.silver)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }
}
