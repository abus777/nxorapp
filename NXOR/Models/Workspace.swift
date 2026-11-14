import Foundation
import SwiftUI

/// Root of the app picked in the ≡ menu (Chat / Studio) plus the Projects list.
enum AppSection: String, Hashable {
    case chat, studio, projects
}

/// Where a project was opened from decides what it shows first (12 = chats, 12s = media).
enum ProjectEntry: String, Hashable {
    case chat, studio
}

/// Pushed screens. Each root keeps one NavigationStack.
enum Dest: Hashable {
    case project(String, ProjectEntry)
    case projectChat(String)
    case newProjectChat(String)
    case presets
    case presetCategory(String)
    case result(String)
    case account
    case projects
    case help
}

/// What a project is for (screen 11). Decides which fields step 2 asks for.
enum ProjectKind: String, Codable, CaseIterable, Identifiable {
    case avatar, brand, product, realEstate, folder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .avatar: return "AI avatar / character"
        case .brand: return "Brand or business"
        case .product: return "Product shoot"
        case .realEstate: return "Real estate listing"
        case .folder: return "Just a folder"
        }
    }

    var shortTitle: String {
        switch self {
        case .avatar: return "AI avatar"
        case .brand: return "Brand"
        case .product: return "Product"
        case .realEstate: return "Real estate"
        case .folder: return "Folder"
        }
    }

    var subtitle: String {
        switch self {
        case .avatar: return "Your face or a made-up character, same look in every shot"
        case .brand: return "Logo, colors and products used in every generation"
        case .product: return "Photos and videos of one product"
        case .realEstate: return "Property photos → ad videos, EN + AR texts"
        case .folder: return "Only a name — keep chats and generations together"
        }
    }

    var icon: String {
        switch self {
        case .avatar: return "person.crop.square"
        case .brand: return "seal"
        case .product: return "shippingbox"
        case .realEstate: return "building.2"
        case .folder: return "folder"
        }
    }

    var photosLabel: String? {
        switch self {
        case .avatar: return "Face photos"
        case .brand: return "Logo and references"
        case .product: return "Product photos"
        case .realEstate: return "Property photos"
        case .folder: return nil
        }
    }

    var namePlaceholder: String {
        switch self {
        case .avatar: return "e.g. Me as a news anchor"
        case .brand: return "e.g. Oud & Co perfume"
        case .product: return "e.g. Summer sneaker drop"
        case .realEstate: return "e.g. Palm Villa Launch"
        case .folder: return "e.g. Personal"
        }
    }
}

/// Things NXOR knows about a project that the API doesn't store yet: kept on the device.
struct ProjectMeta: Codable, Hashable {
    var kind: ProjectKind = .folder
    var about: String = ""
    var defaultFormat: String = "Auto"
    var brandColors: [String] = []
    var referenceIDs: [String] = []
    var voice: String? = nil
    var brandKitOn = true

    var hasBrandKit: Bool { kind == .brand || !brandColors.isEmpty }
}

/// A prompt handed to Studio (from chat, a preset, or the result screen's Reuse).
struct StudioDraft: Equatable {
    var prompt: String
    var mode: CreateMode
    var fromChatTitle: String? = nil
    var fromChatID: String? = nil
    var projectID: String? = nil
    var referenceIDs: [String] = []
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, dark, light

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

/// Chat tiers shown in the mode menu (04): Fast / Smart / Genius.
struct ChatModeInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let note: String
}

extension Date {
    var relativeShort: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: .now)
    }
}
