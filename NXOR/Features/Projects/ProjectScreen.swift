import SwiftUI

/// 12 / 12s / 12x: one project, shown by entry point — from Chat chats first, from Studio media first.
struct ProjectScreen: View {
    @Environment(AppModel.self) private var model
    let projectID: String
    let entry: ProjectEntry
    @State private var library = LibraryModel()
    @State private var filter: MediaFilter = .all
    @State private var selection: Set<String> = []
    @State private var showInfo = false
    @State private var view: ProjectEntry = .chat

    private var project: Project? { model.project(projectID) }
    private var chats: [ChatThread] { model.chats(in: projectID) }
    private var media: [LibraryItem] {
        var seen = Set<String>()
        return (model.freshItems.filter { $0.projectId == projectID } + library.items + library.uploads).filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader {
                BackLink(title: entry == .chat ? "Chats" : "Studio")
            } title: {
                Button { showInfo = true } label: {
                    HStack(spacing: 8) {
                        TilePlaceholder(seed: (project?.name.count ?? 0)).frame(width: 26, height: 26)
                        Text((project?.name ?? "Project").uppercased()).font(NX.F.display(17)).foregroundStyle(NX.C.inkSoft).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(NX.C.ink3)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(project?.name ?? "Project") info and settings")
            } trailing: {
                Menu {
                    Button { model.push(.newProjectChat(projectID)) } label: { Label("New chat", systemImage: "square.and.pencil") }
                    Button { create(.image) } label: { Label("New image", systemImage: "photo") }
                    Button { create(.video) } label: { Label("New video", systemImage: "video") }
                    Button { create(.audio) } label: { Label("New audio", systemImage: "waveform") }
                    Divider()
                    Button { showInfo = true } label: { Label("Project settings", systemImage: "slider.horizontal.3") }
                } label: {
                    SkewIconFace(systemName: "ellipsis")
                }
                .accessibilityLabel("Project actions")
            }

            if view == .chat { chatsView } else { mediaView }
        }
        .background(NX.C.bg.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            SkewButton(title: view == .chat ? "New chat" : "Create", icon: "plus", size: .l, style: .metal) {
                if view == .chat { model.push(.newProjectChat(projectID)) } else { create(.image) }
            }
            .padding(16)
        }
        .onAppear { view = entry }
        .task(id: model.studio.jobs.count) {
            library.scope = projectID
            await library.load(app: model, force: library.loaded)
        }
        .sheet(isPresented: $showInfo) {
            ProjectInfoSheet(projectID: projectID)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
    }

    private func create(_ mode: CreateMode) {
        model.studioDraft = StudioDraft(prompt: "", mode: mode, projectID: projectID)
        model.showCreateSheet = true
    }

    // MARK: 12 chats first

    @ViewBuilder
    private var chatsView: some View {
        if chats.isEmpty {
            // 12x: no chats yet — show the media large.
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("No chats yet · \(media.count) media in this project")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(media.prefix(4)) { item in
                            MediaTile(item: item) { model.push(.result(item.id)) }
                        }
                    }
                    if !media.isEmpty {
                        Button("See all media ›") { withAnimation(NX.Motion.hover) { view = .studio } }
                            .font(NX.F.body(13)).underline().foregroundStyle(NX.C.inkSoft).frame(minHeight: 44)
                    }
                    Spacer(minLength: 40)
                    SkewButton(title: "Start a chat about these", size: .l, style: .metal, fullWidth: true) {
                        model.push(.newProjectChat(projectID))
                    }
                    Text("NXOR will see the project media and brand kit").font(NX.F.body(12)).foregroundStyle(NX.C.ink3).frame(maxWidth: .infinity)
                }
                .padding(16)
                .padding(.bottom, 60)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Button { withAnimation(NX.Motion.hover) { view = .studio } } label: {
                        HStack(spacing: 8) {
                            ForEach(Array(media.prefix(3).enumerated()), id: \.offset) { i, item in
                                AsyncImage(url: item.previewURL) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder(seed: i) }
                                }
                                .frame(width: 34, height: 34).clipped()
                            }
                            Text("Media · \(media.count)").font(NX.F.body(14, .semibold)).foregroundStyle(NX.C.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(NX.C.ink3)
                        }
                        .padding(10)
                        .background(NX.C.tint.opacity(0.035))
                    }
                    .buttonStyle(.plain)

                    SectionLabel("Chats · \(chats.count)").padding(.top, 8)
                    ForEach(chats) { chat in
                        Button { model.push(.projectChat(chat.id)) } label: { chatRow(chat) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { Task { await model.deleteChat(chat.id) } } label: { Label("Delete chat", systemImage: "trash") }
                            }
                    }
                }
                .padding(16)
                .padding(.bottom, 80)
            }
        }
    }

    private func chatRow(_ chat: ChatThread) -> some View {
        HStack(spacing: 12) {
            Text("Aa").font(NX.F.body(13, .semibold)).foregroundStyle(NX.C.inkSoft)
                .frame(width: 32, height: 32).background(NX.C.tint.opacity(0.06))
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.title).font(NX.F.body(15, .semibold)).foregroundStyle(NX.C.ink).lineLimit(1)
                Text("\(model.tiers.first { $0.tier == chat.tier }?.title ?? chat.tier.capitalized) · \(chat.updatedAt.relativeShort)")
                    .font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
            }
            Spacer()
        }
        .padding(12)
        .background(NX.C.tint.opacity(0.035))
        .contentShape(Rectangle())
    }

    // MARK: 12s media first

    private var mediaView: some View {
        VStack(spacing: 8) {
            Button { withAnimation(NX.Motion.hover) { view = .chat } } label: {
                HStack(spacing: 12) {
                    Text("Aa").font(NX.F.body(13, .semibold)).foregroundStyle(NX.C.inkSoft)
                        .frame(width: 32, height: 32).background(NX.C.tint.opacity(0.06))
                    Text("Chats · \(chats.count)\(chats.first.map { " · last: \($0.title)" } ?? "")")
                        .font(NX.F.body(14, .semibold)).foregroundStyle(NX.C.ink).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(NX.C.ink3)
                }
                .padding(10)
                .background(NX.C.tint.opacity(0.035))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            let pending = model.studio.jobs.filter { $0.status != .completed && model.studio.projectID == projectID }
            MediaGrid(
                items: media.filter { filter.matches($0) },
                jobs: pending,
                filter: $filter,
                counts: Dictionary(uniqueKeysWithValues: MediaFilter.allCases.map { f in (f, media.filter { f.matches($0) }.count) }),
                selection: $selection,
                loading: !library.loaded,
                showFilter: media.count >= 12,
                onDelete: { items in Task { await library.delete(items, app: model) } }
            )
        }
    }
}

// MARK: - 13 project info and settings

struct ProjectInfoSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let projectID: String
    @State private var meta = ProjectMeta()
    @State private var editingAbout = false
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmDelete = false

    private var project: Project? { model.project(projectID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SheetCancelButton(title: "Close") { dismiss() }
                Text((project?.name ?? "").uppercased()).font(NX.F.display(18)).foregroundStyle(NX.C.inkSoft).lineLimit(1)
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    row("About · instructions", value: meta.about.isEmpty ? "Tell NXOR what this project is about" : meta.about, action: "Edit") { editingAbout = true }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            SectionLabel("Brand kit")
                            Spacer()
                            Text(meta.kind.shortTitle).font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                        }
                        HStack(spacing: 6) {
                            if meta.brandColors.isEmpty {
                                Text("No brand colors").font(NX.F.body(14)).foregroundStyle(NX.C.ink3)
                            }
                            ForEach(Array(meta.brandColors.enumerated()), id: \.offset) { i, _ in
                                TilePlaceholder(seed: i).frame(width: 22, height: 22)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    row("Files for chat", value: "\(meta.referenceIDs.count) files", action: nil) {}
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel("Default format")
                        HStack(spacing: 0) {
                            ForEach(["Auto", "9:16", "4:5", "1:1", "16:9"], id: \.self) { f in
                                SkewTag(title: f, selected: meta.defaultFormat == f) { meta.defaultFormat = f; save() }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    Button("Rename") { newName = project?.name ?? ""; renaming = true }
                        .font(NX.F.body(16)).foregroundStyle(NX.C.ink).frame(minHeight: 48)
                    Button("Delete project") { confirmDelete = true }
                        .font(NX.F.body(16)).foregroundStyle(NX.C.danger).frame(minHeight: 48)
                }
            }
        }
        .padding(16)
        .onAppear { meta = model.meta(projectID) }
        .sheet(isPresented: $editingAbout) {
            PromptEditorSheet(text: meta.about) { meta.about = $0; save() }
                .nxSheetBackground()
        }
        .alert("Rename project", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Save") { if let p = project { Task { await model.renameProject(p, to: newName) } } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete \(project?.name ?? "project")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete project", role: .destructive) {
                guard let p = project else { return }
                dismiss()
                model.path = []
                Task { await model.deleteProject(p) }
            }
        }
    }

    private func save() { model.setMeta(meta, for: projectID) }

    private func row(_ title: String, value: String, action: String?, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(title)
                    Text(value).font(NX.F.body(14)).foregroundStyle(NX.C.ink).lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer()
                if let action { Text("\(action) ›").font(NX.F.body(13)).foregroundStyle(NX.C.ink3) }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 12a / 12f project chat

struct ProjectChatScreen: View {
    @Environment(AppModel.self) private var model
    var chatID: String?
    var newInProject: String? = nil
    @State private var draft = ""
    @State private var activeID: String?

    private var chat: ChatThread? {
        guard let id = activeID ?? chatID else { return nil }
        return model.chats.first { $0.id == id }
    }

    private var projectID: String? { chat?.projectID ?? newInProject }

    private var subtitle: String {
        let projectName = model.project(projectID)?.name ?? "project"
        guard let chat else { return "in \(projectName)" }
        let tierTitle = model.tiers.first { tier in tier.tier == chat.tier }?.title ?? chat.tier.capitalized
        return "\(tierTitle) · in \(projectName)"
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader {
                BackLink(title: "Project")
            } title: {
                ScreenTitle(text: chat?.title ?? "New chat", subtitle: subtitle)
            } trailing: {
                Menu {
                    if let id = chat?.id {
                        Button(role: .destructive) {
                            Task { await model.deleteChat(id) }
                            model.path.removeLast()
                        } label: { Label("Delete chat", systemImage: "trash") }
                    }
                } label: {
                    SkewIconFace(systemName: "ellipsis")
                }
                .accessibilityLabel("Chat actions")
            }
            if model.offline { OfflineBanner() }
            if let chat, !chat.messages.isEmpty {
                ChatMessagesView(chat: chat) { idea in model.send(idea) }
            } else {
                emptyState
            }
        }
        .background(chat == nil ? AnyView(BackgroundAura()) : AnyView(NX.C.bg.ignoresSafeArea()))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposer(placeholder: chat == nil ? "Ask about this project…" : "Reply…", projectID: projectID, chatID: chat?.id, draft: $draft) { text, urls in
                if chat == nil, let projectID { model.startProjectChat(projectID) } else { model.currentChatID = chat?.id }
                model.send(text, attachments: urls)
                activeID = model.currentChatID
            }
        }
        .onAppear {
            if let chatID {
                model.currentChatID = chatID
                if model.auth == .live { Task { await model.loadChat(chatID) } }
            } else {
                model.currentChatID = nil
            }
        }
    }

    /// 12a: "NXOR knows this project" + ideas.
    private var emptyState: some View {
        let meta = model.meta(projectID)
        let ideas: [String] = {
            switch meta.kind {
            case .realEstate: return ["Write the listing text in English and Arabic", "Script for a 30-second video"]
            case .brand: return ["Plan a week of posts", "Write a launch caption"]
            case .avatar: return ["Script a 30-second intro", "Ideas for 5 reels with me"]
            case .product: return ["Write a product description", "Ideas for a product shoot"]
            case .folder: return ["What can you do in this project?"]
            }
        }()
        return ScrollView {
            VStack(spacing: 12) {
                Spacer(minLength: 80)
                TilePlaceholder(seed: 0).frame(width: 46, height: 46)
                Text("NXOR KNOWS THIS PROJECT").font(NX.F.display(20)).foregroundStyle(NX.C.inkSoft).multilineTextAlignment(.center)
                Text("Uses its instructions\(meta.referenceIDs.isEmpty ? "" : ", \(meta.referenceIDs.count) files")\(meta.hasBrandKit ? " and brand kit" : "")")
                    .font(NX.F.body(13)).foregroundStyle(NX.C.ink3)
                Spacer(minLength: 80)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ideas, id: \.self) { idea in
                        SkewButton(title: idea, size: .m, style: .dark, fullWidth: true) { draft = idea }
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
    }
}
