import Foundation

enum ChatEvent {
    case start(sessionId: String, messageId: String)
    case delta(String)
    case status(stage: String, model: String?)
    case generation(kind: String, generationId: String, prompt: String?, modelSlug: String?, credits: Double?)
    case generationError(kind: String, message: String)
    case proposal(ChatProposal)
    case file(url: URL, name: String)
    case done
}

struct ChatProposal: Identifiable, Hashable {
    let id: String
    let kind: String
    let prompt: String
    let modelLabel: String
    let credits: Double?
}

struct ChatSendBody: Encodable {
    let tier: String
    let content: String
    var attachments: [String] = []
    var documents: [String] = []
    var promptReview = true
}

enum ChatStream {
    /// Sends a message and streams the server-sent events back.
    /// NOTE: this spends credits on the user's account.
    static func send(sessionId: String?, body: ChatSendBody, api: APIClient = .shared) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let path = sessionId.map { "chat/sessions/\($0)/messages" } ?? "chat/messages"
                    var request = try api.makeRequest(path, method: "POST", body: body)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 300

                    var (bytes, response) = try await api.session.bytes(for: request)
                    if (response as? HTTPURLResponse)?.statusCode == 401, await api.refresh() {
                        (bytes, response) = try await api.session.bytes(for: request)
                    }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        throw APIClient.error(from: data, status: status)
                    }

                    // `lines` drops blank separators, so each `data:` line is handled with the latest `event:`.
                    var eventName = "message"
                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            eventName = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            if let event = parse(event: eventName, payload: payload) {
                                continuation.yield(event)
                                if case .done = event { break }
                            }
                            if eventName == "error" {
                                throw APIError(status: 500, code: "stream_error", message: "The reply was interrupted. Failed generations are not charged.")
                            }
                            eventName = "message"
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func cancel(sessionId: String, api: APIClient = .shared) async {
        try? await api.postVoid("chat/sessions/\(sessionId)/cancel")
    }

    static func parse(event: String, payload: String) -> ChatEvent? {
        guard let data = payload.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }

        switch event {
        case "start":
            guard let s = json["sessionId"] as? String, let m = json["messageId"] as? String else { return nil }
            return .start(sessionId: s, messageId: m)
        case "delta":
            guard let text = json["text"] as? String, !text.isEmpty else { return nil }
            return .delta(text)
        case "status":
            guard let stage = json["stage"] as? String else { return nil }
            let detail = json["detail"] as? [String: Any]
            return .status(stage: stage, model: detail?["name"] as? String)
        case "tool":
            guard let id = json["generationId"] as? String else { return nil }
            return .generation(
                kind: json["kind"] as? String ?? "image",
                generationId: id,
                prompt: json["prompt"] as? String,
                modelSlug: json["modelSlug"] as? String,
                credits: json["credits"] as? Double
            )
        case "tool_error":
            return .generationError(kind: json["kind"] as? String ?? "image", message: json["message"] as? String ?? "Generation failed")
        case "proposal":
            guard let id = json["proposalId"] as? String ?? json["id"] as? String else { return nil }
            let model = json["model"] as? [String: Any]
            return .proposal(ChatProposal(
                id: id,
                kind: json["kind"] as? String ?? "image",
                prompt: json["prompt"] as? String ?? "",
                modelLabel: model?["label"] as? String ?? "",
                credits: model?["credits"] as? Double
            ))
        case "file":
            guard let raw = json["url"] as? String, let url = URL(string: raw) else { return nil }
            return .file(url: url, name: json["name"] as? String ?? url.lastPathComponent)
        case "done":
            return .done
        default:
            return nil
        }
    }
}
