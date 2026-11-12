import Foundation

struct Account: Hashable {
    var name: String
    var email: String
    var planName: String
    var planSlug: String
    var available: Double
    var reserved: Double
    var monthlyGrant: Double
}

struct ChatThread: Identifiable, Hashable {
    let id: String
    var title: String
    var messages: [ChatMessage]
}

struct ChatMessage: Identifiable, Hashable {
    enum Role: String, Hashable { case user, assistant }

    let id = UUID()
    let role: Role
    var text: String
    var answeredBy: String? = nil
    var generation: GenerationCard? = nil
}

struct GenerationCard: Hashable {
    enum Kind: String, Hashable { case image, video }
    enum Status: String, Hashable { case pending, processing, completed, failed }

    let kind: Kind
    let model: String
    let credits: Int
    var status: Status
    let prompt: String
}

enum ChatStage: String {
    case thinking, searching, generating, routing, reasoning
    case generatingImage = "generating_image"
    case generatingVideo = "generating_video"
    case modelSelected = "model_selected"
    case writingPrompt = "writing_prompt"
    case runningCode = "running_code"
    case readingLink = "reading_link"
    case waiting
    case searchingPresets = "searching_presets"

    var label: String {
        switch self {
        case .thinking, .reasoning: return "Thinking"
        case .searching: return "Searching the web"
        case .generating: return "Generating"
        case .generatingImage: return "Creating image"
        case .generatingVideo: return "Creating video"
        case .modelSelected, .routing: return "Picking the model"
        case .writingPrompt: return "Writing the prompt"
        case .runningCode: return "Running code"
        case .readingLink: return "Reading the link"
        case .waiting: return "Waiting"
        case .searchingPresets: return "Looking through presets"
        }
    }
}
