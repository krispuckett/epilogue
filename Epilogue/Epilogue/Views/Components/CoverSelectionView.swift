import SwiftUI

struct CoverSelectionView: View {
    let bookTitle: String
    let bookAuthor: String
    let currentCoverURL: String?
    let onCoverSelected: (String?) -> Void
    
    @StateObject private var googleBooksService = GoogleBooksService()
    @State private var availableCovers: [String] = []
    @State private var selectedCoverURL: String?
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DesignSystem.Colors.surfaceBackground
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Finding covers...")
                        .foregroundColor(.white)
                } else if availableCovers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.textQuaternary)
                        Text("No alternative covers found")
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 120, maximum: 150))
                        ], spacing: 16) {
                            ForEach(availableCovers, id: \.self) { coverURL in
                                CoverOption(
                                    coverURL: coverURL,
                                    isSelected: coverURL == selectedCoverURL,
                                    onTap: {
                                        selectedCoverURL = coverURL
                                        SensoryFeedback.light()
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onCoverSelected(selectedCoverURL)
                        dismiss()
                    }
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                    .disabled(selectedCoverURL == nil)
                }
            }
        }
        .onAppear {
            selectedCoverURL = currentCoverURL
            loadAlternativeCovers()
        }
    }
    
    private func loadAlternativeCovers() {
        isLoading = true
        
        Task {
            var allCovers: [String] = []
            
            // Try multiple search strategies to get more cover options
            // 1. Search with full title and author
            let fullSearchTerm = "\(bookTitle) \(bookAuthor)"
            await googleBooksService.searchBooks(query: fullSearchTerm)
            allCovers.append(contentsOf: googleBooksService.searchResults.compactMap { $0.coverImageURL })
            
            // 2. Search with just the title (might get different editions)
            await googleBooksService.searchBooks(query: bookTitle)
            allCovers.append(contentsOf: googleBooksService.searchResults.compactMap { $0.coverImageURL })
            
            // 3. If author has multiple names, try last name only
            let authorParts = bookAuthor.split(separator: " ")
            if authorParts.count > 1, let lastName = authorParts.last {
                let lastNameSearch = "\(bookTitle) \(lastName)"
                await googleBooksService.searchBooks(query: lastNameSearch)
                allCovers.append(contentsOf: googleBooksService.searchResults.compactMap { $0.coverImageURL })
            }
            
            // Remove duplicates and empty URLs
            let uniqueCovers = allCovers
                .filter { !$0.isEmpty }
                .removingDuplicates()
            
            await MainActor.run {
                self.availableCovers = uniqueCovers
                if !uniqueCovers.isEmpty && selectedCoverURL == nil {
                    selectedCoverURL = uniqueCovers.first
                }
                isLoading = false
                
                print("📚 Found \(uniqueCovers.count) unique covers for \(bookTitle)")
            }
        }
    }
}

struct CoverOption: View {
    let coverURL: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var coverImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(Color.white.opacity(0.1))
                        .aspectRatio(0.66, contentMode: .fit)
                        .overlay {
                            ProgressView()
                                .tint(DesignSystem.Colors.textTertiary)
                        }
                }
                
                if isSelected, coverImage != nil {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .stroke(Color.orange, lineWidth: 3)
                    
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: -8, y: -8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
        }
        .task { await loadCover() }
    }
    
    private func loadCover() async {
        // Use shared manager for consistent caching and URL handling
        let image = await SharedBookCoverManager.shared.loadThumbnail(from: coverURL, targetSize: CGSize(width: 200, height: 300))
        await MainActor.run { self.coverImage = image }
    }
}

// Helper extension for removing duplicates
extension Sequence where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
