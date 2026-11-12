import SwiftUI
import Observation
import UIKit

struct LibraryItem: Identifiable, Hashable {
    enum Source: String, Hashable { case image, video, reference }

    let id: String
    let source: Source
    let isVideo: Bool
    let previewURL: URL?
    let url: URL?
    let fileKey: String?
    var projectId: String?
    let prompt: String
    let model: String
    let createdAt: Date
    let width: Int?
    let height: Int?
    let duration: Double?
    let renderSeconds: Double?
    let status: String

    var ref: LibraryRef { LibraryRef(kind: source.rawValue, id: id) }
    var dragPayload: String { "nxor-asset:\(id)" }
    var isImage: Bool { !isVideo }

    init(generation g: Generation, isVideo: Bool) {
        id = g.id
        source = isVideo ? .video : .image
        self.isVideo = isVideo
        previewURL = g.previewURL
        url = g.outputs?.first?.url
        fileKey = g.outputs?.first?.key
        projectId = g.projectId
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

    init(reference r: Reference) {
        id = r.id
        source = .reference
        isVideo = r.kind == "video"
        previewURL = r.thumbnailUrl ?? r.url
        url = r.url
        fileKey = r.fileKey
        projectId = r.projectId
        prompt = r.originalName ?? "Upload"
        model = "Upload"
        createdAt = Self.parse(r.createdAt) ?? .now
        width = r.width
        height = r.height
        duration = r.durationSeconds
        renderSeconds = nil
        status = "completed"
    }

    init(demo preset: PresetSummary, index: Int, projectId: String?) {
        id = "demo-\(preset.slug)"
        source = preset.kind == "video" ? .video : .image
        isVideo = preset.kind == "video"
        previewURL = preset.previewImageUrl
        url = preset.previewVideoUrl ?? preset.previewImageUrl
        fileKey = "demo/\(preset.slug)"
        self.projectId = projectId
        prompt = "\(preset.name) — sample output from the NXOR preset."
        model = isVideo ? "Kling 3.0" : "Nano Banana Pro"
        createdAt = Calendar.current.date(byAdding: .day, value: -index * 4, to: .now) ?? .now
        width = isVideo ? 1080 : 2048
        height = isVideo ? 1920 : 2048
        duration = isVideo ? 5 : nil
        renderSeconds = isVideo ? 96 : 44
        status = "completed"
    }

    init(localUpload fileURL: URL, image: UIImage, projectId: String?) {
        id = "local-\(UUID().uuidString)"
        source = .reference
        isVideo = false
        previewURL = fileURL
        url = fileURL
        fileKey = "demo/\(fileURL.lastPathComponent)"
        self.projectId = projectId
        prompt = "Upload"
        model = "Upload"
        createdAt = .now
        width = Int(image.size.width * image.scale)
        height = Int(image.size.height * image.scale)
        duration = nil
        renderSeconds = nil
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
    var uploads: [LibraryItem] = []
    var loading = false
    var loaded = false
    var uploading = 0
    private var loadedProject: String??

    /// Demo mode keeps everything in memory so folder moves and uploads still behave.
    private static var demoStore: [LibraryItem]?

    @MainActor
    func load(app: AppModel, force: Bool = false) async {
        let project = app.currentProjectID
        if !force, loaded, loadedProject == .some(project) { return }
        guard !loading else { return }
        loading = true
        defer { loading = false; loaded = true; loadedProject = .some(project) }

        if app.auth == .live {
            async let images = try? NXORService.images(pageSize: 60, projectId: project)
            async let videos = try? NXORService.videos(pageSize: 60, projectId: project)
            async let refs = try? NXORService.references(projectId: project)
            let i = (await images)?.items.map { LibraryItem(generation: $0, isVideo: false) } ?? []
            let v = (await videos)?.items.map { LibraryItem(generation: $0, isVideo: true) } ?? []
            items = (i + v).filter { $0.status == "completed" }.sorted { $0.createdAt > $1.createdAt }
            uploads = (await refs)?.items.map(LibraryItem.init(reference:)) ?? []
        } else {
            let all = Self.demo(app)
            items = all.filter { $0.source != .reference && $0.projectId == project }
            uploads = all.filter { $0.source == .reference && $0.projectId == project }
        }
        register(app)
    }

    private static func demo(_ app: AppModel) -> [LibraryItem] {
        if let store = demoStore { return store }
        let ids = app.projects.map(\.id)
        let store = app.presets.prefix(24).enumerated().map { i, p in
            LibraryItem(demo: p, index: i, projectId: ids.isEmpty ? nil : ids[i % min(ids.count, 2)])
        }
        demoStore = store
        return store
    }

    private func register(_ app: AppModel) {
        for item in items + uploads { app.assetIndex[item.dragPayload] = item }
    }

    @MainActor
    func delete(_ targets: [LibraryItem], app: AppModel) async {
        let ids = Set(targets.map(\.id))
        items.removeAll { ids.contains($0.id) }
        uploads.removeAll { ids.contains($0.id) }
        if app.auth != .live {
            Self.demoStore?.removeAll { ids.contains($0.id) }
            return
        }
        do {
            let result = try await NXORService.libraryDelete(targets.map(\.ref))
            if let failed = result.failed, !failed.isEmpty {
                app.errorMessage = failed.contains { $0.code == "GENERATION_IN_PROGRESS" }
                    ? "Some items are still generating — try again once they finish."
                    : "Some items couldn't be deleted."
                await load(app: app, force: true)
            }
        } catch {
            app.errorMessage = error.localizedDescription
            await load(app: app, force: true)
        }
    }

    @MainActor
    func move(_ targets: [LibraryItem], to project: Project, app: AppModel) async {
        let ids = Set(targets.map(\.id))
        if project.id != app.currentProjectID {
            items.removeAll { ids.contains($0.id) }
            uploads.removeAll { ids.contains($0.id) }
        }
        if app.auth != .live {
            if var store = Self.demoStore {
                for i in store.indices where ids.contains(store[i].id) { store[i].projectId = project.id }
                Self.demoStore = store
            }
            return
        }
        do {
            let result = try await NXORService.libraryMove(targets.map(\.ref), to: project.id)
            if let failed = result.failed, !failed.isEmpty {
                app.errorMessage = "Some items couldn't be moved."
                await load(app: app, force: true)
            }
        } catch {
            app.errorMessage = error.localizedDescription
            await load(app: app, force: true)
        }
    }

    @MainActor
    @discardableResult
    func upload(_ image: UIImage, app: AppModel) async -> LibraryItem? {
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else { return nil }
        uploading += 1
        defer { uploading -= 1 }
        let item: LibraryItem
        if app.auth == .live {
            do {
                let ref = try await NXORService.uploadReference(data: jpeg, filename: "photo.jpg", mimeType: "image/jpeg", projectId: app.currentProjectID)
                item = LibraryItem(reference: ref)
            } catch {
                app.errorMessage = error.localizedDescription
                return nil
            }
        } else {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("upload-\(UUID().uuidString).jpg")
            try? jpeg.write(to: file)
            item = LibraryItem(localUpload: file, image: image, projectId: app.currentProjectID)
            Self.demoStore?.insert(item, at: 0)
        }
        uploads.insert(item, at: 0)
        app.assetIndex[item.dragPayload] = item
        return item
    }
}
