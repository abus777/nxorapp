import SwiftUI
import AVKit

/// Thread body shared by plain chats (05) and project chats (12f).
struct ChatMessagesView: View {
    @Environment(AppModel.self) private var model
    let chat: ChatThread
    var onSuggestion: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if let projectID = chat.projectID { ProjectUsesTags(projectID: projectID) }
                    ForEach(chat.messages) { message in
                        MessageRow(message: message, chat: chat)
                            .id(message.id)
                    }
                    if let stage = model.streamingStage, chat.id == model.currentChatID {
                        StageRow(stage: stage)
                    }
                    if let last = chat.messages.last, last.role == .assistant, !model.isStreaming {
                        let ideas = Self.suggestions(for: last)
                        if !ideas.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel("Next")
                                FlowLayout(spacing: 8) {
                                    ForEach(ideas, id: \.self) { idea in
                                        SkewButton(title: idea, size: .m, style: .dark) { onSuggestion(idea) }
                                    }
                                }
                            }
                        }
                    }
                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: chat.messages.count) { _, _ in
                withAnimation(NX.Motion.hover) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    static func suggestions(for message: ChatMessage) -> [String] {
        if message.allGenerations.contains(where: { $0.kind == .video && $0.status == .completed }) {
            return ["Night version", "Add engine sound", "Add to a project"]
        }
        if message.allGenerations.contains(where: { $0.kind == .image && $0.status == .completed }) {
            return ["Add Arabic headline", "Make a video of it"]
        }
        if message.text.contains("```") {
            return ["Faster cuts", "Add music", "Add voice-over", "Arabic version"]
        }
        return []
    }
}

/// "USES: INSTRUCTIONS · 5 FILES · BRAND KIT" at the top of a project chat.
struct ProjectUsesTags: View {
    @Environment(AppModel.self) private var model
    let projectID: String

    var body: some View {
        let meta = model.meta(projectID)
        FlowLayout(spacing: 6) {
            if !meta.about.isEmpty { TagLabel(text: "Uses: instructions") }
            if !meta.referenceIDs.isEmpty { TagLabel(text: "\(meta.referenceIDs.count) files") }
            if meta.hasBrandKit { TagLabel(text: "Brand kit") }
            if meta.about.isEmpty && !meta.hasBrandKit { TagLabel(text: "In \(model.project(projectID)?.name ?? "project")") }
        }
    }
}

struct TagLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(NX.F.mono(10)).tracking(1.4)
            .foregroundStyle(NX.C.ink2)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(SkewFill(style: .glass))
    }
}

struct StageRow: View {
    let stage: ChatStage

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small).tint(NX.C.accent)
            Text(stage.label).font(NX.F.body(14)).foregroundStyle(NX.C.ink3)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Message

struct MessageRow: View {
    @Environment(AppModel.self) private var model
    let message: ChatMessage
    let chat: ChatThread

    var body: some View {
        if message.role == .user {
            VStack(alignment: .trailing, spacing: 6) {
                Text(message.text)
                    .font(NX.F.body(14))
                    .foregroundStyle(NX.C.inkSoft)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 15)
                    .background(NX.C.tint.opacity(0.06))
                    .textSelection(.enabled)
                if message.pending {
                    HStack(spacing: 4) {
                        Text("Waiting for connection ·").font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                        Button("Cancel") { model.cancelQueued() }.font(NX.F.body(12)).underline().foregroundStyle(NX.C.inkSoft)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 60)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    NXMark().fill(NX.C.inkSoft).frame(width: 12, height: 12)
                    Text("NXOR · \((message.answeredBy ?? "Fast").uppercased())").font(NX.F.mono(9)).tracking(1.8).foregroundStyle(NX.C.muted)
                }
                ForEach(Array(MessageSegment.split(message.text).enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case let .text(t):
                        Text(Self.markdown(t))
                            .font(NX.F.body(15))
                            .lineSpacing(5)
                            .foregroundStyle(NX.C.inkSoft)
                            .tint(NX.C.accent)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    case let .prompt(p):
                        PromptBlockView(text: p, intro: message.text, chat: chat, messageID: message.id)
                    }
                }
                if !message.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(message.steps, id: \.self) { step in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(NX.C.accent)
                                Text(step).font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                            }
                        }
                    }
                }
                ForEach(message.proposals) { proposal in
                    ProposalCardView(proposal: proposal, chat: chat)
                }
                ForEach(message.allGenerations) { card in
                    ChatResultCard(card: card, chat: chat)
                }
                ForEach(message.files, id: \.self) { url in
                    Link(destination: url) {
                        Label(url.lastPathComponent, systemImage: "doc").font(NX.F.body(14)).foregroundStyle(NX.C.accent)
                    }
                }
                HStack(spacing: 14) {
                    Text(message.answeredBy ?? "Fast").font(NX.F.body(11)).foregroundStyle(NX.C.muted)
                    Button("copy") { UIPasteboard.general.string = message.text; model.showToast("Copied") }
                        .font(NX.F.body(11)).underline().foregroundStyle(NX.C.ink3)
                    Button("retry") { model.regenerate() }
                        .font(NX.F.body(11)).underline().foregroundStyle(NX.C.ink3)
                        .disabled(model.isStreaming)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

enum MessageSegment {
    case text(String)
    case prompt(String)

    /// Splits ```fenced``` prompt blocks out of the reply.
    static func split(_ text: String) -> [MessageSegment] {
        guard text.contains("```") else { return text.isEmpty ? [] : [.text(text)] }
        var result: [MessageSegment] = []
        let parts = text.components(separatedBy: "```")
        for (i, part) in parts.enumerated() {
            var chunk = part
            if i % 2 == 1, let newline = chunk.firstIndex(of: "\n"), !chunk[..<newline].contains(" "), chunk[..<newline].count < 12 {
                chunk = String(chunk[chunk.index(after: newline)...]) // drop a language tag
            }
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            result.append(i % 2 == 1 ? .prompt(trimmed) : .text(trimmed))
        }
        return result
    }
}

// MARK: - 05b prompt block

struct PromptBlockView: View {
    @Environment(AppModel.self) private var model
    let text: String
    let intro: String
    let chat: ChatThread
    let messageID: UUID
    @State private var showAll = false

    private var lines: [String] { text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    private var shots: [String] { lines.filter { $0.lowercased().hasPrefix("shot") } }
    private var body1: [String] { lines.filter { !$0.lowercased().hasPrefix("shot") } }

    private var seconds: Int? {
        for source in [text, intro] {
            if let range = source.range(of: #"(\d+)\s*(s\b|sec|seconds)"#, options: .regularExpression) {
                let digits = source[range].prefix { $0.isNumber }
                if let n = Int(digits), n > 0, n <= 60 { return n }
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("PROMPT\(seconds.map { " · \($0) S" } ?? "")")
                    .font(NX.F.mono(10)).tracking(1.8).foregroundStyle(NX.C.muted)
                    .lineLimit(1).fixedSize()
                Spacer(minLength: 6)
                SkewButton(title: "Copy", size: .s, style: .dark) {
                    UIPasteboard.general.string = text
                    model.showToast("Prompt copied")
                }
                SkewButton(title: "Open in Studio", size: .s, style: .dark) {
                    model.openInStudio(StudioDraft(prompt: text, mode: seconds != nil ? .video : .image, fromChatTitle: chat.title, fromChatID: chat.id, projectID: chat.projectID))
                }
            }
            ForEach(body1, id: \.self) { line in
                Text(line).font(NX.F.body(13)).foregroundStyle(NX.C.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            if !shots.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array((showAll ? shots : Array(shots.prefix(3))).enumerated()), id: \.offset) { i, shot in
                        shotText(shot)
                            .font(NX.F.body(13))
                            .foregroundStyle(i == 2 && !showAll ? NX.C.ink3 : NX.C.inkSoft)
                            .lineLimit(showAll ? nil : 2)
                    }
                }
                if shots.count > 3 {
                    Button(showAll ? "Show less ▴" : "Show all \(shots.count) shots ▾") { withAnimation(NX.Motion.hover) { showAll.toggle() } }
                        .font(NX.F.body(13, .semibold)).underline().foregroundStyle(NX.C.inkSoft)
                }
            }
            SkewButton(title: "Use this prompt → choose model", size: .l, style: .metal, fullWidth: true) {
                model.addLocalProposal(prompt: text, kind: seconds != nil ? .video : .image, after: messageID, in: chat.id)
            }
        }
        .padding(14)
        .background(NX.C.tint.opacity(0.035))
    }

    private func shotText(_ shot: String) -> Text {
        if let r = shot.range(of: #"^Shot\s*\d+\s*[·:\-–]?\s*[\d.,–\-]*\s*s?"#, options: [.regularExpression, .caseInsensitive]) {
            return Text(String(shot[r])).bold() + Text(String(shot[r.upperBound...]))
        }
        return Text(shot)
    }
}

// MARK: - 05 generation card

struct ProposalCardView: View {
    @Environment(AppModel.self) private var model
    let proposal: ChatProposal
    let chat: ChatThread

    @State private var prompt = ""
    @State private var expanded = false
    @State private var editing = false
    @State private var strategy = "balanced"
    @State private var options: [ModelOption] = []
    @State private var selectedFamily = ""
    @State private var dims: [String: String] = [:]

    struct ModelOption: Identifiable, Hashable {
        let family: ModelFamily
        var price: Int?
        var id: String { family.family }
    }

    private var kind: GenerationCard.Kind { proposal.kind == "video" ? .video : .image }
    private var catalog: [ModelFamily] { kind == .video ? model.videoModels : model.imageModels }
    private var selected: ModelOption? { options.first { $0.id == selectedFamily } ?? options.first }
    private var price: Int? { selected?.price ?? proposal.credits.map(Int.init) }

    private var ordered: [ModelOption] {
        switch strategy {
        case "cheapest": return options.sorted { ($0.price ?? .max) < ($1.price ?? .max) }
        case "quality": return options.sorted { ($0.price ?? 0) > ($1.price ?? 0) }
        default: return options
        }
    }

    var body: some View {
        switch proposal.state {
        case .dismissed:
            Text("Draft dismissed").font(NX.F.body(12)).foregroundStyle(NX.C.muted)
        case .submitted:
            EmptyView()
        default:
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel("\(kind == .video ? "Video" : "Image") · draft")
                Spacer()
                Text(proposal.state == .running ? "Starting…" : "Waiting for you").font(NX.F.body(11)).foregroundStyle(NX.C.ink3)
            }
            Text(prompt.isEmpty ? proposal.prompt : prompt)
                .font(NX.F.body(14))
                .foregroundStyle(NX.C.inkSoft)
                .lineLimit(expanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 0) {
                SkewButton(title: expanded ? "Less" : "Full prompt", size: .s, style: .dark) { withAnimation(NX.Motion.hover) { expanded.toggle() } }
                SkewButton(title: "Edit", size: .s, style: .dark) { editing = true }
            }

            if let family = selected?.family {
                let rows = family.dimensions.filter { $0.key != "operation" && $0.options.count > 1 }
                if !rows.isEmpty {
                    SectionLabel("Settings · tap to change")
                    FlowLayout(spacing: 6) {
                        ForEach(rows, id: \.key) { dim in
                            Menu {
                                ForEach(dim.options, id: \.value) { option in
                                    Button(option.label) { dims[dim.key] = option.value }
                                }
                            } label: {
                                SkewTagFace(title: dim.options.first { $0.value == dims[dim.key] }?.label ?? dim.options[0].label, trailingChevron: true)
                            }
                        }
                    }
                }
            }

            if options.count > 1 {
                SectionLabel("What matters more")
                SkewSegment(items: [("balanced", "Balanced"), ("quality", "Quality"), ("cheapest", "Cheapest")], selection: $strategy)
                    .onChange(of: strategy) { _, _ in selectedFamily = ordered.first?.id ?? selectedFamily }
            }

            if let first = ordered.first {
                SectionLabel("NXOR picked")
                modelRow(first, picked: true)
                if ordered.count > 1 {
                    SectionLabel("Alternatives")
                    ForEach(ordered.dropFirst().prefix(2)) { option in modelRow(option, picked: false) }
                }
                NavigationLink {
                    ModelPickerView(kind: kind, selected: selectedFamily, switchesStudio: false) { family in
                        if !options.contains(where: { $0.id == family.family }) { options.append(ModelOption(family: family, price: nil)) }
                        selectedFamily = family.family
                        Task { await quote(family) }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                } label: {
                    HStack {
                        Text("All models (\(catalog.count))").font(NX.F.body(14)).foregroundStyle(NX.C.inkSoft)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(NX.C.ink3)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(NX.C.tint.opacity(0.035))
                }
                .buttonStyle(.plain)
            }

            if let price, Double(price) > model.account.available {
                NoCreditsBanner(needed: price)
            }

            HStack(spacing: 8) {
                SkewButton(title: proposal.state == .running ? "Starting…" : "Generate\(price.map { " · \($0) cr" } ?? "")", size: .l, style: .metal, fullWidth: true, enabled: proposal.state == .open) {
                    generate()
                }
                if proposal.state == .open {
                    SkewIconButton(systemName: "xmark", label: "Dismiss draft", size: 52) {
                        Task { await model.dismissProposal(proposal, in: chat.id) }
                    }
                }
            }
        }
        .padding(14)
        .background(NX.C.tint.opacity(0.035))
        .sheet(isPresented: $editing) {
            PromptEditorSheet(text: prompt.isEmpty ? proposal.prompt : prompt) { prompt = $0 }
                .nxSheetBackground()
        }
        .task {
            if prompt.isEmpty { prompt = proposal.prompt }
            guard options.isEmpty else { return }
            let picked = catalog.first { $0.label.localizedCaseInsensitiveCompare(proposal.modelLabel) == .orderedSame }
                ?? catalog.first { proposal.modelLabel.localizedCaseInsensitiveContains($0.label) || $0.label.localizedCaseInsensitiveContains(proposal.modelLabel) }
            var list: [ModelOption] = []
            if let picked { list.append(ModelOption(family: picked, price: proposal.credits.map(Int.init))) }
            for family in catalog where family.family != picked?.family && list.count < 3 {
                list.append(ModelOption(family: family, price: nil))
            }
            options = list
            selectedFamily = list.first?.id ?? ""
            for option in list where option.price == nil { await quote(option.family) }
        }
    }

    private func modelRow(_ option: ModelOption, picked: Bool) -> some View {
        let on = option.id == (selected?.id ?? "")
        return Button {
            selectedFamily = option.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(on ? NX.C.accent : NX.C.ink3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(option.family.label).font(NX.F.body(15, .semibold)).foregroundStyle(NX.C.ink).lineLimit(1)
                        if picked && strategy == "balanced" { TagLabel(text: "Best value") }
                    }
                    Text("\(option.family.provider)\(option.price.map { " · \($0) cr" } ?? "")")
                        .font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? NX.C.tint.opacity(0.06) : NX.C.tint.opacity(0.03))
            .overlay(Rectangle().strokeBorder(on ? NX.C.accent.opacity(0.8) : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func slug(for family: ModelFamily) -> String? {
        let op = kind == .video ? "text-to-video" : "text-to-image"
        let variants = family.variants.filter { ($0.dims["operation"] ?? op) == op }
        let match = variants.first { v in dims.allSatisfy { key, value in v.dims[key] == nil || v.dims[key] == value } }
        return (match ?? variants.first ?? family.variants.first)?.slug
    }

    @MainActor
    private func quote(_ family: ModelFamily) async {
        guard let i = options.firstIndex(where: { $0.id == family.family }) else { return }
        if model.auth != .live {
            options[i].price = [180, 400, 240, 350][i % 4]
            return
        }
        guard let slug = slug(for: family) else { return }
        if let value = try? await NXORService.quote(kind: kind.rawValue, body: GenerateBody(modelSlug: slug, prompt: prompt.isEmpty ? proposal.prompt : prompt)) {
            if let j = options.firstIndex(where: { $0.id == family.family }) { options[j].price = Int(value) }
        }
    }

    private func generate() {
        if let price, Double(price) > model.account.available {
            model.showCredits = true
            return
        }
        var p = proposal
        p.prompt = prompt.isEmpty ? proposal.prompt : prompt
        if let family = selected?.family, family.label != proposal.modelLabel || !dims.isEmpty {
            p.modelSlug = slug(for: family)
        }
        let label = selected?.family.label ?? proposal.modelLabel
        Task {
            if proposal.id.hasPrefix("local-") {
                await model.runLocalProposal(p, label: label, price: price, in: chat.id)
            } else {
                await model.runProposal(p, in: chat.id)
            }
        }
    }
}

/// R7: not enough credits — buy right here.
struct NoCreditsBanner: View {
    @Environment(AppModel.self) private var model
    let needed: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Needs \(needed) cr — you have \(Int(model.account.available))").font(NX.F.body(14, .semibold)).foregroundStyle(NX.C.btnInk)
                Text("Buy credits or switch to a cheaper model").font(NX.F.body(12)).foregroundStyle(NX.C.btnInk.opacity(0.7))
            }
            Spacer(minLength: 0)
            Button("Buy") { model.showCredits = true }
                .font(NX.F.body(14, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(NX.C.btnInk)
        }
        .padding(12)
        .background(NX.G.silver)
    }
}

struct PromptEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var text: String
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SheetCancelButton { dismiss() }
                Spacer()
                ScreenTitle(text: "Edit prompt", centered: true)
                Spacer()
                SheetDoneButton(title: "Save") { onSave(text); dismiss() }
            }
            TextEditor(text: $text)
                .font(NX.F.body(15))
                .foregroundStyle(NX.C.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(NX.C.tint.opacity(0.05))
        }
        .padding(16)
    }
}

// MARK: - 05c result in chat

struct ChatResultCard: View {
    @Environment(AppModel.self) private var model
    let card: GenerationCard
    let chat: ChatThread

    private var isModeration: Bool {
        let m = (card.errorMessage ?? "").lowercased()
        return ["moderation", "policy", "safety", "not allowed", "identifiable", "consent", "rejected"].contains { m.contains($0) }
    }

    var body: some View {
        switch card.status {
        case .failed:
            if isModeration { ModerationCard(card: card, chat: chat) } else { failed }
        case .pending, .processing:
            rendering
        case .completed:
            done
        }
    }

    private var rendering: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                TilePlaceholder(seed: 1)
                VStack(spacing: 8) {
                    Text("RENDERING").font(NX.F.mono(10)).tracking(1.8).foregroundStyle(NX.C.inkSoft)
                    IndeterminateBar().frame(width: 140)
                }
            }
            .aspectRatio(card.kind == .video ? 16 / 9 : 1, contentMode: .fit)
            Text("\(card.model) · \(card.credits) cr · you can leave, it keeps going").font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
        }
        .padding(12)
        .background(NX.C.tint.opacity(0.035))
    }

    private var failed: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COULDN'T CREATE THIS \(card.kind == .video ? "VIDEO" : "PICTURE")").font(NX.F.mono(11)).tracking(1.8).foregroundStyle(NX.C.inkSoft)
            if let message = card.errorMessage { Text(message).font(NX.F.body(13)).foregroundStyle(NX.C.ink3) }
            Label("\(card.credits) credits returned · failed generations are never charged", systemImage: "checkmark")
                .font(NX.F.body(12)).foregroundStyle(NX.C.ink2)
            SkewButton(title: "Try again", size: .m, style: .dark) { model.regenerate() }
        }
        .padding(14)
        .background(NX.C.tint.opacity(0.035))
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                let item = LibraryItem(card: card, projectId: chat.projectID)
                model.assetIndex[item.dragPayload] = item
                model.chatGenerationIDs[item.id] = chat.id
                model.push(.result(item.id))
            } label: {
                ZStack {
                    AsyncImage(url: card.thumbnailUrl ?? card.url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder(seed: 0) }
                    }
                    if card.kind == .video {
                        VStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.system(size: 28)).foregroundStyle(.white)
                            Text("VIDEO · 0:05").font(NX.F.mono(9)).tracking(1.6).foregroundStyle(.white)
                        }
                    }
                }
                .aspectRatio(card.kind == .video ? 16 / 9 : (card.aspect ?? 1), contentMode: .fit)
                .clipped()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(card.kind == .video ? "video" : "picture")")

            Text("\(card.model) · \(card.kind == .video ? "5 s · 720p · " : "")\(card.credits) cr").font(NX.F.body(12)).foregroundStyle(NX.C.ink3)

            HStack(spacing: 0) {
                SkewButton(title: "Save", size: .m, style: .dark, fullWidth: true) {
                    Task { await model.saveToPhotos(url: card.url ?? card.thumbnailUrl, isVideo: card.kind == .video) }
                }
                SkewButton(title: "Variations", size: .m, style: .dark, fullWidth: true) {
                    model.openInStudio(StudioDraft(prompt: card.prompt, mode: card.kind == .video ? .video : .image, fromChatTitle: chat.title, fromChatID: chat.id, projectID: chat.projectID))
                }
                SkewButton(title: card.kind == .video ? "+ 5 s" : "Animate", size: .m, style: .dark, fullWidth: true) {
                    if card.kind == .video {
                        model.send("Make it 5 seconds longer")
                    } else {
                        model.openInStudio(StudioDraft(prompt: card.prompt, mode: .video, fromChatTitle: chat.title, fromChatID: chat.id, projectID: chat.projectID))
                    }
                }
            }

            Button {
                if let project = chat.projectID {
                    model.path.append(.project(project, .studio))
                } else {
                    model.open(.studio)
                }
            } label: {
                HStack {
                    Label(chat.projectID == nil ? "Saved to Studio" : "Saved to project media", systemImage: "checkmark")
                        .font(NX.F.body(13)).foregroundStyle(NX.C.inkSoft)
                    Spacer()
                    Text("Open ›").font(NX.F.body(13)).foregroundStyle(NX.C.ink3)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { Rectangle().fill(NX.C.tint.opacity(0.06)).frame(height: 1) }
        }
        .padding(12)
        .background(NX.C.tint.opacity(0.035))
    }
}

/// R9: request refused — explain and offer ways forward.
struct ModerationCard: View {
    @Environment(AppModel.self) private var model
    let card: GenerationCard
    let chat: ChatThread

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Can't create this")
            Text(card.errorMessage ?? "This would show a real, identifiable person without their consent. Try a made-up character or your own photo.")
                .font(NX.F.body(14)).foregroundStyle(NX.C.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                SkewButton(title: "Use a made-up character", size: .m, style: .dark) { model.send("Use a made-up character instead") }
                SkewButton(title: "Use my photo", size: .m, style: .dark) { model.send("I'll use my own photo — what should I upload?") }
                SkewButton(title: "Edit prompt", size: .m, style: .dark, fullWidth: true) {
                    model.openInStudio(StudioDraft(prompt: card.prompt, mode: card.kind == .video ? .video : .image, fromChatTitle: chat.title, fromChatID: chat.id, projectID: chat.projectID))
                }
            }
            HStack(spacing: 4) {
                Text("No credits were charged ·").font(NX.F.body(11)).foregroundStyle(NX.C.ink3)
                Link("Content rules", destination: URL(string: "https://nxor.ai/legal/terms")!)
                    .font(NX.F.body(11)).underline().foregroundStyle(NX.C.inkSoft)
            }
        }
        .padding(14)
        .background(NX.C.tint.opacity(0.035))
    }
}

struct IndeterminateBar: View {
    @State private var phase: CGFloat = -0.4

    var body: some View {
        GeometryReader { geo in
            Rectangle().fill(NX.C.tint.opacity(0.14))
                .overlay(alignment: .leading) {
                    Rectangle().fill(NX.G.credits)
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: phase * geo.size.width)
                }
                .clipped()
        }
        .frame(height: 3)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1 }
        }
    }
}

/// Wrapping row of chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Option chips used by preset and run settings.
struct FlowChips: View {
    let items: [(String, String)]
    let selected: String?
    let onPick: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                SkewTag(title: item.1, selected: item.0 == selected) { onPick(item.0) }
            }
        }
    }
}

/// Compact generation card used by the preset sheet.
struct GenerationCardView: View {
    let card: GenerationCard

    var body: some View {
        ZStack {
            if card.status == .completed {
                AsyncImage(url: card.thumbnailUrl ?? card.url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder() }
                }
            } else if card.status == .failed {
                TilePlaceholder(seed: 2)
                Text(card.errorMessage ?? "Couldn't create this").font(NX.F.body(13)).foregroundStyle(NX.C.inkSoft).padding()
            } else {
                TilePlaceholder(seed: 1)
                VStack(spacing: 8) {
                    Text("RENDERING").font(NX.F.mono(10)).tracking(1.8).foregroundStyle(NX.C.inkSoft)
                    IndeterminateBar().frame(width: 120)
                }
            }
        }
        .aspectRatio(card.kind == .video ? 9 / 16 : 1, contentMode: .fit)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            TileBadge(text: "\(card.model) · \(card.credits) cr").padding(8)
        }
    }
}
