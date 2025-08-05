import SwiftUI

/// Embedded version of AmbientProgressSheet with EXACT same visual design, just compact and auto-saving
struct EmbeddedAmbientProgress: View {
    let book: Book
    let width: CGFloat
    var colorPalette: ColorPalette? = nil
    
    @EnvironmentObject var viewModel: LibraryViewModel
    @State private var currentPage: Int
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    private let amberColor = Color(red: 1.0, green: 0.55, blue: 0.26)
    
    private var primaryColor: Color {
        colorPalette?.primary ?? amberColor
    }
    
    private var secondaryColor: Color {
        colorPalette?.secondary ?? amberColor.opacity(0.7)
    }
    
    init(book: Book, width: CGFloat, colorPalette: ColorPalette? = nil) {
        self.book = book
        self.width = width
        self.colorPalette = colorPalette
        self._currentPage = State(initialValue: book.currentPage)
    }
    
    private var progress: Double {
        guard let pageCount = book.pageCount, pageCount > 0 else { return 0 }
        return Double(currentPage) / Double(pageCount)
    }
    
    private var displayProgress: Double {
        isDragging ? dragProgress : progress
    }
    
    private var displayPage: Int {
        if isDragging {
            guard let pageCount = book.pageCount else { return 0 }
            return Int(dragProgress * Double(pageCount))
        }
        return currentPage
    }
    
    var body: some View {
        ZStack {
            // EXACT same ambient background from sheet
            ambientBackground
            
            // Main content - made more compact
            VStack(spacing: 24) {
                // Compact version of the hero timeline
                compactHeroTimeline
                
                // Bottom info - exact same as sheet
                bottomInfo
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(width: width, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(primaryColor.opacity(0.1), lineWidth: 1)
        }
    }
    
    // MARK: - Views (EXACT COPIES from AmbientProgressSheet)
    
    private var ambientBackground: some View {
        ZStack {
            // Base dark background - EXACT same as sheet
            Color.black
            
            // Animated gradient that responds to progress - EXACT same as sheet
            RadialGradient(
                colors: [
                    primaryColor.opacity(0.3 * displayProgress),
                    secondaryColor.opacity(0.2 * displayProgress),
                    primaryColor.opacity(0.1 * displayProgress),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
            .animation(.easeInOut(duration: 0.8), value: displayProgress)
            
            // Subtle overlay texture - EXACT same as sheet
            Color.white.opacity(0.02)
        }
    }
    
    private var compactHeroTimeline: some View {
        HStack(spacing: 30) {
            // Progress ring (scaled from 180 to 140 for compact)
            ZStack {
                // Background ring - EXACT same styling
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 140, height: 140)
                
                // Progress ring - EXACT same gradient and styling
                Circle()
                    .trim(from: 0, to: displayProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                primaryColor,
                                secondaryColor,
                                primaryColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: primaryColor.opacity(0.5), radius: 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: displayProgress)
                
                // Center percentage - EXACT same styling
                Text("\(Int(displayProgress * 100))%")
                    .font(.system(size: 32, weight: .thin, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: displayProgress)
            }
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isDragging)
            
            // Interactive timeline bar - positioned vertically
            VStack(spacing: 12) {
                timelineBar
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var timelineBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track - EXACT same as sheet
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 12)
                
                // Progress segments (flowing animation) - EXACT copy from sheet
                HStack(spacing: 2) {
                    ForEach(0..<40, id: \.self) { index in
                        let segmentProgress = Double(index) / 39.0
                        let isActive = segmentProgress <= displayProgress
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                isActive 
                                ? LinearGradient(
                                    colors: [primaryColor, secondaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(1, (geometry.size.width - 78) / 40), // Account for spacing
                                height: 12
                            )
                            .opacity(isActive ? 1.0 : 0.0)
                            .scaleEffect(y: isActive ? 1.0 : 0.3)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.01),
                                value: displayProgress
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Current position indicator - EXACT same as sheet
                if displayProgress > 0.02 {
                    HStack {
                        Spacer()
                            .frame(width: max(0, geometry.size.width * displayProgress - 8))
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .scaleEffect(isDragging ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
                        
                        Spacer()
                    }
                }
            }
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .simultaneousGesture(
            DragGesture(coordinateSpace: .local)
                .onChanged { value in
                    handleTimelineDrag(value: value)
                }
                .onEnded { _ in
                    endTimelineDrag()
                }
        )
        .onTapGesture { location in
            handleTimelineTap(location: location)
        }
    }
    
    private var bottomInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(displayPage)")
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: displayPage)
                
                Text("current page")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let pageCount = book.pageCount {
                    Text("\(pageCount - displayPage)")
                        .font(.system(size: 24, weight: .light, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: displayPage)
                    
                    Text("pages left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1)
                }
            }
        }
    }
    
    // MARK: - Gesture Handling (EXACT COPY from sheet with auto-save added)
    
    private func handleTimelineTap(location: CGPoint) {
        guard let pageCount = book.pageCount else { return }
        
        // Calculate progress based on tap location (assuming timeline width)
        let timelineWidth = width - 200 // Account for ring and padding
        let tapProgress = max(0, min(1, location.x / timelineWidth))
        
        let targetPage = Int(tapProgress * Double(pageCount))
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentPage = targetPage
        }
        
        HapticManager.shared.pageTurn()
        
        // Auto-save immediately
        if targetPage != book.currentPage {
            viewModel.updateBookProgress(book, currentPage: targetPage)
            HapticManager.shared.success()
        }
    }
    
    private func handleTimelineDrag(value: DragGesture.Value) {
        guard let pageCount = book.pageCount else { return }
        
        if !isDragging {
            isDragging = true
            HapticManager.shared.selectionChanged()
        }
        
        // Calculate progress based on drag location
        let timelineWidth = width - 200 // Account for ring and padding
        let dragLocationX = max(0, min(timelineWidth, value.location.x))
        let newProgress = dragLocationX / timelineWidth
        
        dragProgress = newProgress
        
        // Haptic feedback every 5% progress
        let progressPercent = Int(newProgress * 100)
        let currentPercent = Int(progress * 100)
        if abs(progressPercent - currentPercent) >= 5 {
            HapticManager.shared.lightTap()
        }
    }
    
    private func endTimelineDrag() {
        guard let pageCount = book.pageCount else { return }
        
        let targetPage = Int(dragProgress * Double(pageCount))
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentPage = targetPage
            isDragging = false
        }
        
        HapticManager.shared.pageTurn()
        
        // Auto-save immediately
        if targetPage != book.currentPage {
            viewModel.updateBookProgress(book, currentPage: targetPage)
            HapticManager.shared.success()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.11, green: 0.105, blue: 0.102)
            .ignoresSafeArea()
        
        VStack(spacing: 30) {
            Text("Embedded Ambient Progress")
                .font(.title2)
                .foregroundStyle(.white)
            
            EmbeddedAmbientProgress(
                book: {
                    var book = Book(
                        id: "preview",
                        title: "Sample Book",
                        author: "Sample Author",
                        publishedYear: "2024",
                        coverImageURL: nil,
                        isbn: nil,
                        description: nil,
                        pageCount: 354,
                        localId: UUID()
                    )
                    book.currentPage = 127
                    return book
                }(),
                width: 350
            )
            .environmentObject(LibraryViewModel())
        }
        .padding()
    }
}