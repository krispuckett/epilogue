import SwiftUI

struct AmbientProgressSheet: View {
    let book: Book
    @Binding var isPresented: Bool
    @EnvironmentObject var viewModel: LibraryViewModel
    var colorPalette: ColorPalette? = nil
    
    @State private var currentPage: Int
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    // Floating indicator removed per user request
    @State private var hasUnsavedChanges = false
    
    private let amberColor = DesignSystem.Colors.primaryAccent
    
    private var primaryColor: Color {
        colorPalette?.primary ?? amberColor
    }
    
    private var secondaryColor: Color {
        colorPalette?.secondary ?? amberColor.opacity(0.7)
    }
    
    init(book: Book, isPresented: Binding<Bool>, colorPalette: ColorPalette? = nil) {
        self.book = book
        self._isPresented = isPresented
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
        NavigationStack {
            ZStack {
                // Ambient background gradient
                ambientBackground
                
                // Main content
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Hero timeline - the only interface
                    heroTimelineSection
                    
                    Spacer()
                    
                    // Minimal bottom info
                    bottomInfo
                        .padding(.bottom, 40)
                }
                
                // Floating progress indicator removed per user request
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // Reset to original
                            currentPage = book.currentPage
                        }
                        isPresented = false
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProgress()
                    }
                    .foregroundStyle(primaryColor)
                    .fontWeight(.semibold)
                    .opacity(hasUnsavedChanges ? 1.0 : 0.5)
                    .disabled(!hasUnsavedChanges)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
    
    // MARK: - Views
    
    private var ambientBackground: some View {
        ZStack {
            // Base dark background
            Color.black.ignoresSafeArea()
            
            // Animated gradient that responds to progress
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
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: displayProgress)
            
            // Subtle overlay texture
            Color.white.opacity(0.02)
                .ignoresSafeArea()
        }
    }
    
    private var heroTimelineSection: some View {
        VStack(spacing: 40) {
            // Book title (minimal)
            VStack(spacing: 8) {
                Text(book.title)
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1)
            }
            .padding(.horizontal, 40)
            
            // The hero timeline - main interaction
            interactiveTimeline
                .frame(height: 300)
                .padding(.horizontal, 30)
        }
    }
    
    private var interactiveTimeline: some View {
        VStack(spacing: 30) {
            // Progress ring (visual centerpiece)
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 180, height: 180)
                
                // Progress ring
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
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: primaryColor.opacity(0.5), radius: 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: displayProgress)
                
                // Center percentage
                Text("\(Int(displayProgress * 100))%")
                    .font(.system(size: 32, weight: .thin, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(DesignSystem.Animation.easeStandard, value: displayProgress)
            }
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isDragging)
            
            // Interactive timeline bar
            timelineBar
                .frame(height: 12)
        }
    }
    
    private var timelineBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 12)
                
                // Progress segments (flowing animation)
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
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                
                // Current position indicator
                if displayProgress > 0.02 {
                    HStack {
                        Spacer()
                            .frame(width: max(0, geometry.size.width * displayProgress - 8))
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .scaleEffect(isDragging ? 1.3 : 1.0)
                            .animation(DesignSystem.Animation.springStandard, value: isDragging)
                        
                        Spacer()
                    }
                }
            }
            .contentShape(Rectangle()) // Make entire area tappable
            .simultaneousGesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        handleTimelineDrag(value: value, geometry: geometry)
                    }
                    .onEnded { _ in
                        endTimelineDrag()
                    }
            )
            .onTapGesture { location in
                handleTimelineTap(location: location, geometry: geometry)
            }
        }
    }
    
    private var bottomInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(displayPage)")
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(DesignSystem.Animation.easeQuick, value: displayPage)
                
                Text("current page")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let pageCount = book.pageCount {
                    Text("\(pageCount - displayPage)")
                        .font(.system(size: 24, weight: .light, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .contentTransition(.numericText())
                        .animation(DesignSystem.Animation.easeQuick, value: displayPage)
                    
                    Text("pages left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(1)
                }
            }
        }
        .padding(.horizontal, 40)
    }
    
    // Floating progress indicator removed per user request
    
    // MARK: - Gesture Handling
    
    private func handleTimelineTap(location: CGPoint, geometry: GeometryProxy) {
        guard let pageCount = book.pageCount else { return }
        
        // Use the actual timeline width from GeometryReader
        let timelineWidth = geometry.size.width
        let tapProgress = max(0, min(1, location.x / timelineWidth))
        
        let targetPage = Int(tapProgress * Double(pageCount))
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentPage = targetPage
            hasUnsavedChanges = (targetPage != book.currentPage)
        }
        
        HapticManager.shared.pageTurn()
    }
    
    private func handleTimelineDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let pageCount = book.pageCount else { return }
        
        if !isDragging {
            isDragging = true
            SensoryFeedback.selection()
        }
        
        // Use the actual timeline width from GeometryReader
        let timelineWidth = geometry.size.width
        let dragLocationX = max(0, min(timelineWidth, value.location.x))
        let newProgress = dragLocationX / timelineWidth
        
        dragProgress = newProgress
        
        // Floating indicator removed
        
        // Haptic feedback every 5% progress
        let progressPercent = Int(newProgress * 100)
        let currentPercent = Int(progress * 100)
        if abs(progressPercent - currentPercent) >= 5 {
            SensoryFeedback.light()
        }
    }
    
    private func endTimelineDrag() {
        guard let pageCount = book.pageCount else { return }
        
        let targetPage = Int(dragProgress * Double(pageCount))
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentPage = targetPage
            isDragging = false
            hasUnsavedChanges = (targetPage != book.currentPage)
        }
        
        HapticManager.shared.pageTurn()
    }
    
    // showFloatingIndicator removed per user request
    
    private func saveProgress() {
        viewModel.updateBookProgress(book, currentPage: currentPage)
        hasUnsavedChanges = false
        SensoryFeedback.success()
        
        // Close sheet after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    let previewBook: Book = {
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
    }()
    
    AmbientProgressSheet(
        book: previewBook,
        isPresented: .constant(true),
        colorPalette: nil
    )
    .environmentObject(LibraryViewModel())
}