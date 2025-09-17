import SwiftUI

/// Ultra-polished scroll timeline reading progress with ambient effects
struct AmbientReadingProgressView: View {
    let book: Book
    let width: CGFloat
    let showDetailed: Bool
    let colorPalette: ColorPalette?
    
    // MARK: - State Variables
    @State private var animatedProgress: Double = 0
    @State private var glowIntensity: Double = 0
    @State private var timelineOffset: CGFloat = 0
    @State private var showMilestones: Bool = false
    @State private var progressDots: [ProgressDot] = []
    @State private var hasAppeared: Bool = false
    @State private var isDragging: Bool = false
    
    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    // MARK: - Color Properties
    private var primaryColor: Color {
        colorPalette?.primary ?? DesignSystem.Colors.primaryAccent
    }
    
    private var secondaryColor: Color {
        colorPalette?.secondary ?? Color(red: 1.0, green: 0.7, blue: 0.4)
    }
    
    private var accentColor: Color {
        colorPalette?.accent ?? Color(red: 0.9, green: 0.4, blue: 0.15)
    }
    
    // MARK: - Computed Properties
    var progress: Double {
        guard let totalPages = book.pageCount, totalPages > 0 else { return 0 }
        return Double(book.currentPage) / Double(totalPages)
    }
    
    var pagesRead: Int {
        return book.currentPage
    }
    
    var totalPages: Int {
        return book.pageCount ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: showDetailed ? 20 : 12) {
            if showDetailed {
                detailedTimelineView
            } else {
                compactTimelineView
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            
            generateProgressDots()
            
            if !reduceMotion {
                withAnimation(.spring(response: 1.5, dampingFraction: 0.8).delay(0.3)) {
                    animatedProgress = progress
                    showMilestones = true
                }
                
                withAnimation(.easeInOut(duration: 2.5).delay(0.6)) {
                    glowIntensity = progress * 1.2
                }
            } else {
                animatedProgress = progress
                showMilestones = true
                glowIntensity = progress * 1.2
            }
        }
        .onChange(of: progress) { _, newProgress in
            updateProgress(to: newProgress)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var compactTimelineView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Progress stats
            HStack {
                Text("\(pagesRead)")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(primaryColor)
                
                Text("of \(totalPages)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            
            // Compact timeline
            compactTimelineTrack
        }
    }
    
    @ViewBuilder
    private var detailedTimelineView: some View {
        VStack(spacing: 24) {
            // Hero progress display
            heroProgressDisplay
            
            // Advanced timeline with milestones
            advancedTimelineTrack
            
            // Reading insights
            readingInsights
        }
    }
    
    @ViewBuilder
    private var heroProgressDisplay: some View {
        ZStack {
            // Ambient background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            primaryColor.opacity(glowIntensity * 0.3),
                            secondaryColor.opacity(glowIntensity * 0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 8)
            
            // Floating progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 3)
                    .frame(width: 120, height: 120)
                
                // Animated progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                secondaryColor,
                                primaryColor,
                                accentColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .shadow(
                        color: primaryColor.opacity(0.6),
                        radius: 4,
                        y: 2
                    )
                
                // Center progress display
                VStack(spacing: 4) {
                    Text("\(Int(animatedProgress * 100))")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .contentTransition(.numericText())
                    
                    Text("%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var compactTimelineTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Base timeline track
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 4)
                
                // Progress fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                secondaryColor,
                                primaryColor,
                                accentColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * animatedProgress,
                        height: 4
                    )
                    .shadow(
                        color: primaryColor.opacity(0.8),
                        radius: 3,
                        y: 1
                    )
                    .offset(x: timelineOffset)
                
                // No position indicator - timeline shows progress through segments only
            }
        }
        .frame(height: 4)
    }
    
    @ViewBuilder
    private var advancedTimelineTrack: some View {
        VStack(spacing: 12) {
            // Timeline title
            HStack {
                Text("Reading Progress")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))

                Spacer()

                Text("Page \(pagesRead) of \(totalPages)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            // Interactive timeline with slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Base track
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 8)

                    // Segment progress
                    HStack(spacing: 2) {
                        let segmentCount = 40
                        ForEach(0..<segmentCount, id: \.self) { segmentIndex in
                            let segmentProgress = Double(segmentIndex) / Double(segmentCount - 1)
                            let isActive = segmentProgress <= animatedProgress

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    isActive
                                    ? LinearGradient(
                                        colors: [
                                            secondaryColor,
                                            primaryColor,
                                            accentColor
                                        ],
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
                                    width: max(1, (geometry.size.width - CGFloat(segmentCount - 1) * 2) / CGFloat(segmentCount)),
                                    height: 8
                                )
                                .opacity(isActive ? 1.0 : 0.0)
                                .scaleEffect(y: isActive ? 1.0 : 0.3)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(Double(segmentIndex) * 0.01),
                                    value: animatedProgress
                                )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))

                    // Add subtle glow effect
                    if animatedProgress > 0 {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        primaryColor.opacity(0.3),
                                        primaryColor.opacity(0.1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * animatedProgress, height: 8)
                            .blur(radius: 6)
                            .opacity(0.6)
                    }

                    // Stock iOS 26 liquid glass slider thumb
                    Circle()
                        .frame(width: 28, height: 28)
                        .glassEffect(.regular, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
                        .offset(x: (geometry.size.width - 28) * animatedProgress)
                }
                .contentShape(Rectangle()) // Make entire area tappable
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Set dragging state
                            if !isDragging {
                                isDragging = true
                                SensoryFeedback.impact(.light)
                            }

                            let newProgress = min(max(0, value.location.x / geometry.size.width), 1.0)
                            let newPage = Int(Double(totalPages) * newProgress)

                            // Update progress immediately for smooth feedback
                            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.9)) {
                                animatedProgress = newProgress
                            }

                            // Update the book's current page
                            viewModel.updateCurrentPage(for: book, to: newPage)

                            // Subtle haptic on significant changes
                            let progressDiff = abs(newProgress - progress)
                            if progressDiff > 0.05 {
                                SensoryFeedback.selection()
                            }
                        }
                        .onEnded { _ in
                            // Release dragging state
                            isDragging = false
                            SensoryFeedback.impact(.light)
                        }
                )
            }
            .frame(height: 24)
        }
    }
    
    @ViewBuilder
    private var readingInsights: some View {
        HStack(spacing: 20) {
            // Pages remaining
            VStack(alignment: .leading, spacing: 4) {
                Text("\(totalPages - pagesRead)")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
                
                Text("pages left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            
            Spacer()
            
            // Estimated time
            VStack(alignment: .trailing, spacing: 4) {
                let remainingMinutes = (totalPages - pagesRead) * 2 // ~2 min per page
                let hours = remainingMinutes / 60
                let minutes = remainingMinutes % 60
                
                Text(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(primaryColor)
                
                Text("remaining")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Helper Functions
    
    private func updateProgress(to newProgress: Double) {
        if !reduceMotion {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = newProgress
                glowIntensity = newProgress * 1.2
                
                // Timeline scroll effect
                timelineOffset = -10
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2)) {
                timelineOffset = 0
            }
        } else {
            animatedProgress = newProgress
            glowIntensity = newProgress * 1.2
        }
        
        updateProgressDots()
        
        // Trigger haptic feedback for progress changes
        HapticManager.shared.pageTurn()
    }
    
    private func generateProgressDots() {
        progressDots = (0..<7).map { index in
            let position = Double(index) / 6.0
            let isActive = position <= progress
            let isMilestone = [0.25, 0.5, 0.75, 1.0].contains { abs($0 - position) < 0.02 }
            
            return ProgressDot(
                position: position,
                isActive: isActive,
                isMilestone: isMilestone,
                size: isMilestone ? 8 : 4
            )
        }
    }
    
    private func updateProgressDots() {
        for index in progressDots.indices {
            progressDots[index].isActive = progressDots[index].position <= animatedProgress
        }
    }
}

// MARK: - Supporting Types

private struct ProgressDot {
    let position: Double
    var isActive: Bool
    let isMilestone: Bool
    let size: CGFloat
}

// MARK: - Preview

struct AmbientReadingProgressDemo: View {
    @State private var sampleBook: Book = {
        var book = Book(
            id: "sample",
            title: "The Ambient Reader's Guide",
            author: "Timeline Progress",
            publishedYear: "2024",
            coverImageURL: nil,
            isbn: nil,
            description: nil,
            pageCount: 320,
            localId: UUID()
        )
        book.currentPage = 127  // Set some progress for preview
        return book
    }()
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.surfaceBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 50) {
                    // Simplified preview - just show one version
                    compactVersionView
                    detailedVersionView
                    
                }
                .padding(40)
            }
        }
        .environmentObject(LibraryViewModel())
    }
    
    // Extract complex views into computed properties
    private var compactVersionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compact Timeline")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            
            AmbientReadingProgressView(
                book: sampleBook,
                width: 300,
                showDetailed: false,
                colorPalette: nil
            )
            .padding(DesignSystem.Spacing.listItemPadding)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        }
    }
    
    private var detailedVersionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Timeline")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            
            AmbientReadingProgressView(
                book: sampleBook,
                width: 320,
                showDetailed: true,
                colorPalette: nil
            )
            .padding(30)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        }
    }
}

#Preview {
    AmbientReadingProgressDemo()
}