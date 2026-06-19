import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImagePicked: (UIImage) -> Void
    var onCaptureFailed: ((String) -> Void)?

    func makeUIViewController(context: Context) -> CameraContainerViewController {
        let container = CameraContainerViewController()
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.showsCameraControls = true
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.modalPresentationStyle = .fullScreen
        picker.view.backgroundColor = .black

        container.embed(picker)
        return container
    }

    func updateUIViewController(_ uiViewController: CameraContainerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isPresented: $isPresented,
            onImagePicked: onImagePicked,
            onCaptureFailed: onCaptureFailed
        )
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        @Binding private var isPresented: Bool
        private let onImagePicked: (UIImage) -> Void
        private let onCaptureFailed: ((String) -> Void)?

        init(
            isPresented: Binding<Bool>,
            onImagePicked: @escaping (UIImage) -> Void,
            onCaptureFailed: ((String) -> Void)?
        ) {
            _isPresented = isPresented
            self.onImagePicked = onImagePicked
            self.onCaptureFailed = onCaptureFailed
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            isPresented = false

            guard let image = info[.originalImage] as? UIImage else {
                onCaptureFailed?("Could not process the photo.")
                return
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                onImagePicked(image.normalizedUp())
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isPresented = false
        }
    }
}

final class CameraContainerViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    func embed(_ picker: UIImagePickerController) {
        guard picker.parent == nil else { return }
        addChild(picker)
        picker.view.frame = view.bounds
        picker.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(picker.view)
        picker.didMove(toParent: self)
    }
}

private extension UIImage {
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
