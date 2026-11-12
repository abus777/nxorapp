import SwiftUI
import UIKit

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
                if let generation = message.generation {
                    GenerationCardView(card: generation)
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
                if card.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(NX.C.ink)
                        .frame(width: 64, height: 64)
                        .background(Color.black.opacity(0.55))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(NX.C.ink3)
                }
            }
            .aspectRatio(card.kind == .video ? 0.75 : 1.5, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))

            HStack {
                MetaLabel("\(card.model) · \(card.credits) credits", color: NX.C.ink3, size: 10)
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
