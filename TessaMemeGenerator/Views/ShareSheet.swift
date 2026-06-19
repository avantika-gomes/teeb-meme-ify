import SwiftUI
import UIKit
import LinkPresentation

struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

final class ShareImageActivityItem: NSObject, UIActivityItemSource {
    let image: UIImage
    private var temporaryFileURL: URL?

    init(image: UIImage) {
        self.image = image
    }

    deinit {
        if let temporaryFileURL {
            try? FileManager.default.removeItem(at: temporaryFileURL)
        }
    }

    @objc func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    @objc func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if let url = writeTemporaryPNG() {
            return url
        }
        return image
    }

    @objc func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "Meme"
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }

    private func writeTemporaryPNG() -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("teeb-meme-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            temporaryFileURL = url
            return url
        } catch {
            return nil
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: (() -> Void)?
    var onDismiss: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityItems = items.map { item -> Any in
            if let image = item as? UIImage {
                return ShareImageActivityItem(image: image)
            }
            return item
        }

        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = context.coordinator.handleCompletion
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    final class Coordinator {
        let onComplete: (() -> Void)?
        let onDismiss: (() -> Void)?

        init(onComplete: (() -> Void)?, onDismiss: (() -> Void)?) {
            self.onComplete = onComplete
            self.onDismiss = onDismiss
        }

        func handleCompletion(
            activityType: UIActivity.ActivityType?,
            completed: Bool,
            returnedItems: [Any]?,
            error: Error?
        ) {
            DispatchQueue.main.async {
                if completed {
                    self.onComplete?()
                }
                self.onDismiss?()
            }
        }
    }
}
