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
        .sheet(isPresented: Binding(get: { model.showAccount }, set: { model.showAccount = $0 })) {
            AccountSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NX.C.surface)
        }
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

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if model.sidebarOpen {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(NX.Motion.pop) { model.sidebarOpen = false } }
                        .transition(.opacity)

                    SidebarView()
                        .onAppear { print("NXDBG SidebarView appeared width=\(drawerWidth)") }
                        .frame(width: drawerWidth)
                        .transition(.move(edge: .leading))
                }
            }
        }
        .task {
            print("NXDBG main.task launchSidebar=\(model.launchSidebar)")
            guard model.launchSidebar else { return }
            model.launchSidebar = false
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(NX.Motion.pop) { model.sidebarOpen = true }
            print("NXDBG sidebarOpen set")
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
            VStack(spacing: 0) { PageHeader(title: "Plan"); BillingScreen() }
        case .settings:
            VStack(spacing: 0) { PageHeader(title: "Settings"); SettingsScreen() }
        case .help:
            VStack(spacing: 0) { PageHeader(title: "Help"); HelpScreen() }
        }
    }
}

/// Header for full pages: ☰ (web-style chamfered button), a display title, optional count and actions.
struct PageHeader<Trailing: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    var count: String? = nil
    var trailing: Trailing

    init(title: String, count: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.count = count
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            ChamferIconButton(systemName: "line.3.horizontal", label: "Menu") {
                withAnimation(NX.Motion.pop) { model.sidebarOpen = true }
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                DisplayTitle(title, size: 28)
                if let count { MetaLabel(count, color: NX.C.ink2, size: 11) }
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, count: String? = nil) {
        self.title = title
        self.count = count
        self.trailing = EmptyView()
    }
}
