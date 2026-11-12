import SwiftUI
import PhotosUI
import UIKit

struct StudioScreen: View {
    @Environment(AppModel.self) private var app
    @State private var studio = StudioModel()
    @State private var library = LibraryModel()
    @State private var showModels = false
    @State private var viewing: LibraryItem?
    @State private var refPicker: [PhotosPickerItem] = []
    @State private var dropActive = false
    @FocusState private var promptFocused: Bool

    private var recent: [LibraryItem] {
        (library.uploads + library.items).filter { studio.kind == .video ? true : !$0.isVideo }
    }

    var body: some View {
        ZStack(alignment: .top) {
            NX.C.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    recentStrip
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 60) }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }

            FloatingHeader {
                ChamferIconButton(systemName: "line.3.horizontal", label: "Menu") {
                    withAnimation(NX.Motion.pop) { app.sidebarOpen = true }
                }
            } center: {
                PillTabs(items: [
                    .init(value: GenerationCard.Kind.image, icon: "photo", title: "Image", accessibility: "Image"),
                    .init(value: GenerationCard.Kind.video, icon: "video", title: "Video", accessibility: "Video"),
                ], selection: Binding(get: { studio.kind }, set: { studio.switchKind($0, app: app) }))
            } trailing: {
                ChamferIconButton(systemName: "folder", label: "Library") { app.open(.library) }
            }
        }
        .task(id: app.currentProjectID) {
            studio.ensureSelection(app)
            await library.load(app: app)
            let preload = UserDefaults.standard.integer(forKey: "refs")
            if preload > 0, studio.references.isEmpty {
                (library.uploads + library.items).filter { !$0.isVideo }.prefix(preload).forEach { studio.addReference($0, app: app) }
            }
        }
        .onChange(of: refPicker) { _, items in
            refPicker = []
            for item in items {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
                       let uploaded = await library.upload(image, app: app) {
                        studio.addReference(uploaded, app: app)
                    }
                }
            }
        }
        .onChange(of: studio.prompt) { _, _ in studio.refreshQuote(app) }
        .sensoryFeedback(.success, trigger: studio.jobs.filter { $0.status == .completed }.count)
        .sensoryFeedback(.impact(weight: .medium), trigger: studio.jobs.count)
        .sheet(isPresented: $showModels) {
            RunSettingsSheet(studio: studio)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NX.C.surface)
        }
        .fullScreenCover(item: $viewing) { item in
            AssetViewer(items: recent, current: item)
        }
        .alert("Couldn't start", isPresented: Binding(get: { studio.error != nil }, set: { if !$0 { studio.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(studio.error ?? "")
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        let job = studio.jobs.first
        ZStack(alignment: .bottomLeading) {
            NX.C.surface
            if let job, job.status == .completed, let url = job.thumbnailUrl ?? job.url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                }
            } else if job != nil {
                if let ref = studio.references.first ?? recent.first {
                    AsyncImage(url: ref.previewURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill().blur(radius: 14).opacity(0.7) } else { Skeleton() }
                    }
                } else {
                    Skeleton()
                }
            } else if let latest = recent.first {
                AsyncImage(url: latest.previewURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                }
                .onTapGesture { viewing = latest }
            } else {
                StripedAvatar(size: 400)
            }

            LinearGradient(colors: [NX.C.bg.opacity(0), NX.C.bg.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                if let job {
                    HStack {
                        MetaLabel(job.status == .completed ? "Ready" : job.status == .failed ? "Failed · not charged" : "Creating", color: NX.C.ink, size: 11)
                        Spacer()
                        if job.status != .completed && job.status != .failed {
                            ProgressView().controlSize(.small).tint(NX.C.accent)
                        }
                    }
                    if job.status != .completed && job.status != .failed { IndeterminateBar() }
                    Text("\(job.model) · \(job.credits) cr").font(NX.F.body(13)).foregroundStyle(NX.C.inkSoft)
                } else if let latest = recent.first {
                    MetaLabel("Latest", color: NX.C.ink, size: 11)
                    Text(latest.model).font(NX.F.body(13)).foregroundStyle(NX.C.inkSoft)
                } else {
                    MetaLabel("Your results appear here", color: NX.C.ink, size: 11)
                }
            }
            .padding(14)
        }
        .frame(height: 248)
        .clipped()
        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
    }

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow("Recent · hold to drag")
                Spacer()
                Button { app.open(.library) } label: {
                    Text("ALL \(library.items.count + library.uploads.count) ›").font(NX.F.mono(11)).tracking(1.8).foregroundStyle(NX.C.accent)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(studio.jobs.filter { $0.status == .completed }) { job in
                        AsyncImage(url: job.thumbnailUrl ?? job.url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                        }
                        .frame(width: 64, height: 64).clipped()
                        .overlay(Rectangle().strokeBorder(NX.C.accent.opacity(0.6), lineWidth: 1))
                    }
                    ForEach(recent.prefix(20)) { item in
                        Color.clear.frame(width: 64, height: 64)
                            .overlay {
                                AsyncImage(url: item.previewURL) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                                }
                            }
                            .clipped()
                            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                            .contentShape(Rectangle())
                            .onTapGesture { viewing = item }
                            .draggable(item.dragPayload) { DragPreview(item: item) }
                            .contextMenu {
                                if !item.isVideo {
                                    Button { studio.addReference(item, app: app) } label: { Label("Use as reference", systemImage: "plus.square.on.square") }
                                }
                                Button { viewing = item } label: { Label("Open", systemImage: "arrow.up.left.and.arrow.down.right") }
                            }
                            .accessibilityLabel(item.prompt)
                    }
                }
            }
        }
    }

    // MARK: Composer

    private var canSend: Bool {
        !studio.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !studio.submitting && studio.variant(app) != nil
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(studio.references) { ref in
                        AsyncImage(url: ref.previewURL) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                        }
                        .frame(width: 44, height: 44).clipped()
                        .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            Button { withAnimation(NX.Motion.pop) { studio.removeReference(ref, app: app) } } label: {
                                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(NX.C.ink).frame(width: 16, height: 16).background(Color.black.opacity(0.75))
                            }
                            .accessibilityLabel("Remove reference")
                        }
                    }
                    PhotosPicker(selection: $refPicker, maxSelectionCount: 4, matching: .images) {
                        Group {
                            if library.uploading > 0 { ProgressView().controlSize(.small) } else { Image(systemName: "plus").font(.system(size: 14)) }
                        }
                        .foregroundStyle(dropActive ? NX.C.accent : NX.C.ink2)
                        .frame(width: 44, height: 44)
                        .overlay(Rectangle().strokeBorder(dropActive ? NX.C.accent : NX.C.line2, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                    .accessibilityLabel("Add reference photo")
                    Spacer(minLength: 0)
                    MetaLabel("\(studio.references.count) / \(studio.maxReferences) refs", color: NX.C.ink2, size: 10)
                }

                TextField("", text: $studio.prompt, prompt: Text(studio.kind == .image ? "Describe the picture" : "Describe the video").foregroundColor(NX.C.ink3), axis: .vertical)
                    .font(NX.F.body(16))
                    .foregroundStyle(NX.C.ink)
                    .lineLimit(2...5)
                    .focused($promptFocused)

                HStack {
                    Button { Task { await studio.enhance(app: app) } } label: {
                        HStack(spacing: 6) {
                            if studio.enhancing { ProgressView().controlSize(.mini) } else { Image(systemName: "bolt").font(.system(size: 12)) }
                            Text("AI PROMPT").font(NX.F.mono(11)).tracking(1.8)
                        }
                        .foregroundStyle(studio.prompt.isEmpty ? NX.C.ink3 : NX.C.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .overlay(Rectangle().strokeBorder(studio.prompt.isEmpty ? NX.C.line : NX.C.accent.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(studio.prompt.isEmpty || studio.enhancing)
                    Spacer()
                    ComposerIcon(systemName: "mic", label: "Dictate") { promptFocused = true }
                }
            }
            .padding(12)
            .background(dropActive ? NX.C.accent.opacity(0.08) : NX.C.surface)
            .overlay(Rectangle().strokeBorder(dropActive || promptFocused ? AnyShapeStyle(NX.G.frame) : AnyShapeStyle(NX.C.line2), lineWidth: dropActive ? 2 : 1))
            .shadow(color: NX.C.accent.opacity(promptFocused ? 0.18 : 0.08), radius: 18)
            .dropDestination(for: String.self) { payloads, _ in
                let items = payloads.compactMap { app.assetIndex[$0] }.filter { !$0.isVideo }
                guard !items.isEmpty else { return false }
                withAnimation(NX.Motion.pop) { items.forEach { studio.addReference($0, app: app) } }
                return true
            } isTargeted: { inside in
                withAnimation(NX.Motion.hover) { dropActive = inside }
            }

            HStack(spacing: 6) {
                Menu {
                    ForEach(app.projects) { project in
                        Button { app.currentProjectID = project.id } label: {
                            if project.id == app.currentProjectID { Label(project.name, systemImage: "checkmark") } else { Text(project.name) }
                        }
                    }
                } label: {
                    chip(icon: "folder", text: app.currentProject?.name ?? "Folder")
                }
                Button { showModels = true } label: {
                    chip(icon: nil, text: studio.familyLabel.isEmpty ? "Model" : studio.familyLabel, chevron: true)
                }
                .buttonStyle(PressStyle())
                if let ratios = studio.variant(app)?.body.aspectRatio, ratios.count > 1 {
                    Menu {
                        ForEach(ratios, id: \.self) { r in
                            Button(r) { studio.aspect = r; studio.refreshQuote(app) }
                        }
                    } label: {
                        chip(icon: nil, text: studio.aspect ?? ratios[0])
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 6) {
                Button {
                    promptFocused = false
                    Task { await studio.generate(app: app) }
                } label: {
                    HStack(spacing: 10) {
                        if studio.submitting { ProgressView().tint(NX.C.btnInk) }
                        Text("GENERATE").font(NX.F.display(17))
                        if let q = studio.quote {
                            Text("\(Int(q)) CR").font(NX.F.mono(12, .semibold)).tracking(1.4).opacity(0.75)
                        } else if studio.quoting {
                            ProgressView().controlSize(.mini).tint(NX.C.btnInk)
                        }
                    }
                    .foregroundStyle(NX.C.btnInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(canSend ? AnyShapeStyle(NX.G.silver) : AnyShapeStyle(NX.G.sendIdle), in: CutCorner(cut: 14))
                }
                .buttonStyle(PressStyle())
                .disabled(!canSend)

                Text("BALANCE \(Int(app.account.available).formatted()) CR · FAILED RUNS ARE FREE")
                    .font(NX.F.mono(10)).tracking(1.4).foregroundStyle(NX.C.ink2)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(NX.C.bg.ignoresSafeArea(edges: .bottom))
    }

    private func chip(icon: String?, text: String, chevron: Bool = false) -> some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.system(size: 12)) }
            Text(text.uppercased()).font(NX.F.mono(11)).tracking(1.2).lineLimit(1)
            if chevron { Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(NX.C.ink2) }
        }
        .foregroundStyle(NX.C.ink)
        .padding(.horizontal, 10)
        .frame(height: 38)
        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
    }
}

struct IndeterminateBar: View {
    @State private var phase: CGFloat = -0.4

    var body: some View {
        GeometryReader { geo in
            Rectangle().fill(Color.white.opacity(0.14))
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

struct JobTile: View {
    let job: GenerationCard

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                switch job.status {
                case .completed:
                    AsyncImage(url: job.thumbnailUrl ?? job.url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                    }
                case .failed:
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(NX.C.danger)
                        MetaLabel("Failed · not charged", size: 9)
                    }
                default:
                    ZStack {
                        Skeleton()
                        VStack(spacing: 10) {
                            ProgressView().tint(NX.C.accent)
                            MetaLabel(job.kind == .video ? "Creating video" : "Creating image", color: NX.C.ink2, size: 9)
                        }
                    }
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                MetaLabel("\(job.model) · \(job.credits) cr", color: NX.C.ink, size: 8)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .padding(6)
            }
            .overlay(Rectangle().strokeBorder(job.status == .completed ? AnyShapeStyle(NX.C.line) : AnyShapeStyle(NX.G.frame), lineWidth: 1))
    }
}

struct RunSettingsSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Bindable var studio: StudioModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                DisplayTitle(studio.kind == .image ? "Image model" : "Video model", size: 22)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16)).foregroundStyle(NX.C.inkSoft).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(studio.families(app)) { family in
                        let on = family.family == studio.familyID
                        Button {
                            studio.select(family: family, app: app)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Rectangle().fill(on ? NX.C.accent : .clear).frame(width: 3)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(family.label).font(NX.F.body(16, .semibold)).foregroundStyle(NX.C.ink)
                                    MetaLabel(family.provider, color: NX.C.ink3, size: 10)
                                    if let d = family.description {
                                        Text(d).font(NX.F.body(13)).foregroundStyle(NX.C.ink2).multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer(minLength: 0)
                                if on { Image(systemName: "checkmark").foregroundStyle(NX.C.accent) }
                            }
                            .padding(.vertical, 14)
                            .padding(.trailing, 16)
                            .background(on ? AnyShapeStyle(NX.G.selected) : AnyShapeStyle(Color.clear))
                            .overlay(alignment: .bottom) { Rectangle().fill(NX.C.lineSoft).frame(height: 1) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(alignment: .top) { Rectangle().fill(NX.C.lineSoft).frame(height: 1) }
                .padding(.top, 10)
            }

            VStack(alignment: .leading, spacing: 12) {
                if let family = studio.family(app) {
                    ForEach(family.dimensions.filter { $0.key != "operation" }, id: \.key) { dimension in
                        let options = studio.options(for: dimension, app: app)
                        if options.count > 1 {
                            FlowChips(items: options.map { ($0.value, $0.label) }, selected: studio.dims[dimension.key]) { value in
                                studio.pick(key: dimension.key, value: value, app: app)
                            }
                        }
                    }
                    if let ratios = studio.variant(app)?.body.aspectRatio, ratios.count > 1 {
                        FlowChips(items: ratios.map { ($0, $0) }, selected: studio.aspect) { value in
                            studio.aspect = value
                            studio.refreshQuote(app)
                        }
                    }
                }
                NXPrimaryButton(title: "Use \(studio.familyLabel.isEmpty ? "model" : studio.familyLabel)") { dismiss() }
            }
            .padding(16)
            .background(NX.C.surface)
            .overlay(alignment: .top) { Rectangle().fill(NX.C.line).frame(height: 1) }
        }
        .background(NX.C.surface)
    }
}

struct FlowChips: View {
    let items: [(String, String)]
    let selected: String?
    let onPick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    NXChip(title: item.1, selected: selected == item.0) { onPick(item.0) }
                }
            }
        }
    }
}
