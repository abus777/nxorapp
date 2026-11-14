import SwiftUI
import PhotosUI
import UIKit

/// 10: projects list — "3 chats · 18 media".
struct ProjectsScreen: View {
    @Environment(AppModel.self) private var model
    var pushed = false
    @State private var query = ""
    @State private var renaming: Project?
    @State private var newName = ""
    @State private var deleting: Project?

    private var projects: [Project] {
        model.userProjects.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader {
                if pushed {
                    BackLink(title: "Back")
                } else {
                    SkewIconButton(systemName: "line.3.horizontal", label: "Menu") {
                        withAnimation(NX.Motion.pop) { model.sidebarOpen = true }
                    }
                }
            } title: {
                ScreenTitle(text: "Projects", size: 20)
            } trailing: {
                SkewButton(title: "New", icon: "plus", size: .s, style: .metal) { model.showNewProject = true }
            }

            ScrollView {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(NX.C.muted)
                        TextField("", text: $query, prompt: Text("Search projects").foregroundColor(NX.C.muted))
                            .font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(NX.C.tint.opacity(0.05))

                    if projects.isEmpty {
                        VStack(spacing: 12) {
                            Text("NO PROJECTS YET").font(NX.F.display(20)).foregroundStyle(NX.C.inkSoft)
                            Text("A project keeps chats, generations, files and instructions together.")
                                .font(NX.F.body(14)).foregroundStyle(NX.C.ink3).multilineTextAlignment(.center)
                            SkewButton(title: "New project", size: .l, style: .metal) { model.showNewProject = true }
                        }
                        .padding(.top, 60)
                    }

                    ForEach(projects) { project in
                        ProjectCard(project: project)
                            .onTapGesture { model.push(.project(project.id, model.section == .studio ? .studio : .chat)) }
                            .contextMenu {
                                Button { newName = project.name; renaming = project } label: { Label("Rename", systemImage: "pencil") }
                                Button(role: .destructive) { deleting = project } label: { Label("Delete project", systemImage: "trash") }
                            }
                    }
                }
                .padding(16)
            }
        }
        .background(NX.C.bg.ignoresSafeArea())
        .alert("Rename project", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") { if let p = renaming { Task { await model.renameProject(p, to: newName) } } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete \(deleting?.name ?? "project")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete project", role: .destructive) { if let p = deleting { Task { await model.deleteProject(p) } } }
        } message: {
            Text("Chats stay in your history. Media moves out of the project.")
        }
    }
}

struct ProjectCard: View {
    @Environment(AppModel.self) private var model
    let project: Project
    @State private var library = LibraryModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    let items = library.items + library.uploads
                    Color.clear
                        .frame(height: 64)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            if i < items.count {
                                AsyncImage(url: items[i].previewURL) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder(seed: i) }
                                }
                            } else {
                                TilePlaceholder(seed: i)
                            }
                        }
                        .clipped()
                }
            }
            Text(project.name.uppercased()).font(NX.F.display(17)).foregroundStyle(NX.C.inkSoft).lineLimit(1)
            let meta = model.meta(project.id)
            if !meta.about.isEmpty {
                Text(meta.about).font(NX.F.body(13)).foregroundStyle(NX.C.ink2).lineLimit(1)
            }
            Text("\(model.chats(in: project.id).count) chats · \(library.loaded ? "\(library.items.count + library.uploads.count)" : "…") media · \(meta.kind.shortTitle)")
                .font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
        }
        .padding(12)
        .background(NX.C.tint.opacity(0.035))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .task {
            library.scope = project.id
            await library.load(app: model)
        }
    }
}

// MARK: - 11 / 11b new project in two steps

struct NewProjectFlow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ProjectKind = .avatar
    @State private var step = 1
    @State private var name = ""
    @State private var about = ""
    @State private var format = "Auto"
    @State private var photos: [UIImage] = []
    @State private var picker: [PhotosPickerItem] = []
    @State private var creating = false
    @State private var colors: [Color] = [Color(hex: 0x0B2545), Color(hex: 0xC9A227)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if step == 1 { chooseKind } else { details }
        }
        .padding(16)
        .onChange(of: picker) { _, items in
            picker = []
            for item in items {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { photos.append(image) }
                }
            }
        }
    }

    private var chooseKind: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SheetCancelButton { dismiss() }
                Spacer()
                Text("NEW PROJECT").font(NX.F.display(18)).foregroundStyle(NX.C.inkSoft)
                Spacer()
                Color.clear.frame(width: 80, height: 1)
            }
            Text("What is it for? NXOR will ask only what this needs.").font(NX.F.body(14)).foregroundStyle(NX.C.ink3)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(ProjectKind.allCases) { k in
                        Button { kind = k } label: {
                            SkewCard(selected: kind == k) {
                                HStack(spacing: 12) {
                                    Image(systemName: k.icon).font(.system(size: 18)).foregroundStyle(NX.C.inkSoft)
                                        .frame(width: 44, height: 44).background(TilePlaceholder(seed: k.title.count))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(k.title).font(NX.F.body(15, .semibold)).foregroundStyle(NX.C.ink)
                                        Text(k.subtitle).font(NX.F.body(12)).foregroundStyle(NX.C.ink3).multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    if kind == k { Image(systemName: "checkmark").foregroundStyle(NX.C.inkSoft) }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(kind == k ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 6)
            }
            SkewButton(title: "Continue", size: .l, style: .metal, fullWidth: true) {
                format = kind == .realEstate || kind == .avatar ? "9:16" : "Auto"
                withAnimation(NX.Motion.pop) { step = 2 }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                BackLink(title: "Back") { withAnimation(NX.Motion.pop) { step = 1 } }
                Text(kind.shortTitle.uppercased()).font(NX.F.display(18)).foregroundStyle(NX.C.inkSoft)
                Spacer()
                SkewButton(title: "Skip", size: .s, style: .glass) { create(skip: true) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel("Name")
                        TextField("", text: $name, prompt: Text(kind.namePlaceholder).foregroundColor(NX.C.muted))
                            .font(NX.F.body(16)).foregroundStyle(NX.C.ink)
                            .padding(.horizontal, 12).frame(height: 48)
                            .background(NX.C.tint.opacity(0.05))
                    }
                    if let label = kind.photosLabel {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                SectionLabel(label)
                                Spacer()
                                Text("\(photos.count) / 10\(kind == .avatar ? " · 3+ recommended" : "")").font(NX.F.body(11)).foregroundStyle(NX.C.ink3)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    PhotosPicker(selection: $picker, maxSelectionCount: 10, matching: .images) {
                                        Image(systemName: "plus").foregroundStyle(NX.C.ink2)
                                            .frame(width: 64, height: 64)
                                            .overlay(Rectangle().strokeBorder(NX.C.tint.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                                    }
                                    .accessibilityLabel("Add photos")
                                    ForEach(Array(photos.enumerated()), id: \.offset) { _, image in
                                        Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64).clipped()
                                    }
                                }
                            }
                        }
                    }
                    if kind == .brand {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel("Brand colors")
                            HStack(spacing: 10) {
                                ForEach(colors.indices, id: \.self) { i in
                                    ColorPicker("Color \(i + 1)", selection: $colors[i]).labelsHidden()
                                }
                                Button { colors.append(.gray) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                                    .foregroundStyle(NX.C.ink2)
                                    .accessibilityLabel("Add color")
                            }
                        }
                    }
                    if kind != .folder {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel("Instructions for NXOR (optional)")
                            TextField("", text: $about, prompt: Text(kind == .realEstate ? "e.g. Ad videos for a villa listing, EN + AR" : "e.g. Warm tone, no text on images").foregroundColor(NX.C.muted), axis: .vertical)
                                .font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                                .lineLimit(2...5)
                                .padding(12)
                                .background(NX.C.tint.opacity(0.05))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel("Default format")
                            HStack(spacing: 0) {
                                ForEach(["Auto", "9:16", "1:1", "16:9"], id: \.self) { f in
                                    SkewTag(title: f, selected: format == f) { format = f }
                                }
                            }
                        }
                    }
                    Text("Everything here can be changed later in project settings").font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                }
            }
            SkewButton(title: creating ? "Creating…" : "Create project", size: .l, style: .metal, fullWidth: true, enabled: !creating) { create(skip: false) }
        }
    }

    private func create(skip: Bool) {
        let title = name.trimmingCharacters(in: .whitespaces).isEmpty ? "\(kind.shortTitle) project" : name
        creating = true
        Task {
            defer { creating = false }
            guard let project = await model.createProject(title) else { return }
            var meta = ProjectMeta(kind: kind)
            if !skip {
                meta.about = about
                meta.defaultFormat = format
                if kind == .brand { meta.brandColors = colors.map { $0.description } }
            }
            let library = LibraryModel()
            library.scope = project.id
            for image in photos where !skip {
                if let item = await library.upload(image, app: model) { meta.referenceIDs.append(item.id) }
            }
            model.setMeta(meta, for: project.id)
            dismiss()
            model.push(.project(project.id, model.section == .studio ? .studio : .chat))
        }
    }
}

// MARK: - 05d move a chat into a project

struct MoveToProjectSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let chatID: String
    @State private var target: String?
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var confirmDelete = false

    private var chat: ChatThread? { model.chats.first { $0.id == chatID } }
    private var mediaCount: Int { chat?.messages.flatMap(\.allGenerations).count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SheetCancelButton { dismiss() }
                Spacer()
                Text("ADD CHAT TO PROJECT").font(NX.F.display(17)).foregroundStyle(NX.C.inkSoft)
                Spacer()
            }
            Text("The chat and its \(mediaCount) \(mediaCount == 1 ? "item" : "items") move together. They appear in the project media.")
                .font(NX.F.body(13)).foregroundStyle(NX.C.ink3)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(model.userProjects) { project in
                        Button { target = project.id } label: {
                            HStack(spacing: 12) {
                                TilePlaceholder(seed: project.name.count).frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name).font(NX.F.body(15, .semibold)).foregroundStyle(NX.C.ink)
                                    Text("\(model.chats(in: project.id).count) chats · \(model.meta(project.id).kind.shortTitle)").font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                                }
                                Spacer()
                                if target == project.id { Image(systemName: "checkmark").foregroundStyle(NX.C.inkSoft) }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                            .background(target == project.id ? NX.C.tint.opacity(0.05) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(target == project.id ? .isSelected : [])
                    }
                    Button {
                        dismiss()
                        model.showNewProject = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus").frame(width: 36, height: 36)
                                .overlay(Rectangle().strokeBorder(NX.C.tint.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                            Text("New project").font(NX.F.body(15, .semibold))
                            Spacer()
                        }
                        .foregroundStyle(NX.C.ink)
                        .padding(.vertical, 8).padding(.horizontal, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 18) {
                Button("Rename") { newTitle = chat?.title ?? ""; renaming = true }.underline().foregroundStyle(NX.C.ink2)
                Button("Delete chat") { confirmDelete = true }.underline().foregroundStyle(NX.C.danger)
            }
            .font(NX.F.body(13))
            .frame(minHeight: 44)
            SkewButton(title: "Move to \(model.project(target)?.name ?? "project")", size: .l, style: .metal, fullWidth: true, enabled: target != nil) {
                guard let project = model.project(target) else { return }
                Task {
                    await model.moveChat(chatID, to: project)
                    dismiss()
                    model.openChat(chatID)
                }
            }
        }
        .padding(16)
        .onAppear { target = chat?.projectID ?? model.userProjects.first?.id }
        .alert("Rename chat", isPresented: $renaming) {
            TextField("Name", text: $newTitle)
            Button("Save") { model.renameChat(chatID, to: newTitle) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this chat?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete chat", role: .destructive) {
                dismiss()
                Task { await model.deleteChat(chatID) }
            }
        }
    }
}
