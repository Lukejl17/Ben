import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// S5 — capture and extract. Calm processing state; failures branch to B2.
struct CaptureExtractView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services

    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isProcessing {
                processingState
            } else {
                pickerButtons
            }
        }
        .padding(.horizontal, 24)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await process(data)
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image]
        ) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                Task { await process(data) }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                if let data {
                    Task { await process(data) }
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            // UI-test hook: feed the (mock) parser directly, skipping OS pickers.
            if ProcessInfo.processInfo.arguments.contains("-autoCapture") {
                Task { await process(Data("ui-test-bill".utf8)) }
                return
            }
            // Photo method goes straight to the picker — no extra tap.
            if coordinator.uploadMethod == .photo && coordinator.pendingImageData == nil {
                showPhotoPicker = true
            } else if coordinator.uploadMethod == .pdf {
                showFileImporter = true
            }
        }
    }

    private var pickerButtons: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add your bill")
                .font(.benTitle)
                .foregroundStyle(Color.benInk)
                .padding(.top, 48)
            VStack(spacing: 10) {
                captureButton(symbol: "photo.on.rectangle", label: "Choose a photo") { showPhotoPicker = true }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    captureButton(symbol: "camera", label: "Take a photo") { showCamera = true }
                }
                captureButton(symbol: "doc", label: "Choose a PDF or file") { showFileImporter = true }
            }
            Spacer()
            BenSecondaryButton(title: "Back") {
                coordinator.advance(to: .upload)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 32)
        }
    }

    private var processingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            BenVoiceText(text: "Reading it now…")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func captureButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                Text(label)
                    .font(.benLabel)
                Spacer()
            }
            .padding(16)
            .background(Color.benCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.benHairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.benInk)
    }

    private func process(_ data: Data) async {
        isProcessing = true
        coordinator.pendingImageData = data
        do {
            let parsed = try await services.parser.parse(data)
            guard parsed.isUsable else { throw BillParsingError.noTextFound }
            services.analytics.track(.billParseSucceeded)
            coordinator.parsed = parsed
            coordinator.advance(to: .confirm)
        } catch {
            services.analytics.track(.billParseFailed)
            coordinator.parsed = nil
            coordinator.advance(to: .manualEntry)
        }
        isProcessing = false
    }
}

/// Minimal camera wrapper. Simulator has no camera; the button hides itself there.
private struct CameraPicker: UIViewControllerRepresentable {
    let completion: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (Data?) -> Void
        init(completion: @escaping (Data?) -> Void) { self.completion = completion }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            completion(image?.jpegData(compressionQuality: 0.85))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
        }
    }
}
