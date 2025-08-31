import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Goodreads CSV import interface
struct GoodreadsImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var googleBooksService: GoogleBooksService
    
    let libraryViewModel: LibraryViewModel?  // Pass this from ContentView
    @StateObject private var importService: GoodreadsImportService
    @State private var importState: ImportState = .start
    @State private var showingFilePicker = false
    @State private var importResult: GoodreadsImportService.ImportResult?
    @State private var selectedSpeed: GoodreadsImportService.ImportSpeed = .balanced
    @State private var searchText = ""
    @State private var selectedTab: ResultsTab = .imported
    @State private var showingManualMatch = false
    @State private var unmatchedBookToMatch: GoodreadsImportService.UnmatchedBook?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    @State private var overwriteDuplicates = false
    
    init(modelContext: ModelContext, googleBooksService: GoogleBooksService, libraryViewModel: LibraryViewModel? = nil) {
        self.libraryViewModel = libraryViewModel
        _importService = StateObject(wrappedValue: GoodreadsImportService(
            googleBooksService: googleBooksService,
            modelContext: modelContext
        ))
    }
    
    enum ImportState {
        case start
        case progress
        case results
    }
    
    enum ResultsTab: String, CaseIterable {
        case imported = "Imported"
        case needReview = "Need Review"
        case duplicates = "Duplicates"
        
        var icon: String {
            switch self {
            case .imported: return "checkmark.circle.fill"
            case .needReview: return "questionmark.circle.fill"
            case .duplicates: return "doc.on.doc.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Settings-style background
                Color(red: 0.11, green: 0.11, blue: 0.118)
                    .ignoresSafeArea()
                
                // Main content based on state
                Group {
                    switch importState {
                    case .start:
                        startView
                    case .progress:
                        progressView
                    case .results:
                        resultsView
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .navigationTitle("Import from Goodreads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if importState != .results {
                        Button("Cancel") {
                            if importState == .progress && importService.isImporting {
                                // Show confirmation dialog
                            } else {
                                dismiss()
                            }
                        }
                        .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if importState == .results {
                        Button("Done") {
                            // Post notification to refresh library
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshLibrary"), object: nil)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showingManualMatch) {
            if let book = unmatchedBookToMatch {
                ManualMatchView(
                    unmatchedBook: book,
                    googleBooksService: googleBooksService,
                    modelContext: modelContext
                )
            }
        }
        .alert("Import Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
        .overlay(alignment: .top) {
            if showingSuccessToast {
                successToastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1000)
            }
        }
    }
    
    // MARK: - Success Toast
    
    private var successToastView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Import Successful")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(successMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 60) // Account for navigation bar
        .onAppear {
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(DesignSystem.Animation.easeStandard) {
                    showingSuccessToast = false
                }
            }
        }
    }
    
    // MARK: - Start View
    
    private var startView: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Icon and title - more refined
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.45, blue: 0.16).opacity(0.2),
                                        Color(red: 1.0, green: 0.45, blue: 0.16).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)
                        
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.45, blue: 0.16),
                                        Color(red: 0.95, green: 0.35, blue: 0.25)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Text("Import Your Library")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Transfer your Goodreads collection")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.top, 24)
                
                // Streamlined instructions
                VStack(spacing: 16) {
                    HStack {
                        Text("EXPORT STEPS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.5)
                        Spacer()
                    }
                    
                    VStack(spacing: 0) {
                        InstructionStep(number: 1, text: "Visit goodreads.com", isFirst: true)
                        InstructionStep(number: 2, text: "Go to My Books")
                        InstructionStep(number: 3, text: "Find Import/Export")
                        InstructionStep(number: 4, text: "Export Library")
                        InstructionStep(number: 5, text: "Download CSV", isLast: true)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                
                // What's included - more compact
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("INCLUDED DATA")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.5)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ImportFeature(icon: "book.fill", text: "Books", color: .blue)
                        ImportFeature(icon: "star.fill", text: "Ratings", color: .yellow)
                        ImportFeature(icon: "note.text", text: "Notes", color: .purple)
                        ImportFeature(icon: "bookmark.fill", text: "Status", color: .green)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                
                // Import button
                Button {
                    showingFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.arrow.up.fill")
                            .font(.title3)
                        Text("Choose CSV File")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
                }
                .padding(.horizontal)
                
                // Duplicate handling toggle
                VStack(spacing: 12) {
                    Toggle(isOn: $overwriteDuplicates) {
                        HStack(spacing: 8) {
                            Image(systemName: overwriteDuplicates ? "arrow.triangle.2.circlepath" : "books.vertical")
                                .foregroundColor(overwriteDuplicates ? .orange : DesignSystem.Colors.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(overwriteDuplicates ? "Update Existing Books" : "Skip Duplicates")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(overwriteDuplicates ? "Overwrite book data with CSV values" : "Keep existing books unchanged")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .glassEffect(in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // Note about processing
                Text("Large libraries may take a few minutes to import")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)
            }
        }
    }
    
    // MARK: - Progress View
    
    private var progressView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: importService.currentProgress?.percentComplete ?? 0)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: importService.currentProgress?.percentComplete)
                
                VStack(spacing: 8) {
                    Text("\(Int((importService.currentProgress?.percentComplete ?? 0) * 100))%")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let progress = importService.currentProgress {
                        Text("\(progress.current) of \(progress.total)")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            
            // Current book
            if let currentBook = importService.currentProgress?.currentBook {
                VStack(spacing: 8) {
                    Text("Processing")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    
                    Text(currentBook)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                .padding(.vertical, 16)
                .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
            }
            
            // Stats grid
            if let progress = importService.currentProgress {
                HStack(spacing: 16) {
                    ImportStatCard(
                        title: "Time Remaining",
                        value: formatTimeRemaining(progress.timeRemaining),
                        icon: "clock.fill"
                    )
                    
                    ImportStatCard(
                        title: "Books/min",
                        value: calculateBooksPerMinute(),
                        icon: "speedometer"
                    )
                    
                    ImportStatCard(
                        title: "Batch",
                        value: "\(progress.batchNumber)/\(progress.totalBatches)",
                        icon: "square.stack.3d.up.fill"
                    )
                }
                .padding(.horizontal)
            }
            
            // Speed selector for large imports
            if let total = importService.currentProgress?.total, total >= 100 {
                VStack(spacing: 16) {
                    // Speed picker
                    VStack(spacing: 8) {
                        Text("Import Speed")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        
                        Picker("Speed", selection: $selectedSpeed) {
                            ForEach(GoodreadsImportService.ImportSpeed.allCases, id: \.self) { speed in
                                Text(speed.rawValue).tag(speed)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    }
                    
                    // Duplicate toggle
                    Toggle(isOn: $overwriteDuplicates) {
                        HStack(spacing: 8) {
                            Image(systemName: overwriteDuplicates ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(overwriteDuplicates ? .orange : .yellow)
                            Text(overwriteDuplicates ? "Update existing books" : "Skip duplicate books")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .frame(maxWidth: 300)
                }
            }
            
            // Control buttons for medium/large imports
            if let total = importService.currentProgress?.total, total >= 50 {
                HStack(spacing: 16) {
                    Button {
                        if importService.isPaused {
                            importService.resume()
                        } else {
                            importService.pause()
                        }
                    } label: {
                        HStack {
                            Image(systemName: importService.isPaused ? "play.fill" : "pause.fill")
                            Text(importService.isPaused ? "Resume" : "Pause")
                        }
                        .foregroundColor(.white)
                        .frame(width: 120, height: 44)
                        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
                    }
                    
                    Button {
                        importService.cancel()
                        importState = .start
                    } label: {
                        Text("Cancel")
                            .foregroundColor(.red)
                            .frame(width: 120, height: 44)
                            .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
                    }
                }
            }
            
            // Background processing note
            Text("You can close this screen - import continues in background")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Success summary
            if let result = importResult {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("Import Complete!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Stats grid
                    HStack(spacing: 12) {
                        ResultStatCard(
                            value: "\(result.successful.count)",
                            label: "Imported",
                            color: .green
                        )
                        
                        if result.needsMatching.count > 0 {
                            ResultStatCard(
                                value: "\(result.needsMatching.count)",
                                label: "Need Review",
                                color: .orange
                            )
                        }
                        
                        if result.duplicates.count > 0 {
                            ResultStatCard(
                                value: "\(result.duplicates.count)",
                                label: "Duplicates",
                                color: .blue
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
                
                // Tab selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ResultsTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(DesignSystem.Animation.easeQuick) {
                                    selectedTab = tab
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.caption)
                                    Text(tab.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                                }
                                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                                .padding(.vertical, 8)
                                .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.large))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                        .stroke(
                                            selectedTab == tab ? Color.orange.opacity(0.3) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 16)
                
                // Search bar for larger result sets
                if totalResultsCount > 20 {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        
                        TextField("Search books...", text: $searchText)
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                
                // Results list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        switch selectedTab {
                        case .imported:
                            ForEach(Array(filteredImportedBooks.enumerated()), id: \.offset) { _, book in
                                ImportedBookRow(book: book)
                            }
                        case .needReview:
                            ForEach(Array(filteredUnmatchedBooks.enumerated()), id: \.offset) { _, book in
                                UnmatchedBookRow(book: book) {
                                    unmatchedBookToMatch = book
                                    showingManualMatch = true
                                }
                            }
                        case .duplicates:
                            ForEach(Array(filteredDuplicateBooks.enumerated()), id: \.offset) { _, book in
                                DuplicateBookRow(book: book)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { 
                print("❌ No URL received from file picker")
                return 
            }
            print("✅ File selected: \(url.lastPathComponent)")
            print("📍 File path: \(url.path)")
            startImport(from: url)
        case .failure(let error):
            print("❌ File selection error: \(error)")
        }
    }
    
    private func startImport(from url: URL) {
        print("🚀 Starting import process...")
        print("📊 Import state before: \(importState)")
        print("📍 URL: \(url)")
        print("📍 URL exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        Task {
            do {
                print("📂 Accessing file at: \(url.path)")
                
                // Try to access the file with security scoping
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                print("🔐 Security scoped access: \(accessing)")
                
                // Update UI on main thread
                await MainActor.run {
                    withAnimation {
                        self.importState = .progress
                    }
                }
                
                print("📊 Import state after transition: \(importState)")
                print("🎯 Calling importService.importCSV...")
                
                let result = try await importService.importCSV(from: url, speed: selectedSpeed)
                
                print("✅ Import completed with \(result.successful.count) books")
                
                await MainActor.run {
                    self.importResult = result
                    withAnimation {
                        self.importState = .results
                    }
                    
                    // Show success toast AND actually add books to the library
                    if result.successful.count > 0 {
                        print("📚 Adding \(result.successful.count) books to library")
                        
                        // Add each successfully imported book to the LibraryViewModel
                        for (index, processedBook) in result.successful.enumerated() {
                            var book = Book(
                                id: processedBook.bookModel.id,
                                title: processedBook.bookModel.title,
                                author: processedBook.bookModel.author,
                                publishedYear: processedBook.bookModel.publishedYear,
                                coverImageURL: processedBook.bookModel.coverImageURL,
                                isbn: processedBook.bookModel.isbn,
                                description: processedBook.bookModel.desc,
                                pageCount: processedBook.bookModel.pageCount,
                                localId: UUID(uuidString: processedBook.bookModel.localId) ?? UUID()
                            )
                            
                            // Set additional properties from the imported book
                            book.isInLibrary = true
                            book.userRating = processedBook.bookModel.userRating
                            book.userNotes = processedBook.bookModel.userNotes
                            book.dateAdded = processedBook.bookModel.dateAdded
                            
                            // Set reading status
                            if let status = ReadingStatus(rawValue: processedBook.bookModel.readingStatus) {
                                book.readingStatus = status
                            }
                            
                            print("    📚 Import data for \(book.title):")
                            print("       Rating: \(book.userRating ?? 0) stars")
                            print("       Status: \(book.readingStatus.rawValue)")
                            print("       Notes: \(book.userNotes?.prefix(50) ?? "None")")
                            print("       Added: \(book.dateAdded)")
                            
                            // Add to library through the view model
                            if let libraryVM = self.libraryViewModel {
                                libraryVM.addBook(book, overwriteIfExists: self.overwriteDuplicates)
                                print("  ✅ \(self.overwriteDuplicates ? "Updated" : "Added") book \(index + 1)/\(result.successful.count): \(book.title)")
                            } else {
                                print("  ❌ LibraryViewModel is nil! Cannot add book: \(book.title)")
                            }
                        }
                        
                        // Verify the books were added
                        if let libraryVM = self.libraryViewModel {
                            print("📊 Library now contains \(libraryVM.books.count) total books")
                        }
                        
                        self.successMessage = "\(result.successful.count) books successfully added to your library"
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            self.showingSuccessToast = true
                        }
                    }
                }
            } catch {
                print("❌ Import error: \(error)")
                print("📍 Error type: \(type(of: error))")
                print("📍 Error details: \(error.localizedDescription)")
                
                let errorDescription: String
                if let urlError = error as? URLError {
                    errorDescription = "Unable to access file: \(urlError.localizedDescription)"
                } else if let cocoaError = error as? CocoaError {
                    errorDescription = "File error: \(cocoaError.localizedDescription)"
                } else {
                    errorDescription = error.localizedDescription
                }
                
                await MainActor.run {
                    self.errorMessage = errorDescription
                    self.showingError = true
                    withAnimation {
                        self.importState = .start
                    }
                }
            }
        }
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval?) -> String {
        guard let seconds = seconds else { return "Calculating..." }
        
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            return "\(remainingSeconds)s"
        }
    }
    
    private func calculateBooksPerMinute() -> String {
        guard let progress = importService.currentProgress,
              progress.current > 0 else { return "0" }
        
        // This is a simplified calculation
        // In production, you'd track actual time elapsed
        return "\(progress.current / max(1, progress.current / 60))"
    }
    
    private var totalResultsCount: Int {
        guard let result = importResult else { return 0 }
        return result.successful.count + result.needsMatching.count + result.duplicates.count
    }
    
    private var filteredImportedBooks: [GoodreadsImportService.ProcessedBook] {
        guard let result = importResult else { return [] }
        
        if searchText.isEmpty {
            return result.successful
        }
        
        return result.successful.filter { book in
            book.goodreadsBook.title.localizedCaseInsensitiveContains(searchText) ||
            book.goodreadsBook.author.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredUnmatchedBooks: [GoodreadsImportService.UnmatchedBook] {
        guard let result = importResult else { return [] }
        
        if searchText.isEmpty {
            return result.needsMatching
        }
        
        return result.needsMatching.filter { book in
            book.goodreadsBook.title.localizedCaseInsensitiveContains(searchText) ||
            book.goodreadsBook.author.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredDuplicateBooks: [GoodreadsImportService.DuplicateBook] {
        guard let result = importResult else { return [] }
        
        if searchText.isEmpty {
            return result.duplicates
        }
        
        return result.duplicates.filter { book in
            book.goodreadsBook.title.localizedCaseInsensitiveContains(searchText) ||
            book.goodreadsBook.author.localizedCaseInsensitiveContains(searchText)
        }
    }
    
}

// MARK: - Supporting Views

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct ImportFeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
}

struct ImportStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct ResultStatCard: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.card))
    }
}

struct ImportedBookRow: View {
    let book: GoodreadsImportService.ProcessedBook
    @State private var coverImage: UIImage?
    @State private var showingCoverPicker = false
    @State private var selectedCoverURL: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover with actual image
            ZStack {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 60)
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textQuaternary)
                        )
                }
            }
            .onTapGesture {
                showingCoverPicker = true
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.goodreadsBook.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(book.goodreadsBook.author)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                if let rating = Int(book.goodreadsBook.myRating), rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                    }
                }
            }
            
            Spacer()
            
            // Edit cover button
            Button {
                showingCoverPicker = true
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green.opacity(0.8))
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
        .task {
            await loadCover()
        }
        .sheet(isPresented: $showingCoverPicker) {
            CoverSelectionView(
                bookTitle: book.goodreadsBook.title,
                bookAuthor: book.goodreadsBook.author,
                currentCoverURL: selectedCoverURL ?? book.bookModel.coverImageURL,
                onCoverSelected: { newCoverURL in
                    selectedCoverURL = newCoverURL
                    book.bookModel.coverImageURL = newCoverURL
                    Task {
                        await loadCover()
                    }
                }
            )
            .presentationDetents([.fraction(0.8)])
        }
    }
    
    private func loadCover() async {
        guard let urlString = selectedCoverURL ?? book.bookModel.coverImageURL,
              let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.coverImage = image
                }
            }
        } catch {
            print("Failed to load cover: \(error)")
        }
    }
}

struct UnmatchedBookRow: View {
    let book: GoodreadsImportService.UnmatchedBook
    let onMatch: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(width: 40, height: 60)
                .overlay(
                    Image(systemName: "questionmark")
                        .font(.caption)
                        .foregroundColor(.orange.opacity(0.5))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.goodreadsBook.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(book.goodreadsBook.author)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                Text(book.reason)
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.6))
            }
            
            Spacer()
            
            Button {
                onMatch()
            } label: {
                Text("Match")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.small))
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct DuplicateBookRow: View {
    let book: GoodreadsImportService.DuplicateBook
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(width: 40, height: 60)
                .overlay(
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue.opacity(0.5))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.goodreadsBook.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(book.goodreadsBook.author)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                Text("Already in library")
                    .font(.caption2)
                    .foregroundColor(.blue.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "info.circle")
                .foregroundColor(.blue.opacity(0.8))
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct ManualMatchView: View {
    let unmatchedBook: GoodreadsImportService.UnmatchedBook
    let googleBooksService: GoogleBooksService
    let modelContext: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var searchResults: [Book] = []
    @State private var isSearching = false
    @State private var selectedBookId: String?
    @State private var showingConfirmation = false
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with glass effect
                headerView
                
                // Unmatched book info card
                unmatchedBookCard
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Search section
                searchBar
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                
                // Results or loading
                if isSearching {
                    Spacer()
                    loadingView
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    searchResultsList
                }
            }
        }
        .onAppear {
            initializeSearch()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Manual Match")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Select the correct edition")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            
            Spacer()
            
            // Skip button
            Button {
                dismiss()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.vertical, 8)
                    .glassEffect()
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            }
        }
        .padding()
    }
    
    // MARK: - Unmatched Book Card
    
    private var unmatchedBookCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Book icon placeholder
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(LinearGradient(
                        colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 75)
                    .overlay(
                        Image(systemName: "book.fill")
                            .font(.title2)
                            .foregroundColor(.orange.opacity(0.6))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(unmatchedBook.goodreadsBook.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(unmatchedBook.goodreadsBook.author)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                    
                    if let isbn = unmatchedBook.goodreadsBook.primaryISBN {
                        Text("ISBN: \(isbn)")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                
                Spacer()
            }
            
            // Additional metadata
            HStack(spacing: 16) {
                if !unmatchedBook.goodreadsBook.myRating.isEmpty,
                   let rating = Int(unmatchedBook.goodreadsBook.myRating), rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("\(rating)/5")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                if !unmatchedBook.goodreadsBook.dateRead.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Read")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                if !unmatchedBook.goodreadsBook.exclusiveShelf.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(unmatchedBook.goodreadsBook.exclusiveShelf.capitalized)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            TextField("Search for this book...", text: $searchQuery)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.textQuaternary)
                }
            }
            
            Button {
                performSearch()
            } label: {
                Text("Search")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.small))
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("Searching books...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textQuaternary)
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
    }
    
    // MARK: - Search Results List
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchResults) { book in
                    BookMatchRow(
                        book: book,
                        isSelected: selectedBookId == book.id,
                        onSelect: {
                            withAnimation(DesignSystem.Animation.easeQuick) {
                                if selectedBookId == book.id {
                                    matchBook(book)
                                } else {
                                    selectedBookId = book.id
                                }
                            }
                        }
                    )
                }
                
                // Bottom padding
                Color.clear
                    .frame(height: 40)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeSearch() {
        // Build intelligent search query
        var query = unmatchedBook.goodreadsBook.title
        
        // Remove common suffixes that might confuse search
        let suffixesToRemove = [
            " (Kindle Edition)",
            " (Hardcover)",
            " (Paperback)",
            " (Mass Market Paperback)",
            " (ebook)"
        ]
        
        for suffix in suffixesToRemove {
            query = query.replacingOccurrences(of: suffix, with: "")
        }
        
        // Add author for better results
        if !unmatchedBook.goodreadsBook.author.isEmpty {
            query += " \(unmatchedBook.goodreadsBook.author)"
        }
        
        searchQuery = query
        performSearch()
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSearching = true
        Task {
            await googleBooksService.searchBooks(query: searchQuery)
            await MainActor.run {
                searchResults = googleBooksService.searchResults
                isSearching = false
                selectedBookId = nil
            }
        }
    }
    
    private func matchBook(_ book: Book) {
        // Create BookModel from selected book
        let bookModel = BookModel(from: book)
        
        // Apply Goodreads metadata
        if let rating = Int(unmatchedBook.goodreadsBook.myRating), rating > 0 {
            bookModel.userRating = rating
        }
        
        if !unmatchedBook.goodreadsBook.privateNotes.isEmpty {
            bookModel.userNotes = unmatchedBook.goodreadsBook.privateNotes
        }
        
        // Set reading status
        if !unmatchedBook.goodreadsBook.dateRead.isEmpty {
            bookModel.readingStatus = ReadingStatus.read.rawValue
        } else if unmatchedBook.goodreadsBook.exclusiveShelf == "currently-reading" {
            bookModel.readingStatus = ReadingStatus.currentlyReading.rawValue
        } else if unmatchedBook.goodreadsBook.exclusiveShelf == "to-read" {
            bookModel.readingStatus = ReadingStatus.wantToRead.rawValue
        }
        
        // Add to library
        bookModel.isInLibrary = true
        bookModel.dateAdded = Date()
        
        // Save to database
        modelContext.insert(bookModel)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save matched book: \(error)")
        }
    }
}

// MARK: - Book Match Row Component

struct BookMatchRow: View {
    let book: Book
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // Cover with async loading
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 60, height: 90)
                    
                    AsyncImage(url: URL(string: book.coverImageURL ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                        case .failure(_):
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.2))
                        case .empty:
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.textQuaternary))
                                .scaleEffect(0.6)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                )
                
                // Book details
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text(book.author)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        if let year = book.publishedYear {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                                Text(year)
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                        
                        if let pageCount = book.pageCount, pageCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                                Text("\(pageCount) pages")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                        
                        if book.isbn != nil {
                            Image(systemName: "barcode")
                                .font(.caption)
                                .foregroundColor(.green.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.orange : Color.white.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(isSelected ? Color.orange.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(DesignSystem.Animation.easeQuick, value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BookSearchRow: View {
    let book: Book
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // Cover placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 50, height: 75)
                    .overlay(
                        AsyncImage(url: URL(string: book.coverImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textQuaternary)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text(book.author)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    if let year = book.publishedYear {
                        Text(year)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textQuaternary)
            }
            .padding(12)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

#Preview {
    GoodreadsImportView(
        modelContext: ModelContext(try! ModelContainer(for: BookModel.self)),
        googleBooksService: GoogleBooksService(),
        libraryViewModel: LibraryViewModel()
    )
}
// MARK: - New Helper Views for Redesigned UI

struct InstructionStep: View {
    let number: Int
    let text: String
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.45, blue: 0.16).opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Text("\(number)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.16))
                }
                
                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                if !isLast {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.vertical, isFirst || isLast ? 0 : 8)
            
            if !isLast {
                Divider()
                    .background(.white.opacity(0.1))
            }
        }
    }
}

struct ImportFeature: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}
