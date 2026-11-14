import SwiftUI
import Observation
import Network
import UserNotifications
import Photos

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
    var section: AppSection = .chat
    var path: [Dest] = []
    var currentChatID: String? = nil
    var selectedTier = "fast"
    var sidebarOpen = false
    var launchSheet: String?
    var launchSidebar = false
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

    // Sheets and prompts owned by the root.
    var studioDraft: StudioDraft?
    var showCreateSheet = false
    var showCredits = false
    var showPlans = false
    var showNewProject = false
    var moveChatID: String?
    var showNotifyPrompt = false
    var toast: String?
    var showPhotosDenied = false
    var webSearchOn = true
    var memoryOn = true

    // Device state.
    var offline = false
    var queuedMessage: String?
    var projectMeta: [String: ProjectMeta] = [:]
    var appearance: Appearance = Appearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .dark {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }
    /// Asked once, right after the first video is started (R5).
    var notifyAsked: Bool = UserDefaults.standard.bool(forKey: "notifyAsked") {
        didSet { UserDefaults.standard.set(notifyAsked, forKey: "notifyAsked") }
    }
    /// Generation ids started from chat — their tiles carry "Aa from chat".
    var chatGenerationIDs: [String: String] = [:]

    private let pathMonitor = NWPathMonitor()

    /// One Studio composer shared by Studio, projects and the create sheet.
    let studio = StudioModel()
    let store = Store()
    /// Finished jobs not yet in a library reload.
    var freshItems: [LibraryItem] = []

    func register(job: GenerationCard, projectID: String?) {
        let item = LibraryItem(card: job, projectId: projectID ?? defaultProject?.id)
        assetIndex[item.dragPayload] = item
        freshItems.removeAll { $0.id == item.id }
        freshItems.insert(item, at: 0)
    }

    func isFromChat(_ item: LibraryItem) -> Bool { chatGenerationIDs[item.id] != nil }

    func chatTitle(for item: LibraryItem) -> String? {
        guard let chatID = chatGenerationIDs[item.id] else { return nil }
        return chats.first { $0.id == chatID }?.title
    }

    /// User projects (the API's default project holds work that is "not in a project").
    var userProjects: [Project] { projects.filter { !$0.isDefault } }
    var defaultProject: Project? { projects.first { $0.isDefault } }

    func meta(_ projectID: String?) -> ProjectMeta {
        guard let projectID else { return ProjectMeta() }
        return projectMeta[projectID] ?? ProjectMeta()
    }

    func setMeta(_ meta: ProjectMeta, for projectID: String) {
        projectMeta[projectID] = meta
        if let data = try? JSONEncoder().encode(projectMeta) { UserDefaults.standard.set(data, forKey: "projectMeta") }
    }

    func project(_ id: String?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    func chats(in projectID: String) -> [ChatThread] {
        chats.filter { $0.projectID == projectID }
    }

    var currentProject: Project? { projects.first { $0.id == currentProjectID } }

    private var streamTask: Task<Void, Never>?

    // Launch arguments (e.g. `-demo YES -route studio -push presets`) let CI open any screen for screenshots.
    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "projectMeta"), let saved = try? JSONDecoder().decode([String: ProjectMeta].self, from: data) {
            projectMeta = saved
        }
        if let raw = defaults.string(forKey: "route"), let section = AppSection(rawValue: raw) { self.section = section }
        currentChatID = defaults.string(forKey: "chat")
        launchSidebar = defaults.bool(forKey: "sidebar")
        launchSheet = defaults.string(forKey: "sheet")
        launchPreset = defaults.string(forKey: "preset")
        if defaults.bool(forKey: "demo") { enterDemo() }
        if let push = defaults.string(forKey: "push") { path = Self.launchPath(push, app: self) }
        if defaults.bool(forKey: "offline") { offline = true }
        startPathMonitor()
    }

    private static func launchPath(_ raw: String, app: AppModel) -> [Dest] {
        let parts = raw.split(separator: ":").map(String.init)
        let first = app.userProjects.first?.id ?? ""
        switch parts.first ?? "" {
        case "presets": return [.presets]
        case "category": return [.presets, .presetCategory(parts.count > 1 ? parts[1] : "product")]
        case "account": return [.account]
        case "projects": return [.projects]
        case "project": return [.project(first, parts.count > 1 && parts[1] == "studio" ? .studio : .chat)]
        case "projectChat": return [.project(first, .chat), .projectChat(parts.count > 1 ? parts[1] : "p1")]
        case "newProjectChat": return [.project(first, .chat), .newProjectChat(first)]
        case "result":
            let first = app.presets.first { $0.kind == "image" }.map { "demo-\($0.slug)" } ?? ""
            return [.result(parts.count > 1 && parts[1] != "first" ? parts[1] : first)]
        default: return []
        }
    }

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self, !UserDefaults.standard.bool(forKey: "offline") else { return }
                let wasOffline = self.offline
                self.offline = path.status != .satisfied
                if wasOffline, !self.offline, let queued = self.queuedMessage {
                    self.queuedMessage = nil
                    self.send(queued)
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "nxor.path"))
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
        for (id, meta) in MockData.projectMeta where projectMeta[id] == nil { projectMeta[id] = meta }
        if let video = presets.first(where: { $0.kind == "video" }) { chatGenerationIDs["demo-\(video.slug)"] = "c3" }
        if let image = presets.first(where: { $0.kind == "image" }) { chatGenerationIDs["demo-\(image.slug)"] = "p1" }
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
            section = .chat
            path = []
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
        section = .chat
        path = []
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
            let links = (UserDefaults.standard.dictionary(forKey: "chatProjects") as? [String: String]) ?? [:]
            chats = page.items.map { ChatThread(id: $0.id, title: $0.title ?? "New chat", messages: [], loaded: false, projectID: links[$0.id]) }
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

    /// Switch root (Chat / Studio / Projects) from the ≡ menu.
    func open(_ section: AppSection) {
        self.section = section
        path = []
        withAnimation(NX.Motion.pop) { sidebarOpen = false }
    }

    func push(_ dest: Dest) {
        withAnimation(NX.Motion.pop) { sidebarOpen = false }
        path.append(dest)
    }

    func openChat(_ id: String?) {
        currentChatID = id
        if let id, let chat = chats.first(where: { $0.id == id }), let project = chat.projectID {
            section = .chat
            path = [.project(project, .chat), .projectChat(id)]
            withAnimation(NX.Motion.pop) { sidebarOpen = false }
        } else {
            open(.chat)
        }
        if let id, auth == .live { Task { await loadChat(id) } }
    }

    func newChat() {
        currentChatID = nil
        open(.chat)
    }

    /// Hand a prompt to Studio (S2 / S4): opens the create sheet with "From chat ×".
    func openInStudio(_ draft: StudioDraft) {
        studioDraft = draft
        if let project = draft.projectID {
            section = .studio
            path = [.project(project, .studio)]
        } else {
            open(.studio)
        }
        showCreateSheet = true
    }

    func showToast(_ text: String) {
        toast = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if toast == text { toast = nil }
        }
    }

    // MARK: Chats ↔ projects

    @MainActor
    func moveChat(_ chatID: String, to project: Project) async {
        guard let i = chats.firstIndex(where: { $0.id == chatID }) else { return }
        chats[i].projectID = project.id
        var links = (UserDefaults.standard.dictionary(forKey: "chatProjects") as? [String: String]) ?? [:]
        links[chatID] = project.id
        UserDefaults.standard.set(links, forKey: "chatProjects")
        let refs = chats[i].messages.flatMap(\.allGenerations).compactMap { card -> LibraryRef? in
            guard let id = card.generationId else { return nil }
            return LibraryRef(kind: card.kind.rawValue, id: id)
        }
        if auth == .live, !refs.isEmpty {
            _ = try? await NXORService.libraryMove(refs, to: project.id)
        }
        showToast("Moved to \(project.name)")
    }

    @MainActor
    func renameChat(_ chatID: String, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = chats.firstIndex(where: { $0.id == chatID }) else { return }
        chats[i].title = trimmed
    }

    /// Start a new chat inside a project (12a).
    func startProjectChat(_ projectID: String) {
        currentChatID = nil
        pendingProjectID = projectID
    }

    var pendingProjectID: String?

    // MARK: Prompt blocks → cards (05b → 05)

    /// "Use this prompt → choose model": a local draft card under the prompt block.
    @MainActor
    func addLocalProposal(prompt: String, kind: GenerationCard.Kind, after messageID: UUID, in chatID: String) {
        guard let c = chats.firstIndex(where: { $0.id == chatID }),
              let m = chats[c].messages.firstIndex(where: { $0.id == messageID }) else { return }
        let families = kind == .video ? videoModels : imageModels
        let label = families.first?.label ?? (kind == .video ? "Kling 3.0" : "Nano Banana Pro")
        let proposal = ChatProposal(id: "local-\(UUID().uuidString)", kind: kind.rawValue, prompt: prompt, modelLabel: label, modelSlug: nil, credits: auth == .live ? nil : (kind == .video ? 1050 : 25))
        chats[c].messages[m].proposals.append(proposal)
    }

    /// Runs a local draft with Studio's generate endpoint.
    @MainActor
    func runLocalProposal(_ proposal: ChatProposal, label: String, price: Int?, in chatID: String) async {
        updateProposal(proposal.id, in: chatID) { $0.state = .running }
        let kind: GenerationCard.Kind = proposal.kind == "video" ? .video : .image
        if auth != .live {
            try? await Task.sleep(for: .seconds(1))
            updateProposal(proposal.id, in: chatID) { $0.state = .submitted }
            var card = GenerationCard(kind: kind, model: label, credits: price ?? 0, status: .completed, prompt: proposal.prompt)
            let sample = presets.first { $0.kind == proposal.kind }
            card.thumbnailUrl = sample?.previewImageUrl
            card.url = sample?.previewVideoUrl ?? sample?.previewImageUrl
            appendGeneration(card, to: proposal.id, in: chatID)
            account.available -= Double(price ?? 0)
            didStartGeneration(kind: kind)
            return
        }
        let families = kind == .video ? videoModels : imageModels
        let family = families.first { $0.label == label } ?? families.first
        let op = kind == .video ? "text-to-video" : "text-to-image"
        let slug = proposal.modelSlug ?? family?.variants.first { ($0.dims["operation"] ?? op) == op }?.slug
        guard let slug else {
            updateProposal(proposal.id, in: chatID) { $0.state = .open }
            errorMessage = "No model available for this prompt."
            return
        }
        do {
            let projectID = chats.first { $0.id == chatID }?.projectID ?? defaultProject?.id
            let body = GenerateBody(modelSlug: slug, prompt: proposal.prompt, projectId: projectID, idempotencyKey: UUID().uuidString)
            let id = try await NXORService.generate(kind: kind.rawValue, body: body)
            updateProposal(proposal.id, in: chatID) { $0.state = .submitted }
            let card = GenerationCard(generationId: id, kind: kind, model: label, credits: price ?? 0, status: .processing, prompt: proposal.prompt)
            appendGeneration(card, to: proposal.id, in: chatID)
            chatGenerationIDs[id] = chatID
            trackGeneration(card, in: chatID)
            didStartGeneration(kind: kind)
            await refreshBalance()
        } catch {
            updateProposal(proposal.id, in: chatID) { $0.state = .open }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Photos (R6)

    @MainActor
    func saveToPhotos(url: URL?, isVideo: Bool) async {
        guard let url else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            showPhotosDenied = true
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("nxor-\(UUID().uuidString).\(isVideo ? "mp4" : (url.pathExtension.isEmpty ? "jpg" : url.pathExtension))")
            try data.write(to: file)
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: isVideo ? .video : .photo, fileURL: file, options: nil)
            }
            showToast("Saved to Photos")
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    // MARK: Notifications (R5)

    @MainActor
    func requestNotifications() async {
        notifyAsked = true
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func notifyReady(kind: GenerationCard.Kind, title: String) {
        let content = UNMutableNotificationContent()
        content.title = "NXOR · Your \(kind == .video ? "video" : "picture") is ready"
        content.body = "\(title) · tap to open"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// After the first video starts, ask once whether to ping when it's ready.
    func didStartGeneration(kind: GenerationCard.Kind) {
        if kind == .video, !notifyAsked { showNotifyPrompt = true }
    }

    func openChatLegacy(_ id: String?) {
        openChat(id)
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
            chats.insert(ChatThread(id: localID, title: String(trimmed.prefix(48)), messages: [], projectID: pendingProjectID, tier: selectedTier), at: 0)
            currentChatID = localID
            pendingProjectID = nil
        }
        var userMessage = ChatMessage(role: .user, text: trimmed)
        userMessage.files = attachments.compactMap(URL.init(string:))
        if offline {
            userMessage.pending = true
            append(userMessage, to: localID)
            queuedMessage = trimmed
            return
        }
        append(userMessage, to: localID)
        let outgoing = contextualized(trimmed, chatID: localID)

        isStreaming = true
        streamTask = Task { @MainActor in
            if auth == .live {
                await streamLive(outgoing, attachments: attachments, chatID: localID)
            } else {
                await streamDemo(chatID: localID)
            }
            streamingStage = nil
            isStreaming = false
            await refreshBalance()
        }
    }

    /// The first message of a project chat carries the project's instructions, so NXOR "knows this project".
    private func contextualized(_ text: String, chatID: String) -> String {
        guard let chat = chats.first(where: { $0.id == chatID }), let projectID = chat.projectID,
              chat.messages.filter({ $0.role == .user }).count <= 1,
              let project = project(projectID) else { return text }
        let m = meta(projectID)
        var context = "Project: \(project.name) (\(m.kind.shortTitle))."
        if !m.about.isEmpty { context += " Instructions: \(m.about)" }
        if m.defaultFormat != "Auto" { context += " Default format: \(m.defaultFormat)." }
        return "[\(context)]\n\n\(text)"
    }

    @MainActor
    func cancelQueued() {
        queuedMessage = nil
        guard let id = currentChatID, let i = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[i].messages.removeAll { $0.pending }
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
                        chats[i] = ChatThread(id: sessionId, title: chats[i].title, messages: chats[i].messages, projectID: chats[i].projectID, tier: chats[i].tier)
                        if let projectID = chats[i].projectID {
                            var links = (UserDefaults.standard.dictionary(forKey: "chatProjects") as? [String: String]) ?? [:]
                            links[sessionId] = projectID
                            UserDefaults.standard.set(links, forKey: "chatProjects")
                        }
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
                    chatGenerationIDs[generationId] = chatID
                    trackGeneration(card, in: chatID)
                    didStartGeneration(kind: card.kind)
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
            var card = GenerationCard(kind: proposal.kind == "video" ? .video : .image, model: proposal.modelLabel, credits: Int(proposal.credits ?? 0), status: .completed, prompt: proposal.prompt)
            let sample = presets.first { $0.kind == proposal.kind }
            card.thumbnailUrl = sample?.previewImageUrl
            card.url = sample?.previewVideoUrl ?? sample?.previewImageUrl
            appendGeneration(card, to: proposal.id, in: chatID)
            didStartGeneration(kind: card.kind)
            return
        }
        do {
            let id = try await NXORService.submitProposal(sessionId: chatID, proposalId: proposal.id, prompt: proposal.prompt, modelSlug: proposal.modelSlug)
            updateProposal(proposal.id, in: chatID) { $0.state = .submitted }
            let card = GenerationCard(generationId: id, kind: proposal.kind == "video" ? .video : .image, model: proposal.modelLabel, credits: Int(proposal.credits ?? 0), status: .processing, prompt: proposal.prompt)
            appendGeneration(card, to: proposal.id, in: chatID)
            if let id { chatGenerationIDs[id] = chatID }
            trackGeneration(card, in: chatID)
            didStartGeneration(kind: card.kind)
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
        if card.status == .processing || card.status == .pending {
            RenderActivities.start(id: generationId, title: chats.first { $0.id == chatID }?.title ?? "NXOR", model: card.model, kind: card.kind)
        }
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
                    if generation.isRunning { RenderActivities.tick(id: generationId) }
                    if !generation.isRunning {
                        RenderActivities.finish(id: generationId, success: generation.status == "completed")
                        if generation.status == "completed", let title = chats.first(where: { $0.id == chatID })?.title {
                            notifyReady(kind: card.kind, title: title)
                        }
                        return
                    }
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
