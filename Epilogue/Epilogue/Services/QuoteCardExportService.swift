import SwiftUI
import UIKit
import Photos

/// Service for exporting quote cards to images
@MainActor
final class QuoteCardExportService {

    static let shared = QuoteCardExportService()

    private init() {}

    // MARK: - Export Methods

    /// Render a quote card to UIImage
    func renderQuoteCard(
        data: QuoteCardData,
        config: QuoteCardConfiguration
    ) async -> UIImage {
        let cardView = QuoteCardTemplateView(
            data: data,
            config: config,
            renderSize: config.effectiveSize
        )

        if #available(iOS 16.0, *) {
            return ImageRenderer.renderModern(
                view: cardView,
                size: config.effectiveSize,
                scale: 3.0
            )
        } else {
            return ImageRenderer.render(
                view: cardView,
                size: config.effectiveSize
            )
        }
    }

    /// Export quote card directly to Photos library
    func saveToPhotos(
        data: QuoteCardData,
        config: QuoteCardConfiguration
    ) async throws {
        let image = await renderQuoteCard(data: data, config: config)

        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    continuation.resume(throwing: QuoteCardExportError.saveFailed)
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: error ?? QuoteCardExportError.saveFailed)
                    }
                }
            }
        }
    }

    /// Present share sheet for quote card
    func shareQuoteCard(
        data: QuoteCardData,
        config: QuoteCardConfiguration,
        from sourceView: UIView? = nil
    ) async {
        let image = await renderQuoteCard(data: data, config: config)

        let activityController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        // iPad support
        if let sourceView = sourceView {
            activityController.popoverPresentationController?.sourceView = sourceView
            activityController.popoverPresentationController?.sourceRect = sourceView.bounds
        }

        presentViewController(activityController)
    }

    /// Quick share with default configuration
    func quickShare(
        quote: Quote,
        template: QuoteCardTemplate = .minimal
    ) async {
        let data = QuoteCardData(quote: quote)
        var config = QuoteCardConfiguration.default
        config.template = template

        // Extract palette if available
        if let coverData = quote.book?.coverImageData,
           let coverImage = UIImage(data: coverData) {
            let extractor = OKLABColorExtractor()
            if let palette = try? await extractor.extractPalette(from: coverImage, imageSource: "Quick Share") {
                let enhancedData = QuoteCardData(
                    text: data.text,
                    author: data.author,
                    bookTitle: data.bookTitle,
                    pageNumber: data.pageNumber,
                    bookCoverImage: coverImage,
                    bookPalette: palette
                )
                await shareQuoteCard(data: enhancedData, config: config)
                return
            }
        }

        await shareQuoteCard(data: data, config: config)
    }

    // MARK: - Helpers

    private func presentViewController(_ controller: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }

        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        // iPad popover fallback
        if let popover = controller.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        topController.present(controller, animated: true)
    }
}

// MARK: - View Extension for Easy Access
extension View {
    /// Present the quote card editor for a quote
    func quoteCardEditor(
        isPresented: Binding<Bool>,
        quote: Quote
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            QuoteCardEditorView(quoteData: QuoteCardData(quote: quote))
        }
    }

    /// Present the quote card editor with custom data
    func quoteCardEditor(
        isPresented: Binding<Bool>,
        text: String,
        author: String? = nil,
        bookTitle: String? = nil,
        pageNumber: Int? = nil,
        coverImage: UIImage? = nil
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            QuoteCardEditorView(
                quoteData: QuoteCardData(
                    text: text,
                    author: author,
                    bookTitle: bookTitle,
                    pageNumber: pageNumber,
                    bookCoverImage: coverImage
                )
            )
        }
    }
}

// MARK: - Quote Extension
extension Quote {
    /// Quick share this quote with a default template
    @MainActor
    func shareAsCard(template: QuoteCardTemplate = .minimal) async {
        await QuoteCardExportService.shared.quickShare(quote: self, template: template)
    }
}
