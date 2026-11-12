import SwiftUI
import PhotosUI
import UIKit
import AVKit

struct PresetDetailView: View {
    let preset: PresetSummary
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var detail: PresetDetail?
    @State private var userPrompt = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var dims: [String: String] = [:]
    @State private var running = false
    @State private var result: GenerationCard?
    @State private var error: String?

    private var photoInput: PresetDetail.Input? { detail?.inputs.first { $0.accepts == "image" } }
    private var photoRequired: Bool { (photoInput?.requirement ?? "required") == "required" }

    private var credits: Int {
        if let option = detail?.options.first(where: { $0.dims == dims }) ?? detail?.options.first, let c = option.credits {
            return Int(c)
        }
        return preset.credits
    }

    private var aspect: String? {
        (detail?.options.first(where: { $0.dims == dims }) ?? detail?.options.first)?.aspectRatio
    }

    private var canRun: Bool { !running && (!photoRequired || photo != nil) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                DisplayTitle(preset.name, size: 22).lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 18)).foregroundStyle(NX.C.ink2)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 56)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sample

                    if let d = detail?.description {
                        Text(d).font(NX.F.body(15)).foregroundStyle(NX.C.ink2)
                    }

                    if detail?.userPrompt == "append" || detail == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            MetaLabel("Prompt · optional")
                            TextField("", text: $userPrompt, prompt: Text(detail?.userPromptPlaceholder ?? "Add a detail, e.g. warmer light").foregroundColor(NX.C.muted), axis: .vertical)
                                .font(NX.F.body(16))
                                .foregroundStyle(NX.C.ink)
                                .lineLimit(2...4)
                                .padding(14)
                                .background(NX.C.surface)
                                .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            MetaLabel(photoInput?.label ?? "Your photo")
                            MetaLabel(photoRequired ? "Required" : "Optional", color: photoRequired ? NX.C.accent : NX.C.muted)
                        }
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            ZStack {
                                if let photo {
                                    Image(uiImage: photo).resizable().scaledToFill()
                                        .frame(height: 220).clipped()
                                } else {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.up")
                                        Text("ADD A PHOTO").font(NX.F.mono(12, .semibold)).tracking(2.2)
                                    }
                                    .foregroundStyle(NX.C.ink2)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 90)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .overlay(Rectangle().strokeBorder(NX.C.line2, style: StrokeStyle(lineWidth: 1, dash: photo == nil ? [5, 4] : [])))
                        }
                        if let hint = photoInput?.hint {
                            Text(hint).font(NX.F.body(13)).foregroundStyle(NX.C.muted)
                        }
                    }

                    if let detail {
                        ForEach(detail.dimensions, id: \.key) { dimension in
                            VStack(alignment: .leading, spacing: 10) {
                                MetaLabel(dimension.label)
                                FlowChips(items: dimension.options.map { ($0.value, $0.label) }, selected: dims[dimension.key]) { value in
                                    dims[dimension.key] = value
                                }
                            }
                        }
                    }

                    if let aspect {
                        HStack {
                            MetaLabel("Locked by preset")
                            Spacer()
                            MetaLabel("Aspect \(aspect)", color: NX.C.ink, size: 11)
                        }
                        .padding(14)
                        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                    }

                    if let result {
                        GenerationCardView(card: result)
                    }
                }
                .padding(18)
            }

            NXPrimaryButton(title: running ? "Starting…" : "Use preset · \(credits) cr") {
                Task { await run() }
            }
            .disabled(!canRun)
            .opacity(canRun ? 1 : 0.5)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(NX.C.bg.ignoresSafeArea())
        .task { await loadDetail() }
        .onChange(of: pickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) { photo = UIImage(data: data) }
            }
        }
        .alert("Couldn't start", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    @ViewBuilder
    private var sample: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let video = preset.previewVideoUrl {
                    LoopingVideo(url: video)
                } else {
                    AsyncImage(url: preset.previewImageUrl) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                    }
                }
            }
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .clipped()

            MetaLabel("Sample output", color: NX.C.ink, size: 9)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Color.black.opacity(0.65))
                .padding(10)
        }
        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
    }

    private func loadDetail() async {
        if app.auth == .live, let d = try? await NXORService.preset(preset.slug) {
            detail = d
            for dimension in d.dimensions where dims[dimension.key] == nil {
                dims[dimension.key] = d.options.first?.dims[dimension.key] ?? dimension.options.first?.value
            }
        }
    }

    @MainActor
    private func run() async {
        guard canRun else { return }
        running = true
        defer { running = false }
        let kind: GenerationCard.Kind = preset.kind == "video" ? .video : .image
        var card = GenerationCard(kind: kind, model: preset.name, credits: credits, status: .processing, prompt: userPrompt.isEmpty ? preset.name : userPrompt)
        result = card

        if app.auth != .live {
            try? await Task.sleep(for: .seconds(2))
            card.status = .completed
            card.thumbnailUrl = preset.previewImageUrl
            card.url = preset.previewVideoUrl ?? preset.previewImageUrl
            result = card
            return
        }

        do {
            var inputs: [String: [String]] = [:]
            if let input = photoInput, let photo, let jpeg = photo.jpegData(compressionQuality: 0.9) {
                let key = try await NXORService.uploadSource(path: input.upload, data: jpeg, filename: "photo.jpg", mimeType: "image/jpeg")
                inputs[input.key] = [key]
            }
            let body = GenerateBody(
                aspectRatio: aspect,
                idempotencyKey: UUID().uuidString,
                presetSlug: preset.slug,
                presetInputs: inputs.isEmpty ? nil : inputs,
                presetDims: dims.isEmpty ? nil : dims,
                presetUserPrompt: userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : userPrompt
            )
            let id = try await NXORService.generate(kind: kind.rawValue, body: body)
            card.generationId = id
            result = card
            for attempt in 0..<200 {
                try? await Task.sleep(for: .seconds(attempt < 20 ? 3 : 6))
                guard let g = try? await (kind == .video ? NXORService.video(id) : NXORService.image(id)) else { continue }
                card.status = GenerationCard.Status(rawValue: g.status) ?? .processing
                card.url = g.outputs?.first?.url
                card.thumbnailUrl = g.previewURL
                card.errorMessage = g.errorMessage
                result = card
                if !g.isRunning { break }
            }
            await app.refreshBalance()
        } catch {
            result = nil
            self.error = error.localizedDescription
        }
    }
}

struct LoopingVideo: View {
    let url: URL
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        VideoPlayer(player: player)
            .disabled(true)
            .onAppear {
                let queue = AVQueuePlayer()
                queue.isMuted = true
                looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
                player = queue
                queue.play()
            }
            .onDisappear { player?.pause() }
    }
}
