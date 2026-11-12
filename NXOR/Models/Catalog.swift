import Foundation

struct ChatTier: Codable, Identifiable, Hashable {
    struct Engine: Codable, Hashable {
        let slug: String?
        let name: String
        let provider: String
    }
    struct Family: Codable, Hashable {
        let family: String
        let label: String
        let provider: String
    }

    let tier: String
    let locked: Bool
    let requires: String?
    let chat: Engine
    let images: [Family]
    let videos: [Family]

    var id: String { tier }
    var title: String { tier.capitalized }
    var subtitle: String {
        switch tier {
        case "fast": return "Quick answers · up to \(chat.name)"
        case "smart": return "Balanced · up to \(chat.name)"
        default: return "Complex work · up to \(chat.name)"
        }
    }
}

struct Capability: Codable, Identifiable, Hashable {
    let id: String
    let group: String
    let icon: String
    let card: Bool
    let title: String
    let tiers: [String]
    let available: Bool

    var systemImage: String {
        switch icon {
        case "sparkles": return "sparkle"
        case "video": return "video"
        case "image": return "photo"
        case "globe": return "globe"
        case "file", "file-text": return "doc.text"
        case "wand": return "wand.and.stars"
        case "maximize": return "viewfinder"
        case "pen": return "pencil.line"
        case "layers": return "square.3.layers.3d"
        default: return "sparkle"
        }
    }

    var summary: String {
        switch id {
        case "preset": return "Ready-made looks and effects, applied to your own photo or video."
        case "video": return "A short video from a text description or from a photo."
        case "image": return "A picture from a text description."
        case "web_search": return "Current news and facts, with sources."
        case "files", "documents": return "Read PDF, Word, Excel, PowerPoint and CSV files, and make new ones."
        case "image_edit": return "Change a photo or an earlier picture. Point at it with @image."
        case "finalize": return "Turn a draft video into a final high-resolution one."
        case "prompt_writing": return "Ready-to-use prompts for any image or video model."
        case "models": return "Name the model you want and it is used."
        default: return ""
        }
    }

    var example: String {
        switch id {
        case "preset": return "Show me trendy presets"
        case "video": return "A 5-second video of a cat walking on a rooftop at sunset"
        case "image": return "A red fox in fresh snow, golden hour"
        case "web_search": return "What's new in AI video this week?"
        case "image_edit": return "Make the sky in @image1 stormy"
        case "finalize": return "Render my last draft in 4K"
        case "prompt_writing": return "Write a prompt for a product shot of sneakers"
        case "models": return "Make an image with Nano Banana Pro"
        default: return "Summarise the attached PDF"
        }
    }
}

struct PresetSummary: Codable, Identifiable, Hashable {
    let slug: String
    let kind: String
    let name: String
    let tags: [String]
    let previewImageUrl: URL?
    let previewVideoUrl: URL?
    let credits: Int
    let creditsVary: Bool

    var id: String { slug }
    var priceLabel: String {
        "\(kind.uppercased()) · \(creditsVary ? "FROM " : "")\(credits) CR"
    }
}

struct ModelDimension: Codable, Hashable {
    struct Option: Codable, Hashable {
        let value: String
        let label: String
    }
    let key: String
    let label: String
    let options: [Option]
}

struct ModelVariant: Codable, Hashable {
    struct Body: Codable, Hashable {
        let prompt: String?
        let aspectRatio: [String]?
        let source: String?
        let maxSourceImages: Int?
        let videoInput: String?
        let negativePrompt: Bool?
    }
    let slug: String
    let dims: [String: String]
    let body: Body
}

struct ModelFamily: Codable, Identifiable, Hashable {
    let family: String
    let label: String
    let provider: String
    let description: String?
    let dimensions: [ModelDimension]
    let variants: [ModelVariant]

    var id: String { family }
}

struct Plan: Codable, Identifiable, Hashable {
    let slug: String
    let name: String
    let priceMonthlyUsd: String
    let priceYearlyUsd: String
    let anchorMonthlyUsd: String?
    let monthlyTokenGrant: Int
    let parallelGenerations: Bool
    let prioritySupport: Bool

    var id: String { slug }
}

struct TopUp: Codable, Identifiable, Hashable {
    let slug: String
    let name: String
    let tokenAmount: Int
    let priceAmount: String

    var id: String { slug }
}
