import SwiftUI

/// Preset categories shown under "What are you making?".
enum PresetCategory {
    static let all: [(tag: String, title: String)] = [
        ("product", "Product"), ("cars", "Cars"), ("portrait", "People"),
        ("seasonal", "Seasonal"), ("ai-trends", "Trends"), ("camera", "Camera moves"),
        ("stylised", "Styles"), ("with-you", "With you"),
    ]

    static func title(_ tag: String) -> String {
        all.first { $0.tag == tag }?.title ?? tag.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

/// 06b: presets — search, categories, trending.
struct PresetsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var selected: PresetSummary?

    private var results: [PresetSummary] {
        model.presets.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) } }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader {
                BackLink(title: "Studio")
            } title: {
                ScreenTitle(text: "Presets", size: 20)
            } trailing: {
                EmptyView()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(NX.C.muted)
                        TextField("", text: $query, prompt: Text("Search \(model.presets.count) presets — “perfume”, “Eid”, “drone”").foregroundColor(NX.C.muted))
                            .font(NX.F.body(15)).foregroundStyle(NX.C.ink)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(NX.C.tint.opacity(0.05))

                    if !query.isEmpty {
                        PresetGrid(presets: results) { selected = $0 }
                    } else {
                        SectionLabel("What are you making?")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 14) {
                            ForEach(PresetCategory.all, id: \.tag) { category in
                                let items = model.presets.filter { $0.tags.contains(category.tag) }
                                if !items.isEmpty {
                                    Button { model.push(.presetCategory(category.tag)) } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Color.clear.aspectRatio(1, contentMode: .fit)
                                                .overlay {
                                                    AsyncImage(url: items.first?.previewImageUrl) { phase in
                                                        if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder(seed: category.tag.count) }
                                                    }
                                                }
                                                .clipped()
                                            Text(category.title).font(NX.F.body(14, .semibold)).foregroundStyle(NX.C.ink)
                                            Text("\(items.count) presets").font(NX.F.body(11)).foregroundStyle(NX.C.ink3)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        SectionLabel("Trending this week")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(model.presets.filter { $0.tags.contains("ai-trends") }.prefix(8)) { preset in
                                    Button { selected = preset } label: { PresetCard(preset: preset).frame(width: 150) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(NX.C.bg.ignoresSafeArea())
        .sheet(item: $selected) { preset in
            PresetDetailView(preset: preset)
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
        .onAppear {
            if let slug = model.launchPreset {
                model.launchPreset = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    selected = model.presets.first { $0.slug == slug }
                }
            }
        }
    }
}

/// 06c: one category with sub-tags and an Image / Video switch.
struct PresetCategoryScreen: View {
    @Environment(AppModel.self) private var model
    let tag: String
    @State private var sub: String?
    @State private var kind = "all"
    @State private var selected: PresetSummary?

    private var inCategory: [PresetSummary] { model.presets.filter { $0.tags.contains(tag) } }

    private var subTags: [(String, Int)] {
        var counts: [String: Int] = [:]
        for p in inCategory { for t in p.tags where t != tag { counts[t, default: 0] += 1 } }
        return counts.sorted { $0.value > $1.value }.prefix(8).map { ($0.key, $0.value) }
    }

    private var items: [PresetSummary] {
        inCategory.filter { p in
            (sub == nil || p.tags.contains(sub!)) && (kind == "all" || p.kind == kind)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader {
                BackLink(title: "Presets")
            } title: {
                ScreenTitle(text: "\(PresetCategory.title(tag)) · \(inCategory.count)", size: 18)
            } trailing: {
                EmptyView()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !subTags.isEmpty {
                        SectionLabel("Type of \(PresetCategory.title(tag).lowercased())")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                SkewTag(title: "All", selected: sub == nil) { sub = nil }
                                ForEach(subTags, id: \.0) { pair in
                                    SkewTag(title: "\(PresetCategory.title(pair.0)) · \(pair.1)", selected: sub == pair.0) { sub = pair.0 }
                                }
                            }
                        }
                    }
                    HStack(spacing: 0) {
                        SkewTag(title: "All", selected: kind == "all") { kind = "all" }
                        SkewTag(title: "Image", selected: kind == "image") { kind = "image" }
                        SkewTag(title: "Video", selected: kind == "video") { kind = "video" }
                    }
                    PresetGrid(presets: items) { selected = $0 }
                }
                .padding(16)
            }
        }
        .background(NX.C.bg.ignoresSafeArea())
        .sheet(item: $selected) { preset in
            PresetDetailView(preset: preset)
                .presentationDragIndicator(.visible)
                .nxSheetBackground()
        }
    }
}

struct PresetGrid: View {
    let presets: [PresetSummary]
    let onPick: (PresetSummary) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 16) {
            ForEach(presets) { preset in
                Button { onPick(preset) } label: { PresetCard(preset: preset) }
                    .buttonStyle(.plain)
            }
        }
    }
}

struct PresetCard: View {
    let preset: PresetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .aspectRatio(4 / 5.0, contentMode: .fit)
                .overlay {
                    AsyncImage(url: preset.previewImageUrl) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { TilePlaceholder(seed: preset.slug.count) }
                    }
                }
                .clipped()
            Text(preset.name).font(NX.F.body(14, .semibold)).foregroundStyle(NX.C.ink).lineLimit(2)
            Text("\(preset.kind.capitalized) · \(preset.creditsVary ? "from " : "")\(preset.credits) cr").font(NX.F.body(11)).foregroundStyle(NX.C.ink3)
        }
        .accessibilityElement(children: .combine)
    }
}
