import SwiftUI
import UIKit
import Combine



struct LibraryView: View {
    @EnvironmentObject var viewModel: LibraryViewModel
    @StateObject private var appState = AppStateManager.shared
    // Removed searchText - no longer needed
    @AppStorage("libraryViewMode") private var viewMode: ViewMode = .grid
    @Namespace private var viewModeAnimation
    @Namespace private var listTransition
    @State private var showingCoverPicker = false
    @State private var selectedBookForEdit: Book?
    @State private var highlightedBookId: UUID? = nil
    @State private var scrollToBookId: UUID? = nil
    @State private var navigateToBookDetail: Bool = false
    @State private var selectedBookForNavigation: Book? = nil
    @State private var isScrolling = false
    @State private var settingsButtonPressed = false
    @State private var visibleBookIDs: Set<UUID> = []
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @Environment(\.modelContext) private var modelContext
    @StateObject private var googleBooksService = GoogleBooksService()
    @State private var isRefreshing = false
    @Namespace private var settingsTransition
    
    #if DEBUG
    @State private var frameDrops = 0
    @State private var performanceTimer: Timer?
    #endif
    
    enum ViewMode: String {
        case grid, list
    }
    
    // Return all books since we removed search
    private var filteredBooks: [Book] {
        return viewModel.books
    }
    
    // Helper function to change book cover
    private func changeCover(for book: Book) {
        selectedBookForEdit = book
        showingCoverPicker = true
    }
    
    // Refresh library data
    private func refreshLibrary() async {
        SensoryFeedback.light()
        
        // Simulate network delay for smooth UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            // Trigger refresh - loadBooks is private
            NotificationCenter.default.post(name: NSNotification.Name("RefreshLibrary"), object: nil)
            SensoryFeedback.light()
        }
    }
    
    private func preloadNeighboringCovers(for book: Book) {
        guard let index = viewModel.books.firstIndex(where: { $0.id == book.id }) else { return }
        
        // Preload based on view mode
        let preloadCount = viewMode == .grid ? 4 : 2 // More for grid view
        let preloadRange = max(0, index - preloadCount)..<min(viewModel.books.count, index + preloadCount + 1)
        
        Task(priority: .background) {
            await performanceMonitor.measureAsync("preloadCovers") {
                for i in preloadRange where i != index {
                    let neighborBook = viewModel.books[i]
                    if let coverURL = neighborBook.coverImageURL {
                        // Use library thumbnail size for faster loading
                        _ = await SharedBookCoverManager.shared.loadLibraryThumbnail(from: coverURL)
                    }
                }
            }
        }
    }
    
    private func preloadAllBookCovers() async {
        // Collect all cover URLs
        let coverURLs = viewModel.books.compactMap { $0.coverImageURL }
        
        guard !coverURLs.isEmpty else { return }
        
        print("📚 Preloading \(coverURLs.count) book covers...")
        
        // Use the batch preload method with throttling
        await SharedBookCoverManager.shared.preloadCovers(coverURLs)
        
        print("✅ Finished preloading covers")
        
        // Also ensure high-quality images are loaded for visible books
        let visibleBooks = Array(viewModel.books.prefix(20))
        for book in visibleBooks {
            if let coverURL = book.coverImageURL {
                // Load full image to ensure high quality in library view
                _ = await SharedBookCoverManager.shared.loadFullImage(from: coverURL)
            }
        }
        print("✅ Loaded high-quality covers for visible books")
        
        // Don't pre-warm color cache - let BookDetailView handle color extraction
        // This ensures all books use the same color extraction path from displayed images
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        ModernEmptyStates.noBooks(
            addAction: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.showingBookSearch = true
            },
            importAction: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.showingGoodreadsImport = true
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    
    @ViewBuilder
    private var navigationLink: some View {
        NavigationLink(
            destination: selectedBookForNavigation.map { BookDetailView(book: $0) },
            isActive: $navigateToBookDetail
        ) {
            EmptyView()
        }
        .hidden()
    }
    
    @ViewBuilder
    private var gridContent: some View {
        OptimizedLibraryGrid(
            books: filteredBooks,
            viewModel: viewModel,
            highlightedBookId: highlightedBookId,
            onChangeCover: { book in changeCover(for: book) }
        )
    }
    
    @ViewBuilder
    private var listContent: some View {
        LibraryBookListView(
            books: filteredBooks,
            viewModel: viewModel,
            highlightedBookId: highlightedBookId,
            onChangeCover: { book in changeCover(for: book) },
            namespace: listTransition
        )
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Push content to the right
        ToolbarSpacer(.flexible)
        
        // Layout options menu
        ToolbarItem {
            Menu {
                // View mode section with picker style
                Picker("View Mode", selection: $viewMode.animation(DesignSystem.Animation.springStandard)) {
                    Label("Grid View", systemImage: "square.grid.2x2")
                        .tag(ViewMode.grid)
                    Label("List View", systemImage: "list.bullet")
                        .tag(ViewMode.list)
                }
                .pickerStyle(.inline)
                .onChange(of: viewMode) { _, newMode in
                    SensoryFeedback.light()
                    if newMode == .list {
                        // Disable reorder mode when switching to list
                        viewModel.isReorderMode = false
                    }
                }
                
                // Reorder option (only in grid mode) - separate section
                if viewMode == .grid {
                    Section {
                        Button {
                            withAnimation(DesignSystem.Animation.springStandard) {
                                viewModel.isReorderMode.toggle()
                                SensoryFeedback.medium()
                            }
                        } label: {
                            Label(
                                viewModel.isReorderMode ? "Done Reordering" : "Reorder Books",
                                systemImage: viewModel.isReorderMode ? "checkmark.circle" : "arrow.up.arrow.down"
                            )
                        }
                    }
                }
            } label: {
                Image(systemName: viewMode == .grid ? "square.grid.2x2" : "list.bullet")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        
        // Fixed spacer between menu and settings
        ToolbarSpacer(.fixed)
        
        // Settings button
        ToolbarItem {
            Button {
                appState.showingSettings = true
                SensoryFeedback.light()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.8))
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }
    
    @ViewBuilder
    private var coverPickerSheet: some View {
        if let book = selectedBookForEdit {
            BookSearchSheet(
                searchQuery: book.title + " " + book.author,
                onBookSelected: { selected in
                    Task { @MainActor in
                        print("📖 Cover change: Selected book '\(selected.title)'")
                        let oldURL = book.coverImageURL
                        let resolved = await DisplayCoverURLResolver.resolveDisplayURL(
                            googleID: selected.id,
                            isbn: selected.isbn,
                            thumbnailURL: selected.coverImageURL
                        )
                        let finalURL = resolved ?? selected.coverImageURL
                        if finalURL == nil { print("  ⚠️ WARNING: Selected book has no cover URL!") }

                        // Update cover on the existing book (do not replace metadata here)
                        viewModel.updateBookCover(book, newCoverURL: finalURL)

                        // Refresh image caches and palette
                        if let oldURL {
                            _ = await SharedBookCoverManager.shared.refreshCover(for: oldURL)
                        }
                        if let finalURL {
                            _ = await SharedBookCoverManager.shared.loadFullImage(from: finalURL)
                            await BookColorPaletteCache.shared.refreshPalette(for: book.id, coverURL: finalURL)
                        }

                        NotificationCenter.default.post(name: NSNotification.Name("RefreshLibrary"), object: nil)
                        showingCoverPicker = false
                        selectedBookForEdit = nil
                    }
                },
                mode: .replace
            )
        }
    }
    
    @ViewBuilder
    private var settingsSheet: some View {
        MinimalSettingsView()
            .matchedGeometryEffect(id: "settings-view", in: settingsTransition, isSource: false)
    }
    
    @ViewBuilder
    private var bookSearchSheet: some View {
        BookSearchSheet(
            searchQuery: "",
            onBookSelected: { book in
                viewModel.addBook(book)
                appState.showingBookSearch = false
            }
        )
    }
    
    @ViewBuilder
    private var enhancedScannerSheet: some View {
        EnhancedBookScannerView { book in
            viewModel.addBook(book)
            appState.showingEnhancedScanner = false
            
            NotificationCenter.default.post(
                name: Notification.Name("ShowGlassToast"),
                object: ["message": "Added \"\(book.title)\" to library"]
            )
        }
    }
    
    @ViewBuilder
    private var goodreadsImportSheet: some View {
        CleanGoodreadsImportView()
            .environmentObject(viewModel)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // iOS 18 optimization
                ScrollViewTracker(isScrolling: $isScrolling)
                
                if viewModel.isLoading {
                    // Show skeleton screens while loading
                    ScrollView {
                        if viewMode == .grid {
                            SkeletonGrid(columns: 2, rows: 4)
                        } else {
                            SkeletonList(count: 6)
                        }
                    }
                    .transition(.opacity)
                } else if viewModel.books.isEmpty {
                    emptyStateView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    ZStack {
                        if viewMode == .grid {
                            gridContent
                                // Removed transition for performance
                        } else {
                            listContent
                                // Removed transition for performance
                        }
                    }
                    // Removed animation for smoother scrolling
                }
                
                // Add bottom padding to prevent content from scrolling under action buttons
                Color.clear
                    .frame(height: 45) // Space for action buttons above tab bar
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)
            .refreshable {
                await refreshLibrary()
            }
            .onChange(of: scrollToBookId) { _, bookId in
                if let bookId = bookId {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(bookId, anchor: .center)
                    }
                    // Clear the scroll request after scrolling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollToBookId = nil
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Permanent ambient gradient background
                AmbientChatGradientView()
                    .opacity(0.4)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                
                // Subtle darkening overlay for better readability
                Color.black.opacity(0.15)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                
                navigationLink
                mainContent
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
        }
        .animation(DesignSystem.Animation.easeQuick, value: viewMode)
        .sheet(isPresented: $showingCoverPicker) {
            coverPickerSheet
        }
        .sheet(isPresented: $appState.showingSettings) {
            settingsSheet
        }
        .sheet(isPresented: $appState.showingBookSearch) {
            bookSearchSheet
        }
        .sheet(isPresented: $appState.showingEnhancedScanner) {
            enhancedScannerSheet
        }
        .sheet(isPresented: $appState.showingGoodreadsImport) {
            goodreadsImportSheet
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToBook"))) { notification in
            if let book = notification.object as? Book {
                // Navigate directly to book detail
                selectedBookForNavigation = book
                navigateToBookDetail = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowBookSearch"))) { _ in
            appState.showingBookSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowEnhancedBookScanner"))) { _ in
            appState.showingEnhancedScanner = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowGoodreadsImport"))) { _ in
            appState.showingGoodreadsImport = true
        }
        #if DEBUG
        .onAppear {
            startPerformanceMonitoring()
        }
        .onDisappear {
            stopPerformanceMonitoring()
        }
        #endif
        .task {
            // Preload all book covers when the library loads
            await preloadAllBookCovers()
        }
    }
}


// MARK: - Library Grid Item Wrapper
struct LibraryGridItem: View {
    let book: Book
    let index: Int
    let viewModel: LibraryViewModel
    let highlightedBookId: UUID?
    let onChangeCover: (Book) -> Void
    @State private var isVisible = false
    
    var body: some View {
        NavigationLink(destination: BookDetailView(book: book).environmentObject(viewModel)) {
            BookCard(book: book)
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(highlightOverlay)
        }
        .simultaneousGesture(TapGesture().onEnded { _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        })
        .buttonStyle(PlainButtonStyle())
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .contextMenu {
                // Same menu items as card
                Button {
                    SensoryFeedback.light()
                    withAnimation {
                        viewModel.toggleReadingStatus(for: book)
                    }
                } label: {
                    Label(
                        book.readingStatus == .read ? "Mark as Want to Read" : "Mark as Read",
                        systemImage: book.readingStatus == .read ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                
                Divider()
                
                Button {
                    SensoryFeedback.light()
                    // Share functionality
                    let text = "Check out \"\(book.title)\" by \(book.author)"
                    let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityVC, animated: true)
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                Button {
                    SensoryFeedback.light()
                    onChangeCover(book)
                } label: {
                    Label("Change Cover", systemImage: "photo")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    SensoryFeedback.light()
                    withAnimation {
                        viewModel.deleteBook(book)
                    }
                } label: {
                    Label("Delete from Library", systemImage: "trash")
                }
            }
    }
    
    private var highlightOverlay: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
            .stroke(DesignSystem.Colors.primaryAccent, lineWidth: 3)
            .opacity(highlightedBookId == book.localId ? 1 : 0)
    }
}

// MARK: - Library List Item Wrapper
struct LibraryListItemWrapper: View {
    let book: Book
    let index: Int
    let viewModel: LibraryViewModel
    let viewMode: LibraryView.ViewMode
    let highlightedBookId: UUID?
    let onChangeCover: (Book) -> Void
    @State private var isVisible = false
    
    var body: some View {
        NavigationLink(destination: BookDetailView(book: book).environmentObject(viewModel)) {
            LibraryBookListItem(book: book, viewModel: viewModel, onChangeCover: onChangeCover)
                .overlay(highlightOverlay)
        }
        .simultaneousGesture(TapGesture().onEnded { _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        })
        .buttonStyle(PlainButtonStyle())
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
            .contextMenu {
                // Same menu items
                Button {
                    SensoryFeedback.light()
                    withAnimation {
                        viewModel.toggleReadingStatus(for: book)
                    }
                } label: {
                    Label(
                        book.readingStatus == .read ? "Mark as Want to Read" : "Mark as Read",
                        systemImage: book.readingStatus == .read ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                
                Divider()
                
                Button {
                    SensoryFeedback.light()
                    let text = "Check out \"\(book.title)\" by \(book.author)"
                    let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityVC, animated: true)
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                Button {
                    SensoryFeedback.light()
                    onChangeCover(book)
                } label: {
                    Label("Change Cover", systemImage: "photo")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    SensoryFeedback.light()
                    withAnimation {
                        viewModel.deleteBook(book)
                    }
                } label: {
                    Label("Delete from Library", systemImage: "trash")
                }
            }
    }
    
    private var highlightOverlay: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
            .stroke(DesignSystem.Colors.primaryAccent, lineWidth: 3)
            .opacity(highlightedBookId == book.localId ? 1 : 0)
    }
}

// MARK: - Library Book Card
struct LibraryBookCard: View {
    let book: Book
    let viewModel: LibraryViewModel
    let onChangeCover: ((Book) -> Void)?
    @State private var isPressed = false
    @State private var tilt: Double = 0
    @State private var isHovered = false
    
    // Normalize author spacing to be consistent (J.R.R. instead of J. R. R.)
    private func normalizeAuthorSpacing(_ author: String) -> String {
        // Replace multiple spaces with single space first
        let singleSpaced = author.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Remove spaces between single initials (e.g., "J. R. R." becomes "J.R.R.")
        let normalized = singleSpaced.replacingOccurrences(of: "\\b([A-Z])\\.\\s+(?=[A-Z]\\.)", with: "$1.", options: .regularExpression)
        return normalized
    }
    
    private func shareBook() {
        let text = "Check out \"\(book.title)\" by \(book.author)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Book cover with 3D effect
            // TEMPORARY TEST: Just use SharedBookCoverView as before
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 170,
                height: 255,
                loadFullImage: false,
                isLibraryView: true
            )
                .onAppear {
                    if book.coverImageURL == nil {
                        print("⚠️⚠️ LibraryBookCard displaying book with NO cover URL: \(book.title)")
                        print("   Book.id: \(book.id)")
                    } else {
                        print("📚 LibraryBookCard showing: \(book.title)")
                        print("   Cover URL: \(book.coverImageURL!)")
                        
                        // TEST: Try loading this URL directly
                        Task {
                            if let url = URL(string: book.coverImageURL!) {
                                do {
                                    let (data, response) = try await URLSession.shared.data(from: url)
                                    if let httpResponse = response as? HTTPURLResponse {
                                        print("   ✅ Direct load test: Status \(httpResponse.statusCode), \(data.count) bytes")
                                    }
                                } catch {
                                    print("   ❌ Direct load test FAILED: \(error)")
                                }
                            } else {
                                print("   ❌ Invalid URL - can't create URL object")
                            }
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isPressed {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .rotation3DEffect(
                    .degrees(tilt),
                    axis: (x: -1, y: 0, z: 0),
                    anchor: .center,
                    perspective: 0.5
                )
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
                .animation(DesignSystem.Animation.springStandard, value: isPressed)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(book.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96)) // Warm white
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(minHeight: 40) // Ensure minimum height for 2 lines
                
                Text(normalizeAuthorSpacing(book.author))
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .kerning(0.8) // Consistent kerning with normalized spacing
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 1) // Just 1 point of spacing
                
                // Progress bar removed per user request
            }
            .padding(.bottom, 8) // Add extra padding at bottom of text
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            // Mark as Read/Want to Read
            Button {
                SensoryFeedback.light()
                withAnimation {
                    viewModel.toggleReadingStatus(for: book)
                }
            } label: {
                Label(
                    book.readingStatus == .read ? "Mark as Want to Read" : "Mark as Read",
                    systemImage: book.readingStatus == .read ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            
            Divider()
            
            // Share
            Button {
                SensoryFeedback.light()
                shareBook()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            // Change Cover
            Button {
                SensoryFeedback.light()
                onChangeCover?(book)
            } label: {
                Label("Change Cover", systemImage: "photo")
            }
            
            Divider()
            
            // Delete
            Button(role: .destructive) {
                SensoryFeedback.light()
                withAnimation {
                    viewModel.deleteBook(book)
                }
            } label: {
                Label("Delete from Library", systemImage: "trash")
            }
        }
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.easeQuick) {
                isHovered = hovering
            }
        }
    }
}

// BookCoverView removed - now using SharedBookCoverView


// MARK: - Placeholder Views
// NotesView moved to NotesView.swift
// ChatView moved to ChatView.swift

// MARK: - View Mode Toggle
struct ViewModeToggle: View {
    @Binding var viewMode: LibraryView.ViewMode
    let namespace: Namespace.ID
    
    var body: some View {
        HStack(spacing: 0) {
            // Grid button
            Button(action: {
                withAnimation(DesignSystem.Animation.springStandard) {
                    viewMode = .grid
                    SensoryFeedback.light()
                }
            }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewMode == .grid ? DesignSystem.Colors.primaryAccent : .white.opacity(0.6))
                    .frame(width: 40, height: 32)
                    .contentTransition(.symbolEffect(.replace))
            }
            
            // List button
            Button(action: {
                withAnimation(DesignSystem.Animation.springStandard) {
                    viewMode = .list
                    SensoryFeedback.light()
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewMode == .list ? DesignSystem.Colors.primaryAccent : .white.opacity(0.6))
                    .frame(width: 40, height: 32)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding(4)
    }
}

// MARK: - Library Book List Item
struct LibraryBookListItem: View {
    let book: Book
    let viewModel: LibraryViewModel
    let onChangeCover: ((Book) -> Void)?
    @State private var isPressed = false
    @State private var showActions = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content
            HStack(spacing: 16) {
                // Book cover with fixed dimensions
                ZStack {
                    // Cover with proper aspect ratio
                    if let coverURL = book.coverImageURL,
                       let url = URL(string: coverURL.replacingOccurrences(of: "http://", with: "https://")) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(Color.gray.opacity(0.2))
                        }
                        .frame(width: 60, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                        .overlay {
                            // Subtle gradient for depth
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                        }
                    } else {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                    }
                }
                .frame(width: 60, height: 90)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                
                // Book details
                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text(book.title)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96)) // Warm white
                        .lineLimit(2)
                        .truncationMode(.tail)
                    
                    // Author
                    Text(book.author)
                        .font(.system(size: 14, design: .monospaced))
                        .kerning(1.2) // Letter spacing for author names
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer()
                    
                    // Bottom row with status and metadata
                    HStack(alignment: .center, spacing: 8) {
                        // Reading status pill with glass effect
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor(for: book.readingStatus))
                                .frame(width: 5, height: 5)
                            
                            Text(book.readingStatus.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .opacity(0.8)
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(statusColor(for: book.readingStatus).opacity(0.3), lineWidth: 0.5)
                        }
                        
                        Spacer()
                        
                        // Page count
                        if let pageCount = book.pageCount {
                            Text("\(pageCount) pages")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                        }
                    }
                    
                    // Reading progress bar (if applicable)
                    if book.readingStatus == .currentlyReading {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Background
                                Capsule()
                                    .fill(.white.opacity(0.1))
                                    .frame(height: 3)
                                
                                // Progress
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.green.opacity(0.8),
                                                Color.green
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * 0.3, height: 3) // 30% progress example
                            }
                        }
                        .frame(height: 3)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            
            // Actions area
            if showActions {
                HStack(spacing: 0) {
                    // Edit button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        // TODO: Edit action
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                    }
                    
                    // Delete button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            viewModel.removeBook(book)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(height: 114) // Fixed height to contain cover + padding
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)) // #262524 with transparency
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .offset(x: showActions ? -120 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPressed)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showActions)
        .onTapGesture {
            SensoryFeedback.light()
            
            if showActions {
                withAnimation {
                    showActions = false
                }
            }
        }
        .contextMenu {
            // Same menu items
            Button {
                SensoryFeedback.light()
                withAnimation {
                    viewModel.toggleReadingStatus(for: book)
                }
            } label: {
                Label(
                    book.readingStatus == .read ? "Mark as Want to Read" : "Mark as Read",
                    systemImage: book.readingStatus == .read ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            
            Divider()
            
            Button {
                SensoryFeedback.light()
                let text = "Check out \"\(book.title)\" by \(book.author)"
                let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(activityVC, animated: true)
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button {
                SensoryFeedback.light()
                onChangeCover?(book)
            } label: {
                Label("Change Cover", systemImage: "photo")
            }
            
            Divider()
            
            Button(role: .destructive) {
                SensoryFeedback.light()
                withAnimation {
                    viewModel.deleteBook(book)
                }
            } label: {
                Label("Delete from Library", systemImage: "trash")
            }
        }
    }
    
}

// MARK: - Helper Functions

private func statusColor(for status: ReadingStatus) -> Color {
    switch status {
    case .wantToRead:
        return .blue
    case .currentlyReading:
        return .green
    case .read:
        return .purple
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(LibraryViewModel())
    }
}

// MARK: - Scroll Performance Tracking
struct ScrollViewTracker: View {
    @Binding var isScrolling: Bool
    @State private var lastOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    let delta = abs(value - lastOffset)
                    isScrolling = delta > 10
                    lastOffset = value
                }
        }
        .frame(height: 0)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Performance Monitoring
#if DEBUG
extension LibraryView {
    func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let fps = CACurrentMediaTime()
            if fps < 55 { // Below 60fps threshold
                frameDrops += 1
                print("⚠️ Frame drop detected. Total drops: \(frameDrops)")
            }
        }
    }
    
    func stopPerformanceMonitoring() {
        performanceTimer?.invalidate()
        performanceTimer = nil
        if frameDrops > 0 {
            print("📊 Performance Report: \(frameDrops) frame drops detected")
        }
    }
}
#endif

// MARK: - Library Book List View
struct LibraryBookListView: View {
    let books: [Book]
    let viewModel: LibraryViewModel
    let highlightedBookId: UUID?
    let onChangeCover: (Book) -> Void
    let namespace: Namespace.ID
    
    @State private var colorPalettes: [String: ColorPalette] = [:]
    @State private var loadingGradients: Set<String> = []
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(books) { book in
                LibraryBookListRow(
                    book: book,
                    viewModel: viewModel,
                    colorPalette: colorPalettes[book.id],
                    isHighlighted: highlightedBookId == book.localId,
                    onChangeCover: onChangeCover,
                    namespace: namespace
                )
                .id(book.localId)
                // Removed transition for 120Hz scrolling
                .task {
                    await loadColorPalette(for: book)
                }
            }
        }
        .scrollTargetLayout() // iOS 18 optimization
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 100)
    }
    
    private func loadColorPalette(for book: Book) async {
        guard colorPalettes[book.id] == nil,
              !loadingGradients.contains(book.id),
              let coverURL = book.coverImageURL else { return }
        
        loadingGradients.insert(book.id)
        
        // Check cache first
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: book.id) {
            await MainActor.run {
                colorPalettes[book.id] = cachedPalette
                loadingGradients.remove(book.id)
            }
            return
        }
        
        // Load and extract colors
        if let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURL) {
            do {
                let extractor = OKLABColorExtractor()
                let palette = try await extractor.extractPalette(from: image, imageSource: book.id)
                
                await BookColorPaletteCache.shared.cachePalette(palette, for: book.id, coverURL: coverURL)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        colorPalettes[book.id] = palette
                    }
                    loadingGradients.remove(book.id)
                }
            } catch {
                await MainActor.run {
                    loadingGradients.remove(book.id)
                }
            }
        }
    }
}

// MARK: - Library Book List Row
struct LibraryBookListRow: View {
    let book: Book
    let viewModel: LibraryViewModel
    let colorPalette: ColorPalette?
    let isHighlighted: Bool
    let onChangeCover: (Book) -> Void
    let namespace: Namespace.ID
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    private var progress: Double {
        guard let pageCount = book.pageCount, pageCount > 0 else { return 0 }
        return Double(book.currentPage) / Double(pageCount)
    }
    
    var body: some View {
        NavigationLink(destination: BookDetailView(book: book).environmentObject(viewModel)) {
            ZStack {
                // Background with edge-to-edge gradient
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .fill(Color.black.opacity(0.2))
                
                // Blurred gradient overlay
                if let palette = colorPalette {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            palette.primary.opacity(0.15),
                            palette.primary.opacity(0.25)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blur(radius: 20)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
                    .opacity(isHovered ? 1 : 0.7)
                    .animation(DesignSystem.Animation.easeStandard, value: isHovered)
                }
                
                // Border
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .strokeBorder(
                        isHighlighted ? DesignSystem.Colors.primaryAccent : Color.white.opacity(0.1),
                        lineWidth: isHighlighted ? 2 : 1
                    )
                
                // Content
                HStack(spacing: 0) {
                    // Book cover
                    SharedBookCoverView(
                        coverURL: book.coverImageURL,
                        width: 60,
                        height: 80,
                        loadFullImage: false,
                        isLibraryView: true
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .padding(.trailing, 12)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                            .lineLimit(1)
                        
                        Text(book.author)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Progress bar
                        if book.pageCount != nil && book.currentPage > 0 {
                            HStack(spacing: 6) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 4)
                                        
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        colorPalette?.primary ?? DesignSystem.Colors.primaryAccent,
                                                        colorPalette?.secondary ?? DesignSystem.Colors.primaryAccent.opacity(0.8)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * progress, height: 4)
                                    }
                                }
                                .frame(width: 80, height: 4)
                                
                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .frame(height: 104)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.springStandard, value: isPressed)
            .onHover { hovering in
                withAnimation(DesignSystem.Animation.easeQuick) {
                    isHovered = hovering
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .contextMenu {
            Button {
                SensoryFeedback.light()
                withAnimation {
                    viewModel.toggleReadingStatus(for: book)
                }
            } label: {
                Label(
                    book.readingStatus == .read ? "Mark as Want to Read" : "Mark as Read",
                    systemImage: book.readingStatus == .read ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            
            Divider()
            
            Button {
                SensoryFeedback.light()
                onChangeCover(book)
            } label: {
                Label("Change Cover", systemImage: "photo")
            }
            
            Divider()
            
            Button(role: .destructive) {
                SensoryFeedback.light()
                withAnimation {
                    viewModel.deleteBook(book)
                }
            } label: {
                Label("Delete from Library", systemImage: "trash")
            }
        }
    }
}

// MARK: - Library View Model
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentDetailBook: Book? = nil  // Track which book is being viewed in detail
    @Published var isReorderMode = false  // Track if we're in reorder mode
    
    private let googleBooksService = GoogleBooksService()
    private let userDefaults = UserDefaults.standard
    private let booksKey = "com.epilogue.savedBooks"
    private let bookOrderKey = "com.epilogue.bookOrder"
    
    init() {
        loadBooks()
        updateBookCoverURLsToHigherQuality()
        
        // Generate context for all books in background
        Task {
            await BookContextCache.shared.generateContextForAllBooks(books)
        }
        
        // Listen for library refresh notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshLibrary"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 RefreshLibrary notification received")
            self.loadBooks()
            // CRITICAL: Also update URLs after import to remove zoom parameters
            self.updateBookCoverURLsToHigherQuality()
        }
    }
    
    private func loadBooks() {
        print("📚 Loading books from UserDefaults")
        print("🔍 DEBUG: loadBooks() called from: \(Thread.callStackSymbols[2...5].joined(separator: "\n"))")
        if let data = userDefaults.data(forKey: booksKey) {
            print("  📦 Found data in UserDefaults, size: \(data.count) bytes")
            do {
                var decodedBooks = try JSONDecoder().decode([Book].self, from: data)
                
                // Apply custom sort order if exists
                if let orderData = userDefaults.data(forKey: bookOrderKey),
                   let bookOrder = try? JSONDecoder().decode([String].self, from: orderData) {
                    print("  📋 Applying custom sort order")
                    decodedBooks = sortBooksByCustomOrder(decodedBooks, order: bookOrder)
                }
                
                self.books = decodedBooks
                print("  ✅ Loaded \(decodedBooks.count) books from UserDefaults")
                
                // Log first few books for debugging
                for (index, book) in decodedBooks.prefix(3).enumerated() {
                    print("    Book \(index + 1): \(book.title) by \(book.author)")
                    print("      Cover URL: \(book.coverImageURL ?? "NO COVER")")
                }
            } catch {
                print("  ❌ Failed to decode books: \(error)")
            }
        } else {
            print("  ⚠️ No books found in UserDefaults")
            self.books = []
        }
    }
    
    private func sortBooksByCustomOrder(_ books: [Book], order: [String]) -> [Book] {
        var sortedBooks: [Book] = []
        var remainingBooks = books
        
        // First, add books in the specified order
        for bookId in order {
            if let index = remainingBooks.firstIndex(where: { $0.id == bookId }) {
                sortedBooks.append(remainingBooks.remove(at: index))
            }
        }
        
        // Add any remaining books that weren't in the order (new books)
        sortedBooks.append(contentsOf: remainingBooks)
        
        return sortedBooks
    }
    
    func saveBookOrder() {
        let bookIds = books.map { $0.id }
        if let data = try? JSONEncoder().encode(bookIds) {
            userDefaults.set(data, forKey: bookOrderKey)
            userDefaults.synchronize()
            print("  📋 Saved custom book order")
        }
    }
    
    func moveBook(from source: IndexSet, to destination: Int) {
        books.move(fromOffsets: source, toOffset: destination)
        saveBookOrder()
        saveBooks()
    }
    
    func moveBook(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex,
              fromIndex >= 0 && fromIndex < books.count,
              toIndex >= 0 && toIndex <= books.count else { return }
        
        let book = books.remove(at: fromIndex)
        let adjustedIndex = toIndex > fromIndex ? toIndex - 1 : toIndex
        books.insert(book, at: adjustedIndex)
        
        saveBookOrder()
        saveBooks()
        objectWillChange.send()
    }
    
    private func saveBooks() {
        print("💾 Saving \(books.count) books to UserDefaults")
        
        // Debug: Check URLs before encoding
        for (index, book) in books.prefix(3).enumerated() {
            print("  Book \(index + 1) before save: \(book.title)")
            print("    Cover URL: \(book.coverImageURL ?? "NO URL")")
        }
        
        do {
            let encoded = try JSONEncoder().encode(books)
            userDefaults.set(encoded, forKey: booksKey)
            
            // Force immediate save and verify
            let didSync = userDefaults.synchronize()
            print("  📝 UserDefaults synchronize: \(didSync)")
            
            // Verify the save worked
            if let verifyData = userDefaults.data(forKey: booksKey) {
                let verifyBooks = try JSONDecoder().decode([Book].self, from: verifyData)
                print("  ✅ Verified save: \(verifyBooks.count) books in storage")
            }
            
            print("  ✅ Successfully saved \(books.count) books")
        } catch {
            print("  ❌ Failed to save books: \(error)")
            errorMessage = "Failed to save library changes"
        }
    }
    
    private func updateBookCoverURLsToHigherQuality() {
        var hasUpdates = false
        
        for index in books.indices {
            if let url = books[index].coverImageURL {
                var updatedURL = url
                
                // Convert HTTP to HTTPS
                if updatedURL.starts(with: "http://") {
                    updatedURL = updatedURL.replacingOccurrences(of: "http://", with: "https://")
                    hasUpdates = true
                }
                
                // DON'T remove zoom parameters - Google Books requires them!
                // Commenting this out was the fix for the import bug
                /*
                if updatedURL.contains("zoom=") {
                    // Remove any existing zoom parameter
                    if let regex = try? NSRegularExpression(pattern: "&zoom=\\d", options: []) {
                        let range = NSRange(location: 0, length: updatedURL.utf16.count)
                        updatedURL = regex.stringByReplacingMatches(in: updatedURL, options: [], range: range, withTemplate: "")
                    }
                    
                    // Also remove zoom at start of query string
                    updatedURL = updatedURL.replacingOccurrences(of: "?zoom=1&", with: "?")
                    updatedURL = updatedURL.replacingOccurrences(of: "?zoom=2&", with: "?")
                    updatedURL = updatedURL.replacingOccurrences(of: "?zoom=3&", with: "?")
                    updatedURL = updatedURL.replacingOccurrences(of: "?zoom=4&", with: "?")
                    updatedURL = updatedURL.replacingOccurrences(of: "?zoom=5&", with: "?")
                    
                    hasUpdates = true
                    print("📚 Removed zoom parameter from '\(books[index].title)' for full cover")
                }
                */
                
                // Remove edge=curl if present  
                if updatedURL.contains("&edge=curl") {
                    updatedURL = updatedURL.replacingOccurrences(of: "&edge=curl", with: "")
                    hasUpdates = true
                }
                
                
                books[index].coverImageURL = updatedURL
            }
        }
        
        if hasUpdates {
            print("✅ Updated \(books.filter { $0.coverImageURL != nil }.count) cover URLs for higher quality images")
            saveBooks()
        } else {
            print("ℹ️ All book cover URLs already optimized")
        }
    }
    
    func addBook(_ book: Book, overwriteIfExists: Bool = false) {
        print("\n📖📖📖 LibraryViewModel.addBook called 📖📖📖")
        print("  Title: \(book.title)")
        print("  ID: \(book.id)")
        print("  🖼️ Cover URL: \(book.coverImageURL ?? "NO COVER URL")")
        if let url = book.coverImageURL {
            print("  🔍 URL Analysis:")
            print("    - Contains zoom? \(url.contains("zoom="))")
            print("    - Contains http? \(url.starts(with: "http://"))")
            print("    - Full URL: \(url)")
        }
        if book.coverImageURL == nil {
            print("  ⚠️⚠️⚠️ WARNING: Book being added with NO cover URL!")
        }
        print("  📊 Book data - Rating: \(book.userRating ?? 0), Status: \(book.readingStatus.rawValue)")
        print("  📝 Notes: \(book.userNotes?.prefix(50) ?? "None")")
        
        // Check if book already exists
        if let existingIndex = books.firstIndex(where: { $0.id == book.id }) {
            if overwriteIfExists {
                print("  🔄 Overwriting existing book: \(book.title)")
                var updatedBook = book
                updatedBook.isInLibrary = true
                // Preserve the original dateAdded if the imported one is today
                if book.dateAdded == Date() {
                    updatedBook.dateAdded = books[existingIndex].dateAdded
                }
                books[existingIndex] = updatedBook
                saveBooks()
                // Don't reload during import - causes race conditions
                // loadBooks()
                print("  ✅ Book updated with new data")
                return
            } else {
                print("  ⚠️ Book already exists in library: \(book.title)")
                return
            }
        }
        
        var newBook = book
        newBook.isInLibrary = true
        // Only set dateAdded if it's not already set (preserve imported date)
        if newBook.dateAdded == Date() {
            newBook.dateAdded = Date()
        }
        
        print("  📝 Adding book to array. Current count: \(books.count)")
        books.append(newBook)
        print("  📝 New count after adding: \(books.count)")
        print("  ✅ Preserved data - Rating: \(newBook.userRating ?? 0), Status: \(newBook.readingStatus.rawValue)")
        
        saveBooks()
        
        // Verify it was saved
        loadBooks()
        print("  ✅ Book saved. Library now has \(books.count) books")
        
        // Verify the saved book has the correct data
        if let savedBook = books.first(where: { $0.id == book.id }) {
            print("  🔍 Verified saved book - Rating: \(savedBook.userRating ?? 0), Status: \(savedBook.readingStatus.rawValue)")
            print("  🔍 Verified saved book - Cover URL: \(savedBook.coverImageURL ?? "NO COVER URL")")
            if savedBook.coverImageURL == nil {
                print("  ❌❌❌ ERROR: Saved book lost its cover URL!")
            }
        }
    }
    
    func removeBook(_ book: Book) {
        print("🗑️ Attempting to remove book: \(book.title) with ID: \(book.id)")
        let countBefore = books.count
        books.removeAll { $0.id == book.id }
        let countAfter = books.count
        print("  📊 Books before: \(countBefore), after: \(countAfter)")
        
        if countBefore != countAfter {
            saveBooks()
            // Force UI update
            objectWillChange.send()
            print("  ✅ Book removed successfully")
        } else {
            print("  ⚠️ Book not found in array")
        }
    }
    
    @MainActor
    func deleteBook(_ book: Book) {
        print("🗑️ deleteBook called for: \(book.title)")
        
        // Find the index first to ensure we have the right book
        guard let index = books.firstIndex(where: { $0.id == book.id }) else {
            print("  ⚠️ Book not found in array by ID: \(book.id)")
            // Try matching by localId as fallback
            if let index = books.firstIndex(where: { $0.localId == book.localId }) {
                print("  🔄 Found book by localId instead: \(book.localId)")
                let bookToRemove = books[index]
                books.remove(at: index)
                saveBooks()
                objectWillChange.send()
                print("  ✅ Book removed successfully by localId")
            } else {
                print("  ❌ Book not found by either ID or localId")
                // List all book IDs for debugging
                print("  📚 Current book IDs in library:")
                for (idx, b) in books.enumerated() {
                    print("    [\(idx)] ID: \(b.id), LocalID: \(b.localId), Title: \(b.title)")
                }
            }
            return
        }
        
        // Remove the book
        books.remove(at: index)
        print("  📊 Removed book at index \(index), \(books.count) books remaining")
        
        // Save immediately
        saveBooks()
        
        // Force UI update
        objectWillChange.send()
        
        // Reload to ensure consistency
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.loadBooks()
            print("  🔄 Reloaded library after deletion")
        }
        
        print("  ✅ Book deleted and UI update triggered")
    }
    
    func toggleReadingStatus(for book: Book) {
        let newStatus: ReadingStatus = book.readingStatus == .read ? .wantToRead : .read
        updateReadingStatus(for: book.id, status: newStatus)
    }
    
    func loadSampleBooks() {
        // Add some sample books for testing
        let sampleBooks = [
            Book(id: "hobbit123", title: "The Hobbit", author: "J.R.R. Tolkien", description: "A fantasy adventure", pageCount: 310),
            Book(id: "1984_456", title: "1984", author: "George Orwell", description: "A dystopian novel", pageCount: 328),
            Book(id: "pride789", title: "Pride and Prejudice", author: "Jane Austen", description: "A romantic novel", pageCount: 432)
        ]
        
        for book in sampleBooks {
            if !books.contains(where: { $0.title == book.title }) {
                addBook(book)
            }
        }
    }
    
    func updateReadingStatus(for bookId: String, status: ReadingStatus) {
        if let index = books.firstIndex(where: { $0.id == bookId }) {
            books[index].readingStatus = status
            saveBooks()
        }
    }
    
    func updateBookCover(_ book: Book, newCoverURL: String?) {
        print("🔄 updateBookCover called")
        print("  📖 Book: \(book.title)")
        print("  🆔 Book ID: \(book.id)")
        print("  🖼️ Old cover URL: \(book.coverImageURL ?? "NO OLD URL")")
        print("  🖼️ New cover URL: \(newCoverURL ?? "NO NEW URL")")
        
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            print("  ✅ Found book at index \(index)")
            let oldURL = books[index].coverImageURL
            books[index].coverImageURL = newCoverURL
            print("  🔄 Updated coverImageURL from '\(oldURL ?? "nil")' to '\(newCoverURL ?? "nil")'")
            
            saveBooks()
            
            // Post notification so other views can update
            NotificationCenter.default.post(
                name: NSNotification.Name("BookCoverUpdated"),
                object: nil,
                userInfo: ["bookId": book.id, "coverURL": newCoverURL as Any]
            )
            print("  ✅ Cover update complete, notification posted")
        } else {
            print("  ❌ ERROR: Could not find book with ID \(book.id) in library")
        }
    }
    
    func updateBookProgress(_ book: Book, currentPage: Int) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index].currentPage = currentPage
            saveBooks()
        }
    }
    
    func updateBook(_ book: Book) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
            saveBooks()
        }
    }
    
    func replaceBook(originalBook: Book, with newBook: Book, preserveCover: Bool = false) {
        if let index = books.firstIndex(where: { $0.id == originalBook.id }) {
            var updatedBook = newBook
            // Preserve user data from original book
            updatedBook.isInLibrary = true
            updatedBook.readingStatus = originalBook.readingStatus
            updatedBook.userRating = originalBook.userRating
            updatedBook.userNotes = originalBook.userNotes
            updatedBook.dateAdded = originalBook.dateAdded
            
            // Preserve the cover URL if requested or if it's been manually selected
            if preserveCover || originalBook.coverImageURL != nil {
                // Keep the original cover if it exists
                updatedBook.coverImageURL = originalBook.coverImageURL
            }
            
            books[index] = updatedBook
            saveBooks()
            
            // Update any existing notes to link to the new book
            updateNotesForReplacedBook(oldLocalId: originalBook.localId, newLocalId: updatedBook.localId)
        }
    }
    
    private func updateNotesForReplacedBook(oldLocalId: UUID, newLocalId: UUID) {
        // This would ideally be handled by NotesViewModel, but we can trigger it here
        NotificationCenter.default.post(
            name: Notification.Name("BookReplaced"),
            object: nil,
            userInfo: ["oldLocalId": oldLocalId, "newLocalId": newLocalId]
        )
    }
    
    // MARK: - Book Matching System
    
    /// Find a matching book in the library using fuzzy matching
    func findMatchingBook(title: String, author: String? = nil) -> Book? {
        guard !title.isEmpty else { return nil }
        
        print("🔎 findMatchingBook called with title: '\(title)', author: '\(author ?? "nil")'")
        
        let normalizedTitle = normalizeTitle(title)
        print("📝 Normalized search title: '\(normalizedTitle)'")
        
        var bestMatch: Book? = nil
        var bestScore: Double = 0.0
        
        for book in books {
            let normalizedBookTitle = normalizeTitle(book.title)
            print("📚 Checking against book: '\(book.title)' -> normalized: '\(normalizedBookTitle)'")
            
            let score = calculateMatchScore(
                searchTitle: normalizedTitle,
                bookTitle: normalizedBookTitle,
                searchAuthor: author?.lowercased(),
                bookAuthor: book.author.lowercased()
            )
            
            print("   Score: \(score)")
            
            if score > bestScore && score > 0.6 { // Lowered threshold for better fuzzy matching
                bestScore = score
                bestMatch = book
                print("   ✅ New best match!")
            }
        }
        
        if let match = bestMatch {
            print("🎯 Final match: '\(match.title)' with score: \(bestScore)")
        } else {
            print("❌ No match found (best score was: \(bestScore))")
        }
        
        return bestMatch
    }
    
    /// Normalize title for better matching
    private func normalizeTitle(_ title: String) -> String {
        let lowercased = title.lowercased()
        
        // Remove common prefixes
        let prefixes = ["the ", "a ", "an "]
        var normalized = lowercased
        
        for prefix in prefixes {
            if normalized.hasPrefix(prefix) {
                normalized = String(normalized.dropFirst(prefix.count))
                break
            }
        }
        
        // Remove subtitles and series information in parentheses
        normalized = normalized.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
        
        // Remove colons and everything after them (for subtitles)
        if let colonIndex = normalized.firstIndex(of: ":") {
            normalized = String(normalized[..<colonIndex])
        }
        
        // Remove common series indicators
        let seriesToRemove = [
            " book 1", " book 2", " book 3", " book one", " book two", " book three",
            " volume 1", " volume 2", " volume 3", " vol 1", " vol 2", " vol 3",
            " part 1", " part 2", " part 3", " part one", " part two", " part three"
        ]
        
        for series in seriesToRemove {
            normalized = normalized.replacingOccurrences(of: series, with: "")
        }
        
        // Remove punctuation and extra spaces
        normalized = normalized.replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        normalized = normalized.trimmingCharacters(in: .whitespaces)
        
        return normalized
    }
    
    /// Calculate match score between search term and book
    private func calculateMatchScore(searchTitle: String, bookTitle: String, searchAuthor: String?, bookAuthor: String) -> Double {
        // Exact title match
        if searchTitle == bookTitle {
            return searchAuthor == nil ? 1.0 : (searchAuthor == bookAuthor ? 1.0 : 0.9)
        }
        
        // Check for acronym matches (e.g., "LOTR" -> "Lord of the Rings")
        if isAcronymMatch(searchTitle, bookTitle) {
            return searchAuthor == nil ? 0.95 : (searchAuthor == bookAuthor ? 0.95 : 0.85)
        }
        
        // Check for series matches (e.g., "fellowship of the ring" matches "lord of the rings")
        let seriesScore = calculateSeriesMatch(searchTitle, bookTitle)
        if seriesScore > 0.8 {
            let authorBonus: Double
            if let searchAuthor = searchAuthor {
                authorBonus = (bookAuthor.contains(searchAuthor) || searchAuthor.contains(bookAuthor)) ? 0.1 : 0.0
            } else {
                authorBonus = 0.1  // No author specified means we don't penalize
            }
            return seriesScore + authorBonus
        }
        
        // Check for partial matches
        let titleWords = searchTitle.split(separator: " ")
        let bookWords = bookTitle.split(separator: " ")
        
        let matchingWords = titleWords.filter { searchWord in
            bookWords.contains { bookWord in
                bookWord.contains(searchWord) || searchWord.contains(bookWord) || 
                levenshteinDistance(String(searchWord), String(bookWord)) <= 2
            }
        }
        
        let titleScore = Double(matchingWords.count) / Double(max(titleWords.count, bookWords.count))
        
        // Author bonus
        let authorScore: Double = {
            guard let searchAuthor = searchAuthor else { return 0.0 }
            if bookAuthor.contains(searchAuthor) || searchAuthor.contains(bookAuthor) {
                return 0.2
            }
            return 0.0
        }()
        
        return titleScore + authorScore
    }
    
    /// Check if search term is an acronym of the book title
    private func isAcronymMatch(_ acronym: String, _ title: String) -> Bool {
        let words = title.split(separator: " ")
        let firstLetters = words.compactMap { $0.first?.lowercased() }.joined()
        
        return acronym.lowercased() == firstLetters
    }
    
    /// Calculate series match score for titles that might be related (e.g., LOTR series)
    private func calculateSeriesMatch(_ searchTitle: String, _ bookTitle: String) -> Double {
        let searchWords = Set(searchTitle.split(separator: " ").map(String.init))
        let bookWords = Set(bookTitle.split(separator: " ").map(String.init))
        
        // Check for Lord of the Rings specific patterns
        let lotrKeywords = Set(["lord", "rings", "fellowship", "towers", "return", "king", "tolkien"])
        let searchLotrWords = searchWords.intersection(lotrKeywords)
        let bookLotrWords = bookWords.intersection(lotrKeywords)
        
        if searchLotrWords.count >= 2 && bookLotrWords.count >= 2 {
            // High score for LOTR series matches
            return 0.9
        }
        
        // Check for other common series keywords
        let commonSeriesKeywords = Set(["chronicles", "tales", "saga", "trilogy", "series"])
        let hasSeriesKeyword = !searchWords.intersection(commonSeriesKeywords).isEmpty || 
                              !bookWords.intersection(commonSeriesKeywords).isEmpty
        
        if hasSeriesKeyword {
            let overlap = searchWords.intersection(bookWords)
            return Double(overlap.count) / Double(max(searchWords.count, bookWords.count)) + 0.2
        }
        
        // Regular overlap calculation
        let overlap = searchWords.intersection(bookWords)
        return Double(overlap.count) / Double(max(searchWords.count, bookWords.count))
    }
    
    /// Calculate Levenshtein distance between two strings for fuzzy matching
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count {
            matrix[i][0] = i
        }
        
        for j in 0...b.count {
            matrix[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,
                        matrix[i][j-1] + 1,
                        matrix[i-1][j-1] + 1
                    )
                }
            }
        }
        
        return matrix[a.count][b.count]
    }
    
    /// Add a note to a specific book
    func addNoteToBook(_ localId: UUID, note: Note) {
        // This could be expanded to store book-specific notes if needed
        // For now, we rely on the bookId in the note itself
        print("📚 Linked note '\(note.content.prefix(50))...' to book with localId: \(localId)")
    }
}
