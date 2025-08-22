import SwiftUI
import UIKit
import Combine



struct LibraryView: View {
    @EnvironmentObject var viewModel: LibraryViewModel
    @State private var searchText = ""
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
    @State private var showingSettings = false
    @State private var settingsButtonPressed = false
    @State private var visibleBookIDs: Set<UUID> = []
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var showingBookSearch = false
    @State private var showingEnhancedScanner = false
    
    #if DEBUG
    @State private var frameDrops = 0
    @State private var performanceTimer: Timer?
    #endif
    
    enum ViewMode: String {
        case grid, list
    }
    
    // Helper function to change book cover
    private func changeCover(for book: Book) {
        selectedBookForEdit = book
        showingCoverPicker = true
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
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
        
            Text("Your library awaits")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            
            Text("Tap + to add your first book")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        // Simple background for performance
        Color(red: 0.11, green: 0.105, blue: 0.102)
            .ignoresSafeArea(.all)
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
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 32) { // Increased spacing between rows
            ForEach(viewModel.books) { book in
                LibraryGridItem(
                    book: book,
                    index: 0, // Remove index-based animations
                    viewModel: viewModel,
                    highlightedBookId: highlightedBookId,
                    onChangeCover: { book in changeCover(for: book) }
                )
                .id(book.localId) // Stable identity for recycling
                .onAppear {
                    visibleBookIDs.insert(book.localId)
                    // Preload neighboring book covers
                    preloadNeighboringCovers(for: book)
                }
                .onDisappear {
                    visibleBookIDs.remove(book.localId)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private var listContent: some View {
        LibraryBookListView(
            books: viewModel.books,
            viewModel: viewModel,
            highlightedBookId: highlightedBookId,
            onChangeCover: { book in changeCover(for: book) },
            namespace: listTransition
        )
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                // Grid button - simple
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewMode = .grid
                        HapticManager.shared.lightTap()
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: viewMode == .grid ? .semibold : .regular))
                        .foregroundStyle(viewMode == .grid ? Color.orange : .white.opacity(0.7))
                }
                
                // List button - simple
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewMode = .list
                        HapticManager.shared.lightTap()
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: viewMode == .list ? .semibold : .regular))
                        .foregroundStyle(viewMode == .list ? Color.orange : .white.opacity(0.7))
                }
                
                // Settings button - simple
                Button {
                    showingSettings = true
                    HapticManager.shared.lightTap()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
            )
        }
    }
    
    @ViewBuilder
    private var coverPickerSheet: some View {
        if let book = selectedBookForEdit {
            BookSearchSheet(
                searchQuery: book.title,
                onBookSelected: { newBook in
                    viewModel.updateBookCover(book, newCoverURL: newBook.coverImageURL)
                    showingCoverPicker = false
                    selectedBookForEdit = nil
                }
            )
        }
    }
    
    @ViewBuilder
    private var settingsSheet: some View {
        SettingsView()
    }
    
    @ViewBuilder
    private var bookSearchSheet: some View {
        BookSearchSheet(
            searchQuery: "",
            onBookSelected: { book in
                viewModel.addBook(book)
                showingBookSearch = false
            }
        )
    }
    
    @ViewBuilder
    private var enhancedScannerSheet: some View {
        EnhancedBookScannerView { book in
            viewModel.addBook(book)
            showingEnhancedScanner = false
            
            NotificationCenter.default.post(
                name: Notification.Name("ShowGlassToast"),
                object: ["message": "Added \"\(book.title)\" to library"]
            )
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
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
                } else {
                    ZStack {
                        if viewMode == .grid {
                            gridContent
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                    removal: .opacity.combined(with: .scale(scale: 1.02))
                                ))
                        } else {
                            listContent
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                    removal: .opacity.combined(with: .scale(scale: 1.02))
                                ))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewMode)
                }
            }
            .ignoresSafeArea(edges: .bottom)
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
                backgroundView
                navigationLink
                mainContent
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewMode)
        .sheet(isPresented: $showingCoverPicker) {
            coverPickerSheet
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet
        }
        .sheet(isPresented: $showingBookSearch) {
            bookSearchSheet
        }
        .sheet(isPresented: $showingEnhancedScanner) {
            enhancedScannerSheet
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToBook"))) { notification in
            if let book = notification.object as? Book {
                // Navigate directly to book detail
                selectedBookForNavigation = book
                navigateToBookDetail = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowBookSearch"))) { _ in
            showingBookSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowEnhancedBookScanner"))) { _ in
            showingEnhancedScanner = true
        }
        #if DEBUG
        .onAppear {
            startPerformanceMonitoring()
        }
        .onDisappear {
            stopPerformanceMonitoring()
        }
        #endif
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
                    HapticManager.shared.lightTap()
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
                    HapticManager.shared.lightTap()
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
                    HapticManager.shared.lightTap()
                    onChangeCover(book)
                } label: {
                    Label("Change Cover", systemImage: "photo")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    HapticManager.shared.lightTap()
                    withAnimation {
                        viewModel.deleteBook(book)
                    }
                } label: {
                    Label("Delete from Library", systemImage: "trash")
                }
            }
    }
    
    private var highlightOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 3)
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
                    HapticManager.shared.lightTap()
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
                    HapticManager.shared.lightTap()
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
                    HapticManager.shared.lightTap()
                    onChangeCover(book)
                } label: {
                    Label("Change Cover", systemImage: "photo")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    HapticManager.shared.lightTap()
                    withAnimation {
                        viewModel.deleteBook(book)
                    }
                } label: {
                    Label("Delete from Library", systemImage: "trash")
                }
            }
    }
    
    private var highlightOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 3)
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
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 170,
                height: 255,
                loadFullImage: false,
                isLibraryView: true
            )
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
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96)) // Warm white
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(minHeight: 40) // Ensure minimum height for 2 lines
                
                Text(book.author)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .kerning(1.2) // Letter spacing for author names
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Progress bar removed per user request
            }
            .padding(.bottom, 8) // Add extra padding at bottom of text
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            // Mark as Read/Want to Read
            Button {
                HapticManager.shared.lightTap()
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
                HapticManager.shared.lightTap()
                shareBook()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            // Change Cover
            Button {
                HapticManager.shared.lightTap()
                onChangeCover?(book)
            } label: {
                Label("Change Cover", systemImage: "photo")
            }
            
            Divider()
            
            // Delete
            Button(role: .destructive) {
                HapticManager.shared.lightTap()
                withAnimation {
                    viewModel.deleteBook(book)
                }
            } label: {
                Label("Delete from Library", systemImage: "trash")
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewMode = .grid
                    HapticManager.shared.lightTap()
                }
            }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewMode == .grid ? Color(red: 0.98, green: 0.97, blue: 0.96) : Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                    .frame(width: 40, height: 32)
                    .contentTransition(.symbolEffect(.replace))
                    .background {
                        if viewMode == .grid {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.15)) // Warm amber/orange glow
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1)
                                }
                                .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), radius: 6)
                                .matchedGeometryEffect(id: "viewModeSelection", in: namespace)
                        }
                    }
            }
            
            // List button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewMode = .list
                    HapticManager.shared.lightTap()
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewMode == .list ? Color(red: 0.98, green: 0.97, blue: 0.96) : Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                    .frame(width: 40, height: 32)
                    .contentTransition(.symbolEffect(.replace))
                    .background {
                        if viewMode == .list {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.15)) // Warm amber/orange glow
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1)
                                }
                                .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), radius: 6)
                                .matchedGeometryEffect(id: "viewModeSelection", in: namespace)
                        }
                    }
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
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .overlay {
                                    ProgressView()
                                        .tint(.white.opacity(0.5))
                                }
                        }
                        .frame(width: 60, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                            .overlay {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
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
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)) // #262524 with transparency
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .offset(x: showActions ? -120 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPressed)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showActions)
        .onTapGesture {
            HapticManager.shared.lightTap()
            
            if showActions {
                withAnimation {
                    showActions = false
                }
            }
        }
        .contextMenu {
            // Same menu items
            Button {
                HapticManager.shared.lightTap()
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
                HapticManager.shared.lightTap()
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
                HapticManager.shared.lightTap()
                onChangeCover?(book)
            } label: {
                Label("Change Cover", systemImage: "photo")
            }
            
            Divider()
            
            Button(role: .destructive) {
                HapticManager.shared.lightTap()
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
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .task {
                    await loadColorPalette(for: book)
                }
            }
        }
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
                RoundedRectangle(cornerRadius: 16)
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
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .opacity(isHovered ? 1 : 0.7)
                    .animation(.easeInOut(duration: 0.3), value: isHovered)
                }
                
                // Border
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isHighlighted ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color.white.opacity(0.1),
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                                                        colorPalette?.primary ?? Color(red: 1.0, green: 0.55, blue: 0.26),
                                                        colorPalette?.secondary ?? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8)
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
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
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
                HapticManager.shared.lightTap()
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
                HapticManager.shared.lightTap()
                onChangeCover(book)
            } label: {
                Label("Change Cover", systemImage: "photo")
            }
            
            Divider()
            
            Button(role: .destructive) {
                HapticManager.shared.lightTap()
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
    
    private let googleBooksService = GoogleBooksService()
    private let userDefaults = UserDefaults.standard
    private let booksKey = "com.epilogue.savedBooks"
    
    init() {
        loadBooks()
        updateBookCoverURLsToHigherQuality()
    }
    
    private func loadBooks() {
        if let data = userDefaults.data(forKey: booksKey),
           let decodedBooks = try? JSONDecoder().decode([Book].self, from: data) {
            self.books = decodedBooks
        }
    }
    
    private func saveBooks() {
        if let encoded = try? JSONEncoder().encode(books) {
            userDefaults.set(encoded, forKey: booksKey)
        }
    }
    
    private func updateBookCoverURLsToHigherQuality() {
        var hasUpdates = false
        
        for index in books.indices {
            if let url = books[index].coverImageURL {
                var updatedURL = url
                
                // REMOVE all zoom parameters to get full covers
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
                
                // Remove edge=curl if present
                if updatedURL.contains("&edge=curl") {
                    updatedURL = updatedURL.replacingOccurrences(of: "&edge=curl", with: "")
                    hasUpdates = true
                }
                
                books[index].coverImageURL = updatedURL
            }
        }
        
        if hasUpdates {
            print("✅ Updated cover URLs for higher quality images")
            saveBooks()
        } else {
            print("ℹ️ All book cover URLs already optimized")
        }
    }
    
    func addBook(_ book: Book) {
        var newBook = book
        newBook.isInLibrary = true
        newBook.dateAdded = Date()
        books.append(newBook)
        saveBooks()
    }
    
    func removeBook(_ book: Book) {
        books.removeAll { $0.id == book.id }
        saveBooks()
    }
    
    func deleteBook(_ book: Book) {
        removeBook(book)
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
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index].coverImageURL = newCoverURL
            saveBooks()
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
    
    func replaceBook(originalBook: Book, with newBook: Book) {
        if let index = books.firstIndex(where: { $0.id == originalBook.id }) {
            var updatedBook = newBook
            // Preserve user data from original book
            updatedBook.isInLibrary = true
            updatedBook.readingStatus = originalBook.readingStatus
            updatedBook.userRating = originalBook.userRating
            updatedBook.userNotes = originalBook.userNotes
            updatedBook.dateAdded = originalBook.dateAdded
            
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
