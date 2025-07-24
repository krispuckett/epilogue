import SwiftUI

// MARK: - Accent Color Debug View
// Visual preview of extracted accent colors for testing

struct AccentColorDebugView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedBooks: [(book: Book, image: UIImage?, accentColor: Color?)] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Text("Accent Color Extraction Test")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    Text("Testing SmartAccentColorExtractor on your library")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if isLoading {
                        ProgressView("Loading book covers...")
                            .padding(40)
                    } else if selectedBooks.isEmpty {
                        Text("No books loaded yet")
                            .foregroundColor(.white.opacity(0.5))
                            .padding(40)
                    } else {
                        // Book grid
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 160), spacing: 20)
                        ], spacing: 20) {
                            ForEach(selectedBooks, id: \.book.id) { item in
                                BookAccentPreview(
                                    book: item.book,
                                    coverImage: item.image,
                                    accentColor: item.accentColor
                                )
                            }
                        }
                        .padding()
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Load Books") {
                        loadRandomBooks()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadRandomBooks()
        }
    }
    
    private func loadRandomBooks() {
        isLoading = true
        selectedBooks = []
        
        // Get up to 12 random books
        let books = Array(libraryViewModel.books.shuffled().prefix(12))
        
        // Load each book's cover and extract accent color
        for book in books {
            loadBookCover(book)
        }
        
        // Set loading to false after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
        }
    }
    
    private func loadBookCover(_ book: Book) {
        guard var urlString = book.coverImageURL else { return }
        
        urlString = urlString.replacingOccurrences(of: "http://", with: "https://")
        if !urlString.contains("zoom=") {
            urlString += urlString.contains("?") ? "&zoom=2" : "?zoom=2"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                // Extract accent color
                let accentColor = SmartAccentColorExtractor.extractAccentColor(
                    from: image,
                    bookTitle: book.title
                )
                
                DispatchQueue.main.async {
                    selectedBooks.append((book: book, image: image, accentColor: accentColor))
                }
            }
        }.resume()
    }
}

// MARK: - Book Accent Preview Component
struct BookAccentPreview: View {
    let book: Book
    let coverImage: UIImage?
    let accentColor: Color?
    
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Book cover
            ZStack(alignment: .bottomTrailing) {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay {
                            ProgressView()
                        }
                }
                
                // Accent color swatch
                if let accent = accentColor {
                    Circle()
                        .fill(accent)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        }
                        .shadow(radius: 4)
                        .offset(x: -8, y: -8)
                }
            }
            
            // Book title
            Text(book.title)
                .font(.caption.bold())
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Accent color info
            if let accent = accentColor {
                Button {
                    showDetails.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(accent)
                            .frame(width: 12, height: 12)
                        Text(colorDescription(accent))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            // Simulated UI elements with accent color
            if showDetails, let accent = accentColor {
                VStack(spacing: 8) {
                    // Simulated button
                    Text("Want to Read")
                        .font(.caption)
                        .foregroundColor(accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .stroke(accent, lineWidth: 1)
                        )
                    
                    // Simulated icon buttons
                    HStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .foregroundColor(accent)
                            .font(.system(size: 20))
                        
                        Image(systemName: "quote.opening")
                            .foregroundColor(accent)
                            .font(.system(size: 20))
                        
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(accent)
                            .font(.system(size: 20))
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.3), value: showDetails)
    }
    
    private func colorDescription(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        let hue = Int(h * 360)
        
        // Get color name
        let colorName: String
        switch hue {
        case 0...10, 340...360: colorName = "Red"
        case 11...40: colorName = "Orange"
        case 41...70: colorName = "Yellow"
        case 71...160: colorName = "Green"
        case 161...250: colorName = "Blue"
        case 251...290: colorName = "Purple"
        case 291...339: colorName = "Pink"
        default: colorName = "Gray"
        }
        
        return colorName
    }
}

// MARK: - Preview
#Preview {
    AccentColorDebugView()
        .environmentObject(LibraryViewModel())
}