import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geo in
            let drawerWidth = min(geo.size.width * 0.78, 340)

            ZStack(alignment: .leading) {
                NX.C.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    TopBar()
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if model.sidebarOpen {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(NX.Motion.pop) { model.sidebarOpen = false } }
                        .transition(.opacity)

                    SidebarView()
                        .frame(width: drawerWidth)
                        .transition(.move(edge: .leading))
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.route {
        case .chat:
            ChatScreen()
        case .presets:
            PresetsScreen()
        default:
            ComingSoonView(route: model.route)
        }
    }
}

struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            NXLogo(size: 20)
            HStack {
                NXIconButton(systemName: "line.3.horizontal") {
                    withAnimation(NX.Motion.pop) { model.sidebarOpen = true }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct ComingSoonView: View {
    let route: Route

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DisplayTitle(title, size: 30)
            MetaLabel("Coming in the next build")
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private var title: String {
        switch route {
        case .chat: return "Chat"
        case .studio: return "Studio"
        case .library: return "Library"
        case .presets: return "Presets"
        case .billing: return "Plans"
        case .settings: return "Settings"
        case .help: return "Help center"
        }
    }
}
