import SwiftUI
import UIKit



struct LibraryView: View {
    @EnvironmentObject var viewModel: LibraryViewModel
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .grid
    @Namespace private var viewModeAnimation
    @State private var showingCoverPicker = false
    @State private var selectedBookForEdit: Book?
    @State private var bookRotation: Double = -5.0
    @State private var floatingOffset: Double = -10.0
    @State private var showingBookOptions = false
    @State private var selectedBookForOptions: Book?
    @State private var selectedBookRect: CGRect = .zero
    
    enum ViewMode {
        case grid, list
    }
    
    var body: some View {
        ZStack {
            // Midnight scholar background with warm charcoal
            Color(red: 0.11, green: 0.105, blue: 0.102) // #1C1B1A
                .ignoresSafeArea(.all)
            
            // Soft vignette effect
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.2)
                ]),
                center: .center,
                startRadius: 200,
                endRadius: 400
            )
            .ignoresSafeArea(.all)
            
            // Subtle wood grain texture overlay
            WoodGrainOverlay()
                .ignoresSafeArea(.all)
            
            // Content
            ScrollView {
                if viewModel.isLoading {
                    LiteraryLoadingView(message: "Loading books...")
                        .padding(.top, 100)
                } else if viewModel.books.isEmpty {
                    // Empty state
                    ZStack {
                        // Minimal particle system
                        MinimalParticleSystem()
                        
                        VStack(spacing: 20) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26)) // Glowing orange #FF8C42
                                .shadow(color: .orange.opacity(0.3), radius: 20)
                                .shadow(color: .orange.opacity(0.2), radius: 40)
                                .rotationEffect(.degrees(bookRotation))
                                .offset(y: floatingOffset)
                                .onAppear {
                                    withAnimation(
                                        .easeInOut(duration: 4)
                                        .repeatForever(autoreverses: true)
                                    ) {
                                        bookRotation = 5
                                    }
                                    
                                    withAnimation(
                                        .easeInOut(duration: 3)
                                        .repeatForever(autoreverses: true)
                                    ) {
                                        floatingOffset = 10
                                    }
                                }
                        
                            Text("Your library awaits")
                                .font(.system(size: 24, weight: .medium, design: .serif))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96)) // Warm white
                            
                            Text("Tap + to add your first book")
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    if viewMode == .grid {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 20) {
                            ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
                                GeometryReader { geo in
                                    NavigationLink(destination: BookDetailView(book: book)) {
                                        LibraryBookCard(book: book, viewModel: viewModel)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                                        removal: .scale(scale: 1.2).combined(with: .opacity)
                                    ))
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.05),
                                        value: viewModel.books.count
                                    )
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.5)
                                            .onEnded { _ in
                                                HapticManager.shared.mediumImpact()
                                                selectedBookForOptions = book
                                                selectedBookRect = geo.frame(in: .global)
                                                showingBookOptions = true
                                            }
                                    )
                                }
                                .aspectRatio(2/3, contentMode: .fit)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
                                GeometryReader { geo in
                                    NavigationLink(destination: BookDetailView(book: book)) {
                                        LibraryBookListItem(book: book, viewModel: viewModel)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.05),
                                        value: viewMode
                                    )
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.5)
                                            .onEnded { _ in
                                                HapticManager.shared.mediumImpact()
                                                selectedBookForOptions = book
                                                selectedBookRect = geo.frame(in: .global)
                                                showingBookOptions = true
                                            }
                                    )
                                }
                                .frame(height: 100)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom) // Allow scroll content to go under tab bar
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ViewModeToggle(viewMode: $viewMode, namespace: viewModeAnimation)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewMode)
        .sheet(isPresented: $showingCoverPicker) {
            if let book = selectedBookForEdit {
                BookSearchSheet(
                    searchQuery: book.title,
                    onBookSelected: { newBook in
                        // Update the existing book with the new cover
                        viewModel.updateBookCover(book, newCoverURL: newBook.coverImageURL)
                        showingCoverPicker = false
                        selectedBookForEdit = nil
                    }
                )
            }
        }
        .overlay {
            if showingBookOptions, let book = selectedBookForOptions {
                BookContextMenu(
                    book: book,
                    sourceRect: selectedBookRect,
                    isPresented: $showingBookOptions
                )
                .environmentObject(viewModel)
                .zIndex(999)
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
}


// MARK: - Library Book Card
struct LibraryBookCard: View {
    let book: Book
    let viewModel: LibraryViewModel
    @State private var isPressed = false
    @State private var showingOptions = false
    @State private var tilt: Double = 0
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book cover with 3D effect
            BookCoverView(coverURL: book.coverImageURL)
                .frame(width: 170, height: 255)
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96)) // Warm white
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                Text(book.author)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .kerning(1.2) // Letter spacing for author names
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Reading progress indicator
                if let pageCount = book.pageCount, pageCount > 0 {
                    ReadingProgressIndicator(
                        currentPage: book.currentPage,
                        totalPages: pageCount,
                        width: 150
                    )
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            HapticManager.shared.mediumImpact()
            
            showingOptions = true
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
                if pressing {
                    isHovered = true
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Book Cover View
struct BookCoverView: View {
    let coverURL: String?
    @State private var isLoading = true
    @State private var showShimmer = false
    
    private func enhanceGoogleBooksImageURL(_ urlString: String) -> String {
        // Google Books image URLs support zoom parameter for higher resolution
        var enhanced = urlString
        
        // Remove existing zoom parameter if present
        if let regex = try? NSRegularExpression(pattern: "&zoom=\\d", options: []) {
            let range = NSRange(location: 0, length: enhanced.utf16.count)
            enhanced = regex.stringByReplacingMatches(in: enhanced, options: [], range: range, withTemplate: "")
        }
        
        // Add high quality zoom parameter
        if enhanced.contains("?") {
            enhanced += "&zoom=2"
        } else {
            enhanced += "?zoom=2"
        }
        
        // Also remove edge curl parameter if present (makes covers look cleaner)
        enhanced = enhanced.replacingOccurrences(of: "&edge=curl", with: "")
        enhanced = enhanced.replacingOccurrences(of: "?edge=curl", with: "?")
        
        return enhanced
    }
    
    var body: some View {
        ZStack {
            // Background placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.3, blue: 0.35),
                            Color(red: 0.25, green: 0.25, blue: 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            if let coverURL = coverURL,
               !coverURL.isEmpty {
                let enhancedURL = enhanceGoogleBooksImageURL(coverURL)
                if let url = URL(string: enhancedURL.replacingOccurrences(of: "http://", with: "https://").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? enhancedURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // Loading state with shimmer
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                ShimmerView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 170, height: 255)
                            .clipped()
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isLoading = false
                                }
                            }
                    case .failure(let error):
                        // Error state - show book icon
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white.opacity(0.3))
                            
                            Text("Cover Unavailable")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .onAppear {
                            print("📚 DEBUG: Cover failed to load: \(error.localizedDescription)")
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                }
            } else {
                // No cover URL available - show placeholder
                VStack(spacing: 12) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text("No Cover")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .onAppear {
                    print("📚 DEBUG: No cover URL available - coverURL: \(coverURL ?? "nil")")
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isLoading = false
            }
        }
        .frame(width: 170, height: 255)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Shimmer View
struct ShimmerView: View {
    @State private var phase: CGFloat = -1.0
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.3), location: 0.5),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geometry.size.width * 3)
            .offset(x: geometry.size.width * phase)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        }
        .mask(RoundedRectangle(cornerRadius: 8))
    }
}

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
                }
            }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewMode == .grid ? Color(red: 0.98, green: 0.97, blue: 0.96) : Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                    .frame(width: 40, height: 32)
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
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewMode == .list ? Color(red: 0.98, green: 0.97, blue: 0.96) : Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                    .frame(width: 40, height: 32)
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
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay {
                                        ProgressView()
                                            .tint(.white.opacity(0.5))
                                    }
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
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
                            case .failure(_):
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                                    .overlay {
                                        Image(systemName: "book.closed.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                            @unknown default:
                                EmptyView()
                            }
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
            .padding(.leading, 12)
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
        .onLongPressGesture(minimumDuration: 0.4) {
            HapticManager.shared.mediumImpact()
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
    
    private func statusColor(for status: ReadingStatus) -> Color {
        switch status {
        case .wantToRead:
            return .blue
        case .currentlyReading:
            return .green
        case .finished:
            return .purple
        }
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(LibraryViewModel())
    }
}

// MARK: - Wood Grain Overlay
struct WoodGrainOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Create subtle wood grain pattern
                for i in 0..<50 {
                    let y = CGFloat(i) * size.height / 50
                    let path = Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        
                        // Create organic wood grain lines
                        for x in stride(from: 0, to: size.width, by: 10) {
                            let variation = sin(x / 100 + Double(i)) * 2
                            path.addLine(to: CGPoint(x: x, y: y + variation))
                        }
                    }
                    
                    context.stroke(
                        path,
                        with: .color(Color(red: 0.2, green: 0.19, blue: 0.18).opacity(0.03)),
                        lineWidth: 0.5
                    )
                }
            }
        }
    }
}

// MARK: - Minimal Particle System
struct MinimalParticleSystem: View {
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var opacity: Double
        var scale: CGFloat
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(Color(red: 0.83, green: 0.65, blue: 0.45)) // Soft amber
                    .frame(width: 4 * particle.scale, height: 4 * particle.scale)
                    .opacity(particle.opacity)
                    .position(particle.position)
                    .blur(radius: 2)
            }
            .onAppear {
                // Create 8 particles
                for _ in 0..<8 {
                    particles.append(Particle(
                        position: CGPoint(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        ),
                        velocity: CGVector(
                            dx: CGFloat.random(in: -0.5...0.5),
                            dy: CGFloat.random(in: -0.3...(-0.1))
                        ),
                        opacity: Double.random(in: 0.2...0.4),
                        scale: CGFloat.random(in: 0.8...1.2)
                    ))
                }
                
                // Animate particles
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    for i in particles.indices {
                        particles[i].position.x += particles[i].velocity.dx
                        particles[i].position.y += particles[i].velocity.dy
                        
                        // Wrap around
                        if particles[i].position.y < -10.0 {
                            particles[i].position.y = geometry.size.height + 10
                            particles[i].position.x = CGFloat.random(in: 0...geometry.size.width)
                        }
                        
                        if particles[i].position.x < -10.0 {
                            particles[i].position.x = geometry.size.width + 10
                        } else if particles[i].position.x > geometry.size.width + 10 {
                            particles[i].position.x = -10.0
                        }
                    }
                }
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
            let authorBonus = (searchAuthor == nil || bookAuthor.contains(searchAuthor!) || searchAuthor!.contains(bookAuthor)) ? 0.1 : 0.0
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
