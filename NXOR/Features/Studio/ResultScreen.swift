import SwiftUI
import AVKit

/// 08: the result. No input here — rework goes through Edit / Animate / Variations.
struct ResultScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let itemID: String
    @State private var showAllPrompt = false
    @State private var detailsOpen = true
    @State private var confirmDelete = false

    private var job: GenerationCard? {
        guard itemID.hasPrefix("job:") else { return nil }
        let id = String(itemID.dropFirst(4))
        return model.studio.jobs.first { $0.generationId == id }
    }

    private var item: LibraryItem? { model.assetIndex["nxor-asset:\(itemID)"] }

    private var backTitle: String {
        if let previous = model.path.dropLast().last {
            switch previous {
            case .project: return "Media"
            case .projectChat: return "Chat"
            default: break
            }
        }
        return model.section == .chat ? "Chat" : "Studio"
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader {
                BackLink(title: backTitle)
            } title: {
                ScreenTitle(text: (job?.kind == .video || item?.isVideo == true) ? "Video" : "Image", centered: true)
            } trailing: {
                Menu {
                    if let url = item?.url ?? item?.previewURL {
                        ShareLink(item: url) { Label("Share…", systemImage: "square.and.arrow.up") }
                    }
                    if item != nil {
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                    }
                } label: {
                    SkewIconFace(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }

            if let job, job.status == .failed {
                FailedResultView(job: job)
            } else if let item {
                content(item)
            } else {
                Spacer()
                Text("This item isn't available anymore.").font(NX.F.body(15)).foregroundStyle(NX.C.ink3)
                Spacer()
            }
        }
        .background(NX.C.bg.ignoresSafeArea())
        .confirmationDialog("Delete this?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let item else { return }
                Task {
                    if model.auth == .live { _ = try? await NXORService.libraryDelete([item.ref]) }
                    model.freshItems.removeAll { $0.id == item.id }
                    dismiss()
                }
            }
        } message: {
            Text("It's removed from Studio and every chat that shows it.")
        }
    }

    private func content(_ item: LibraryItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                media(item)

                HStack(spacing: 0) {
                    SkewButton(title: "Save", icon: "arrow.down", size: .l, style: .metal) {
                        Task { await model.saveToPhotos(url: item.url ?? item.previewURL, isVideo: item.isVideo) }
                    }
                    if !item.isVideo {
                        SkewButton(title: "Animate", icon: "play.fill", size: .m, style: .dark, fullWidth: true) {
                            model.openInStudio(StudioDraft(prompt: "", mode: .video, projectID: item.projectId == model.defaultProject?.id ? nil : item.projectId, referenceIDs: [item.id]))
                        }
                    }
                    SkewButton(title: "Edit", size: .m, style: .dark, fullWidth: true) {
                        model.openInStudio(StudioDraft(prompt: item.prompt == "Upload" ? "" : item.prompt, mode: item.isVideo ? .video : .image, referenceIDs: item.isVideo ? [] : [item.id]))
                    }
                }
                HStack(spacing: 0) {
                    SkewButton(title: "Variations", size: .m, style: .dark, fullWidth: true) {
                        model.openInStudio(StudioDraft(prompt: item.prompt, mode: item.isVideo ? .video : .image))
                    }
                    Menu {
                        ForEach(model.userProjects) { project in
                            Button(project.name) {
                                Task {
                                    if model.auth == .live { _ = try? await NXORService.libraryMove([item.ref], to: project.id) }
                                    model.showToast("Added to \(project.name)")
                                }
                            }
                        }
                    } label: {
                        Text("TO PROJECT").font(NX.F.mono(10)).tracking(1.6).foregroundStyle(NX.C.inkSoft)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(SkewFill(style: .dark))
                    }
                    if !item.isVideo {
                        SkewButton(title: "Use as ref", size: .m, style: .dark, fullWidth: true) {
                            model.studio.addReference(item, app: model)
                            model.studioDraft = StudioDraft(prompt: model.studio.prompt, mode: model.studio.mode, referenceIDs: model.studio.references.map(\.id))
                            model.showCreateSheet = true
                        }
                    }
                }

                if let chatTitle = model.chatTitle(for: item), let chatID = model.chatGenerationIDs[item.id] {
                    Button { model.openChat(chatID) } label: {
                        HStack(spacing: 12) {
                            Text("Aa").font(NX.F.body(13, .semibold)).foregroundStyle(NX.C.inkSoft)
                                .frame(width: 32, height: 32).background(NX.C.tint.opacity(0.06))
                            VStack(alignment: .leading, spacing: 2) {
                                SectionLabel("Made in chat")
                                Text(chatTitle).font(NX.F.body(15, .semibold)).foregroundStyle(NX.C.ink).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(NX.C.ink3)
                        }
                        .padding(12)
                        .background(NX.C.tint.opacity(0.035))
                    }
                    .buttonStyle(.plain)
                }

                if !item.prompt.isEmpty && item.prompt != "Upload" {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SectionLabel("Prompt")
                            Spacer()
                            SkewButton(title: "Copy", size: .s, style: .dark) {
                                UIPasteboard.general.string = item.prompt
                                model.showToast("Prompt copied")
                            }
                            SkewButton(title: "Reuse", size: .s, style: .dark) {
                                model.openInStudio(StudioDraft(prompt: item.prompt, mode: item.isVideo ? .video : .image))
                            }
                        }
                        Text(item.prompt).font(NX.F.body(15)).foregroundStyle(NX.C.inkSoft)
                            .lineLimit(showAllPrompt ? nil : 3)
                            .textSelection(.enabled)
                        if item.prompt.count > 140 {
                            Button(showAllPrompt ? "Less" : "See all") { showAllPrompt.toggle() }
                                .font(NX.F.body(13, .semibold)).underline().foregroundStyle(NX.C.inkSoft)
                        }
                    }
                }

                DisclosureGroup(isExpanded: $detailsOpen) {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 14) {
                        detail("Model", item.model)
                        if let w = item.width, let h = item.height { detail("Size", "\(w) × \(h)") }
                        if let d = item.duration { detail("Length", "\(Int(d)) s") }
                        if let r = item.renderSeconds { detail("Render time", String(format: "%02d:%02d", Int(r) / 60, Int(r) % 60)) }
                        detail("Created", item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        detail("Type", item.source == .reference ? "Upload" : item.isVideo ? "Video" : "Image")
                    }
                    .padding(.top, 10)
                } label: {
                    SectionLabel("Details")
                }
                .tint(NX.C.ink3)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func media(_ item: LibraryItem) -> some View {
        if item.isVideo, let url = item.url, url.pathExtension.lowercased() != "jpg", url.pathExtension.lowercased() != "png", url.pathExtension.lowercased() != "webp" {
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(CGFloat(item.width ?? 9) / CGFloat(max(item.height ?? 16, 1)), contentMode: .fit)
                .frame(maxHeight: 520)
        } else {
            AsyncImage(url: item.url ?? item.previewURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    TilePlaceholder().aspectRatio(1, contentMode: .fit)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(item.prompt)
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(title)
            Text(value).font(NX.F.body(14)).foregroundStyle(NX.C.ink)
        }
    }
}

/// R8: generation failed — credits returned, try again or another model.
struct FailedResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let job: GenerationCard

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                TilePlaceholder(seed: 1)
                VStack(spacing: 8) {
                    Text("COULDN'T CREATE THIS \(job.kind == .video ? "VIDEO" : "PICTURE")").font(NX.F.mono(14)).tracking(2).foregroundStyle(NX.C.inkSoft)
                    Text((job.errorMessage ?? "The model timed out.").uppercased()).font(NX.F.mono(9)).tracking(1.6).foregroundStyle(NX.C.ink3)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .frame(height: 260)
            .clipped()

            HStack(spacing: 10) {
                Image(systemName: "checkmark").foregroundStyle(NX.C.inkSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(job.credits) credits returned").font(NX.F.body(15, .semibold)).foregroundStyle(NX.C.ink)
                    Text("Failed generations are never charged").font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                }
                Spacer()
            }
            .padding(14)
            .background(NX.C.tint.opacity(0.035))

            SkewButton(title: "Try again", size: .l, style: .metal, fullWidth: true) {
                model.studio.jobs.removeAll { $0.generationId == job.generationId }
                model.openInStudio(StudioDraft(prompt: job.prompt, mode: job.kind == .video ? .video : .image))
            }
            NavigationLink {
                ModelPickerView(kind: job.kind, selected: "") { family in
                    model.studio.select(family: family, app: model)
                    model.studioDraft = StudioDraft(prompt: job.prompt, mode: job.kind == .video ? .video : .image)
                    model.showCreateSheet = true
                }
                .toolbar(.hidden, for: .navigationBar)
            } label: {
                Text("TRY ANOTHER MODEL").font(NX.F.mono(10)).tracking(1.6).foregroundStyle(NX.C.inkSoft)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(SkewFill(style: .dark))
            }
            Button("Report a problem") {
                if let url = URL(string: "mailto:support@nxor.ai?subject=Generation%20failed&body=\(job.generationId ?? "")") { openURL(url) }
            }
            .font(NX.F.body(14)).underline().foregroundStyle(NX.C.inkSoft)
            .frame(minHeight: 44)
            Spacer()
        }
        .padding(16)
    }
}
