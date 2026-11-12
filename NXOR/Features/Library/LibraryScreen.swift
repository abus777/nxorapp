import SwiftUI
import AVKit
import UIKit
import Photos

struct LibraryItem: Identifiable, Hashable {
    let id: String
    let isVideo: Bool
    let previewURL: URL?
    let url: URL?
    let prompt: String
    let model: String
    let createdAt: Date
    let width: Int?
    let height: Int?
    let duration: Double?
    let renderSeconds: Double?
    let status: String

    init(generation g: Generation, isVideo: Bool) {
        id = g.id
        self.isVideo = isVideo
        previewURL = g.previewURL
        url = g.outputs?.first?.url
        prompt = g.prompt ?? ""
        model = AppModel.modelLabel(for: g.modelSlug)
        createdAt = Self.parse(g.createdAt) ?? .now
        width = g.outputs?.first?.width
        height = g.outputs?.first?.height
        duration = g.outputs?.first?.durationSeconds ?? g.durationSeconds
        if let s = g.startedAt.flatMap(Self.parse), let c = g.completedAt.flatMap(Self.parse) {
            renderSeconds = c.timeIntervalSince(s)
        } else {
            renderSeconds = nil
        }
        status = g.status
    }

    init(demo preset: PresetSummary, index: Int) {
        id = "demo-\(preset.slug)"
        isVideo = preset.kind == "video"
        previewURL = preset.previewImageUrl
        url = preset.previewVideoUrl ?? preset.previewImageUrl
        prompt = "\(preset.name) — sample output from the NXOR preset."
        model = isVideo ? "Kling 3.0" : "Nano Banana Pro"
        createdAt = Calendar.current.date(byAdding: .day, value: -index * 4, to: .now) ?? .now
        width = isVideo ? 1080 : 2048
        height = isVideo ? 1920 : 2048
        duration = isVideo ? 5 : nil
        renderSeconds = isVideo ? 96 : 44
        status = "completed"
    }

    private static func parse(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}

@Observable
final class LibraryModel {
    var items: [LibraryItem] = []
    var loading = false
    var loaded = false

    @MainActor
    func delete(_ item: LibraryItem, app: AppModel) async {
        items.removeAll { $0.id == item.id }
        guard app.auth == .live else { return }
        do {
            try await NXORService.deleteGeneration(kind: item.isVideo ? "video" : "image", id: item.id)
        } catch {
            app.errorMessage = error.localizedDescription
            loaded = false
            await load(app: app)
        }
    }

    @MainActor
    func load(app: AppModel) async {
        guard !loading else { return }
        loading = true
        defer { loading = false; loaded = true }
        if app.auth == .live {
            async let images = try? NXORService.images(pageSize: 40)
            async let videos = try? NXORService.videos(pageSize: 40)
            let i = (await images)?.items.map { LibraryItem(generation: $0, isVideo: false) } ?? []
            let v = (await videos)?.items.map { LibraryItem(generation: $0, isVideo: true) } ?? []
            items = (i + v).filter { $0.status == "completed" }.sorted { $0.createdAt > $1.createdAt }
        } else {
            items = app.presets.prefix(14).enumerated().map { LibraryItem(demo: $0.element, index: $0.offset) }
        }
    }
}

struct LibraryScreen: View {
    @Environment(AppModel.self) private var app
    @State private var library = LibraryModel()
    @State private var filter = "all"
    @State private var selected: LibraryItem?

    private var filtered: [LibraryItem] {
        switch filter {
        case "image": return library.items.filter { !$0.isVideo }
        case "video": return library.items.filter { $0.isVideo }
        default: return library.items
        }
    }

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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    DisplayTitle("Library", size: 34)
                    MetaLabel("\(library.items.count) assets", size: 13)
                }

                NXSegmented(options: [("all", "All"), ("image", "Image"), ("video", "Video")], selection: $filter)

                if !library.loaded || library.loading {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<6, id: \.self) { _ in Skeleton().aspectRatio(1, contentMode: .fit) }
                    }
                } else if filtered.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        MetaLabel("Nothing here yet")
                        Text("Images and videos you create appear here.")
                            .font(NX.F.body(15)).foregroundStyle(NX.C.ink3)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        MetaLabel(section.0, color: NX.C.ink3, size: 12).padding(.top, 8)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(section.1) { item in
                                LibraryTile(item: item).onTapGesture { selected = item }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .refreshable { library.loaded = false; await library.load(app: app) }
        .task { if !library.loaded { await library.load(app: app) } }
        .fullScreenCover(item: $selected) { item in
            AssetViewer(items: filtered, current: item) { deleted in
                Task { await library.delete(deleted, app: app) }
            }
        }
    }

    private var columns: [GridItem] { [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)] }
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
                if let d = item.duration, item.isVideo {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill").font(.system(size: 9))
                        Text(String(format: "0:%02d", Int(d.rounded()))).font(NX.F.mono(10, .semibold))
                    }
                    .foregroundStyle(NX.C.ink)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .padding(8)
                }
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
