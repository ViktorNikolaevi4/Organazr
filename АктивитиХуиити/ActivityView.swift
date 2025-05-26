import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any] // Элементы для обмена (например, текст)
    let applicationActivities: [UIActivity]? = nil // Дополнительные активности (опционально)

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: applicationActivities
        )
        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Ничего не нужно обновлять
    }
}
