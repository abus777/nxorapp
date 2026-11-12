import SwiftUI

extension Color {
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
        static let bg = Color(hex: 0x08090A)
        static let surface = Color(hex: 0x0B0D10)
        static let raised = Color(hex: 0x12151A)
        static let line = Color(hex: 0x23272D)
        static let line2 = Color(hex: 0x2E3238)
        static let ink = Color.white
        static let inkSoft = Color(hex: 0xEEF1F5)
        static let ink2 = Color(hex: 0xAEB7C2)
        static let ink3 = Color(hex: 0x8A93A0)
        static let muted = Color(hex: 0x6E7681)
        static let accent = Color(hex: 0x12E0FF)
        static let onAccent = Color(hex: 0x08090A)
        static let btnInk = Color(hex: 0x0B0D10)
        static let warn = Color(hex: 0xFFD166)
        static let danger = Color(hex: 0xFF6B6B)
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
        static let logo = LinearGradient(
            colors: [Color(hex: 0xF4F7FB), Color(hex: 0xBFC7D2)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    enum F {
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .black).italic()
        }
        static func body(_ size: CGFloat = 16, _ weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }
        static func mono(_ size: CGFloat = 11, _ weight: Font.Weight = .medium) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    enum Motion {
        static let press = Animation.easeOut(duration: 0.09)
        static let hover = Animation.easeOut(duration: 0.2)
        static let pop = Animation.spring(response: 0.3, dampingFraction: 0.85)
        static let enter = Animation.spring(response: 0.62, dampingFraction: 0.9)
    }
}
