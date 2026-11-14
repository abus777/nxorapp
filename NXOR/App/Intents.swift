import AppIntents
import Foundation

/// R14: "Hey Siri, make an image with NXOR" — asks what to show, then opens Studio with it.
struct MakeImageIntent: AppIntent {
    static var title: LocalizedStringResource = "Make an image with NXOR"
    static var description = IntentDescription("Describe a picture; NXOR opens Studio with your prompt ready to render.")
    static var openAppWhenRun = true

    @Parameter(title: "What should it show?", requestValueDialog: "What should it show?")
    var prompt: String

    func perform() async throws -> some IntentResult {
        PendingLaunch.store(mode: "image", prompt: prompt)
        return .result()
    }
}

struct MakeVideoIntent: AppIntent {
    static var title: LocalizedStringResource = "Make a video with NXOR"
    static var description = IntentDescription("Describe a video; NXOR opens Studio with your prompt ready to render.")
    static var openAppWhenRun = true

    @Parameter(title: "What should happen?", requestValueDialog: "What should happen in the video?")
    var prompt: String

    func perform() async throws -> some IntentResult {
        PendingLaunch.store(mode: "video", prompt: prompt)
        return .result()
    }
}

struct AskNXORIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask NXOR"
    static var openAppWhenRun = true

    @Parameter(title: "Question", requestValueDialog: "What do you want to ask?")
    var question: String

    func perform() async throws -> some IntentResult {
        PendingLaunch.store(mode: "chat", prompt: question)
        return .result()
    }
}

struct NXORShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MakeImageIntent(), phrases: ["Make an image with \(.applicationName)", "Create a picture in \(.applicationName)"], shortTitle: "Make an image", systemImageName: "photo")
        AppShortcut(intent: MakeVideoIntent(), phrases: ["Make a video with \(.applicationName)"], shortTitle: "Make a video", systemImageName: "video")
        AppShortcut(intent: AskNXORIntent(), phrases: ["Ask \(.applicationName)"], shortTitle: "Ask NXOR", systemImageName: "bubble.left")
    }
}

/// Hand-off from Siri, widgets and `nxor://` links to the running app.
enum PendingLaunch {
    static func store(mode: String, prompt: String) {
        UserDefaults.standard.set(["mode": mode, "prompt": prompt], forKey: "pendingLaunch")
    }

    static func take() -> (mode: String, prompt: String)? {
        guard let value = UserDefaults.standard.dictionary(forKey: "pendingLaunch") as? [String: String],
              let mode = value["mode"] else { return nil }
        UserDefaults.standard.removeObject(forKey: "pendingLaunch")
        return (mode, value["prompt"] ?? "")
    }

    /// nxor://new · nxor://ask · nxor://create?mode=video&prompt=…
    static func handle(_ url: URL) {
        guard url.scheme == "nxor" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let prompt = items.first { $0.name == "prompt" }?.value ?? ""
        switch url.host {
        case "create": store(mode: items.first { $0.name == "mode" }?.value ?? "image", prompt: prompt)
        case "ask", "new": store(mode: "chat", prompt: prompt)
        case "studio": store(mode: "studio", prompt: "")
        default: break
        }
    }
}
