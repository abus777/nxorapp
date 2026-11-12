import SwiftUI
import UIKit
import AVKit

struct ThreadView: View {
    let chat: ChatThread
    let stage: ChatStage?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(chat.messages) { message in
                        MessageView(message: message).id(message.id)
                    }
                    if let stage {
                        StageIndicator(stage: stage).id("stage")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
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
}

struct MessageView: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(NX.F.body(16))
                    .foregroundStyle(NX.C.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(NX.C.raised)
                    .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
            }
        case .assistant:
            VStack(alignment: .leading, spacing: 16) {
                MetaLabel("NXOR", color: NX.C.ink3)
                Text(LocalizedStringKey(message.text))
                    .font(NX.F.body(17))
                    .foregroundStyle(NX.C.ink)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                ForEach(message.allGenerations) { generation in
                    GenerationCardView(card: generation)
                }
                ForEach(message.proposals) { proposal in
                    ProposalCardView(proposal: proposal)
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
                if let answeredBy = message.answeredBy, !message.text.isEmpty {
                    HStack(spacing: 22) {
                        MetaLabel(answeredBy, color: NX.C.ink3)
                        Button { UIPasteboard.general.string = message.text } label: {
                            Image(systemName: "square.on.square")
                        }
                        Image(systemName: "arrow.clockwise")
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(NX.C.ink3)
                }
            }
        }
    }
}

struct GenerationCardView: View {
    let card: GenerationCard
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                MetaLabel("Prompt sent · \(card.model)", color: NX.C.accent, size: 10)
                Text(card.prompt)
                    .font(NX.F.mono(13))
                    .tracking(0.6)
                    .foregroundStyle(NX.C.ink2)
                    .lineLimit(expanded ? nil : 4)
                    .onTapGesture { withAnimation(NX.Motion.hover) { expanded.toggle() } }
            }
            .padding(14)
            .overlay(alignment: .leading) { Rectangle().fill(NX.C.line2).frame(width: 2) }

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
            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))

            HStack {
                MetaLabel(card.credits > 0 ? "\(card.model) · \(card.credits) credits" : card.model, color: NX.C.ink3, size: 10)
                Spacer()
                MetaLabel(statusLabel, color: NX.C.ink3, size: 10)
            }
        }
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
    let proposal: ChatProposal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MetaLabel("Proposed · \(proposal.modelLabel)", color: NX.C.accent, size: 10)
                Spacer()
                if let credits = proposal.credits {
                    MetaLabel("\(Int(credits)) cr", color: NX.C.ink, size: 10)
                }
            }
            Text(proposal.prompt)
                .font(NX.F.mono(13))
                .tracking(0.6)
                .foregroundStyle(NX.C.ink2)
                .lineLimit(6)
            Text("Reply “run it” to start this \(proposal.kind), or tell the agent what to change.")
                .font(NX.F.body(13))
                .foregroundStyle(NX.C.ink3)
        }
        .padding(14)
        .background(NX.C.surface)
        .overlay(Rectangle().strokeBorder(NX.G.frame, lineWidth: 1))
    }
}
