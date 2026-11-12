import SwiftUI
import PhotosUI
import UIKit

struct StudioScreen: View {
    @Environment(AppModel.self) private var app
    @State private var studio = StudioModel()
    @State private var library = LibraryModel()
    @State private var showSettings = false
    @State private var viewing: LibraryItem?
    @State private var refPicker: [PhotosPickerItem] = []
    @State private var dropActive = false
    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        DisplayTitle("Library", size: 30)
                        MetaLabel("\(library.items.count + library.uploads.count + studio.jobs.count) assets", size: 12)
                        Spacer()
                        Menu {
                            ForEach(app.projects) { project in
                                Button { app.currentProjectID = project.id } label: {
                                    if project.id == app.currentProjectID { Label(project.name, systemImage: "checkmark") } else { Text(project.name) }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                Text((app.currentProject?.name ?? "Folder").uppercased()).font(NX.F.mono(11, .semibold)).tracking(1.4).lineLimit(1)
                                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(NX.C.ink2)
                            .padding(.horizontal, 10).frame(height: 32)
                            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                        }
                    }
                    Text("Long-press a picture and drag it into References below.")
                        .font(NX.F.body(13)).foregroundStyle(NX.C.muted)

                    if !studio.jobs.isEmpty {
                        MetaLabel("This session", color: NX.C.ink3, size: 11)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(studio.jobs) { job in JobTile(job: job) }
                        }
                    }

                    let recent = (library.uploads + library.items).filter { studio.kind == .video ? true : !$0.isVideo }
                    if !recent.isEmpty {
                        MetaLabel("Recent", color: NX.C.ink3, size: 11)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(recent.prefix(12)) { item in
                                LibraryTile(item: item)
                                    .onTapGesture { viewing = item }
                                    .draggable(item.dragPayload) { DragPreview(item: item) }
                                    .contextMenu {
                                        if !item.isVideo {
                                            Button { studio.addReference(item, app: app) } label: {
                                                Label("Use as reference", systemImage: "plus.square.on.square")
                                            }
                                        }
                                        Button { viewing = item } label: { Label("Open", systemImage: "arrow.up.left.and.arrow.down.right") }
                                    }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)

            composer
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
        .sheet(isPresented: $showSettings) {
            RunSettingsSheet(studio: studio)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NX.C.surface)
        }
        .sensoryFeedback(.success, trigger: studio.jobs.filter { $0.status == .completed }.count)
        .sensoryFeedback(.impact(weight: .medium), trigger: studio.jobs.count)
        .fullScreenCover(item: $viewing) { item in
            AssetViewer(items: library.items, current: item)
        }
        .alert("Couldn't start", isPresented: Binding(get: { studio.error != nil }, set: { if !$0 { studio.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(studio.error ?? "")
        }
    }

    private var columns: [GridItem] { [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)] }

    private var canSend: Bool {
        !studio.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !studio.submitting && studio.variant(app) != nil
    }

    private var referencesTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MetaLabel("References", size: 10)
                Spacer()
                MetaLabel("\(studio.references.count)/\(studio.maxReferences)", size: 10)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(studio.references) { ref in
                        AsyncImage(url: ref.previewURL) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Skeleton() }
                        }
                        .frame(width: 54, height: 54)
                        .clipped()
                        .overlay(Rectangle().strokeBorder(NX.C.line2, lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            Button { withAnimation(NX.Motion.pop) { studio.removeReference(ref, app: app) } } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(NX.C.ink).frame(width: 18, height: 18).background(Color.black.opacity(0.7))
                            }
                        }
                    }
                    PhotosPicker(selection: $refPicker, maxSelectionCount: 4, matching: .images) {
                        VStack(spacing: 4) {
                            if library.uploading > 0 { ProgressView().controlSize(.small) } else { Image(systemName: "plus") }
                            if studio.references.isEmpty {
                                Text("ADD OR DROP").font(NX.F.mono(8, .semibold)).tracking(1)
                            }
                        }
                        .foregroundStyle(dropActive ? NX.C.accent : NX.C.ink2)
                        .frame(width: studio.references.isEmpty ? 110 : 54, height: 54)
                        .overlay(Rectangle().strokeBorder(dropActive ? NX.C.accent : NX.C.line2, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                referencesTray
                TextField("", text: $studio.prompt, prompt: Text(studio.kind == .image ? "Describe the picture" : "Describe the video").foregroundColor(NX.C.muted), axis: .vertical)
                    .font(NX.F.body(17))
                    .foregroundStyle(NX.C.ink)
                    .lineLimit(2...6)
                    .focused($promptFocused)

                Button { Task { await studio.enhance(app: app) } } label: {
                    HStack(spacing: 8) {
                        if studio.enhancing { ProgressView().controlSize(.mini) } else { Image(systemName: "bolt") }
                        Text("AI PROMPT").font(NX.F.mono(12, .semibold)).tracking(2.4)
                    }
                    .foregroundStyle(studio.prompt.isEmpty ? NX.C.muted : NX.C.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
                .disabled(studio.prompt.isEmpty || studio.enhancing)
            }
            .padding(16)
            .background(dropActive ? NX.C.accent.opacity(0.08) : NX.C.surface)
            .overlay(Rectangle().strokeBorder(dropActive ? AnyShapeStyle(NX.G.frame) : AnyShapeStyle(promptFocused ? NX.C.line2 : NX.C.line), lineWidth: dropActive ? 2 : 1))
            .dropDestination(for: String.self) { payloads, _ in
                let items = payloads.compactMap { app.assetIndex[$0] }.filter { !$0.isVideo }
                guard !items.isEmpty else { return false }
                withAnimation(NX.Motion.pop) { items.forEach { studio.addReference($0, app: app) } }
                return true
            } isTargeted: { inside in
                withAnimation(NX.Motion.hover) { dropActive = inside }
            }

            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    kindButton(.image, icon: "photo")
                    kindButton(.video, icon: "video")
                }
                .overlay(Rectangle().strokeBorder(NX.C.accent, lineWidth: 1))

                Button { showSettings = true } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(studio.familyLabel.uppercased())
                                .font(NX.F.mono(11, .semibold)).tracking(0.8)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            if let aspect = studio.aspect {
                                Text(aspect).font(NX.F.mono(10)).foregroundStyle(NX.C.ink3)
                            }
                        }
                        Image(systemName: "chevron.up").font(.system(size: 10, weight: .semibold)).foregroundStyle(NX.C.ink3)
                    }
                    .foregroundStyle(NX.C.ink)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                }
                .buttonStyle(PressStyle())

                Group {
                    if studio.quoting {
                        ProgressView().controlSize(.small)
                    } else {
                        MetaLabel(studio.quote.map { "\(Int($0)) cr" } ?? "— cr", color: NX.C.ink, size: 12)
                    }
                }
                .frame(minWidth: 52)

                SendButton(enabled: canSend) {
                    promptFocused = false
                    Task { await studio.generate(app: app) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(NX.C.bg)
        .overlay(alignment: .top) { Hairline() }
    }

    private func kindButton(_ kind: GenerationCard.Kind, icon: String) -> some View {
        Button {
            withAnimation(NX.Motion.hover) { studio.switchKind(kind, app: app) }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(studio.kind == kind ? NX.C.btnInk : NX.C.ink2)
                .frame(width: 50, height: 46)
                .background(studio.kind == kind ? AnyShapeStyle(NX.G.silver) : AnyShapeStyle(Color.clear))
        }
        .buttonStyle(.plain)
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
    @Bindable var studio: StudioModel
    @State private var showModels = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DisplayTitle("Run settings", size: 26).padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    MetaLabel("Model")
                    Button { withAnimation(NX.Motion.hover) { showModels.toggle() } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill").foregroundStyle(NX.C.ink2)
                            Text(studio.family(app)?.label ?? "Choose a model").font(NX.F.body(17)).foregroundStyle(NX.C.ink)
                            Spacer()
                            MetaLabel(studio.family(app)?.provider ?? "", size: 9)
                            Image(systemName: showModels ? "chevron.up" : "chevron.down").font(.system(size: 11)).foregroundStyle(NX.C.ink3)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 54)
                        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    if showModels {
                        VStack(spacing: 0) {
                            ForEach(studio.families(app)) { family in
                                Button {
                                    studio.select(family: family, app: app)
                                    withAnimation(NX.Motion.hover) { showModels = false }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(family.label).font(NX.F.body(16, .medium)).foregroundStyle(NX.C.ink)
                                            Spacer()
                                            MetaLabel(family.provider, size: 9)
                                        }
                                        if let d = family.description {
                                            Text(d).font(NX.F.body(13)).foregroundStyle(NX.C.ink3).multilineTextAlignment(.leading)
                                        }
                                    }
                                    .padding(14)
                                    .background(family.family == studio.familyID ? NX.C.raised : Color.clear)
                                    .overlay(alignment: .bottom) { Hairline() }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))
                    }
                }

                if let family = studio.family(app) {
                    ForEach(family.dimensions.filter { $0.key != "operation" }, id: \.key) { dimension in
                        let options = studio.options(for: dimension, app: app)
                        if options.count > 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                MetaLabel(dimension.label)
                                FlowChips(items: options.map { ($0.value, $0.label) }, selected: studio.dims[dimension.key]) { value in
                                    studio.pick(key: dimension.key, value: value, app: app)
                                }
                            }
                        }
                    }

                    if let ratios = studio.variant(app)?.body.aspectRatio, ratios.count > 1 {
                        VStack(alignment: .leading, spacing: 10) {
                            MetaLabel("Aspect ratio")
                            FlowChips(items: ratios.map { ($0, $0) }, selected: studio.aspect) { value in
                                studio.aspect = value
                                studio.refreshQuote(app)
                            }
                        }
                    }
                }

                HStack {
                    MetaLabel("Price")
                    Spacer()
                    MetaLabel(studio.quote.map { "\(Int($0)) credits" } ?? "—", color: NX.C.ink, size: 13)
                }
                .padding(.top, 6)
            }
            .padding(20)
        }
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
