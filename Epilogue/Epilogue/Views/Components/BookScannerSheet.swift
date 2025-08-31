import SwiftUI
import VisionKit
import UIKit

struct BookScannerSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @StateObject private var scanner = BookScannerService.shared
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    let onCompletion: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && uiViewController.presentedViewController == nil {
            let scannerViewController = VNDocumentCameraViewController()
            scannerViewController.delegate = context.coordinator
            uiViewController.present(scannerViewController, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: BookScannerSheet
        
        init(_ parent: BookScannerSheet) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            controller.dismiss(animated: true) {
                Task {
                    await self.processScan(scan)
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.parent.isPresented = false
                self.parent.onCompletion()
            }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.parent.scanner.scanError = .processingFailed
                self.parent.isPresented = false
                self.parent.onCompletion()
            }
        }
        
        @MainActor
        private func processScan(_ scan: VNDocumentCameraScan) async {
            guard scan.pageCount > 0 else {
                parent.scanner.scanError = .noTextDetected
                parent.isPresented = false
                parent.onCompletion()
                return
            }
            
            // Get the scanned image
            let image = scan.imageOfPage(at: 0)
            
            // Process with BookScannerService
            let scanner = BookScannerService.shared
            scanner.isProcessing = true
            scanner.processingStatus = "Analyzing book cover..."
            
            // Extract information
            let extractedInfo = await scanner.processScannedImage(image)
            
            if extractedInfo.hasValidInfo {
                await scanner.searchWithExtractedInfo(extractedInfo)
                
                // Wait for results
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                
                if !scanner.detectedBooks.isEmpty {
                    parent.isPresented = false
                    parent.onCompletion()
                }
            } else {
                scanner.scanError = .noTextDetected
                parent.isPresented = false
                parent.onCompletion()
            }
        }
    }
}

// MARK: - Simplified Scanner Presentation View

struct BookScannerPresentationView: View {
    @StateObject private var scanner = BookScannerService.shared
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            BookScannerView()
                .environmentObject(libraryViewModel)
                .navigationBarHidden(true)
        }
        .presentationBackground(.clear)
        .presentationCornerRadius(0)
        .interactiveDismissDisabled()
    }
}

// MARK: - Wrapper for proper UIKit integration

struct BookScannerWrapper: View {
    let onCompletion: () -> Void
    @State private var isPresented = true
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
            
            BookScannerSheet(
                isPresented: $isPresented,
                onCompletion: onCompletion
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Search Results View

struct BookSearchResultsView: View {
    let books: [Book]
    let searchQuery: String
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan Results")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("\(books.count) book\(books.count == 1 ? "" : "s") found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    BookScannerService.shared.reset()
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium))
            }
            .padding()
            
            // Search results
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(books) { book in
                        BookSearchResultCard(book: book) {
                            libraryViewModel.addBook(book)
                            SensoryFeedback.success()
                            
                            // Show success and dismiss
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                BookScannerService.shared.reset()
                                dismiss()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Book Search Result Card

struct BookSearchResultCard: View {
    let book: Book
    let onAdd: () -> Void
    @State private var isAdded = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Book cover
            if let coverURL = book.coverImageURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            ProgressView()
                        }
                }
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            }
            
            // Book info
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let isbn = book.isbn {
                    Text("ISBN: \(isbn)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Add button
            Button {
                withAnimation(.spring()) {
                    isAdded = true
                    onAdd()
                }
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isAdded ? .green : DesignSystem.Colors.primaryAccent)
            }
            .disabled(isAdded)
        }
        .padding()
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
}