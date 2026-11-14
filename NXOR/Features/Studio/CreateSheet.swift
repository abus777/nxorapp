import SwiftUI
import PhotosUI
import UIKit

/// 06e / 06d / 12b–12d: the create sheet. Cancel left, Settings right, mode key + model + "↑ price" in the field.
struct CreateSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var refPicker: [PhotosPickerItem] = []
    @State private var library = LibraryModel()
    @State private var showTip = false
    @FocusState private var focused: Bool

    private var studio: StudioModel { model.studio }
    private var project: Project? { model.project(studio.projectID) }

    var body: some View {
        @Bindable var studio = model.studio
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                SheetCancelButton { dismiss() }
                Spacer(minLength: 4)
                VStack(spacing: 1) {
                    Text(project == nil ? "NEW" : "NEW \(studio.mode.title.uppercased())").font(NX.F.display(18)).foregroundStyle(NX.C.inkSoft)
                    if let project {
                        Text("in \(project.name)\(library.loaded ? " · \(library.items.count + library.uploads.count) assets" : "")")
                            .font(NX.F.body(11)).foregroundStyle(NX.C.ink3).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                SkewButton(title: "Settings", size: .s, style: .glass) { showSettings = true }
            }

            if project != nil && studio.mode != .audio { projectStrip }
            if studio.mode == .audio { audioRows }

            VStack(alignment: .leading, spacing: 10) {
                if let title = studio.fromChatTitle {
                    HStack(spacing: 6) {
                        Text("AA FROM CHAT: \(title.uppercased())").font(NX.F.mono(10)).tracking(1.4).lineLimit(1)
                        Button { studio.clearFromChat() } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                            .accessibilityLabel("Remove chat link")
                    }
                    .foregroundStyle(NX.C.inkSoft)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(SkewFill(style: .glass, selected: true))
                }

                ZStack(alignment: .topTrailing) {
                    TextField("", text: $studio.prompt, prompt: Text(studio.mode.placeholder).foregroundColor(NX.C.muted), axis: .vertical)
                        .font(NX.F.body(16))
                        .foregroundStyle(NX.C.ink)
                        .lineLimit(3...10)
                        .focused($focused)
                        .padding(.trailing, studio.wordCount >= 3 ? 96 : 0)
                    if studio.wordCount >= 3 || studio.promptBeforeEnhance != nil { improveControls }
                }

                if !studio.references.isEmpty || studio.mode != .audio { referenceRow }

                if let price = studio.price, Double(price) > model.account.available {
                    NoCreditsBanner(needed: price)
                }

                HStack(spacing: 6) {
                    ModeKey(mode: Binding(get: { studio.mode }, set: { studio.setMode($0, app: model) }))
                    Button { showSettings = true } label: {
                        FieldChip(title: studio.mode == .audio ? "Voice · \(studio.language)" : chipTitle)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Model and settings")
                    Spacer(minLength: 0)
                    SendPriceButton(price: studio.price, loading: studio.submitting || studio.quoting && studio.price == nil, enabled: canSend) {
                        Task {
                            if await studio.generate(app: model) { dismiss() }
                        }
                    }
                }
            }
            .auraComposer(active: focused, highlighted: focused)

            Spacer(minLength: 0)
        }
        .padding(16)
        .task {
            if let draft = model.studioDraft {
                studio.apply(draft, app: model)
                model.studioDraft = nil
            } else {
                studio.ensureSelection(model)
            }
            studio.refreshQuote(model)
            if studio.projectID != nil {
                library.scope = studio.projectID
                await library.load(app: model)
            }
            focused = studio.prompt.isEmpty
            if UserDefaults.standard.bool(forKey: "openSettings") {
                try? await Task.sleep(for: .milliseconds(900))
                showSettings = true
            }
        }
        .onChange(of: studio.prompt) { _, _ in
            studio.refreshQuote(model)
            if studio.wordCount >= 3, !UserDefaults.standard.bool(forKey: "improveTipSeen") {
                showTip = true
                UserDefaults.standard.set(true, forKey: "improveTipSeen")
            }
        }
        .onChange(of: refPicker) { _, items in
            refPicker = []
            for item in items {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
                       let uploaded = await library.upload(image, app: model) {
                        studio.addReference(uploaded, app: model)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            RunSettingsSheet { dismiss() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
        .alert("Couldn't start", isPresented: Binding(get: { studio.error != nil }, set: { if !$0 { studio.error = nil } })) {
            if studio.error?.hasPrefix("Needs") == true {
                Button("Buy credits") { model.showCredits = true }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(studio.error ?? "")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: studio.references.count)
    }

    private var chipTitle: String {
        let label = studio.familyLabel.isEmpty ? "Model" : studio.familyLabel
        if studio.kind == .video, let d = studio.durationOptions(model) {
            let v = studio.dims[d.key].flatMap { Double($0.filter { $0.isNumber || $0 == "." }) } ?? d.values.first ?? 5
            return "\(label) · \(Int(v)) s"
        }
        return "\(label)\(studio.aspect.map { " · \($0)" } ?? "")"
    }

    private var canSend: Bool {
        !studio.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !studio.submitting && (studio.mode == .audio || studio.variant(model) != nil)
    }

    /// ✦ inside the field (3+ words), tip on first show, Undo after applying.
    private var improveControls: some View {
        HStack(spacing: 4) {
            if studio.promptBeforeEnhance != nil {
                SkewButton(title: "Undo", size: .s, style: .dark) { studio.undoEnhance() }
            }
            Button {
                showTip = false
                Task { await studio.enhance(app: model) }
            } label: {
                Group {
                    if studio.enhancing { ProgressView().controlSize(.small).tint(NX.C.btnInk) } else { Image(systemName: "sparkle").font(.system(size: 13, weight: .semibold)) }
                }
                .foregroundStyle(NX.C.btnInk)
                .frame(width: 34, height: 32)
                .background(Parallelogram().fill(NX.G.silver))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Improve your prompt with AI")
            .popover(isPresented: $showTip, arrowEdge: .top) {
                Text("Improve your prompt with AI")
                    .font(NX.F.body(13))
                    .padding(12)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private var referenceRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(studio.references.enumerated()), id: \.element.id) { index, ref in
                    VStack(spacing: 3) {
                        AsyncImage(url: ref.previewURL) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder() }
                        }
                        .frame(width: 44, height: 44)
                        .clipped()
                        .overlay(alignment: .topTrailing) {
                            Button { studio.removeReference(ref, app: model) } label: {
                                Image(systemName: "xmark").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 16, height: 16).background(Color.black.opacity(0.7))
                            }
                            .accessibilityLabel("Remove reference \(index + 1)")
                        }
                        Text("@image\(index + 1)").font(NX.F.mono(8)).foregroundStyle(NX.C.muted)
                    }
                }
                if studio.mode != .audio && studio.references.count < studio.maxReferences {
                    PhotosPicker(selection: $refPicker, maxSelectionCount: 4, matching: .images) {
                        Image(systemName: library.uploading > 0 ? "hourglass" : "plus")
                            .font(.system(size: 13))
                            .foregroundStyle(NX.C.ink3)
                            .frame(width: 44, height: 44)
                            .overlay(Rectangle().strokeBorder(NX.C.tint.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                    .accessibilityLabel("Add reference photo")
                }
            }
        }
    }

    /// "TAP TO USE AS REFERENCE": the project's media (12b / 12c).
    private var projectStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Tap to use as reference")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach((library.uploads + library.items).filter { !$0.isVideo }.prefix(16)) { item in
                        let on = studio.references.contains { $0.id == item.id }
                        Button {
                            if on { studio.removeReference(item, app: model) } else { studio.addReference(item, app: model) }
                        } label: {
                            AsyncImage(url: item.previewURL) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder() }
                            }
                            .frame(width: 64, height: 64)
                            .clipped()
                            .overlay(Rectangle().strokeBorder(on ? NX.C.accent : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(on ? "Reference selected" : "Use as reference")
                    }
                }
            }
        }
    }

    /// 12d: voice settings for audio.
    private var audioRows: some View {
        @Bindable var studio = model.studio
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel("Voice")
                    Text("\(studio.voice) · \(studio.language)").font(NX.F.body(15, .semibold)).foregroundStyle(NX.C.ink)
                }
                Spacer()
                Menu {
                    Picker("Voice", selection: $studio.voice) {
                        ForEach(["Default male", "Default female", "Warm narrator", "Bright presenter"], id: \.self) { Text($0) }
                    }
                    Picker("Language", selection: $studio.language) {
                        ForEach(["Arabic", "English", "Russian", "French"], id: \.self) { Text($0) }
                    }
                } label: {
                    Text("Change ›").font(NX.F.body(14)).foregroundStyle(NX.C.inkSoft).frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 12)
            .background(NX.C.tint.opacity(0.04))
            if let projectID = studio.projectID {
                let texts = model.chats(in: projectID).filter { !$0.messages.isEmpty }
                if !texts.isEmpty {
                    SectionLabel("Text from this project")
                    ForEach(texts.prefix(2)) { chat in
                        Button {
                            studio.prompt = chat.messages.last { $0.role == .assistant }?.text ?? ""
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.title).font(NX.F.body(14, .semibold)).foregroundStyle(NX.C.ink)
                                Text("From chat · tap to voice it").font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(NX.C.tint.opacity(0.04))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 07 / 07c Run settings

struct RunSettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onCreated: () -> Void = {}
    @State private var refPicker: [PhotosPickerItem] = []
    @State private var library = LibraryModel()

    var body: some View {
        @Bindable var studio = model.studio
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    SheetCancelButton { dismiss() }
                    Spacer()
                    Text("RUN SETTINGS").font(NX.F.display(18)).foregroundStyle(NX.C.inkSoft)
                    Spacer()
                    SheetDoneButton { dismiss() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        group("Model") {
                            NavigationLink {
                                ModelPickerView(kind: studio.kind, selected: studio.familyID) { family in
                                    studio.select(family: family, app: model)
                                }
                                .toolbar(.hidden, for: .navigationBar)
                            } label: {
                                formRow(studio.familyLabel.isEmpty ? "Choose a model" : studio.familyLabel,
                                        subtitle: studio.family(model).map { "\($0.provider)\(studio.quote.map { " · from \(Int($0)) cr" } ?? "")" },
                                        value: nil, chevron: "chevron.right")
                            }
                            .buttonStyle(.plain)
                        }

                        if studio.mode != .audio { references }

                        group("Output") {
                            if let ratios = studio.variant(model)?.body.aspectRatio, ratios.count > 1 {
                                menuRow("Aspect ratio", value: studio.aspect ?? ratios[0]) {
                                    ForEach(ratios, id: \.self) { r in Button(r) { studio.aspect = r; studio.refreshQuote(model) } }
                                }
                            }
                            if let family = studio.family(model) {
                                ForEach(family.dimensions.filter { $0.key != "operation" && !$0.key.lowercased().contains("duration") }, id: \.key) { dimension in
                                    let options = studio.options(for: dimension, app: model)
                                    if options.count > 1 {
                                        menuRow(dimension.label, value: options.first { $0.value == studio.dims[dimension.key] }?.label ?? options[0].label) {
                                            ForEach(options, id: \.value) { option in
                                                Button(option.label) { studio.pick(key: dimension.key, value: option.value, app: model) }
                                            }
                                        }
                                    }
                                }
                            }
                            if studio.kind == .video, let duration = studio.durationOptions(model), duration.values.count > 1 {
                                durationRow(duration)
                            }
                            if studio.kind == .image {
                                HStack {
                                    Text("Images · \(studio.count)").font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                                    Spacer()
                                    Stepper("Images", value: $studio.count, in: 1...4)
                                        .labelsHidden()
                                        .onChange(of: studio.count) { _, _ in studio.refreshQuote(model) }
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 52)
                            }
                        }

                        if let projectID = studio.projectID, let project = model.project(projectID), model.meta(projectID).hasBrandKit {
                            group("Project") {
                                Toggle(isOn: $studio.brandKitOn) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(project.name) brand kit").font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                                        Text("Logo, colors, \(model.meta(projectID).referenceIDs.count) references").font(NX.F.body(12)).foregroundStyle(NX.C.ink3)
                                    }
                                }
                                .tint(NX.C.accent)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 56)
                            }
                        }
                    }
                    .padding(16)
                }

                SkewButton(title: "Create\(studio.price.map { " · \($0) cr" } ?? "")", size: .l, style: .metal, fullWidth: true, enabled: !studio.prompt.isEmpty && !studio.submitting) {
                    Task {
                        if await studio.generate(app: model) {
                            dismiss()
                            onCreated()
                        }
                    }
                }
                .padding(16)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            library.scope = studio.projectID
            await library.load(app: model)
        }
        .onChange(of: refPicker) { _, items in
            refPicker = []
            for item in items {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
                       let uploaded = await library.upload(image, app: model) {
                        model.studio.addReference(uploaded, app: model)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var references: some View {
        let studio = model.studio
        if studio.kind == .video {
            group("References", trailing: "image \(studio.references.count)/3") {
                HStack(spacing: 8) {
                    slot("First frame", item: studio.references.first)
                    slot("Last frame", item: studio.references.count > 1 ? studio.references[1] : nil)
                    PhotosPicker(selection: $refPicker, maxSelectionCount: 3, matching: .images) {
                        Text("+ MEDIA").font(NX.F.mono(10)).tracking(1.6).foregroundStyle(NX.C.inkSoft)
                            .frame(maxWidth: .infinity).frame(height: 64)
                            .background(LinearGradient(colors: [Color(hex: 0x2A1B3D), Color(hex: 0x14122B)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .padding(10)
            }
        } else {
            group("References", trailing: "\(studio.references.count) of \(studio.maxReferences)") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(studio.references.enumerated()), id: \.element.id) { index, ref in
                            VStack(spacing: 4) {
                                AsyncImage(url: ref.previewURL) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder() }
                                }
                                .frame(width: 58, height: 58).clipped()
                                .contextMenu { Button(role: .destructive) { studio.removeReference(ref, app: model) } label: { Label("Remove", systemImage: "trash") } }
                                Text("@image\(index + 1)").font(NX.F.mono(8)).foregroundStyle(NX.C.muted)
                            }
                        }
                        PhotosPicker(selection: $refPicker, maxSelectionCount: 4, matching: .images) {
                            Image(systemName: "plus").foregroundStyle(NX.C.ink3)
                                .frame(width: 58, height: 58)
                                .overlay(Rectangle().strokeBorder(NX.C.tint.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        }
                        .accessibilityLabel("Add reference")
                    }
                    .padding(10)
                }
            }
        }
    }

    private func slot(_ title: String, item: LibraryItem?) -> some View {
        ZStack {
            if let item {
                AsyncImage(url: item.previewURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder() }
                }
            } else {
                NX.C.tint.opacity(0.04)
            }
            if item == nil {
                Text(title.uppercased()).font(NX.F.mono(9)).tracking(1.4).foregroundStyle(NX.C.ink3).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 64).clipped()
    }

    private func durationRow(_ duration: (key: String, values: [Double])) -> some View {
        let studio = model.studio
        let current = studio.dims[duration.key].flatMap { Double($0.filter { $0.isNumber || $0 == "." }) } ?? duration.values[0]
        let index = Double(duration.values.firstIndex(of: current) ?? 0)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Duration").font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                Spacer()
                Text("\(Int(current)) s").font(NX.F.display(15)).foregroundStyle(NX.C.ink)
            }
            Slider(value: Binding(get: { index }, set: { new in
                let i = min(max(Int(new.rounded()), 0), duration.values.count - 1)
                let target = duration.values[i]
                if let family = studio.family(model), let dim = family.dimensions.first(where: { $0.key == duration.key }),
                   let option = studio.options(for: dim, app: model).first(where: { Double($0.value.filter { $0.isNumber || $0 == "." }) == target }) {
                    studio.pick(key: duration.key, value: option.value, app: model)
                }
            }), in: 0...Double(max(duration.values.count - 1, 1)), step: 1)
            .tint(NX.C.accent)
            .accessibilityValue("\(Int(current)) seconds")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func group<Content: View>(_ title: String, trailing: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title)
                Spacer()
                if let trailing { Text(trailing).font(NX.F.body(11)).foregroundStyle(NX.C.ink3) }
            }
            VStack(spacing: 0) { content() }
                .background(NX.C.tint.opacity(0.035))
        }
    }

    private func formRow(_ title: String, subtitle: String?, value: String?, chevron: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                if let subtitle { Text(subtitle).font(NX.F.body(12)).foregroundStyle(NX.C.ink3) }
            }
            Spacer()
            if let value { Text(value).font(NX.F.body(14)).foregroundStyle(NX.C.ink3) }
            Image(systemName: chevron).font(.system(size: 11, weight: .semibold)).foregroundStyle(NX.C.ink3)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func menuRow<Items: View>(_ title: String, value: String, @ViewBuilder items: () -> Items) -> some View {
        Menu {
            items()
        } label: {
            formRow(title, subtitle: nil, value: value, chevron: "chevron.up.chevron.down")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 07d Model picker

struct ModelPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var kind: GenerationCard.Kind
    var selected: String
    var switchesStudio = true
    let onPick: (ModelFamily) -> Void
    @State private var query = ""
    @State private var tab: CreateMode = .image

    private var families: [ModelFamily] {
        let all = tab == .video ? model.videoModels : tab == .image ? model.imageModels : []
        guard !query.isEmpty else { return all }
        return all.filter { $0.label.localizedCaseInsensitiveContains(query) || $0.provider.localizedCaseInsensitiveContains(query) || ($0.description ?? "").localizedCaseInsensitiveContains(query) }
    }

    private var providers: [(String, [ModelFamily])] {
        var order: [String] = []
        var groups: [String: [ModelFamily]] = [:]
        for family in families.dropFirst(query.isEmpty ? 3 : 0) {
            if groups[family.provider] == nil { order.append(family.provider) }
            groups[family.provider, default: []].append(family)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader {
                BackLink(title: "Run settings")
            } title: {
                ScreenTitle(text: "Model", centered: true)
            } trailing: {
                Color.clear.frame(width: 60, height: 1)
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(NX.C.muted)
                    TextField("", text: $query, prompt: Text("Search \(families.count) \(tab.title.lowercased()) models").foregroundColor(NX.C.muted))
                        .font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(NX.C.tint.opacity(0.05))
                SkewSegment(items: [(.image, "Image"), (.video, "Video"), (.audio, "Audio")], selection: $tab)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if tab == .audio {
                        Text("Voice models aren't in the NXOR API yet. They'll show up here.")
                            .font(NX.F.body(14)).foregroundStyle(NX.C.ink3)
                            .padding(.vertical, 24)
                    } else {
                        if query.isEmpty, !families.isEmpty {
                            SectionLabel("Recommended").padding(.top, 10).padding(.bottom, 4)
                            ForEach(families.prefix(3)) { row($0) }
                        }
                        ForEach(providers, id: \.0) { provider, list in
                            SectionLabel("\(provider) · \(list.count)").padding(.top, 16).padding(.bottom, 4)
                            ForEach(list) { row($0) }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(NX.C.bg.ignoresSafeArea())
        .onAppear { tab = kind == .video ? .video : .image }
    }

    private func row(_ family: ModelFamily) -> some View {
        Button {
            if switchesStudio {
                if tab == .video { model.studio.switchKind(.video, app: model) } else if tab == .image { model.studio.switchKind(.image, app: model) }
            }
            onPick(family)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(family.label).font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                    Text(family.description ?? family.provider).font(NX.F.body(12)).foregroundStyle(NX.C.ink3).lineLimit(2)
                }
                Spacer()
                if family.family == selected { Image(systemName: "checkmark").foregroundStyle(NX.C.accent) }
            }
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(NX.C.tint.opacity(0.05)).frame(height: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(family.family == selected ? .isSelected : [])
    }
}
