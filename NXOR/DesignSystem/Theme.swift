import SwiftUI
import UIKit

extension Color {
    /// Colour pair for light and dark appearance.
    init(light: UInt32, dark: UInt32, darkOpacity: Double = 1) {
        self.init(uiColor: UIColor { trait in
            let hex = trait.userInterfaceStyle == .light ? light : dark
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: trait.userInterfaceStyle == .light ? 1 : darkOpacity
            )
        })
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum NX {
    enum C {
        static let bg = Color(light: 0xF2F4F7, dark: 0x08090A)
        static let surface = Color(light: 0xFFFFFF, dark: 0x0B0D10)
        static let raised = Color(light: 0xE8ECF1, dark: 0x12151A)
        static let card = Color(light: 0xF7F8FA, dark: 0x0D0F12)
        static let popover = Color(light: 0xFFFFFF, dark: 0x12161B)
        static let lineSoft = Color(light: 0xE3E7EC, dark: 0x191B1F)
        static let track = Color(light: 0xD5DAE1, dark: 0x2A2F36)
        static let line = Color(light: 0xD9DEE5, dark: 0x23272D)
        static let line2 = Color(light: 0xC9D0D9, dark: 0x2E3238)
        static let ink = Color(light: 0x0B0D10, dark: 0xFFFFFF)
        static let inkSoft = Color(light: 0x14171B, dark: 0xEEF1F5)
        static let ink2 = Color(light: 0x444C56, dark: 0xAEB7C2)
        static let ink3 = Color(light: 0x5A636E, dark: 0x8A93A0)
        static let muted = Color(light: 0x66707B, dark: 0x6E7681)
        /// Base for soft fills: white on dark, black on light.
        static let tint = Color(light: 0x000000, dark: 0xFFFFFF)
        static let accent = Color(light: 0x0090B0, dark: 0x12E0FF)
        static let onAccent = Color(hex: 0x08090A)
        static let btnInk = Color(hex: 0x0B0D10)
        static let warn = Color(hex: 0xFFD166)
        static let danger = Color(light: 0xD62F2F, dark: 0xFF6B6B)
        static let blue = Color(hex: 0x2E5BFF)
        static let violet = Color(hex: 0x7B5BFF)
        static let pink = Color(hex: 0xFF3DD1)
        static let orchid = Color(hex: 0xC86BC8)
    }

    enum G {
        static let heroInk = LinearGradient(
            stops: [
                .init(color: C.blue, location: 0),
                .init(color: C.accent, location: 0.38),
                .init(color: C.orchid, location: 0.70),
                .init(color: C.pink, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
        static let brand = LinearGradient(
            stops: [
                .init(color: C.pink, location: 0),
                .init(color: C.violet, location: 0.55),
                .init(color: C.accent, location: 1),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let frame = LinearGradient(
            stops: [
                .init(color: C.accent, location: 0),
                .init(color: C.blue, location: 0.52),
                .init(color: C.pink, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
        static let silver = LinearGradient(
            stops: [
                .init(color: Color(hex: 0xF4F7FB), location: 0),
                .init(color: Color(hex: 0xC9D2DE), location: 0.55),
                .init(color: Color(hex: 0xDCE3EC), location: 1),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let sendIdle = LinearGradient(
            colors: [Color(hex: 0x8A93A0), Color(hex: 0x5C636D)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let sidebar = LinearGradient(
            stops: [
                .init(color: C.raised, location: 0),
                .init(color: Color(hex: 0x0A0B0D), location: 0.5),
                .init(color: Color(hex: 0x0F1216), location: 1),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let credits = LinearGradient(
            stops: [
                .init(color: C.blue, location: 0),
                .init(color: C.accent, location: 0.4),
                .init(color: C.pink, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
        static let selected = LinearGradient(
            colors: [Color(hex: 0xFDFEFF, opacity: 0.16), Color(hex: 0xC6CEDA, opacity: 0.08)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let featured = LinearGradient(
            colors: [Color(hex: 0x14122B), Color(hex: 0x1B1533), Color(hex: 0x241A3D)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let logo = LinearGradient(
            colors: [Color(hex: 0xF4F7FB), Color(hex: 0xBFC7D2)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    enum F {
        /// Archivo 900 italic — headlines and the wordmark.
        static func display(_ size: CGFloat) -> Font {
            .custom("Archivo-BlackItalic", size: size)
        }
        static func body(_ size: CGFloat = 16, _ weight: Font.Weight = .regular) -> Font {
            switch weight {
            case .black, .heavy, .bold: return .custom("Archivo-Black", size: size)
            case .semibold, .medium: return .custom("Archivo-SemiBold", size: size)
            default: return .custom("Archivo-Regular", size: size)
            }
        }
        /// IBM Plex Mono — labels, prices, parameters (always uppercase with wide tracking).
        static func mono(_ size: CGFloat = 11, _ weight: Font.Weight = .medium) -> Font {
            switch weight {
            case .semibold, .bold, .heavy, .black: return .custom("IBMPlexMono-SemiBold", size: size)
            case .regular, .light, .thin, .ultraLight: return .custom("IBMPlexMono-Regular", size: size)
            default: return .custom("IBMPlexMono-Medium", size: size)
            }
        }
    }

    enum Motion {
        static let press = Animation.easeOut(duration: 0.09)
        static let hover = Animation.easeOut(duration: 0.2)
        static let pop = Animation.spring(response: 0.3, dampingFraction: 0.85)
        static let enter = Animation.spring(response: 0.62, dampingFraction: 0.9)
    }
}
