import SwiftUI
import UniformTypeIdentifiers

struct CleanGoodreadsImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @StateObject private var importer = GoodreadsCleanImporter()
    @State private var showingFilePicker = false
    @State private var importState: ImportState = .ready
    @State private var selectedTab: ResultTab = .imported
    
    enum ImportState {
        case ready
        case importing
        case complete
    }
    
    enum ResultTab: String, CaseIterable {
        case imported = "Imported"
        case failed = "Failed"
        
        var icon: String {
            switch self {
            case .imported: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient gradient background (matching BookSearchSheet)
                AmbientChatGradientView()
                    .opacity(0.6)
                    .ignoresSafeArea()
                
                // Subtle darkening for readability
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                
                // Main content
                Group {
                    switch importState {
                    case .ready:
                        startView
                    case .importing:
                        importingView
                    case .complete:
                        resultsView
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .navigationTitle("Import from Goodreads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }
    
    // MARK: - Start View
    private var startView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 40)
            
            // Simplified header
            VStack(spacing: 24) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.warmAmber,
                                Color.warmAmber.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
                
                VStack(spacing: 12) {
                    Text("Import Your Library")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    
                    Text("Bring your reading history to life")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
                .frame(height: 60)
            
            // Import button with enhanced design
            Button {
                showingFilePicker = true
                SensoryFeedback.light()
            } label: {
                ZStack {
                    // Liquid glass button
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.clear)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 30))
                        .overlay {
                            RoundedRectangle(cornerRadius: 30)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            DesignSystem.Colors.primaryAccent.opacity(0.6),
                                            .white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    
                    HStack(spacing: 14) {
                        Image(systemName: "doc.badge.arrow.up.fill")
                            .font(.system(size: 22))
                        Text("Select Goodreads Export")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
                .frame(height: 60)
                .frame(maxWidth: 300)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
                .frame(height: 50)
            
            // Instructions with refined design
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.warmAmber)
                    
                    Text("EXPORT INSTRUCTIONS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.warmAmber)
                        .tracking(1.5)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    instructionRow(number: "1", text: "Visit your Goodreads library", icon: "book.circle")
                    instructionRow(number: "2", text: "Find 'Import and export'", icon: "square.and.arrow.up.circle")
                    instructionRow(number: "3", text: "Click 'Export library'", icon: "arrow.down.circle")
                    instructionRow(number: "4", text: "Select the CSV file here", icon: "doc.circle")
                }
            }
            .padding(24)
            .glassEffect(in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }
            .padding(.horizontal, 24)
            
            Spacer()
                .frame(height: 40)
            
            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                Text("Your data never leaves your device")
                    .font(.system(size: 14))
            }
            .foregroundStyle(.white.opacity(0.5))
            
            Spacer()
                .frame(height: 40)
            }
        }
    }
    
    // MARK: - Helper Views
    private func instructionRow(number: String, text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.warmAmber.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.warmAmber)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
    
    // MARK: - Importing View
    private var importingView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Animated progress visualization
            ZStack {
                // Background glow
                Circle()
                    .fill(Color.warmAmber.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .scaleEffect(1.2)
                
                // Progress indicator
                CircularProgressView(
                    progress: Double(importer.progress?.current ?? 0) / Double(importer.progress?.total ?? 1),
                    accentColor: DesignSystem.Colors.primaryAccent,
                    isIndeterminate: false
                )
                .frame(width: 140, height: 140)
            }
            
            Spacer()
                .frame(height: 48)
            
            // Current book info with refined typography
            VStack(spacing: 20) {
                Text("Finding Your Books")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                
                if let progress = importer.progress {
                    HStack(spacing: 8) {
                        Text("\(progress.current)")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.warmAmber)
                        
                        Text("of")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Text("\(progress.total)")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.warmAmber)
                    }
                    
                    // Current book title with animation
                    Text(progress.currentBookTitle)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity.combined(with: .scale))
                        .id(progress.currentBookTitle) // Force re-render on change
                }
            }
            
            Spacer()
                .frame(height: 60)
            
            // Live preview with enhanced design
            if !importer.importedBooks.isEmpty {
                VStack(spacing: 20) {
                    Text("RECENTLY IMPORTED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.5)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(importer.importedBooks.suffix(6)) { book in
                                VStack(spacing: 0) {
                                    ImportBookCoverView(
                                        coverURL: book.coverImageURL,
                                        width: 70,
                                        height: 105
                                    )
                                    .onAppear {
                                        #if DEBUG
                                        print("📚 Import preview - Book: \(book.title)")
                                        #endif
                                        #if DEBUG
                                        print("   Cover URL: \(book.coverImageURL ?? "nil")")
                                        #endif
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                                    
                                    if let rating = book.userRating, rating > 0 {
                                        HStack(spacing: 2) {
                                            ForEach(Array(1...5), id: \.self) { star in
                                                starIcon(for: star, rating: rating)
                                            }
                                        }
                                        .padding(.top, 8)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .identity
                                ))
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(height: 140)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 24) {
            // Success header
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                
                Text("Import Complete!")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                
                HStack(spacing: 32) {
                    VStack {
                        Text("\(importer.importedBooks.count)")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.warmAmber)
                        Text("Imported")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    if !importer.failedBooks.isEmpty {
                        VStack {
                            Text("\(importer.failedBooks.count)")
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                            Text("Failed")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding(.top, 32)
            
            // Tab picker
            if !importer.failedBooks.isEmpty {
                Picker("View", selection: $selectedTab) {
                    ForEach(ResultTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            
            // Results list
            ScrollView {
                LazyVStack(spacing: 8) {
                    switch selectedTab {
                    case .imported:
                        ForEach(importer.importedBooks) { book in
                            importedBookRow(book)
                        }
                    case .failed:
                        ForEach(importer.failedBooks, id: \.0.title) { (csvBook, reason) in
                            failedBookRow(csvBook: csvBook, reason: reason)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Row Views
    private func importedBookRow(_ book: Book) -> some View {
        HStack(spacing: 12) {
            ImportBookCoverView(
                coverURL: book.coverImageURL,
                width: 50,
                height: 75
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    if let rating = book.userRating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                            Text("\(rating)")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .foregroundStyle(.yellow)
                    }
                    
                    Text(book.readingStatus.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(book.readingStatus.color)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
        }
        .padding(12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func failedBookRow(csvBook: GoodreadsCleanImporter.CSVBook, reason: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 75)
                .overlay {
                    Image(systemName: "book.closed")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.5))
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(csvBook.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(csvBook.author)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                
                Text(reason)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            
            Spacer()
            
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.red)
        }
        .padding(12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - File Handling
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            withAnimation {
                importState = .importing
            }
            
            Task {
                await importer.importCSV(from: url, libraryViewModel: libraryViewModel)
                
                await MainActor.run {
                    withAnimation {
                        importState = .complete
                    }
                }
            }
            
        case .failure(let error):
            #if DEBUG
            print("❌ File selection error: \(error)")
            #endif
        }
    }

    // MARK: - Rating Helper

    /// Returns the appropriate star icon for displaying half-star ratings
    private func starIcon(for star: Int, rating: Double) -> some View {
        let starValue = Double(star)
        let icon: String

        if rating >= starValue {
            icon = "star.fill"
        } else if rating >= starValue - 0.5 {
            icon = "star.leadinghalf.filled"
        } else {
            icon = "star"
        }

        return Image(systemName: icon)
            .font(.system(size: 8))
            .foregroundStyle(rating >= starValue - 0.5 ? .yellow : .gray.opacity(0.3))
    }
}

// MARK: - Import Book Cover View
// Direct image loading that also caches for SharedBookCoverManager
struct ImportBookCoverView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    
    @State private var coverImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "book.closed")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
            }
        }
        .task {
            await loadCover()
        }
    }
    
    private func loadCover() async {
        guard let urlString = coverURL,
              let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.coverImage = image
                        self.isLoading = false
                    }
                }
                #if DEBUG
                print("✅ Loaded import preview cover from: \(urlString)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to load import preview cover: \(error)")
            #endif
            await MainActor.run {
                isLoading = false
            }
        }
    }

}