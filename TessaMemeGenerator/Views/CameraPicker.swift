import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CameraContainerViewController {
        let container = CameraContainerViewController()
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.showsCameraControls = true
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        picker.view.backgroundColor = .black

        container.picker = picker
        container.embed(picker)
        context.coordinator.picker = picker
        return container
    }

    func updateUIViewController(_ uiViewController: CameraContainerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        weak var picker: UIImagePickerController?

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                let cropped = CameraImageCropper.cropToVisiblePreview(image: image, picker: picker)
                parent.onImagePicked(cropped)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

final class CameraContainerViewController: UIViewController {
    var picker: UIImagePickerController?

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

private enum CameraImageCropper {
    /// Maps the on-screen camera preview (including pinch zoom) to a crop of the captured photo.
    static func cropToVisiblePreview(image: UIImage, picker: UIImagePickerController) -> UIImage {
        let normalized = image.normalizedUp()
        let viewSize = picker.view.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return normalized }

        let imageSize = normalized.size
        let transform = picker.cameraViewTransform

        // Aspect-fill mapping from image space into the preview view.
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let fittedWidth = imageSize.width * scale
        let fittedHeight = imageSize.height * scale
        let xOffset = (viewSize.width - fittedWidth) / 2
        let yOffset = (viewSize.height - fittedHeight) / 2

        var imageToView = CGAffineTransform.identity
            .translatedBy(x: xOffset, y: yOffset)
            .scaledBy(x: scale, y: scale)

        let viewToImage = imageToView.inverted().concatenating(transform.inverted())
        let viewBounds = CGRect(origin: .zero, size: viewSize)
        let cropRect = viewBounds.applying(viewToImage).integral

        let bounds = CGRect(origin: .zero, size: imageSize)
        let clamped = cropRect.intersection(bounds)
        guard clamped.width > 1, clamped.height > 1,
              let cgImage = normalized.cgImage?.cropping(to: clamped) else {
            return normalized
        }

        return UIImage(cgImage: cgImage, scale: normalized.scale, orientation: .up)
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
