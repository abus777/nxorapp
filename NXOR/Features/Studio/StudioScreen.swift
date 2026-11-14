import SwiftUI
import PhotosUI
import UIKit

enum MediaFilter: String, CaseIterable, Identifiable {
    case all, image, video, audio, refs

    var id: String { rawValue }
    var title: String { self == .refs ? "Refs" : rawValue.capitalized }

    func matches(_ item: LibraryItem) -> Bool {
        switch self {
        case .all: return true
        case .image: return item.source == .image
        case .video: return item.source == .video
        case .audio: return false
        case .refs: return item.source == .reference
        }
    }
}

/// 06 Studio: your work + a thin "✦ Describe what to create…" line that opens the create sheet.
struct StudioScreen: View {
    @Environment(AppModel.self) private var model
    @State private var library = LibraryModel()
    @State private var filter: MediaFilter = .all
    @State private var selecting = false
    @State private var selection: Set<String> = []
    @State private var importItems: [PhotosPickerItem] = []
    @State private var dropActive = false
    @State private var mode: CreateMode = .image
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            NavHeader {
                SkewIconButton(systemName: "line.3.horizontal", label: "Menu") {
                    withAnimation(NX.Motion.pop) { model.sidebarOpen = true }
                }
            } title: {
                ScreenTitle(text: "Studio", size: 20)
            } trailing: {
                PhotosPicker(selection: $importItems, maxSelectionCount: 10, matching: .images) {
                    SkewIconFace(systemName: library.uploading > 0 ? "hourglass" : "arrow.up")
                }
                .accessibilityLabel("Import photos")
                SkewIconButton(systemName: selecting ? "checkmark" : "checkmark.square", label: selecting ? "Done" : "Select") {
                    withAnimation(NX.Motion.hover) { selecting.toggle(); selection = [] }
                }
            }

            if library.loaded && allItems.isEmpty && model.studio.jobs.isEmpty {
                StudioEmptyView()
            } else {
                MediaGrid(
                    items: visible,
                    jobs: pendingJobs,
                    filter: $filter,
                    counts: counts,
                    selecting: selecting,
                    selection: $selection,
                    loading: !library.loaded,
                    onDelete: { items in Task { await library.delete(items, app: model) } }
                )
                .refreshable { await library.load(app: model, force: true) }
            }
        }
        .background(NX.C.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selecting { selectionBar } else { createLine }
        }
        .task {
            library.scope = nil
            await library.load(app: model)
        }
        .onChange(of: importItems) { _, items in
            importItems = []
            filter = .refs
            for item in items {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await library.upload(image, app: model)
                    }
                }
            }
        }
        .confirmationDialog("Delete \(selection.count) item\(selection.count == 1 ? "" : "s")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                let items = allItems.filter { selection.contains($0.id) }
                selection = []
                selecting = false
                Task { await library.delete(items, app: model) }
            }
        }
    }

    private var allItems: [LibraryItem] {
        var seen = Set<String>()
        return (model.freshItems + library.items + library.uploads).filter { seen.insert($0.id).inserted }
    }

    /// Jobs still rendering or failed (finished ones show as normal tiles).
    private var pendingJobs: [GenerationCard] {
        model.studio.jobs.filter { job in job.status != .completed }
    }

    private var visible: [LibraryItem] { allItems.filter { filter.matches($0) } }

    private var counts: [MediaFilter: Int] {
        Dictionary(uniqueKeysWithValues: MediaFilter.allCases.map { f in (f, allItems.filter { f.matches($0) }.count) })
    }

    /// Thin creation line; drop a tile here to use it as a reference (07b).
    private var createLine: some View {
        HStack(spacing: 10) {
            Button {
                model.studioDraft = StudioDraft(prompt: "", mode: mode)
                model.showCreateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle").font(.system(size: 13)).foregroundStyle(NX.C.accent)
                    Text(dropActive ? "Drop to add as reference" : "Describe what to create…")
                        .font(NX.F.body(15))
                        .foregroundStyle(dropActive ? NX.C.accent : NX.C.muted)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            ModeKey(mode: $mode)
        }
        .auraComposer(active: dropActive, highlighted: dropActive)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .dropDestination(for: String.self) { payloads, _ in
            let items = payloads.compactMap { model.assetIndex[$0] }.filter { !$0.isVideo }
            guard !items.isEmpty else { return false }
            model.studio.setMode(mode, app: model)
            items.forEach { model.studio.addReference($0, app: model) }
            model.studioDraft = StudioDraft(prompt: model.studio.prompt, mode: mode, referenceIDs: model.studio.references.map(\.id))
            model.showCreateSheet = true
            return true
        } isTargeted: { inside in
            withAnimation(NX.Motion.hover) { dropActive = inside }
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 8) {
            Text("\(selection.count) SELECTED").font(NX.F.mono(10)).tracking(1.6).foregroundStyle(NX.C.ink2)
            Spacer()
            Menu {
                ForEach(model.userProjects) { project in
                    Button(project.name) {
                        let items = allItems.filter { selection.contains($0.id) }
                        selection = []
                        selecting = false
                        Task {
                            await library.move(items, to: project, app: model)
                            model.showToast("Moved to \(project.name)")
                        }
                    }
                }
            } label: {
                SkewIconFace(systemName: "folder")
            }
            .disabled(selection.isEmpty)
            .accessibilityLabel("Add to project")
            SkewIconButton(systemName: "trash", label: "Delete") { confirmDelete = true }
                .disabled(selection.isEmpty)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .background(GlassBackground().ignoresSafeArea(edges: .bottom))
    }
}

/// Media grid with the month header and "· All ▾" filter in it (no separate filter row).
struct MediaGrid: View {
    @Environment(AppModel.self) private var model
    let items: [LibraryItem]
    var jobs: [GenerationCard] = []
    @Binding var filter: MediaFilter
    var counts: [MediaFilter: Int]
    var selecting = false
    @Binding var selection: Set<String>
    var loading = false
    var showFilter = true
    var columns = 2
    var onDelete: ([LibraryItem]) -> Void

    private var sections: [(String, [LibraryItem])] {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        var order: [String] = []
        var groups: [String: [LibraryItem]] = [:]
        for item in items {
            let key = f.string(from: item.createdAt).uppercased()
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(item)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    private var grid: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 6), count: columns) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if loading {
                    LazyVGrid(columns: grid, spacing: 6) {
                        ForEach(0..<6, id: \.self) { _ in Skeleton().aspectRatio(1, contentMode: .fit) }
                    }
                }
                if !jobs.isEmpty {
                    LazyVGrid(columns: grid, spacing: 6) {
                        ForEach(jobs) { job in JobTile(job: job) }
                    }
                }
                if sections.isEmpty && !loading {
                    header(title: "Nothing here", count: 0)
                }
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    header(title: section.0, count: index == 0 ? items.count : section.1.count, withFilter: index == 0)
                    LazyVGrid(columns: grid, spacing: 6) {
                        ForEach(section.1) { item in
                            MediaTile(item: item, selecting: selecting, selected: selection.contains(item.id)) {
                                if selecting {
                                    if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
                                } else {
                                    model.push(.result(item.id))
                                }
                            } onDelete: {
                                onDelete([item])
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func header(title: String, count: Int, withFilter: Bool = true) -> some View {
        HStack {
            SectionLabel("\(title) · \(count)")
            Spacer()
            if showFilter && withFilter {
                Menu {
                    ForEach(MediaFilter.allCases) { f in
                        Button {
                            filter = f
                        } label: {
                            if f == filter { Label("\(f.title) · \(counts[f] ?? 0)", systemImage: "checkmark") } else { Text("\(f.title) · \(counts[f] ?? 0)") }
                        }
                    }
                } label: {
                    SkewTagFace(title: filter.title, trailingChevron: true)
                }
                .accessibilityLabel("Filter: \(filter.title)")
            }
        }
        .padding(.top, 6)
    }
}

struct MediaTile: View {
    @Environment(AppModel.self) private var model
    let item: LibraryItem
    var selecting = false
    var selected = false
    let onTap: () -> Void
    var onDelete: () -> Void = {}

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: item.previewURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder(seed: item.id.count) }
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 4) {
                    if item.isVideo { TileBadge(text: duration, icon: "play.fill") }
                    if model.isFromChat(item) { TileBadge(text: "Aa from chat") }
                    if item.source == .reference { TileBadge(text: "Ref") }
                }
                .padding(6)
            }
            .overlay(alignment: .topTrailing) {
                if selecting {
                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(selected ? NX.C.accent : .white)
                        .padding(8)
                }
            }
            .overlay(Rectangle().strokeBorder(selected ? NX.C.accent : .clear, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .draggable(item.dragPayload) { DragPreview(item: item) }
            .contextMenu {
                if !item.isVideo {
                    Button { useAsReference() } label: { Label("Use as reference", systemImage: "plus.square.on.square") }
                    Button { animate() } label: { Label("Animate → video", systemImage: "play.rectangle") }
                }
                Button { variations() } label: { Label("Variations", systemImage: "square.on.square") }
                Button { Task { await model.saveToPhotos(url: item.url ?? item.previewURL, isVideo: item.isVideo) } } label: { Label("Save to Photos", systemImage: "square.and.arrow.down") }
                if let url = item.url ?? item.previewURL {
                    ShareLink(item: url) { Label("Share…", systemImage: "square.and.arrow.up") }
                }
                Menu {
                    ForEach(model.userProjects) { project in
                        Button(project.name) {
                            Task {
                                if model.auth == .live { _ = try? await NXORService.libraryMove([item.ref], to: project.id) }
                                model.showToast("Added to \(project.name)")
                            }
                        }
                    }
                } label: { Label("Add to project…", systemImage: "folder.badge.plus") }
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            } preview: {
                AsyncImage(url: item.previewURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFit() } else { TilePlaceholder() }
                }
                .frame(width: 300, height: 300)
            }
            .accessibilityLabel(item.prompt.isEmpty ? (item.isVideo ? "Video" : "Picture") : item.prompt)
            .accessibilityAddTraits(.isButton)
    }

    private var duration: String {
        let s = Int(item.duration ?? 5)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func useAsReference() {
        model.studio.addReference(item, app: model)
        model.studioDraft = StudioDraft(prompt: model.studio.prompt, mode: model.studio.mode, projectID: model.studio.projectID, referenceIDs: model.studio.references.map(\.id))
        model.showCreateSheet = true
    }

    private func animate() {
        model.studioDraft = StudioDraft(prompt: "", mode: .video, referenceIDs: [item.id])
        model.showCreateSheet = true
    }

    private func variations() {
        model.studioDraft = StudioDraft(prompt: item.prompt == "Upload" ? "" : item.prompt, mode: item.isVideo ? .video : .image)
        model.showCreateSheet = true
    }
}

/// Rendering / failed job tile (12e).
struct JobTile: View {
    @Environment(AppModel.self) private var model
    let job: GenerationCard

    var body: some View {
        Button {
            if job.status == .failed, let id = job.generationId { model.push(.result("job:\(id)")) }
            if job.status == .completed, let id = job.generationId { model.push(.result(id)) }
        } label: {
            ZStack {
                if job.status == .completed {
                    AsyncImage(url: job.thumbnailUrl ?? job.url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder() }
                    }
                } else {
                    TilePlaceholder(seed: 1)
                    VStack(spacing: 8) {
                        Text(job.status == .failed ? "FAILED · NOT CHARGED" : "RENDERING")
                            .font(NX.F.mono(10)).tracking(1.8)
                            .foregroundStyle(job.status == .failed ? NX.C.danger : NX.C.inkSoft)
                        if job.status != .failed { IndeterminateBar().frame(width: 90) }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .overlay(alignment: .bottomLeading) { TileBadge(text: "\(job.model) · \(job.credits) cr").padding(6) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(job.status == .failed ? "Failed: \(job.prompt)" : "Rendering: \(job.prompt)")
    }
}

struct DragPreview: View {
    let item: LibraryItem

    var body: some View {
        AsyncImage(url: item.previewURL) { phase in
            if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder() }
        }
        .frame(width: 96, height: 96)
        .clipped()
        .rotationEffect(.degrees(-6))
        .overlay(Rectangle().strokeBorder(NX.C.accent, lineWidth: 1.5))
    }
}

/// R11: empty Studio.
struct StudioEmptyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            NXMark().fill(NX.G.logo).frame(width: 56, height: 56).padding(.bottom, 8)
            Text("NOTHING HERE YET").font(NX.F.display(24)).foregroundStyle(NX.C.inkSoft)
            Text("Your pictures, videos and voice-overs will live here.")
                .font(NX.F.body(15)).foregroundStyle(NX.C.ink3).multilineTextAlignment(.center)
            SkewButton(title: "Start from a preset", size: .l, style: .metal) { model.push(.presets) }
                .padding(.top, 8)
            Button("or describe your own") {
                model.studioDraft = StudioDraft(prompt: "", mode: .image)
                model.showCreateSheet = true
            }
            .font(NX.F.body(14)).underline().foregroundStyle(NX.C.inkSoft)
            .frame(minHeight: 44)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(BackgroundAura())
    }
}
