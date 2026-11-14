import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct ChatAttachment: Identifiable {
    let id = UUID()
    var image: UIImage? = nil
    var previewURL: URL? = nil
    var uploading: Bool
    var url: String? = nil
}

/// Chat input (01 / 05): [+] [Fast ▴] [⊞ presets] … [↑]. In a project: [CHAT key] [Fast ▴] … [↑].
struct ChatComposer: View {
    @Environment(AppModel.self) private var model
    var placeholder: String
    var projectID: String? = nil
    var chatID: String? = nil
    @Binding var draft: String
    var onSend: (String, [String]) -> Void

    @State private var attachments: [ChatAttachment] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var showCamera = false
    @State private var showFiles = false
    @State private var keyMode: CreateMode = .chat
    @FocusState private var focused: Bool

    private var hasText: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var uploading: Bool { attachments.contains { $0.uploading } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !attachments.isEmpty { attachmentStrip }

            TextField("", text: $draft, prompt: Text(placeholder).foregroundColor(NX.C.muted), axis: .vertical)
                .font(NX.F.body(16))
                .foregroundStyle(NX.C.ink)
                .lineLimit(1...6)
                .focused($focused)
                .padding(.horizontal, 4)
                .frame(minHeight: 34, alignment: .topLeading)

            HStack(spacing: 6) {
                if projectID != nil {
                    ModeKey(mode: $keyMode, modes: [.chat, .image, .video, .audio])
                } else {
                    addMenu
                }
                modeMenu
                if projectID == nil {
                    SkewIconButton(systemName: "square.grid.2x2", label: "Presets", size: 40) { model.push(.presets) }
                }
                Spacer(minLength: 0)
                if model.isStreaming {
                    SendPriceButton(icon: "stop.fill") { model.stop() }
                } else {
                    SendPriceButton(enabled: hasText && !uploading) { send() }
                }
            }
        }
        .auraComposer(active: focused || hasText)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .padding(.top, 6)
        .onChange(of: keyMode) { _, mode in
            guard mode != .chat else { return }
            // Switching the key away from Chat hands the text to the project's Studio (12b–12d).
            model.openInStudio(StudioDraft(prompt: draft, mode: mode, fromChatTitle: chatID.flatMap { id in model.chats.first { $0.id == id }?.title }, fromChatID: chatID, projectID: projectID))
            draft = ""
            keyMode = .chat
        }
        .photosPicker(isPresented: $showPhotos, selection: $pickerItems, maxSelectionCount: 4, matching: .images)
        .onChange(of: pickerItems) { _, items in
            pickerItems = []
            for item in items { Task { await add(item) } }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in Task { await add(image: image) } }
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image, .pdf, .plainText], allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                Task { await add(image: image) }
            } else {
                model.showToast("Only pictures can be attached for now")
            }
        }
        .task(id: model.pendingAttachments.count) {
            guard !model.pendingAttachments.isEmpty else { return }
            let items = model.pendingAttachments
            model.pendingAttachments = []
            for item in items {
                attachments.append(ChatAttachment(previewURL: item.previewURL, uploading: false, url: item.url?.absoluteString))
            }
            focused = true
        }
    }

    // MARK: Menus (03 / 04)

    private var addMenu: some View {
        @Bindable var model = model
        return Menu {
            Button { showPhotos = true } label: { Label("Photos", systemImage: "photo") }
            Button { showCamera = true } label: { Label("Camera", systemImage: "camera") }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            Button { showFiles = true } label: { Label("Files", systemImage: "doc") }
            Divider()
            Button {
                if let id = model.currentChatID { model.moveChatID = id } else { model.showToast("Send a message first, then add the chat to a project") }
            } label: {
                Label("Add to project", systemImage: "folder.badge.plus")
            }
            Toggle(isOn: $model.webSearchOn) { Label("Web search", systemImage: "globe") }
            Toggle(isOn: $model.memoryOn) { Label("Memory", systemImage: "brain") }
        } label: {
            SkewIconFace(systemName: "plus", size: 40)
        }
        .accessibilityLabel("Add photos, files or a project")
    }

    private var modeMenu: some View {
        Menu {
            ForEach(model.tiers) { tier in
                Button {
                    model.selectedTier = tier.tier
                } label: {
                    if model.selectedTier == tier.tier {
                        Label("\(tier.title) — \(tier.subtitle)", systemImage: "checkmark")
                    } else if tier.locked {
                        Label("\(tier.title) — \(tier.subtitle)", systemImage: "lock")
                    } else {
                        Text("\(tier.title) — \(tier.subtitle)")
                    }
                }
                .disabled(tier.locked)
            }
        } label: {
            HStack(spacing: 6) {
                Text((model.tier?.title ?? "Fast").uppercased()).font(NX.F.mono(10)).tracking(1.4)
                Image(systemName: "chevron.up").font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(NX.C.ink2)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(SkewFill(style: .glass))
        }
        .accessibilityLabel("Chat mode: \(model.tier?.title ?? "Fast")")
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { a in
                    ZStack {
                        if let image = a.image {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            AsyncImage(url: a.previewURL) { $0.resizable().scaledToFill() } placeholder: { TilePlaceholder() }
                        }
                        if a.uploading { Color.black.opacity(0.5); ProgressView().controlSize(.small) }
                    }
                    .frame(width: 52, height: 52)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        Button { attachments.removeAll { $0.id == a.id } } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 18, height: 18).background(Color.black.opacity(0.7))
                        }
                        .accessibilityLabel("Remove attachment")
                    }
                }
            }
        }
    }

    private func send() {
        let text = draft
        let urls = attachments.compactMap(\.url)
        draft = ""
        attachments = []
        onSend(text, urls)
    }

    @MainActor
    private func add(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        await add(image: image)
    }

    @MainActor
    private func add(image: UIImage) async {
        let attachment = ChatAttachment(image: image, uploading: model.auth == .live)
        attachments.append(attachment)
        guard model.auth == .live, let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        let url = try? await NXORService.uploadChatAttachment(data: jpeg)
        if let i = attachments.firstIndex(where: { $0.id == attachment.id }) {
            if let url {
                attachments[i].url = url
                attachments[i].uploading = false
            } else {
                attachments.remove(at: i)
                model.errorMessage = "Couldn't upload the photo. Try again."
            }
        }
    }
}

/// System camera for "+ → Camera".
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
