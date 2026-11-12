import SwiftUI
import UIKit
import AVKit

struct ThreadView: View {
    let chat: ChatThread
    let stage: ChatStage?
    var mode: ThreadMode = .answer

    var body: some View {
        switch mode {
        case .answer: answer
        case .prompt: prompts
        case .media: media
        }
    }

    private var answer: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(chat.messages) { message in
                        MessageView(message: message, chatID: chat.id).id(message.id)
                    }
                    if let stage {
                        StageIndicator(stage: stage).id("stage")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: chat.messages.last?.text) { _, _ in
                withAnimation(NX.Motion.hover) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: chat.messages.count) { _, _ in
                withAnimation(NX.Motion.hover) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var allCards: [GenerationCard] { chat.messages.flatMap(\.allGenerations) }

    private var prompts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow("Prompts in this chat")
                if allCards.isEmpty {
                    Text("Prompts NXOR writes for images and videos appear here.")
                        .font(NX.F.body(15)).foregroundStyle(NX.C.ink2)
                }
                ForEach(allCards) { card in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            MetaLabel(card.model, color: NX.C.accent, size: 10)
                            Spacer()
                            Button { UIPasteboard.general.string = card.prompt } label: {
                                Image(systemName: "square.on.square").font(.system(size: 14)).foregroundStyle(NX.C.ink2)
                                    .frame(width: 36, height: 36)
                            }
                            .accessibilityLabel("Copy prompt")
                        }
                        Text(card.prompt).font(NX.F.mono(13, .regular)).foregroundStyle(NX.C.inkSoft).lineSpacing(3)
                            .textSelection(.enabled)
                    }
                    .padding(14)
                    .background(NX.C.card)
                    .overlay(Rectangle().strokeBorder(NX.C.lineSoft, lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var media: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow("Media in this chat")
                if allCards.isEmpty {
                    Text("Images and videos from this chat appear here.")
                        .font(NX.F.body(15)).foregroundStyle(NX.C.ink2)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(allCards) { card in
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if let url = card.thumbnailUrl ?? card.url, card.status == .completed {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                                    }
                                } else {
                                    ZStack {
                                        NX.C.raised
                                        Image(systemName: card.kind == .video ? "video" : "photo").foregroundStyle(NX.C.ink3)
                                    }
                                }
                            }
                            .clipped()
                            .overlay(alignment: .bottomLeading) {
                                MetaLabel(card.model, color: NX.C.ink, size: 8)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Color.black.opacity(0.7))
                                    .padding(6)
                            }
                            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    @Environment(AppModel.self) private var model
    var chatID: String = ""

    var body: some View {
        switch message.role {
        case .user:
            VStack(alignment: .trailing, spacing: 8) {
                if !message.files.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.files, id: \.self) { url in
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                            }
                            .frame(width: 72, height: 72)
                            .clipped()
                            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                        }
                    }
                }
                HStack {
                    Spacer(minLength: 56)
                    Text(message.text)
                        .font(NX.F.body(15))
                        .foregroundStyle(NX.C.ink)
                        .lineSpacing(3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(NX.C.raised)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .assistant:
            VStack(alignment: .leading, spacing: 16) {
                if !message.text.isEmpty {
                    Text(LocalizedStringKey(message.text))
                        .font(NX.F.body(17))
                        .foregroundStyle(NX.C.ink)
                        .lineSpacing(7)
                        .tint(NX.C.accent)
                        .textSelection(.enabled)
                }
                if !message.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(message.steps.enumerated()), id: \.offset) { _, step in
                            HStack(spacing: 10) {
                                Image(systemName: Self.stepIcon(step)).font(.system(size: 13)).foregroundStyle(NX.C.ink3).frame(width: 16)
                                Text(step).font(NX.F.body(13)).foregroundStyle(NX.C.ink2)
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(NX.C.ink3)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                ForEach(message.allGenerations) { generation in
                    GenerationCardView(card: generation)
                }
                ForEach(message.proposals.filter { $0.state != .dismissed }) { proposal in
                    ProposalCardView(proposal: proposal, chatID: chatID)
                }
                ForEach(message.files, id: \.self) { url in
                    Link(destination: url) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc")
                            Text(url.lastPathComponent).lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                        }
                        .font(NX.F.body(15))
                        .foregroundStyle(NX.C.ink)
                        .padding(14)
                        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                    }
                }
                if !message.text.isEmpty {
                    HStack(spacing: 2) {
                        Button { UIPasteboard.general.string = message.text } label: {
                            Image(systemName: "square.on.square").frame(width: 40, height: 40)
                        }
                        .accessibilityLabel("Copy")
                        Button { model.regenerate() } label: { Image(systemName: "arrow.clockwise").frame(width: 40, height: 40) }
                            .disabled(model.isStreaming)
                            .accessibilityLabel("Regenerate")
                        Spacer()
                        if let answeredBy = message.answeredBy {
                            MetaLabel(answeredBy, color: NX.C.ink3, size: 10)
                        }
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(NX.C.ink2)
                }
            }
        }
    }

    static func stepIcon(_ step: String) -> String {
        let s = step.lowercased()
        if s.contains("prompt") { return "text.quote" }
        if s.contains("search") || s.contains("web") { return "globe" }
        if s.contains("video") { return "video" }
        if s.contains("image") || s.contains("photo") { return "photo" }
        if s.contains("model") { return "cpu" }
        if s.contains("preset") { return "sparkle" }
        return "circle.dashed"
    }
}

struct GenerationCardView: View {
    let card: GenerationCard
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                LinearGradient(
                    colors: card.kind == .video
                        ? [Color(hex: 0x2A1746), Color(hex: 0x12151A), Color(hex: 0x0F2A33)]
                        : [Color(hex: 0x3D1B2E), Color(hex: 0x12151A), Color(hex: 0x16203A)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                if card.status == .completed, card.kind == .video, let url = card.url {
                    VideoPlayer(player: AVPlayer(url: url))
                } else if card.status == .completed, let url = card.thumbnailUrl ?? card.url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFit() } else { Skeleton() }
                    }
                } else if card.status == .failed {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(NX.C.danger)
                        Text(card.errorMessage ?? "Generation failed").font(NX.F.body(14)).foregroundStyle(NX.C.ink2)
                    }
                    .padding()
                } else if card.status == .completed {
                    Image(systemName: card.kind == .video ? "play.fill" : "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(NX.C.ink)
                        .frame(width: 64, height: 64)
                        .background(Color.black.opacity(0.55))
                } else {
                    VStack(spacing: 10) {
                        ProgressView().tint(NX.C.accent)
                        MetaLabel(statusLabel, color: NX.C.ink2, size: 10)
                    }
                }
            }
            .aspectRatio(card.aspect.map { CGFloat($0) } ?? (card.kind == .video ? 0.75 : 1.5), contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                MetaLabel(caption, color: NX.C.ink, size: 10)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.black.opacity(0.75))
                    .padding(10)
                    .allowsHitTesting(false)
            }
            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
        }
    }

    private var caption: String {
        var parts = [card.model]
        if card.status == .completed { parts.append(card.kind == .video ? "Video" : "Image") } else { parts.append(statusLabel) }
        if card.credits > 0 { parts.append("\(card.credits) cr") }
        return parts.joined(separator: " · ")
    }

    private var statusLabel: String {
        switch card.status {
        case .pending, .processing: return card.kind == .video ? "Creating video" : "Creating image"
        case .completed: return card.kind == .video ? "Video created" : "Image created"
        case .failed: return "Failed · not charged"
        }
    }
}

struct StageIndicator: View {
    let stage: ChatStage
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(NX.C.accent)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 1 : 0.25)
            Text(stage.label.uppercased())
                .font(NX.F.mono(11, .semibold))
                .tracking(2.2)
                .foregroundStyle(NX.G.credits)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) { pulse = true }
        }
    }
}

struct ProposalCardView: View {
    @Environment(AppModel.self) private var model
    let proposal: ChatProposal
    let chatID: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MetaLabel(proposal.state == .submitted ? "Prompt sent · \(proposal.modelLabel)" : "Proposed · \(proposal.modelLabel)", color: NX.C.accent, size: 10)
                Spacer()
                if let credits = proposal.credits {
                    MetaLabel("\(Int(credits)) cr", color: NX.C.ink, size: 10)
                }
            }
            Text(proposal.prompt)
                .font(NX.F.mono(13))
                .tracking(0.6)
                .foregroundStyle(NX.C.ink2)
                .lineLimit(expanded ? nil : 6)
                .onTapGesture { withAnimation(NX.Motion.hover) { expanded.toggle() } }

            if proposal.state == .open || proposal.state == .running {
                HStack(spacing: 10) {
                    Button {
                        Task { await model.runProposal(proposal, in: chatID) }
                    } label: {
                        HStack(spacing: 8) {
                            if proposal.state == .running { ProgressView().controlSize(.small).tint(NX.C.btnInk) }
                            Text(runTitle.uppercased()).font(NX.F.display(14))
                        }
                        .foregroundStyle(NX.C.btnInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(NX.G.silver, in: CutCorner(cut: 10))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(proposal.state == .running)

                    Button {
                        Task { await model.dismissProposal(proposal, in: chatID) }
                    } label: {
                        Text("DISMISS").font(NX.F.mono(11, .semibold)).tracking(1.8)
                            .foregroundStyle(NX.C.ink2)
                            .padding(.horizontal, 14).frame(height: 44)
                            .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(proposal.state == .running)
                }
            }
        }
        .padding(14)
        .background(NX.C.surface)
        .overlay(Rectangle().strokeBorder(proposal.state == .submitted ? AnyShapeStyle(NX.C.line) : AnyShapeStyle(NX.G.frame), lineWidth: 1))
    }

    private var runTitle: String {
        let what = proposal.kind == "video" ? "Make video" : "Make image"
        if let credits = proposal.credits { return "\(what) · \(Int(credits)) cr" }
        return what
    }
}
