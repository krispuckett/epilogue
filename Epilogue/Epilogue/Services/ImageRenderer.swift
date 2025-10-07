import SwiftUI
import UIKit

/// Service for rendering SwiftUI views to UIImage for sharing
@MainActor
struct ImageRenderer {

    /// Render a SwiftUI view to a UIImage
    /// - Parameters:
    ///   - view: The SwiftUI view to render
    ///   - size: The size of the output image (default: Instagram square 1080x1080)
    /// - Returns: Rendered UIImage
    static func render<Content: View>(
        view: Content,
        size: CGSize = CGSize(width: 1080, height: 1080)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Create a hosting controller for the SwiftUI view
            let hostingController = UIHostingController(rootView: view)
            hostingController.view.bounds = CGRect(origin: .zero, size: size)
            hostingController.view.backgroundColor = .clear

            // Render the view
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
    }

    /// Render a SwiftUI view to UIImage using modern iOS 16+ ImageRenderer
    @available(iOS 16.0, *)
    static func renderModern<Content: View>(
        view: Content,
        size: CGSize = CGSize(width: 1080, height: 1080),
        scale: CGFloat = 3.0 // Retina quality
    ) -> UIImage {
        let renderer = SwiftUI.ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale

        if let image = renderer.uiImage {
            return image
        }

        // Fallback to legacy renderer
        return render(view: view, size: size)
    }
}
