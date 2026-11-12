import Foundation

struct MeResponse: Decodable {
    struct User: Decodable {
        let id: String
        let email: String
        let name: String?
        let lastProjectId: String?
    }
    struct Subscription: Decodable {
        struct PlanRef: Decodable {
            let slug: String
            let name: String
            let monthlyTokenGrant: Double?
        }
        let status: String
        let interval: String?
        let currentPeriodEnd: String?
        let cancelAtPeriodEnd: Bool?
        let plan: PlanRef
    }
    struct Usage: Decodable {
        struct Credits: Decodable {
            let available: Double
            let reserved: Double
            let monthlyGrant: Double?
        }
        let credits: Credits?
    }

    let user: User
    let subscription: Subscription?
    let usage: Usage?

    var account: Account {
        Account(
            name: user.name ?? user.email,
            email: user.email,
            planName: subscription?.plan.name ?? "Free",
            planSlug: subscription?.plan.slug ?? "none",
            available: usage?.credits?.available ?? 0,
            reserved: usage?.credits?.reserved ?? 0,
            monthlyGrant: usage?.credits?.monthlyGrant ?? subscription?.plan.monthlyTokenGrant ?? 0
        )
    }
}

struct Page<Item: Decodable>: Decodable {
    let items: [Item]
    let page: Int?
    let pageSize: Int?
    let total: Int?
    let hasMore: Bool?
}

struct ChatSessionSummary: Decodable, Identifiable {
    let id: String
    let title: String?
    let createdAt: String
    let updatedAt: String
}

struct ChatSessionDetail: Decodable {
    struct Message: Decodable {
        struct AnsweredBy: Decodable { let name: String }
        struct GenerationRef: Decodable {
            let kind: String
            let prompt: String?
            let modelSlug: String?
            let generationId: String
        }
        let id: String
        let role: String
        let content: String?
        let answeredBy: AnsweredBy?
        let attachments: [String]?
        let generationRefs: [GenerationRef]?
    }
    let session: ChatSessionSummary
    let messages: [Message]
}

struct MediaOutput: Decodable, Hashable {
    let url: URL?
    let width: Int?
    let height: Int?
    let durationSeconds: Double?
    let thumbnailUrl: URL?
}

struct Generation: Decodable, Identifiable, Hashable {
    let id: String
    let status: String
    let prompt: String?
    let modelSlug: String?
    let presetSlug: String?
    let projectId: String?
    let aspectRatio: String?
    let durationSeconds: Double?
    let outputs: [MediaOutput]?
    let thumbnailUrl: URL?
    let errorMessage: String?
    let createdAt: String
    let startedAt: String?
    let completedAt: String?

    var isRunning: Bool { status == "pending" || status == "processing" }
    var isVideo: Bool { durationSeconds != nil }
    var previewURL: URL? { thumbnailUrl ?? outputs?.first?.thumbnailUrl ?? outputs?.first?.url }
}

struct Project: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let isDefault: Bool
}

struct CreditsBalance: Decodable {
    let available: Double
    let reserved: Double
}

struct AuthResult: Decodable {
    let authEvent: String?
    let authMethod: String?
}

/// Typed wrappers for the NXOR endpoints the app uses.
enum NXORService {
    static var api: APIClient { .shared }

    // MARK: Auth
    static func requestCode(email: String) async throws {
        try await api.postVoid("auth/magic-link", body: ["email": email] as [String: String])
    }

    static func verifyCode(email: String, code: String) async throws {
        let request = try api.makeRequest("auth/magic-link/code", method: "POST", body: ["email": email, "code": code] as [String: String])
        _ = try await api.data(for: request, retryOnAuth: false)
    }

    static func logout() async {
        try? await api.postVoid("auth/logout")
        HTTPCookieStorage.shared.cookies(for: api.base)?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
    }

    static func me() async throws -> MeResponse { try await api.get("users/me") }

    // MARK: Catalog
    static func tiers() async throws -> [ChatTier] { try await api.get("chat/tiers") }
    static func capabilities() async throws -> [Capability] { try await api.get("chat/capabilities") }
    static func presets() async throws -> [PresetSummary] { try await api.get("public/presets") }
    static func imageModels() async throws -> [ModelFamily] { try await api.get("image-models") }
    static func videoModels() async throws -> [ModelFamily] { try await api.get("video-models") }
    static func plans() async throws -> [Plan] { try await api.get("subscriptions/plans") }
    static func topups() async throws -> [TopUp] { try await api.get("billing/topups") }
    static func balance() async throws -> CreditsBalance { try await api.get("credits/balance") }

    // MARK: Chat
    static func sessions(page: Int = 1, pageSize: Int = 50) async throws -> Page<ChatSessionSummary> {
        try await api.get("chat/sessions", query: ["page": "\(page)", "pageSize": "\(pageSize)"])
    }
    static func session(_ id: String) async throws -> ChatSessionDetail { try await api.get("chat/sessions/\(id)") }

    // MARK: Library
    static func projects() async throws -> [Project] { try await api.get("projects") }
    static func images(page: Int = 1, pageSize: Int = 30, projectId: String? = nil) async throws -> Page<Generation> {
        var q = ["page": "\(page)", "pageSize": "\(pageSize)"]
        if let projectId { q["projectId"] = projectId }
        return try await api.get("images", query: q)
    }
    static func videos(page: Int = 1, pageSize: Int = 30, projectId: String? = nil) async throws -> Page<Generation> {
        var q = ["page": "\(page)", "pageSize": "\(pageSize)"]
        if let projectId { q["projectId"] = projectId }
        return try await api.get("videos", query: q)
    }
    static func image(_ id: String) async throws -> Generation { try await api.get("images/\(id)") }
    static func video(_ id: String) async throws -> Generation { try await api.get("videos/\(id)") }

    // MARK: Studio
    static func quote(kind: String, body: GenerateBody) async throws -> Double {
        let q: QuoteResponse = try await api.post("\(kind)s/quote", body: body)
        return q.credits
    }

    /// Starts a paid generation and returns its id.
    static func generate(kind: String, body: GenerateBody) async throws -> String {
        let r: GenerateResponse = try await api.post("\(kind)s/generate", body: body)
        guard let id = r.imageId ?? r.videoId ?? r.id else { throw APIError(status: 500, code: "no_id", message: "The generation didn't start.") }
        return id
    }

    static func enhance(prompt: String, kind: String, modelSlug: String?) async throws -> String {
        let r: EnhanceResponse = try await api.post("prompts/enhance", body: EnhanceBody(prompt: prompt, kind: kind, modelSlug: modelSlug))
        return r.prompt
    }
}

struct GenerateBody: Encodable {
    var modelSlug: String?
    var prompt: String?
    var aspectRatio: String?
    var projectId: String?
    var idempotencyKey: String?
    var presetSlug: String?
    var presetInputs: [String: [String]]?
    var presetDims: [String: String]?
    var presetUserPrompt: String?
}

struct UploadResponse: Decodable {
    let fileKey: String?
    let key: String?
    let url: String?

    var resolvedKey: String? { fileKey ?? key }
}

struct PresetDetail: Decodable {
    struct Input: Decodable, Hashable {
        let key: String
        let label: String
        let requirement: String
        let hint: String?
        let maxFiles: Int?
        let accepts: String
        let upload: String
    }
    struct Option: Decodable, Hashable {
        let dims: [String: String]
        let credits: Double?
        let aspectRatio: String?
    }
    let slug: String
    let kind: String
    let name: String
    let description: String?
    let previewImageUrl: URL?
    let previewVideoUrl: URL?
    let inputs: [Input]
    let dimensions: [ModelDimension]
    let options: [Option]
    let userPrompt: String?
    let userPromptPlaceholder: String?
}

extension NXORService {
    static func preset(_ slug: String) async throws -> PresetDetail { try await api.get("presets/\(slug)") }

    static func deleteGeneration(kind: String, id: String) async throws {
        _ = try await api.data(for: api.makeRequest("\(kind)s/\(id)", method: "DELETE"))
    }

    static func uploadChatAttachment(data: Data) async throws -> String {
        let r: UploadResponse = try await api.upload("chat/uploads/attachment", data: data, filename: "photo.jpg", mimeType: "image/jpeg")
        guard let url = r.url else { throw APIError(status: 500, code: "upload", message: "The upload didn't return a URL.") }
        return url
    }

    /// Uploads an image to one of the `/v1/{images|videos}/uploads/...` paths a preset input names.
    static func uploadSource(path: String, data: Data, filename: String, mimeType: String) async throws -> String {
        let clean = path.hasPrefix("/v1/") ? String(path.dropFirst(4)) : path
        let r: UploadResponse = try await api.upload(clean, data: data, filename: filename, mimeType: mimeType)
        guard let key = r.resolvedKey else { throw APIError(status: 500, code: "upload", message: "The upload didn't return a file key.") }
        return key
    }
}

struct QuoteResponse: Decodable { let credits: Double }
struct GenerateResponse: Decodable {
    let imageId: String?
    let videoId: String?
    let id: String?
    let status: String?
}
struct EnhanceBody: Encodable {
    let prompt: String
    let kind: String
    let modelSlug: String?
}
struct EnhanceResponse: Decodable { let prompt: String }
