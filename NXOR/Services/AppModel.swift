import SwiftUI
import Observation

enum Route: Hashable {
    case chat
    case studio
    case library
    case presets
    case billing
    case settings
    case help
}

@Observable
final class AppModel {
    var account = MockData.account
    var tiers: [ChatTier] = MockData.load("tiers") ?? []
    var capabilities: [Capability] = MockData.load("capabilities") ?? []
    var presets: [PresetSummary] = MockData.load("presets") ?? []
    var imageModels: [ModelFamily] = MockData.load("imageModels") ?? []
    var videoModels: [ModelFamily] = MockData.load("videoModels") ?? []
    var plans: [Plan] = MockData.load("plans") ?? []
    var topups: [TopUp] = MockData.load("topups") ?? []

    var chats: [ChatThread] = MockData.chats
    var route: Route = .chat
    var currentChatID: String? = nil
    var selectedTier = "fast"
    var sidebarOpen = false

    var currentChat: ChatThread? {
        guard let id = currentChatID else { return nil }
        return chats.first { $0.id == id }
    }

    var tier: ChatTier? { tiers.first { $0.tier == selectedTier } }

    func open(_ route: Route) {
        self.route = route
        withAnimation(NX.Motion.pop) { sidebarOpen = false }
    }

    func openChat(_ id: String?) {
        currentChatID = id
        open(.chat)
    }

    @MainActor
    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let id: String
        if let current = currentChatID {
            id = current
        } else {
            id = UUID().uuidString
            chats.insert(ChatThread(id: id, title: String(trimmed.prefix(48)), messages: []), at: 0)
            currentChatID = id
        }
        append(ChatMessage(role: .user, text: trimmed), to: id)

        // Mock stream: stages, then the reply arrives word by word.
        streamingStage = .thinking
        try? await Task.sleep(for: .milliseconds(700))
        streamingStage = .writingPrompt
        try? await Task.sleep(for: .milliseconds(700))
        streamingStage = nil

        let reply = "This is a demo reply — the real NXOR agent will answer here once the app is connected to your account. Model: \(tier?.chat.name ?? "Claude")."
        var message = ChatMessage(role: .assistant, text: "", answeredBy: tier?.chat.name)
        append(message, to: id)
        for word in reply.split(separator: " ") {
            try? await Task.sleep(for: .milliseconds(35))
            message.text += (message.text.isEmpty ? "" : " ") + word
            replaceLast(with: message, in: id)
        }
    }

    var streamingStage: ChatStage? = nil

    private func append(_ message: ChatMessage, to id: String) {
        guard let i = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[i].messages.append(message)
    }

    private func replaceLast(with message: ChatMessage, in id: String) {
        guard let i = chats.firstIndex(where: { $0.id == id }), !chats[i].messages.isEmpty else { return }
        chats[i].messages[chats[i].messages.count - 1] = message
    }
}
