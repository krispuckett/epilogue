import SwiftUI
import SwiftData

/// Ultra-polished scroll timeline reading progress with ambient effects
struct AmbientReadingProgressView: View {
    let book: Book
    var bookModel: BookModel?  // Optional - use SwiftData model for reactive updates when available
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
    @State private var dragStartProgress: Double = 0
    @State private var celebrationPulses: [CelebrationPulse] = []
    @State private var hasTriggeredCompletion: Bool = false

    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.modelContext) private var modelContext

    // Binding to control completion sheet from parent
    @Binding var showCompletionSheet: Bool

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
        // Use bookModel if available (reactive), otherwise fall back to book struct
        if let bookModel = bookModel, let pages = bookModel.pageCount, pages > 0 {
            return Double(bookModel.currentPage) / Double(pages)
        } else {
            guard let totalPages = book.pageCount, totalPages > 0 else { return 0 }
            return Double(book.currentPage) / Double(totalPages)
        }
    }

    var pagesRead: Int {
        return bookModel?.currentPage ?? book.currentPage
    }

    var totalPages: Int {
        return bookModel?.pageCount ?? (book.pageCount ?? 0)
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
            // Reset completion flag if not at 100%
            if progress < 1.0 {
                hasTriggeredCompletion = false
            }

            guard !hasAppeared else { return }
            hasAppeared = true

            generateProgressDots()

            if !reduceMotion {
                withAnimation(.spring(response: 1.5, dampingFraction: 0.8).delay(0.3)) {
                    animatedProgress = progress
                    showMilestones = true
                }

                withAnimation(.easeInOut(duration: 2.5).delay(0.6)) {
                    glowIntensity = progress * 1.5 + 0.2
                }
            } else {
                animatedProgress = progress
                showMilestones = true
                glowIntensity = progress * 1.5 + 0.2
            }
        }
        .onChange(of: progress) { oldProgress, newProgress in
            // Reset if dragging back below 100%
            if oldProgress >= 1.0 && newProgress < 1.0 {
                hasTriggeredCompletion = false
            }
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
            // Ambient background glow - more pronounced as progress increases but fixed size
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            primaryColor.opacity(glowIntensity * 0.2 * (1 + animatedProgress * 2)),  // Intensifies with progress
                            secondaryColor.opacity(glowIntensity * 0.15 * (1 + animatedProgress * 1.5)),
                            accentColor.opacity(glowIntensity * 0.1 * animatedProgress * 2),  // Only appears with progress
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,  // Fixed start radius
                        endRadius: 140  // Fixed end radius
                    )
                )
                .frame(width: 280, height: 280)  // Fixed size - no growth
                .blur(radius: 6)  // Fixed blur for consistency
                .opacity(0.6 + 0.4 * animatedProgress)  // Use opacity to show progress instead of size
            
            // Floating progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 3)
                    .frame(width: 120, height: 120)

                // Animated progress ring - more vibrant but fixed thickness
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                secondaryColor.opacity(0.6 + 0.4 * animatedProgress),
                                primaryColor.opacity(0.8 + 0.2 * animatedProgress),
                                accentColor.opacity(0.7 + 0.3 * animatedProgress)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: primaryColor.opacity(0.3 * animatedProgress), radius: 4, x: 0, y: 0)
                    .shadow(
                        color: primaryColor.opacity(0.6),
                        radius: 4,
                        y: 2
                    )

                // Center progress display - single line
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .contentTransition(.numericText())
            }
            .overlay {
                // Celebration pulse rings - as overlay so they don't affect layout
                // Clean expanding rings with subtle organic wobble via Metal shader
                ForEach(celebrationPulses) { pulse in
                    ZStack {
                        // Soft outer glow
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        primaryColor.opacity(pulse.opacity * 0.7),
                                        secondaryColor.opacity(pulse.opacity * 0.5),
                                        accentColor.opacity(pulse.opacity * 0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 12
                            )
                            .frame(width: 120 * pulse.scale, height: 120 * pulse.scale)
                            .blur(radius: 16)
                            .modifier(WaterWobbleModifier(wobblePhase: pulse.scale * 10.0))

                        // Sharp inner ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        primaryColor.opacity(pulse.opacity * 1.0),
                                        secondaryColor.opacity(pulse.opacity * 0.85),
                                        accentColor.opacity(pulse.opacity * 0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 5
                            )
                            .frame(width: 120 * pulse.scale, height: 120 * pulse.scale)
                            .blur(radius: 2)
                            .modifier(WaterWobbleModifier(wobblePhase: pulse.scale * 12.0))
                    }
                    .allowsHitTesting(false)
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

                Text("Page \(Int(animatedProgress * Double(totalPages))) of \(totalPages)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .contentTransition(.numericText())
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
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    // Set dragging state and store initial progress on first drag
                                    if !isDragging {
                                        isDragging = true
                                        dragStartProgress = animatedProgress
                                        SensoryFeedback.impact(.light)
                                    }

                                    // Calculate new progress based on drag translation from start position
                                    let dragOffset = value.translation.width / geometry.size.width
                                    let newProgress = min(max(0, dragStartProgress + dragOffset), 1.0)
                                    let newPage = Int(Double(totalPages) * newProgress)

                                    // Update progress immediately without animation for instant feedback
                                    animatedProgress = newProgress

                                    // Update the book's current page
                                    viewModel.updateCurrentPage(for: book, to: newPage)

                                    // Subtle haptic on 5% intervals
                                    let oldInterval = Int(progress * 20)
                                    let newInterval = Int(newProgress * 20)
                                    if oldInterval != newInterval {
                                        SensoryFeedback.selection()
                                    }
                                }
                                .onEnded { _ in
                                    // Release dragging state with smooth animation
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isDragging = false
                                    }
                                    SensoryFeedback.impact(.light)

                                    // Check if book was just completed
                                    checkForCompletion(newProgress: animatedProgress)
                                }
                        )
                }
                // Add tap gesture to the entire track area
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Calculate progress from tap location
                    let tapProgress = min(max(0, location.x / geometry.size.width), 1.0)

                    // Update progress instantly
                    animatedProgress = tapProgress

                    // Update the book's current page
                    let newPage = Int(Double(totalPages) * tapProgress)
                    viewModel.updateCurrentPage(for: book, to: newPage)

                    SensoryFeedback.impact(.medium)

                    // Check if book was just completed
                    checkForCompletion(newProgress: tapProgress)
                }
            }
            .frame(height: 24)
        }
    }
    
    @ViewBuilder
    private var readingInsights: some View {
        HStack(spacing: 20) {
            // Pages remaining
            VStack(alignment: .leading, spacing: 4) {
                let currentPage = Int(animatedProgress * Double(totalPages))
                Text("\(totalPages - currentPage)")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .contentTransition(.numericText())

                Text("pages left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            Spacer()

            // Estimated time
            VStack(alignment: .trailing, spacing: 4) {
                let currentPage = Int(animatedProgress * Double(totalPages))
                let remainingMinutes = (totalPages - currentPage) * 2 // ~2 min per page
                let hours = remainingMinutes / 60
                let minutes = remainingMinutes % 60

                Text(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(primaryColor)
                    .contentTransition(.numericText())

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
                glowIntensity = newProgress * 1.5 + 0.2  // More pronounced glow formula

                // Timeline scroll effect
                timelineOffset = -10
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2)) {
                timelineOffset = 0
            }
        } else {
            animatedProgress = newProgress
            glowIntensity = newProgress * 1.5 + 0.2  // More pronounced glow formula
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

    private func checkForCompletion(newProgress: Double) {
        guard newProgress >= 1.0 && !hasTriggeredCompletion else { return }

        hasTriggeredCompletion = true

        // Update current page to total pages (but DON'T change status yet!)
        if let bookModel = bookModel {
            bookModel.currentPage = bookModel.pageCount ?? totalPages
            try? modelContext.save()
        }
        viewModel.updateCurrentPage(for: book, to: totalPages)

        // Success haptic feedback
        SensoryFeedback.success()

        // Trigger celebration animation
        triggerCelebrationPulses()

        // After animation completes: change status and show sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            // Now change status to read
            if let bookModel = bookModel {
                bookModel.readingStatus = ReadingStatus.read.rawValue
                try? modelContext.save()
            }
            viewModel.updateReadingStatus(for: book.id, status: .read)

            // Show completion sheet (controlled by parent via binding)
            showCompletionSheet = true
        }
    }

    private func triggerCelebrationPulses() {
        // Create 5 expanding pulse rings with realistic water-ripple physics
        for i in 0..<5 {
            let delay = Double(i) * 0.15  // Faster succession like real water ripples
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let pulse = CelebrationPulse(id: UUID())
                celebrationPulses.append(pulse)

                // Realistic water physics - each ring loses energy as it travels outward
                let waveNumber = Double(i)
                let baseResponse = 1.8
                let variableResponse = baseResponse + (waveNumber * 0.18)  // Later waves slower
                let variableDamping = 0.38 + (waveNumber * 0.04)           // Progressive energy loss
                let variableScale = 5.0 - (waveNumber * 0.15)              // Later waves don't travel as far

                // Add slight randomness for organic feel
                let randomOffset = Double.random(in: -0.05...0.05)
                let finalResponse = variableResponse + randomOffset

                // Animate with water-like spring physics
                withAnimation(.spring(response: finalResponse, dampingFraction: variableDamping)) {
                    if let index = celebrationPulses.firstIndex(where: { $0.id == pulse.id }) {
                        celebrationPulses[index].scale = variableScale
                        celebrationPulses[index].opacity = 0.0
                    }
                }

                // Remove pulse after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    celebrationPulses.removeAll(where: { $0.id == pulse.id })
                }
            }
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

struct CelebrationPulse: Identifiable {
    let id: UUID
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
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
    @State private var showCompletionSheet = false
    
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
                colorPalette: nil,
                showCompletionSheet: $showCompletionSheet
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
                colorPalette: nil,
                showCompletionSheet: $showCompletionSheet
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