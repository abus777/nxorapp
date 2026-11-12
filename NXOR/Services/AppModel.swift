import SwiftUI
import Observation

enum Route: String, Hashable {
    case chat
    case studio
    case library
    case presets
    case billing
    case settings
    case help
}

enum AuthState: Equatable {
    case checking
    case signedOut
    case demo
    case live
}

@Observable
final class AppModel {
    var auth: AuthState = .checking
    var account = MockData.account
    var tiers: [ChatTier] = MockData.load("tiers") ?? []
    var capabilities: [Capability] = MockData.load("capabilities") ?? []
    var presets: [PresetSummary] = MockData.load("presets") ?? []
    var imageModels: [ModelFamily] = MockData.load("imageModels") ?? []
    var videoModels: [ModelFamily] = MockData.load("videoModels") ?? []
    var plans: [Plan] = MockData.load("plans") ?? []
    var topups: [TopUp] = MockData.load("topups") ?? []

    var chats: [ChatThread] = []
    var route: Route = .chat
    var currentChatID: String? = nil
    var selectedTier = "fast"
    var sidebarOpen = false
    var launchSheet: String?
    var launchPreset: String?
    var pendingAttachments: [LibraryItem] = []
    var showAccount = false
    var streamingStage: ChatStage? = nil
    var isStreaming = false
    var errorMessage: String?
    var projects: [Project] = []
    var assetIndex: [String: LibraryItem] = [:]
    var currentProjectID: String?
    var lastProjectHint: String?

    var currentProject: Project? { projects.first { $0.id == currentProjectID } }

    private var streamTask: Task<Void, Never>?

    // Launch arguments (e.g. `-demo YES -route presets -sidebar YES`) let CI open any screen for screenshots.
    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "route"), let route = Route(rawValue: raw) { self.route = route }
        currentChatID = defaults.string(forKey: "chat")
        sidebarOpen = defaults.bool(forKey: "sidebar")
        launchSheet = defaults.string(forKey: "sheet")
        launchPreset = defaults.string(forKey: "preset")
        if defaults.bool(forKey: "demo") { enterDemo() }
    }

    var isDemo: Bool { auth == .demo }

    var currentChat: ChatThread? {
        guard let id = currentChatID else { return nil }
        return chats.first { $0.id == id }
    }

    var tier: ChatTier? { tiers.first { $0.tier == selectedTier } }

    // MARK: Session

    @MainActor
    func bootstrap() async {
        guard auth == .checking else { return }
        guard APIClient.shared.hasSessionCookie else { auth = .signedOut; return }
        do {
            let me = try await NXORService.me()
            account = me.account
            lastProjectHint = me.user.lastProjectId
            auth = .live
            await loadLive()
        } catch {
            auth = .signedOut
        }
    }

    func enterDemo() {
        account = MockData.account
        chats = MockData.chats
        projects = MockData.projects
        currentProjectID = MockData.projects.first?.id
        auth = .demo
    }

    @MainActor
    func didSignIn() async {
        auth = .checking
        do {
            let me = try await NXORService.me()
            account = me.account
            lastProjectHint = me.user.lastProjectId
            auth = .live
            route = .chat
            currentChatID = nil
            await loadLive()
        } catch {
            errorMessage = error.localizedDescription
            auth = .signedOut
        }
    }

    @MainActor
    func signOut() async {
        if auth == .live { await NXORService.logout() }
        chats = []
        currentChatID = nil
        route = .chat
        sidebarOpen = false
        auth = .signedOut
    }

    @MainActor
    func loadLive() async {
        await loadProjects()
        async let sessions = try? NXORService.sessions()
        async let tiers = try? NXORService.tiers()
        async let caps = try? NXORService.capabilities()
        async let presets = try? NXORService.presets()
        if let page = await sessions {
            chats = page.items.map { ChatThread(id: $0.id, title: $0.title ?? "New chat", messages: [], loaded: false) }
        }
        if let t = await tiers, !t.isEmpty { self.tiers = t }
        if let c = await caps, !c.isEmpty { capabilities = c }
        if let p = await presets, !p.isEmpty { self.presets = p }

        async let image = try? NXORService.imageModels()
        async let video = try? NXORService.videoModels()
        if let i = await image, !i.isEmpty { imageModels = i }
        if let v = await video, !v.isEmpty { videoModels = v }
    }

    @MainActor
    func refreshBalance() async {
        guard auth == .live, let balance = try? await NXORService.balance() else { return }
        account.available = balance.available
        account.reserved = balance.reserved
    }

    // MARK: Projects (folders)

    @MainActor
    func loadProjects() async {
        guard auth == .live, let list = try? await NXORService.projects() else { return }
        projects = list
        if currentProjectID == nil || !list.contains(where: { $0.id == currentProjectID }) {
            currentProjectID = list.first { $0.id == lastProjectHint }?.id ?? list.first { $0.isDefault }?.id ?? list.first?.id
        }
    }

    @MainActor
    func createProject(_ name: String) async -> Project? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if auth != .live {
            let project = Project(id: UUID().uuidString, name: trimmed, isDefault: false)
            projects.append(project)
            return project
        }
        do {
            let project = try await NXORService.createProject(name: trimmed)
            projects.append(project)
            return project
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @MainActor
    func renameProject(_ project: Project, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = projects.firstIndex(of: project) else { return }
        let old = projects[i].name
        projects[i].name = trimmed
        guard auth == .live else { return }
        do {
            try await NXORService.renameProject(id: project.id, name: trimmed)
        } catch {
            if let j = projects.firstIndex(where: { $0.id == project.id }) { projects[j].name = old }
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteProject(_ project: Project) async {
        guard !project.isDefault else { return }
        if auth == .live {
            do { try await NXORService.deleteProject(id: project.id) } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        projects.removeAll { $0.id == project.id }
        if currentProjectID == project.id { currentProjectID = projects.first { $0.isDefault }?.id ?? projects.first?.id }
    }

    // MARK: Navigation

    func open(_ route: Route) {
        self.route = route
        withAnimation(NX.Motion.pop) { sidebarOpen = false }
    }

    func openChat(_ id: String?) {
        currentChatID = id
        open(.chat)
        if let id, auth == .live { Task { await loadChat(id) } }
    }

    @MainActor
    func loadChat(_ id: String) async {
        guard let index = chats.firstIndex(where: { $0.id == id }), !chats[index].loaded else { return }
        do {
            let detail = try await NXORService.session(id)
            let messages = detail.messages.map { m -> ChatMessage in
                var message = ChatMessage(
                    role: m.role == "user" ? .user : .assistant,
                    text: m.content ?? "",
                    answeredBy: m.answeredBy?.name
                )
                message.files = (m.attachments ?? []).compactMap(URL.init(string:))
                message.generations = (m.generationRefs ?? []).map { ref in
                    GenerationCard(
                        generationId: ref.generationId,
                        kind: ref.kind == "video" ? .video : .image,
                        model: Self.modelLabel(for: ref.modelSlug),
                        credits: 0,
                        status: .processing,
                        prompt: ref.prompt ?? ""
                    )
                }
                return message
            }
            guard let i = chats.firstIndex(where: { $0.id == id }) else { return }
            chats[i].messages = messages
            chats[i].loaded = true
            for card in messages.flatMap(\.generations) { trackGeneration(card, in: id) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Sending

    @MainActor
    func send(_ text: String, attachments: [String] = []) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        let localID = currentChatID ?? "local-\(UUID().uuidString)"
        if currentChatID == nil {
            chats.insert(ChatThread(id: localID, title: String(trimmed.prefix(48)), messages: []), at: 0)
            currentChatID = localID
        }
        var userMessage = ChatMessage(role: .user, text: trimmed)
        userMessage.files = attachments.compactMap(URL.init(string:))
        append(userMessage, to: localID)

        isStreaming = true
        streamTask = Task { @MainActor in
            if auth == .live {
                await streamLive(trimmed, attachments: attachments, chatID: localID)
            } else {
                await streamDemo(chatID: localID)
            }
            streamingStage = nil
            isStreaming = false
            await refreshBalance()
        }
    }

    @MainActor
    func regenerate() {
        guard let chat = currentChat, let lastUser = chat.messages.last(where: { $0.role == .user }) else { return }
        send(lastUser.text, attachments: lastUser.files.map(\.absoluteString))
    }

    func sendToChat(_ items: [LibraryItem]) {
        pendingAttachments = items.filter { !$0.isVideo && $0.url != nil }
        currentChatID = nil
        open(.chat)
    }

    @MainActor
    func stop() {
        streamTask?.cancel()
        if let id = currentChatID, auth == .live, !id.hasPrefix("local-") {
            Task { await ChatStream.cancel(sessionId: id) }
        }
    }

    @MainActor
    private func streamLive(_ text: String, attachments: [String], chatID: String) async {
        var chatID = chatID
        let serverID = chatID.hasPrefix("local-") ? nil : chatID
        streamingStage = .thinking
        var reply = ChatMessage(role: .assistant, text: "", answeredBy: tier?.chat.name)
        var appended = false

        do {
            for try await event in ChatStream.send(sessionId: serverID, body: ChatSendBody(tier: selectedTier, content: text, attachments: attachments)) {
                switch event {
                case let .start(sessionId, _):
                    if sessionId != chatID, let i = chats.firstIndex(where: { $0.id == chatID }) {
                        chats[i] = ChatThread(id: sessionId, title: chats[i].title, messages: chats[i].messages)
                        if currentChatID == chatID { currentChatID = sessionId }
                        chatID = sessionId
                    }
                case let .delta(chunk):
                    streamingStage = nil
                    reply.text += chunk
                case let .status(stage, model):
                    let parsed = ChatStage(rawValue: stage) ?? .thinking
                    streamingStage = parsed
                    let label = model.map { "\(parsed.doneLabel) · \($0)" } ?? parsed.doneLabel
                    if parsed != .thinking, parsed != .reasoning, reply.steps.last != label { reply.steps.append(label) }
                    if let model, stage == "model_selected" { reply.answeredBy = model }
                case let .generation(kind, generationId, prompt, modelSlug, credits):
                    let card = GenerationCard(
                        generationId: generationId,
                        kind: kind == "video" ? .video : .image,
                        model: Self.modelLabel(for: modelSlug),
                        credits: Int(credits ?? 0),
                        status: .processing,
                        prompt: prompt ?? ""
                    )
                    reply.generations.append(card)
                    trackGeneration(card, in: chatID)
                case let .generationError(_, message):
                    errorMessage = message
                case let .proposal(proposal):
                    reply.proposals.append(proposal)
                case let .file(url, _):
                    reply.files.append(url)
                case .done:
                    break
                }
                if appended {
                    replaceLast(with: reply, in: chatID)
                } else if !reply.text.isEmpty || !reply.generations.isEmpty || !reply.proposals.isEmpty {
                    append(reply, to: chatID)
                    appended = true
                }
            }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func streamDemo(chatID: String) async {
        streamingStage = .thinking
        try? await Task.sleep(for: .milliseconds(700))
        streamingStage = .writingPrompt
        try? await Task.sleep(for: .milliseconds(700))
        streamingStage = nil

        let text = "This is a demo reply. Sign in with your NXOR account and the real agent will answer here. Model: \(tier?.chat.name ?? "Claude")."
        var message = ChatMessage(role: .assistant, text: "", answeredBy: tier?.chat.name)
        message.steps = [ChatStage.writingPrompt.doneLabel]
        append(message, to: chatID)
        for word in text.split(separator: " ") {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(35))
            message.text += (message.text.isEmpty ? "" : " ") + word
            replaceLast(with: message, in: chatID)
        }
    }

    // MARK: Proposals & chats

    @MainActor
    func runProposal(_ proposal: ChatProposal, in chatID: String) async {
        updateProposal(proposal.id, in: chatID) { $0.state = .running }
        if auth != .live {
            try? await Task.sleep(for: .seconds(1))
            updateProposal(proposal.id, in: chatID) { $0.state = .submitted }
            appendGeneration(GenerationCard(kind: proposal.kind == "video" ? .video : .image, model: proposal.modelLabel, credits: Int(proposal.credits ?? 0), status: .completed, prompt: proposal.prompt), to: proposal.id, in: chatID)
            return
        }
        do {
            let id = try await NXORService.submitProposal(sessionId: chatID, proposalId: proposal.id, prompt: proposal.prompt, modelSlug: proposal.modelSlug)
            updateProposal(proposal.id, in: chatID) { $0.state = .submitted }
            let card = GenerationCard(generationId: id, kind: proposal.kind == "video" ? .video : .image, model: proposal.modelLabel, credits: Int(proposal.credits ?? 0), status: .processing, prompt: proposal.prompt)
            appendGeneration(card, to: proposal.id, in: chatID)
            trackGeneration(card, in: chatID)
            await refreshBalance()
        } catch {
            updateProposal(proposal.id, in: chatID) { $0.state = .open }
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func dismissProposal(_ proposal: ChatProposal, in chatID: String) async {
        updateProposal(proposal.id, in: chatID) { $0.state = .dismissed }
        if auth == .live { try? await NXORService.dismissProposal(sessionId: chatID, proposalId: proposal.id) }
    }

    @MainActor
    func deleteChat(_ id: String) async {
        chats.removeAll { $0.id == id }
        if currentChatID == id { currentChatID = nil }
        if auth == .live, !id.hasPrefix("local-") {
            do { try await NXORService.deleteChat(id) } catch { errorMessage = error.localizedDescription }
        }
    }

    @MainActor
    private func updateProposal(_ id: String, in chatID: String, _ change: (inout ChatProposal) -> Void) {
        guard let c = chats.firstIndex(where: { $0.id == chatID }) else { return }
        for m in chats[c].messages.indices {
            if let p = chats[c].messages[m].proposals.firstIndex(where: { $0.id == id }) {
                change(&chats[c].messages[m].proposals[p])
            }
        }
    }

    @MainActor
    private func appendGeneration(_ card: GenerationCard, to proposalID: String, in chatID: String) {
        guard let c = chats.firstIndex(where: { $0.id == chatID }) else { return }
        for m in chats[c].messages.indices where chats[c].messages[m].proposals.contains(where: { $0.id == proposalID }) {
            chats[c].messages[m].generations.append(card)
        }
    }

    // MARK: Generations

    private func trackGeneration(_ card: GenerationCard, in chatID: String) {
        guard let generationId = card.generationId else { return }
        Task { @MainActor in
            for attempt in 0..<200 {
                let generation = try? await (card.kind == .video ? NXORService.video(generationId) : NXORService.image(generationId))
                if let generation {
                    update(generationId: generationId, in: chatID) { c in
                        c.status = GenerationCard.Status(rawValue: generation.status) ?? .processing
                        c.url = generation.outputs?.first?.url
                        c.thumbnailUrl = generation.previewURL
                        if let o = generation.outputs?.first, let w = o.width, let h = o.height, h > 0 {
                            c.aspect = Double(w) / Double(h)
                        }
                        c.errorMessage = generation.errorMessage
                    }
                    if !generation.isRunning { return }
                }
                try? await Task.sleep(for: .seconds(attempt < 20 ? 3 : 6))
            }
        }
    }

    @MainActor
    private func update(generationId: String, in chatID: String, _ change: (inout GenerationCard) -> Void) {
        guard let i = chats.firstIndex(where: { $0.id == chatID }) else { return }
        for m in chats[i].messages.indices {
            if let g = chats[i].messages[m].generations.firstIndex(where: { $0.generationId == generationId }) {
                change(&chats[i].messages[m].generations[g])
            }
        }
    }

    static func modelLabel(for slug: String?) -> String {
        guard let slug else { return "NXOR" }
        let words = slug.split(separator: "-").prefix { !["text", "image", "to", "video", "reference"].contains(String($0)) }
        return words.map { $0.count <= 3 ? $0.uppercased() : $0.capitalized }.joined(separator: " ")
    }

    private func append(_ message: ChatMessage, to id: String) {
        guard let i = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[i].messages.append(message)
    }

    private func replaceLast(with message: ChatMessage, in id: String) {
        guard let i = chats.firstIndex(where: { $0.id == id }), !chats[i].messages.isEmpty else { return }
        chats[i].messages[chats[i].messages.count - 1] = message
    }
}
