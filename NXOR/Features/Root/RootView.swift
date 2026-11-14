import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.auth {
            case .checking:
                ZStack {
                    BackgroundAura()
                    NXMark().fill(NX.G.logo).frame(width: 64, height: 64)
                }
            case .signedOut:
                SignInView()
            case .demo, .live:
                MainShell()
            }
        }
        .preferredColorScheme(model.appearance.scheme)
        .task { await model.bootstrap() }
    }
}

/// One NavigationStack per root (Chat / Studio / Projects), the ≡ menu over it, and app-wide sheets.
struct MainShell: View {
    @Environment(AppModel.self) private var model
    @State private var dragX: CGFloat = 0

    var body: some View {
        @Bindable var model = model
        GeometryReader { geo in
            let drawerWidth = min(geo.size.width * 0.81, 340)
            ZStack(alignment: .leading) {
                NX.C.bg.ignoresSafeArea()

                NavigationStack(path: $model.path) {
                    root
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: Dest.self) { dest in
                            destination(dest)
                                .toolbar(.hidden, for: .navigationBar)
                        }
                }
                .tint(NX.C.inkSoft)

                // ≡ opens with a swipe only on the main chat screen (elsewhere it would fight "back").
                if model.section == .chat, model.path.isEmpty, !model.sidebarOpen {
                    Color.clear
                        .frame(width: 18)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
                            if value.translation.width > 50 { withAnimation(NX.Motion.pop) { model.sidebarOpen = true } }
                        })
                        .ignoresSafeArea()
                }

                if model.sidebarOpen {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(NX.C.bg.opacity(0.45))
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(NX.Motion.pop) { model.sidebarOpen = false } }
                        .accessibilityLabel("Close menu")
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity)

                    DrawerView()
                        .frame(width: drawerWidth)
                        .offset(x: min(0, dragX))
                        .gesture(DragGesture().onChanged { dragX = $0.translation.width }.onEnded { value in
                            if value.translation.width < -80 { withAnimation(NX.Motion.pop) { model.sidebarOpen = false } }
                            withAnimation(NX.Motion.pop) { dragX = 0 }
                        })
                        .transition(.move(edge: .leading))
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = model.toast {
                    ToastView(text: toast)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 92)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(NX.Motion.pop, value: model.toast)
        }
        .task {
            guard model.launchSidebar else { return }
            model.launchSidebar = false
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(NX.Motion.pop) { model.sidebarOpen = true }
        }
        .task { await openLaunchSheet() }
        .sheet(isPresented: $model.showCreateSheet) {
            CreateSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
        .sheet(isPresented: $model.showCredits) {
            CreditsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
        .sheet(isPresented: $model.showPlans) {
            PlansSheet()
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
        .sheet(isPresented: $model.showNewProject) {
            NewProjectFlow()
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
        .sheet(item: Binding(get: { model.moveChatID.map(IdentifiedString.init) }, set: { model.moveChatID = $0?.id })) { item in
            MoveToProjectSheet(chatID: item.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
        .sheet(isPresented: $model.showPhotosDenied) {
            PhotosDeniedSheet()
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
        .sheet(isPresented: $model.showNotifyPrompt) {
            NotifyPromptSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
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

    @ViewBuilder
    private var root: some View {
        switch model.section {
        case .chat: ChatScreen()
        case .studio: StudioScreen()
        case .projects: ProjectsScreen()
        }
    }

    @ViewBuilder
    private func destination(_ dest: Dest) -> some View {
        switch dest {
        case let .project(id, entry): ProjectScreen(projectID: id, entry: entry)
        case let .projectChat(id): ProjectChatScreen(chatID: id)
        case let .newProjectChat(projectID): ProjectChatScreen(chatID: nil, newInProject: projectID)
        case .presets: PresetsScreen()
        case let .presetCategory(tag): PresetCategoryScreen(tag: tag)
        case let .result(id): ResultScreen(itemID: id)
        case .account: AccountScreen()
        case .projects: ProjectsScreen(pushed: true)
        case .help: HelpScreen()
        }
    }

    /// CI screenshots: `-sheet credits|plans|newProject|move|notify|create`.
    private func openLaunchSheet() async {
        guard let sheet = model.launchSheet, sheet != "capabilities" else { return }
        try? await Task.sleep(for: .milliseconds(1200))
        switch sheet {
        case "credits": model.showCredits = true
        case "plans": model.showPlans = true
        case "newProject": model.showNewProject = true
        case "move": model.moveChatID = model.currentChatID ?? "c3"
        case "notify": model.showNotifyPrompt = true
        case "photos": model.showPhotosDenied = true
        case "create": model.showCreateSheet = true
        case "fromChat":
            model.studioDraft = StudioDraft(prompt: "A cinematic luxury car commercial for a red LaFerrari in Dubai at night, 15 seconds, 24fps. Shot 1 (0–1.5 s): wide aerial drone shot over the skyline…", mode: .video, fromChatTitle: "LaFerrari in Dubai", fromChatID: "c2")
            model.showCreateSheet = true
        default: return
        }
        model.launchSheet = nil
    }
}

struct IdentifiedString: Identifiable {
    let id: String
}

struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(text).font(NX.F.body(14)).foregroundStyle(NX.C.btnInk).lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .background(NX.G.silver)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .accessibilityAddTraits(.isStaticText)
    }
}
