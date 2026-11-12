import SwiftUI
import AVKit
import UIKit
import Photos
import PhotosUI

struct LibraryScreen: View {
    @Environment(AppModel.self) private var app
    @State private var library = LibraryModel()
    @State private var tab = "generations"
    @State private var filter = "all"
    @State private var viewing: LibraryItem?
    @State private var selecting = false
    @State private var selection: Set<String> = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showMove = false
    @State private var confirmDelete = false
    @State private var dropTarget: String?

    private var source: [LibraryItem] { tab == "uploads" ? library.uploads : library.items }

    private var filtered: [LibraryItem] {
        switch filter {
        case "image": return source.filter { !$0.isVideo }
        case "video": return source.filter { $0.isVideo }
        default: return source
        }
    }

    private var selectedItems: [LibraryItem] { filtered.filter { selection.contains($0.id) } }

    private var sections: [(String, [LibraryItem])] {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        var order: [String] = []
        var groups: [String: [LibraryItem]] = [:]
        for item in filtered {
            let key = f.string(from: item.createdAt).uppercased()
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(item)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    FolderBar(dropTarget: $dropTarget) { payloads, project in
                        let items = payloads.compactMap { app.assetIndex[$0] }
                        guard !items.isEmpty else { return false }
                        Task { await library.move(items, to: project, app: app) }
                        return true
                    }

                    HStack(spacing: 10) {
                        NXSegmented(options: [("generations", "Generations"), ("uploads", "Uploads")], selection: $tab)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 6) {
                        NXChip(title: "All", selected: filter == "all") { filter = "all" }
                        NXChip(title: "Images", selected: filter == "image") { filter = "image" }
                        NXChip(title: "Videos", selected: filter == "video") { filter = "video" }
                        Spacer(minLength: 0)
                        NXChip(title: selecting ? "Done" : "Select", selected: selecting) {
                            withAnimation(NX.Motion.hover) {
                                selecting.toggle()
                                selection = []
                            }
                        }
                    }

                    content
                }
                .padding(16)
            }
            .refreshable { await library.load(app: app, force: true) }

            if selecting { selectionBar }
        }
        .task(id: app.currentProjectID) {
            await library.load(app: app)
            if UserDefaults.standard.bool(forKey: "select"), !selecting {
                selecting = true
                selection = Set(filtered.prefix(2).map(\.id))
            }
        }
        .onChange(of: pickerItems) { _, items in
            pickerItems = []
            tab = "uploads"
            for item in items {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await library.upload(image, app: app)
                    }
                }
            }
        }
        .fullScreenCover(item: $viewing) { item in
            AssetViewer(items: filtered, current: item) { deleted in
                Task { await library.delete([deleted], app: app) }
            }
        }
        .confirmationDialog("Move \(selection.count) item\(selection.count == 1 ? "" : "s") to…", isPresented: $showMove, titleVisibility: .visible) {
            ForEach(app.projects.filter { $0.id != app.currentProjectID }) { project in
                Button(project.name) {
                    let items = selectedItems
                    selection = []
                    selecting = false
                    Task { await library.move(items, to: project, app: app) }
                }
            }
        }
        .confirmationDialog("Delete \(selection.count) item\(selection.count == 1 ? "" : "s")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                let items = selectedItems
                selection = []
                selecting = false
                Task { await library.delete(items, app: app) }
            }
        } message: {
            Text("They will be removed from your NXOR library.")
        }
        .sensoryFeedback(.success, trigger: library.uploads.count)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            DisplayTitle("Library", size: 34)
            MetaLabel("\(library.items.count + library.uploads.count) assets", size: 13)
            Spacer()
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                HStack(spacing: 8) {
                    if library.uploading > 0 { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.up") }
                    Text("UPLOAD").font(NX.F.mono(12, .semibold)).tracking(2)
                }
                .foregroundStyle(NX.C.ink)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !library.loaded || library.loading {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in Skeleton().aspectRatio(1, contentMode: .fit) }
            }
        } else if filtered.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MetaLabel(tab == "uploads" ? "No uploads in this folder" : "Nothing in this folder yet")
                Text(tab == "uploads"
                     ? "Upload photos to use them as references in Studio and presets."
                     : "Images and videos you create appear here. Long-press a tile and drag it onto a folder to move it.")
                    .font(NX.F.body(15)).foregroundStyle(NX.C.ink3)
            }
            .padding(.top, 30)
        } else {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                MetaLabel(section.0, color: NX.C.ink3, size: 12).padding(.top, 8)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(section.1) { item in
                        tile(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ item: LibraryItem) -> some View {
        let isSelected = selection.contains(item.id)
        let base = LibraryTile(item: item)
            .overlay(alignment: .topTrailing) {
                if selecting {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? NX.C.accent : NX.C.ink)
                        .padding(8)
                }
            }
            .overlay(Rectangle().strokeBorder(isSelected ? NX.C.accent : .clear, lineWidth: 2))
            .onTapGesture {
                if selecting {
                    if isSelected { selection.remove(item.id) } else { selection.insert(item.id) }
                } else {
                    viewing = item
                }
            }
        if selecting {
            base
        } else {
            base
                .draggable(item.dragPayload) { DragPreview(item: item) }
                .contextMenu {
                    Button { viewing = item } label: { Label("Open", systemImage: "arrow.up.left.and.arrow.down.right") }
                    if !item.isVideo {
                        Button { app.sendToChat([item]) } label: { Label("Send to chat", systemImage: "bubble.left.and.text.bubble.right") }
                    }
                    Menu {
                        ForEach(app.projects.filter { $0.id != app.currentProjectID }) { project in
                            Button(project.name) { Task { await library.move([item], to: project, app: app) } }
                        }
                    } label: { Label("Move to…", systemImage: "folder") }
                    Button(role: .destructive) { Task { await library.delete([item], app: app) } } label: { Label("Delete", systemImage: "trash") }
                }
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 10) {
            MetaLabel("\(selection.count) selected", color: NX.C.ink, size: 11)
            Spacer()
            Button {
                selection = selection.count == filtered.count ? [] : Set(filtered.map(\.id))
            } label: { MetaLabel(selection.count == filtered.count ? "Clear" : "Select all", color: NX.C.accent, size: 11) }
            Button { showMove = true } label: {
                Label("Move", systemImage: "folder").labelStyle(.iconOnly)
                    .foregroundStyle(NX.C.ink).frame(width: 42, height: 40)
                    .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
            }
            .disabled(selection.isEmpty || app.projects.count < 2)
            Button { confirmDelete = true } label: {
                Image(systemName: "trash")
                    .foregroundStyle(NX.C.danger).frame(width: 42, height: 40)
                    .overlay(Rectangle().strokeBorder(NX.C.danger.opacity(0.6), lineWidth: 1))
            }
            .disabled(selection.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(NX.C.surface)
        .overlay(alignment: .top) { Hairline() }
    }

    private var columns: [GridItem] { [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)] }
}

/// Horizontal list of folders (NXOR projects). Tap to open, long-press for rename/delete, drop tiles to move them.
struct FolderBar: View {
    @Environment(AppModel.self) private var app
    @Binding var dropTarget: String?
    let onDrop: ([String], Project) -> Bool

    @State private var showNew = false
    @State private var newName = ""
    @State private var renaming: Project?
    @State private var renameText = ""
    @State private var deleting: Project?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(app.projects) { project in
                    folderChip(project)
                }
                Button { newName = ""; showNew = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text("NEW FOLDER").font(NX.F.mono(11, .semibold)).tracking(1.6)
                    }
                    .foregroundStyle(NX.C.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .overlay(Rectangle().strokeBorder(NX.C.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(PressStyle())
            }
            .padding(.vertical, 2)
        }
        .alert("New folder", isPresented: $showNew) {
            TextField("Folder name", text: $newName)
            Button("Create") {
                let name = newName
                Task {
                    if let project = await app.createProject(name) { app.currentProjectID = project.id }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename folder", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Folder name", text: $renameText)
            Button("Save") {
                if let project = renaming {
                    let name = renameText
                    Task { await app.renameProject(project, to: name) }
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("Delete folder “\(deleting?.name ?? "")”?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete folder", role: .destructive) {
                if let project = deleting { Task { await app.deleteProject(project) } }
                deleting = nil
            }
        } message: {
            Text("The folder is removed. What happens to its items is decided by NXOR.")
        }
    }

    private func folderChip(_ project: Project) -> some View {
        let current = project.id == app.currentProjectID
        let targeted = dropTarget == project.id
        return Button {
            withAnimation(NX.Motion.hover) { app.currentProjectID = project.id }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: current ? "folder.fill" : "folder")
                Text(project.name.uppercased()).font(NX.F.mono(12, .semibold)).tracking(1.6).lineLimit(1)
            }
            .foregroundStyle(current ? NX.C.ink : NX.C.ink2)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(targeted ? NX.C.accent.opacity(0.18) : (current ? NX.C.raised : Color.clear))
            .overlay(Rectangle().strokeBorder(targeted ? NX.C.accent : (current ? NX.C.inkSoft.opacity(0.8) : NX.C.line), lineWidth: targeted ? 2 : 1))
            .scaleEffect(targeted ? 1.06 : 1)
            .animation(NX.Motion.pop, value: targeted)
        }
        .buttonStyle(PressStyle())
        .dropDestination(for: String.self) { payloads, _ in
            onDrop(payloads, project)
        } isTargeted: { inside in
            dropTarget = inside ? project.id : (dropTarget == project.id ? nil : dropTarget)
        }
        .contextMenu {
            Button { renameText = project.name; renaming = project } label: { Label("Rename", systemImage: "pencil") }
            if !project.isDefault {
                Button(role: .destructive) { deleting = project } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }
}

struct DragPreview: View {
    let item: LibraryItem

    var body: some View {
        AsyncImage(url: item.previewURL) { phase in
            if let image = phase.image { image.resizable().scaledToFill() } else { NX.C.raised }
        }
        .frame(width: 96, height: 96)
        .clipped()
        .overlay(Rectangle().strokeBorder(NX.C.accent, lineWidth: 2))
        .rotationEffect(.degrees(-4))
    }
}

struct LibraryTile: View {
    let item: LibraryItem

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: item.previewURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Image(systemName: item.isVideo ? "video" : "photo").foregroundStyle(NX.C.muted)
                    } else {
                        Skeleton()
                    }
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    if item.source == .reference {
                        Text("REFERENCE").font(NX.F.mono(9, .semibold)).tracking(1.4)
                    }
                    if let d = item.duration, item.isVideo {
                        Image(systemName: "video.fill").font(.system(size: 9))
                        Text(String(format: "0:%02d", Int(d.rounded()))).font(NX.F.mono(10, .semibold))
                    }
                }
                .foregroundStyle(NX.C.ink)
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(Color.black.opacity(item.source == .reference || item.isVideo ? 0.6 : 0))
                .padding(8)
            }
            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

struct AssetViewer: View {
    let items: [LibraryItem]
    var onDelete: ((LibraryItem) -> Void)?
    @State var current: LibraryItem
    @Environment(\.dismiss) private var dismiss
    @State private var showAllPrompt = false
    @State private var confirmDelete = false
    @State private var toast: String?

    init(items: [LibraryItem], current: LibraryItem, onDelete: ((LibraryItem) -> Void)? = nil) {
        self.items = items
        self.onDelete = onDelete
        _current = State(initialValue: current)
    }

    private var index: Int { items.firstIndex(of: current) ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(NX.C.ink)
                }
                Spacer()
                DisplayTitle(current.isVideo ? "Video" : "Image", size: 20)
                Spacer()
                Menu {
                    if let url = current.url {
                        ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                        Button { Task { await saveToPhotos(url) } } label: { Label("Save to Photos", systemImage: "square.and.arrow.down") }
                    }
                    Button { UIPasteboard.general.string = current.prompt } label: { Label("Copy prompt", systemImage: "doc.on.doc") }
                    if onDelete != nil {
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NX.C.ink)
                        .frame(width: 40, height: 40)
                        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 56)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    media
                        .frame(maxWidth: .infinity)
                        .background(NX.C.surface)
                        .overlay(alignment: .leading) { navButton("chevron.left", enabled: index > 0) { current = items[index - 1] } }
                        .overlay(alignment: .trailing) { navButton("chevron.right", enabled: index < items.count - 1) { current = items[index + 1] } }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            MetaLabel("Prompt")
                            Spacer()
                            Button { UIPasteboard.general.string = current.prompt } label: { MetaLabel("Copy", color: NX.C.accent) }
                        }
                        Text(current.prompt)
                            .font(NX.F.body(16))
                            .foregroundStyle(NX.C.ink)
                            .lineLimit(showAllPrompt ? nil : 4)
                        if current.prompt.count > 160 {
                            Button { showAllPrompt.toggle() } label: { MetaLabel(showAllPrompt ? "Less" : "See all", color: NX.C.accent) }
                        }
                        Hairline().padding(.vertical, 6)
                        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 18) {
                            meta("Model", current.model)
                            meta("Quality", qualityLabel)
                            meta("Size", sizeLabel)
                            meta(current.isVideo ? "Length" : "Render time", current.isVideo ? lengthLabel : renderLabel)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .background(NX.C.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            if let toast {
                MetaLabel(toast, color: NX.C.ink, size: 11)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(NX.C.raised)
                    .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .confirmationDialog("Delete this \(current.isVideo ? "video" : "image")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?(current)
                dismiss()
            }
        } message: {
            Text("It will be removed from your NXOR library.")
        }
    }

    @MainActor
    private func saveToPhotos(_ url: URL) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { show("Allow Photos access in Settings"); return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let isVideo = current.isVideo
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + (isVideo ? ".mp4" : ".jpg"))
            try data.write(to: file)
            try await PHPhotoLibrary.shared().performChanges {
                if isVideo {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: file)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: file)
                }
            }
            show("Saved to Photos")
        } catch {
            show("Couldn't save")
        }
    }

    private func show(_ message: String) {
        withAnimation(NX.Motion.pop) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(NX.Motion.pop) { toast = nil }
        }
    }

    @ViewBuilder
    private var media: some View {
        if current.isVideo, let url = current.url, url.pathExtension.lowercased() != "jpg" {
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(aspect, contentMode: .fit)
                .id(current.id)
        } else {
            AsyncImage(url: current.url ?? current.previewURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Skeleton().aspectRatio(aspect, contentMode: .fit)
                }
            }
            .id(current.id)
        }
    }

    private var aspect: CGFloat {
        guard let w = current.width, let h = current.height, h > 0 else { return 1 }
        return CGFloat(w) / CGFloat(h)
    }

    private func navButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NX.C.ink)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.6))
        }
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
        .padding(10)
    }

    private func meta(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MetaLabel(title, size: 10)
            Text(value).font(NX.F.body(16)).foregroundStyle(NX.C.ink)
        }
    }

    private var sizeLabel: String {
        guard let w = current.width, let h = current.height else { return "—" }
        return "\(w) × \(h)"
    }

    private var qualityLabel: String {
        guard let w = current.width, let h = current.height else { return "—" }
        let side = max(w, h)
        if side >= 3800 { return "4K" }
        if side >= 1900 { return current.isVideo ? "1080p" : "2K" }
        if side >= 1200 { return current.isVideo ? "720p" : "1K" }
        return "SD"
    }

    private var renderLabel: String {
        guard let s = current.renderSeconds else { return "—" }
        return String(format: "%02d:%04.1f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60))
    }

    private var lengthLabel: String {
        guard let d = current.duration else { return "—" }
        return String(format: "0:%02d", Int(d.rounded()))
    }
}
