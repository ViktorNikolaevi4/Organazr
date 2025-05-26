import SwiftUI
import VisionKit
import Vision

struct TextScanner: UIViewControllerRepresentable {
    let onCompletion: (String) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: TextScanner

        init(_ parent: TextScanner) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var recognizedText = ""
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                recognizeText(from: image) { text in
                    recognizedText += text + "\n"
                }
            }
            parent.onCompletion(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines))
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Ошибка сканирования: \(error)")
            controller.dismiss(animated: true)
        }

        private func recognizeText(from image: UIImage, completion: @escaping (String) -> Void) {
            guard let cgImage = image.cgImage else { return }
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("Ошибка распознавания текста: \(error)")
                    completion("")
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion("")
                    return
                }
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                completion(recognizedStrings.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            try? requestHandler.perform([request])
        }
    }
}
