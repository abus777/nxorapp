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

    private var quoteTask: Task<Void, Never>?

    private static let textOps: Set<String> = ["text-to-image", "text-to-video"]

    func families(_ app: AppModel) -> [ModelFamily] {
        let all = kind == .image ? app.imageModels : app.videoModels
        return all.filter { !textVariants($0).isEmpty }
    }

    func textVariants(_ family: ModelFamily) -> [ModelVariant] {
        family.variants.filter { v in
            guard let op = v.dims["operation"] else { return true }
            return Self.textOps.contains(op)
        }
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
        let body = GenerateBody(modelSlug: slug, prompt: prompt.isEmpty ? "a" : prompt, aspectRatio: aspect)
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
            try? await Task.sleep(for: .milliseconds(600))
            prompt += ", cinematic lighting, shallow depth of field, rich detail"
            return
        }
        do {
            prompt = try await NXORService.enhance(prompt: prompt, kind: kind.rawValue, modelSlug: variant(app)?.slug)
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func generate(app: AppModel) async {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let slug = variant(app)?.slug, !submitting else { return }
        submitting = true
        defer { submitting = false }

        var card = GenerationCard(kind: kind, model: familyLabel, credits: Int(quote ?? 0), status: .processing, prompt: text)

        if app.auth != .live {
            let sample = app.presets.filter { $0.kind == kind.rawValue }.randomElement()
            jobs.insert(card, at: 0)
            prompt = ""
            try? await Task.sleep(for: .seconds(3))
            card.status = .completed
            card.thumbnailUrl = sample?.previewImageUrl
            card.url = sample?.previewVideoUrl ?? sample?.previewImageUrl
            if let i = jobs.firstIndex(where: { $0.prompt == text && $0.status == .processing }) { jobs[i] = card }
            return
        }

        do {
            let body = GenerateBody(modelSlug: slug, prompt: text, aspectRatio: aspect, idempotencyKey: UUID().uuidString)
            let id = try await NXORService.generate(kind: kind.rawValue, body: body)
            card.generationId = id
            jobs.insert(card, at: 0)
            prompt = ""
            track(id: id, kind: card.kind, app: app)
        } catch {
            self.error = error.localizedDescription
        }
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
                    await app.refreshBalance()
                    return
                }
            }
        }
    }
}
