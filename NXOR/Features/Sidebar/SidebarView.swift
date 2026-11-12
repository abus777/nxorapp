import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var tab = 0
    @State private var chatsExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                NXLogo(size: 18)
                Spacer()
                Button {
                    withAnimation(NX.Motion.pop) { model.sidebarOpen = false }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .regular)).foregroundStyle(NX.C.ink2)
                }
            }
            .padding(.bottom, 22)

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(NX.C.muted)
                TextField("", text: $query, prompt: Text("SEARCH").font(NX.F.mono(13)).foregroundColor(NX.C.muted))
                    .font(NX.F.body(15))
                    .foregroundStyle(NX.C.ink)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
            .padding(.bottom, 18)

            tabs.padding(.bottom, 16)

            if tab == 0 { chatList } else { studioList }

            Spacer(minLength: 0)
            Hairline().padding(.bottom, 14)
            profile
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(NX.G.sidebar.ignoresSafeArea())
        .overlay(alignment: .trailing) { Rectangle().fill(NX.C.line).frame(width: 1).ignoresSafeArea() }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(Array(["Chat", "Studio"].enumerated()), id: \.offset) { i, title in
                Button {
                    withAnimation(NX.Motion.hover) { tab = i }
                } label: {
                    VStack(spacing: 12) {
                        Text(title.uppercased())
                            .font(NX.F.mono(13, .semibold)).tracking(2.6)
                            .foregroundStyle(tab == i ? NX.C.ink : NX.C.ink3)
                        Rectangle()
                            .fill(tab == i ? NX.C.accent : NX.C.line)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredChats: [ChatThread] {
        guard !query.isEmpty else { return model.chats }
        return model.chats.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var chatList: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Button { withAnimation(NX.Motion.hover) { chatsExpanded.toggle() } } label: {
                    Image(systemName: chatsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NX.C.ink2)
                        .frame(width: 28, height: 28)
                        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                }
                MetaLabel("Chats", size: 12)
                Spacer()
                MetaLabel("\(model.chats.count)", color: NX.C.ink3, size: 12)
                Button { model.openChat(nil) } label: {
                    Image(systemName: "plus").font(.system(size: 18, weight: .regular)).foregroundStyle(NX.C.accent)
                }
            }
            .padding(.bottom, 8)

            if chatsExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredChats) { chat in
                            Button { model.openChat(chat.id) } label: {
                                Text(chat.title)
                                    .font(NX.F.body(16))
                                    .foregroundStyle(chat.id == model.currentChatID ? NX.C.ink : NX.C.ink2)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 6)
                                    .background(chat.id == model.currentChatID ? NX.C.raised : .clear)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await model.deleteChat(chat.id) }
                                } label: { Label("Delete chat", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
        }
    }

    private var studioList: some View {
        VStack(alignment: .leading, spacing: 0) {
            studioRow("Make an image", icon: "photo") { model.open(.studio) }
            studioRow("Make a video", icon: "video") { model.open(.studio) }
            studioRow("Presets", icon: "sparkle") { model.open(.presets) }
            studioRow("Library", icon: "folder") { model.open(.library) }
        }
    }

    private func studioRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundStyle(NX.C.accent).frame(width: 22)
                Text(title).font(NX.F.body(16)).foregroundStyle(NX.C.ink2)
                Spacer()
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private var profile: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(NX.Motion.pop) { model.sidebarOpen = false }
                model.showAccount = true
            } label: {
                HStack(spacing: 14) {
                    HatchAvatar(size: 46)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.account.name).font(NX.F.body(18, .semibold)).foregroundStyle(NX.C.ink)
                        MetaLabel("\(model.account.planName) · \(Int(model.account.available).formatted()) credits", color: NX.C.ink3, size: 10)
                    }
                    Spacer()
                    Image(systemName: "chevron.up").font(.system(size: 12)).foregroundStyle(NX.C.muted)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                footerButton("Presets", count: model.presets.count, icon: nil) { model.open(.presets) }
                footerButton("Library", count: nil, icon: "folder") { model.open(.library) }
                Button { model.open(.help) } label: {
                    Image(systemName: "info.circle").foregroundStyle(NX.C.ink3)
                        .frame(width: 46, height: 46)
                        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                }
            }
        }
    }

    private func footerButton(_ title: String, count: Int?, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 12)) }
                Text(title.uppercased()).font(NX.F.mono(11, .semibold)).tracking(1.8)
                if let count { Text("\(count)").font(NX.F.mono(11)).foregroundStyle(NX.C.muted) }
            }
            .foregroundStyle(NX.C.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
