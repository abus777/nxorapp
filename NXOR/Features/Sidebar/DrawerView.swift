import SwiftUI

/// ≡ menu (02 / 02b): search, Chat | Studio segment, recent chats or Create, projects, profile.
struct DrawerView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var tab: AppSection = .chat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SheetCancelButton { withAnimation(NX.Motion.pop) { model.sidebarOpen = false } }
                Spacer()
                NXLogo(size: 17)
                Spacer()
                Color.clear.frame(width: 80, height: 1)
            }
            .padding(.bottom, 14)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(NX.C.muted)
                TextField("", text: $query, prompt: Text("Search").foregroundColor(NX.C.muted))
                    .font(NX.F.body(15))
                    .foregroundStyle(NX.C.ink)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(NX.C.tint.opacity(0.05))
            .padding(.bottom, 14)

            SkewSegment(items: [(.chat, "Chat"), (.studio, "Studio")], selection: $tab)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if tab == .chat { chatTab } else { studioTab }
                    projectsBlock.padding(.top, 18)
                }
            }
            .scrollIndicators(.hidden)

            footer
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(GlassBackground(opacity: 0.8).ignoresSafeArea())
        .overlay(alignment: .trailing) { Rectangle().fill(NX.C.tint.opacity(0.06)).frame(width: 1).ignoresSafeArea() }
        .onAppear { tab = model.section == .studio ? .studio : .chat }
    }

    private var filteredChats: [ChatThread] {
        let loose = model.chats.filter { $0.projectID == nil }
        guard !query.isEmpty else { return loose }
        return model.chats.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var chatTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkewButton(title: "New chat", icon: "plus", size: .l, style: .metal, fullWidth: true) { model.newChat() }
                .padding(.bottom, 16)
            SectionLabel("Recent").padding(.bottom, 6)
            if filteredChats.isEmpty {
                Text(query.isEmpty ? "Your chats will show up here." : "Nothing found for “\(query)”.")
                    .font(NX.F.body(14)).foregroundStyle(NX.C.ink3)
                    .padding(.vertical, 10)
            }
            ForEach(filteredChats) { chat in
                Button { model.openChat(chat.id) } label: {
                    Text(chat.title)
                        .font(NX.F.body(15))
                        .foregroundStyle(chat.id == model.currentChatID && model.section == .chat ? NX.C.ink : NX.C.ink2)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(chat.id == model.currentChatID && model.section == .chat ? NX.C.tint.opacity(0.06) : .clear)
                        .overlay(alignment: .leading) {
                            if chat.id == model.currentChatID && model.section == .chat { Rectangle().fill(NX.C.accent).frame(width: 2) }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { model.moveChatID = chat.id } label: { Label("Add to project…", systemImage: "folder.badge.plus") }
                    Button(role: .destructive) { Task { await model.deleteChat(chat.id) } } label: { Label("Delete chat", systemImage: "trash") }
                }
            }
        }
    }

    private var studioTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Create").padding(.bottom, 6)
            createRow("Image", icon: "photo", mode: .image)
            createRow("Video", icon: "video", mode: .video)
            createRow("Audio", icon: "waveform", mode: .audio)
            Button {
                model.open(.studio)
            } label: {
                rowLabel("All my work", icon: "square.grid.2x2", selected: model.section == .studio && model.path.isEmpty)
            }
            .buttonStyle(.plain)
        }
    }

    private func createRow(_ title: String, icon: String, mode: CreateMode) -> some View {
        Button {
            model.studioDraft = StudioDraft(prompt: "", mode: mode)
            model.open(.studio)
            model.showCreateSheet = true
        } label: {
            rowLabel(title, icon: icon, selected: false)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(_ title: String, icon: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? NX.C.btnInk : NX.C.inkSoft)
                .frame(width: 30, height: 24)
                .background(selected ? AnyView(Parallelogram().fill(NX.G.silver)) : AnyView(SkewFill(style: .glass)))
            Text(title).font(NX.F.body(15)).foregroundStyle(NX.C.ink)
            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var projectsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { model.open(.projects) } label: {
                    HStack(spacing: 6) {
                        SectionLabel("Projects")
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(NX.C.muted)
                    }
                    .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    withAnimation(NX.Motion.pop) { model.sidebarOpen = false }
                    model.showNewProject = true
                } label: {
                    Image(systemName: "plus").font(.system(size: 16)).foregroundStyle(NX.C.ink).frame(width: 44, height: 32)
                }
                .accessibilityLabel("New project")
            }
            ForEach(model.userProjects.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { project in
                Button {
                    model.section = tab
                    model.path = [.project(project.id, tab == .studio ? .studio : .chat)]
                    withAnimation(NX.Motion.pop) { model.sidebarOpen = false }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(NX.C.inkSoft)
                            .frame(width: 30, height: 24)
                            .background(SkewFill(style: .glass))
                        Text(project.name).font(NX.F.body(15)).foregroundStyle(NX.C.ink).lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                model.push(.account)
            } label: {
                HStack(spacing: 12) {
                    HatchAvatar(size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.account.name).font(NX.F.body(15, .semibold)).foregroundStyle(NX.C.ink).lineLimit(1)
                        Text("\(model.account.planName) · \(Int(model.account.available).formatted()) credits")
                            .font(NX.F.body(12)).foregroundStyle(NX.C.ink3).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.up").font(.system(size: 11)).foregroundStyle(NX.C.muted)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account and credits")

            HStack(spacing: 2) {
                SkewButton(title: "Presets", size: .m, style: .dark, fullWidth: true) {
                    model.section = .studio
                    model.path = [.presets]
                    withAnimation(NX.Motion.pop) { model.sidebarOpen = false }
                }
                SkewButton(title: "Library", size: .m, style: .dark, fullWidth: true) { model.open(.studio) }
                SkewIconButton(systemName: "info", label: "Help") { model.push(.help) }
            }
        }
        .padding(.top, 10)
        .overlay(alignment: .top) { Rectangle().fill(NX.C.tint.opacity(0.06)).frame(height: 1) }
    }
}
