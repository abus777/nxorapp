import SwiftUI
import Observation

@Observable
final class StudioModel {
    var kind: GenerationCard.Kind = .image
    var prompt = ""
    var familyID = ""
    var dims: [String: String] = [:]
    var aspect: String?
    var quote: Double?
    var quoting = false
    var enhancing = false
    var submitting = false
    var jobs: [GenerationCard] = []
    var error: String?
    var references: [LibraryItem] = []

    // Create sheet state (06e / 12b–d).
    var mode: CreateMode = .image
    var count = 1
    var projectID: String?
    var fromChatTitle: String?
    var fromChatID: String?
    var promptBeforeEnhance: String?
    var brandKitOn = true
    var voice = "Default male"
    var language = "Arabic"
    var durationSeconds: Double = 5
    var soundOn = false

    private var quoteTask: Task<Void, Never>?

    /// Price on the send button: quote × number of pictures.
    var price: Int? {
        guard mode != .audio, let quote else { return nil }
        return Int(quote) * max(1, count)
    }

    var wordCount: Int { prompt.split(whereSeparator: { $0 == " " || $0 == "\n" }).count }

    func setMode(_ newMode: CreateMode, app: AppModel) {
        mode = newMode
        if let kind = newMode.generationKind, kind != self.kind {
            switchKind(kind, app: app)
        } else {
            refreshQuote(app)
        }
    }

    /// Fill the sheet from a chat prompt, a preset or Reuse.
    func apply(_ draft: StudioDraft, app: AppModel) {
        prompt = draft.prompt
        fromChatTitle = draft.fromChatTitle
        fromChatID = draft.fromChatID
        projectID = draft.projectID
        promptBeforeEnhance = nil
        references = draft.referenceIDs.compactMap { app.assetIndex["nxor-asset:\($0)"] }
        setMode(draft.mode == .chat ? .image : draft.mode, app: app)
        ensureSelection(app)
    }

    func clearFromChat() {
        fromChatTitle = nil
        fromChatID = nil
    }

    func undoEnhance() {
        if let previous = promptBeforeEnhance { prompt = previous }
        promptBeforeEnhance = nil
    }

    /// Duration dimension (seconds) if the model has one.
    func durationOptions(_ app: AppModel) -> (key: String, values: [Double])? {
        guard let family = family(app), let dim = family.dimensions.first(where: { $0.key.lowercased().contains("duration") }) else { return nil }
        let values = options(for: dim, app: app).compactMap { Double($0.value.filter { $0.isNumber || $0 == "." }) }
        return values.isEmpty ? nil : (dim.key, values.sorted())
    }

    /// The operation the current inputs call for: text only, or with reference images.
    var wantedOperation: String {
        let imageRefs = references.contains { !$0.isVideo }
        switch (kind, imageRefs) {
        case (.image, false): return "text-to-image"
        case (.image, true): return "image-to-image"
        case (.video, false): return "text-to-video"
        case (.video, true): return "image-to-video"
        }
    }

    func families(_ app: AppModel) -> [ModelFamily] {
        let all = kind == .image ? app.imageModels : app.videoModels
        return all.filter { !textVariants($0).isEmpty }
    }

    func textVariants(_ family: ModelFamily) -> [ModelVariant] {
        let op = wantedOperation
        return family.variants.filter { v in
            guard let variantOp = v.dims["operation"] else { return true }
            return variantOp == op
        }
    }

    var maxReferences: Int { 8 }

    func addReference(_ item: LibraryItem, app: AppModel) {
        guard !item.isVideo, item.fileKey != nil, !references.contains(where: { $0.id == item.id }), references.count < maxReferences else { return }
        references.append(item)
        reselect(app)
    }

    func removeReference(_ item: LibraryItem, app: AppModel) {
        references.removeAll { $0.id == item.id }
        reselect(app)
    }

    private func reselect(_ app: AppModel) {
        if let family = family(app) {
            let variants = textVariants(family)
            if !variants.contains(where: { $0.dims == dims }) {
                let best = variants.max { a, b in score(a) < score(b) } ?? variants.first
                if let best { dims = best.dims }
            }
        } else if let first = preferredFamily(app) {
            select(family: first, app: app)
            return
        }
        refreshQuote(app)
    }


    func family(_ app: AppModel) -> ModelFamily? {
        families(app).first { $0.family == familyID }
    }

    func variant(_ app: AppModel) -> ModelVariant? {
        guard let family = family(app) else { return nil }
        return textVariants(family).first { $0.dims == dims }
    }

    func ensureSelection(_ app: AppModel) {
        if family(app) == nil, let first = preferredFamily(app) { select(family: first, app: app) }
    }

    private func preferredFamily(_ app: AppModel) -> ModelFamily? {
        let list = families(app)
        let preferred = kind == .image ? "flux1-kontext" : "kling-v3-turbo"
        return list.first { $0.family == preferred } ?? list.first
    }

    func switchKind(_ kind: GenerationCard.Kind, app: AppModel) {
        guard kind != self.kind else { return }
        self.kind = kind
        if mode.generationKind != kind { mode = kind == .video ? .video : .image }
        familyID = ""
        ensureSelection(app)
    }

    func select(family: ModelFamily, app: AppModel) {
        familyID = family.family
        if let v = textVariants(family).first {
            dims = v.dims
            aspect = v.body.aspectRatio?.first
        }
        refreshQuote(app)
    }

    func pick(key: String, value: String, app: AppModel) {
        guard let family = family(app) else { return }
        let candidates = textVariants(family).filter { $0.dims[key] == value }
        let best = candidates.max { a, b in score(a) < score(b) }
        if let best {
            dims = best.dims
            if let ratios = best.body.aspectRatio, let a = aspect, !ratios.contains(a) { aspect = ratios.first }
        }
        refreshQuote(app)
    }

    private func score(_ v: ModelVariant) -> Int {
        v.dims.filter { dims[$0.key] == $0.value }.count
    }

    func options(for dimension: ModelDimension, app: AppModel) -> [ModelDimension.Option] {
        guard let family = family(app) else { return [] }
        let valid = Set(textVariants(family).compactMap { $0.dims[dimension.key] })
        return dimension.options.filter { valid.contains($0.value) }
    }

    var chipLabel: String {
        "\(familyLabel)\(aspect.map { " · \($0)" } ?? "")"
    }

    var familyLabel = ""

    func refreshQuote(_ app: AppModel) {
        familyLabel = family(app)?.label ?? ""
        quoteTask?.cancel()
        guard let slug = variant(app)?.slug else { quote = nil; return }
        if app.auth != .live {
            quote = kind == .image ? 25 : 450
            return
        }
        var body = GenerateBody(modelSlug: slug, prompt: prompt.isEmpty ? "a" : prompt, aspectRatio: aspect)
        attachSources(to: &body, app: app)
        let kindName = kind.rawValue
        quoting = true
        quoteTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            let value = try? await NXORService.quote(kind: kindName, body: body)
            if Task.isCancelled { return }
            quote = value
            quoting = false
        }
    }

    @MainActor
    func enhance(app: AppModel) async {
        guard !prompt.trimmingCharacters(in: .whitespaces).isEmpty, !enhancing else { return }
        enhancing = true
        defer { enhancing = false }
        if app.auth != .live {
            promptBeforeEnhance = prompt
            try? await Task.sleep(for: .milliseconds(600))
            prompt += ", cinematic lighting, shallow depth of field, rich detail"
            return
        }
        promptBeforeEnhance = prompt
        do {
            prompt = try await NXORService.enhance(prompt: prompt, kind: kind.rawValue, modelSlug: variant(app)?.slug)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Where new work is saved: the open project, else the account's default project.
    func targetProject(_ app: AppModel) -> String? {
        projectID ?? app.defaultProject?.id ?? app.currentProjectID
    }

    @MainActor
    @discardableResult
    func generate(app: AppModel) async -> Bool {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !submitting else { return false }
        if mode == .audio {
            error = "Voice-overs aren't available in the NXOR API yet. Switch to Image or Video."
            return false
        }
        guard let slug = variant(app)?.slug else { return false }
        if let price, Double(price) > app.account.available {
            error = "Needs \(price) cr — you have \(Int(app.account.available)). Buy credits or switch to a cheaper model."
            return false
        }
        submitting = true
        defer { submitting = false }
        let runs = kind == .image ? max(1, count) : 1
        let chatTag = fromChatID

        if app.auth != .live {
            for _ in 0..<runs {
                var card = GenerationCard(kind: kind, model: familyLabel, credits: Int(quote ?? 0), status: .processing, prompt: text)
                card.generationId = "demo-\(UUID().uuidString)"
                if let chatTag, let id = card.generationId { app.chatGenerationIDs[id] = chatTag }
                jobs.insert(card, at: 0)
                let cardID = card.generationId
                let jobKind = kind
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(4))
                    let sample = app.presets.filter { $0.kind == jobKind.rawValue }.randomElement()
                    if let i = jobs.firstIndex(where: { $0.generationId == cardID }) {
                        jobs[i].status = .completed
                        jobs[i].thumbnailUrl = sample?.previewImageUrl
                        jobs[i].url = sample?.previewVideoUrl ?? sample?.previewImageUrl
                        app.register(job: jobs[i], projectID: projectID)
                    }
                }
            }
            app.account.available -= Double(price ?? 0)
            app.showToast("\(kind == .video ? "Video" : "Image") is rendering · \(price ?? 0) cr")
            app.didStartGeneration(kind: kind)
            prompt = ""
            promptBeforeEnhance = nil
            clearFromChat()
            return true
        }

        var started = false
        for _ in 0..<runs {
            do {
                var body = GenerateBody(modelSlug: slug, prompt: text, aspectRatio: aspect, projectId: targetProject(app), idempotencyKey: UUID().uuidString)
                attachSources(to: &body, app: app)
                let id = try await NXORService.generate(kind: kind.rawValue, body: body)
                var card = GenerationCard(kind: kind, model: familyLabel, credits: Int(quote ?? 0), status: .processing, prompt: text)
                card.generationId = id
                if let chatTag { app.chatGenerationIDs[id] = chatTag }
                jobs.insert(card, at: 0)
                track(id: id, kind: card.kind, app: app)
                started = true
            } catch {
                self.error = error.localizedDescription
                break
            }
        }
        if started {
            app.showToast("\(kind == .video ? "Video" : "Image") is rendering · \(price ?? 0) cr")
            app.didStartGeneration(kind: kind)
            prompt = ""
            promptBeforeEnhance = nil
            clearFromChat()
            await app.refreshBalance()
        }
        return started
    }

    private func track(id: String, kind: GenerationCard.Kind, app: AppModel) {
        Task { @MainActor in
            for attempt in 0..<200 {
                try? await Task.sleep(for: .seconds(attempt < 20 ? 3 : 6))
                guard let g = try? await (kind == .video ? NXORService.video(id) : NXORService.image(id)) else { continue }
                if let i = jobs.firstIndex(where: { $0.generationId == id }) {
                    jobs[i].status = GenerationCard.Status(rawValue: g.status) ?? .processing
                    jobs[i].url = g.outputs?.first?.url
                    jobs[i].thumbnailUrl = g.previewURL
                    jobs[i].errorMessage = g.errorMessage
                }
                if !g.isRunning {
                    if let job = jobs.first(where: { $0.generationId == id }), job.status == .completed {
                        app.register(job: job, projectID: projectID)
                        app.notifyReady(kind: kind, title: String(job.prompt.prefix(40)))
                    }
                    await app.refreshBalance()
                    return
                }
            }
        }
    }

    private func attachSources(to body: inout GenerateBody, app: AppModel) {
        let keys = references.filter { !$0.isVideo }.compactMap(\.fileKey)
        guard !keys.isEmpty else { return }
        let limit = max(1, variant(app)?.body.maxSourceImages ?? 1)
        if limit > 1 {
            body.sourceFileKeys = Array(keys.prefix(limit))
        } else {
            body.sourceFileKey = keys.first
        }
    }
}
