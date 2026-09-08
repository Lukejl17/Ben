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
        Group {
            if isProcessing {
                processingState
            } else {
                pickerScreen
            }
        }
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
            // The chosen method goes straight to its picker — no extra tap.
            guard coordinator.pendingImageData == nil else { return }
            switch coordinator.uploadMethod {
            case .photo:
                showPhotoPicker = true
            case .camera:
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    showPhotoPicker = true  // simulator has no camera
                }
            case .pdf:
                showFileImporter = true
            default:
                break
            }
        }
    }

    private var pickerScreen: some View {
        BenScreen(title: "Add your bill") {
            VStack(spacing: 12) {
                captureCard(symbol: "photo.on.rectangle.angled", fill: .chartreuse, iconColor: .onChartreuse,
                            label: "Upload a photo") { showPhotoPicker = true }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    captureCard(symbol: "camera.fill", fill: .sky, iconColor: .onSky,
                                label: "Take a photo") { showCamera = true }
                }
                captureCard(symbol: "doc.fill", fill: .amber, iconColor: .onAmber,
                            label: "Upload a PDF or file") { showFileImporter = true }
            }
        } cta: {
            EmptyView()
        }
    }

    private var processingState: some View {
        ZStack {
            BenCanvas()
            VStack(spacing: 20) {
                BenCharacter(size: 110)
                ProgressView()
                    .controlSize(.large)
                    .tint(.chartreuse)
                BenVoiceText(text: "Reading it now…")
            }
        }
    }

    private func captureCard(
        symbol: String, fill: Color, iconColor: Color, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                BenIconCircle(systemName: symbol, fill: fill, iconColor: iconColor)
                Text(label)
                    .font(.benCardTitle)
                    .foregroundStyle(Color.onCream)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.onCreamMuted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(BenPressable())
        .benShadow(.floating)
        .accessibilityIdentifier(label)
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
