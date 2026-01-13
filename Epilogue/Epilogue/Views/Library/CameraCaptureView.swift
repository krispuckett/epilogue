import SwiftUI
import UIKit

/// Camera capture view for photographing book covers
/// Wraps UIImagePickerController with built-in editing/cropping
struct CameraCaptureView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = true // Built-in cropping for book covers
        picker.cameraCaptureMode = .photo

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage?) -> Void

        init(onImageCaptured: @escaping (UIImage?) -> Void) {
            self.onImageCaptured = onImageCaptured
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Prefer edited (cropped) image, fall back to original
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage

            picker.dismiss(animated: true) {
                self.onImageCaptured(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onImageCaptured(nil)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CameraCaptureView { image in
        print("Captured: \(image != nil ? "Image" : "Nothing")")
    }
}
