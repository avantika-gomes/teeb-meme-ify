import SwiftUI
import UIKit

struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: (() -> Void)?
    var onDismiss: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
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
