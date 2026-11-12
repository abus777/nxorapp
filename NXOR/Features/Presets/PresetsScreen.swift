import SwiftUI

struct PresetsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var filter = "all"

    private let filters: [(String, String)] = [
        ("all", "All"), ("portrait", "Portrait"), ("product", "Product"),
        ("camera", "Camera"), ("video", "Video"), ("seasonal", "Seasonal"),
    ]

    private var items: [PresetSummary] {
        switch filter {
        case "all": return model.presets
        case "video": return model.presets.filter { $0.kind == "video" }
        default: return model.presets.filter { $0.tags.contains(filter) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    DisplayTitle("Presets", size: 34)
                    MetaLabel("\(model.presets.count)", size: 13)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(filters.enumerated()), id: \.offset) { _, item in
                            NXChip(title: item.1, selected: filter == item.0) {
                                withAnimation(NX.Motion.hover) { filter = item.0 }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 18) {
                    ForEach(items) { preset in
                        PresetTile(preset: preset)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
    }
}

struct PresetTile: View {
    let preset: PresetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(4 / 5.0, contentMode: .fit)
                    .overlay {
                        AsyncImage(url: preset.previewImageUrl) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Skeleton()
                            }
                        }
                    }
                    .clipped()

                Text("USE PRESET")
                    .font(NX.F.mono(9, .semibold)).tracking(1.6)
                    .foregroundStyle(NX.C.ink)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .padding(8)
            }
            .overlay(Rectangle().strokeBorder(NX.C.line, lineWidth: 1))

            Text(preset.name)
                .font(NX.F.body(15, .medium))
                .foregroundStyle(NX.C.ink)
                .lineLimit(1)
            MetaLabel(preset.priceLabel, color: NX.C.ink3, size: 10)
        }
    }
}
