import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.auth {
            case .checking:
                ZStack {
                    NX.C.bg.ignoresSafeArea()
                    NXMark().fill(NX.G.logo).frame(width: 64, height: 64)
                }
            case .signedOut:
                LoginView()
            case .demo, .live:
                main
            }
        }
        .task { await model.bootstrap() }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var main: some View {
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
        case .library:
            LibraryScreen()
        case .studio:
            StudioScreen()
        case .billing:
            BillingScreen()
        case .settings:
            SettingsScreen()
        case .help:
            HelpScreen()
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
