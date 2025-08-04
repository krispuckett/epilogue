import SwiftUI

struct AmbientReadingProgressView: View { // Opening brace for struct
    let book: Book
    let width: CGFloat
    let showDetailed: Bool
    var isInteractive: Bool = false
    var onProgressChange: ((Double) -> Void)? = nil
    var colorPalette: ColorPalette? = nil
    
    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @StateObject private var accessibility = AccessibilityManager.shared
    
    @State private var animatedProgress: Double = 0
    @State private var segmentAnimations: [Bool] = []
    @State private var milestoneGlows: [Double] = [0.3, 0.3, 0.3, 0.3]
    @State private var positionIndicatorOffset: CGFloat = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var insightsOpacity: Double = 0
    @State private var lastProgress: Double = 0
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var hasAppeared = false
    @State private var celebrationScale: CGFloat = 1.0
    @State private var showMilestoneCelebration = false
    @State private var recentActivity = false
    @State private var readingVelocity: Double = 0
    @State private var lastUpdateTime = Date()
    @State private var chapterMarkers: [Double] = []
    
    // Dynamic colors based on book palette
    private var primaryColor: Color {
        if let palette = colorPalette {
            return palette.primary
        }
        return Color(red: 1.0, green: 0.55, blue: 0.26) // Amber fallback
    }
    
    private var secondaryColor: Color {
        if let palette = colorPalette {
            return palette.secondary
        }
        return primaryColor.opacity(0.8)
    }
    
    // Adaptive segment count based on book length
    private var segmentCount: Int {
        guard let pageCount = book.pageCount else { return 30 }
        switch pageCount {
        case 0..<100: return 20
        case 100..<300: return 30
        case 300..<500: return 40
        default: return 50
        }
    }
    
    private var progress: Double {
        guard let pageCount = book.pageCount, pageCount > 0 else { return 0 }
        return Double(book.currentPage) / Double(pageCount)
    }
    
    private var progressPercentage: Int {
        Int(progress * 100)
    }
    
    private var pagesRemaining: Int {
        guard let pageCount = book.pageCount else { return 0 }
        return max(0, pageCount - book.currentPage)
    }
    
    private var estimatedTimeRemaining: String {
        let pagesPerMinute = 1.5 // Average reading speed
        let minutes = Double(pagesRemaining) / pagesPerMinute
        let hours = Int(minutes / 60)
        let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
    
    var body: some View {
        Group {
            if showDetailed {
                detailedView
            } else {
                compactView
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(voiceOverLabel)
        .accessibilityValue(voiceOverValue)
        .if(isInteractive) { view in
            view.accessibilityHint("Double tap and hold to adjust progress")
                .accessibilityAddTraits(.allowsDirectInteraction)
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: book.currentPage) { oldValue, newValue in
            if oldValue != newValue {
                handleProgressChange(oldValue: oldValue, newValue: newValue)
            }
        }
    }
    
    // MARK: - Compact View
    private var compactView: some View {
        VStack(spacing: 12) {
            // Progress percentage and pages
            HStack {
                Label("\(book.currentPage)/\(book.pageCount ?? 0)", systemImage: "book.pages")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(progressPercentage)%")
                    .font(.system(size: sizeCategory.isAccessibilitySize ? 16 : 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(primaryColor)
                    .shadow(color: primaryColor.opacity(0.5), radius: 2)
            }
            
            // Flowing timeline
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                        .overlay {
                            // Subtle inner glow with book colors
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    LinearGradient(
                                        colors: [primaryColor.opacity(0.1), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .blur(radius: recentActivity && !reduceMotion ? 1 : 0)
                    
                    // Segmented progress
                    HStack(spacing: 1) {
                        ForEach(0..<segmentCount, id: \.self) { index in
                            SegmentView(
                                index: index,
                                totalSegments: segmentCount,
                                progress: isDragging ? dragProgress : animatedProgress,
                                isAnimated: segmentAnimations.indices.contains(index) ? segmentAnimations[index] : false,
                                primaryColor: primaryColor,
                                reduceMotion: reduceMotion
                            )
                            .if(isInteractive) { view in
                                view.onTapGesture {
                                    handleSegmentTap(at: index)
                                }
                            }
                        }
                    }
                    .frame(height: 8)
                    
                    // Milestone markers
                    HStack(spacing: 0) {
                        ForEach([0.25, 0.5, 0.75], id: \.self) { milestone in
                            Spacer()
                                .frame(width: geometry.size.width * milestone - 1)
                            
                            MilestoneMarker(
                                isReached: animatedProgress >= milestone,
                                primaryColor: primaryColor,
                                isCelebrating: showMilestoneCelebration && Int(milestone * 100) == progressPercentage
                            )
                            .scaleEffect(showMilestoneCelebration && Int(milestone * 100) == progressPercentage ? celebrationScale : 1.0)
                            .accessibilityLabel("\(Int(milestone * 100))% milestone \(animatedProgress >= milestone ? "reached" : "not reached")")
                            
                            if milestone < 0.75 {
                                Spacer()
                            }
                        }
                    }
                    
                    // Floating position indicator
                    Circle()
                        .fill(isDragging ? primaryColor : .white)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .shadow(color: isDragging ? primaryColor : .white.opacity(0.6), radius: isDragging ? 8 : 4)
                        .shadow(color: primaryColor.opacity(0.3), radius: 8)
                        .offset(x: (isDragging ? dragProgress * geometry.size.width : positionIndicatorOffset) - (isDragging ? 8 : 6))
                        .offset(y: isDragging ? -4 : -2)
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                        .animation(reduceMotion ? .linear(duration: 0.2) : SmoothAnimationType.bouncy.animation, value: isDragging)
                }
                .frame(height: 8)
                .onChange(of: geometry.size.width) { _, newWidth in
                    positionIndicatorOffset = newWidth * animatedProgress
                }
                .if(isInteractive) { view in
                    view.gesture(
                        DragGesture()
                            .onChanged { value in
                                let newProgress = min(1.0, max(0, value.location.x / geometry.size.width))
                                dragProgress = newProgress
                                isDragging = true
                                HapticManager.shared.selectionChanged()
                            }
                            .onEnded { value in
                                let finalProgress = min(1.0, max(0, value.location.x / geometry.size.width))
                                handleProgressUpdate(finalProgress)
                                isDragging = false
                            }
                    )
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay {
                    // Ambient glow
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    primaryColor.opacity(0.2),
                                    secondaryColor.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        )
        .onAppear {
            animateProgress()
        }
        .onChange(of: book.currentPage) { oldValue, newValue in
            if oldValue != newValue {
                HapticManager.shared.pageTurn()
                animateProgress()
            }
        }
    }
    
    // MARK: - Detailed View
    private var detailedView: some View {
        VStack(spacing: 24) {
            heroProgressRing
            advancedTimeline
        }
        .onAppear {
            animateProgress()
            animateDetailsAppearance()
        }
        .onChange(of: book.currentPage) { oldValue, newValue in
            if oldValue != newValue {
                HapticManager.shared.pageTurn()
                animateProgress()
                updateMilestoneGlows()
            }
        }
    }
    
    private var heroProgressRing: some View {
        ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                primaryColor.opacity(0.3),
                                primaryColor.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .blur(radius: 20)
                
                // Progress ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 20)
                        .frame(width: 160, height: 160)
                    
                    // Progress arc
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    primaryColor,
                                    primaryColor.opacity(0.8),
                                    primaryColor,
                                    primaryColor.opacity(0.6),
                                    primaryColor
                                ],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: primaryColor, radius: 5)
                    
                    // Center content
                    VStack(spacing: 4) {
                        Text("\(progressPercentage)%")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Text("Complete")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .scaleEffect(ringScale)
                
                // Floating particles
                ForEach(0..<6) { index in
                    Circle()
                        .fill(primaryColor.opacity(0.6))
                        .frame(width: 4, height: 4)
                        .offset(x: 100)
                        .rotationEffect(.degrees(Double(index) * 60 + animatedProgress * 360))
                        .animation(
                            reduceMotion ? nil : .linear(duration: 20).repeatForever(autoreverses: false),
                            value: animatedProgress
                        )
                }
            }
            .frame(height: 240)
    }
    
    private var advancedTimeline: some View {
        VStack(spacing: 20) {
                // Timeline header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reading Timeline")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        
                        Text("Page \(book.currentPage) of \(book.pageCount ?? 0)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Reading insights
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(estimatedTimeRemaining, systemImage: "clock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(primaryColor)
                        
                        Text("\(pagesRemaining) pages left")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .opacity(insightsOpacity)
                }
                
                // Segmented timeline with milestones
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background with gradient
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.white.opacity(0.08),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 12)
                        
                        // Segmented progress bars
                        HStack(spacing: 2) {
                            ForEach(0..<segmentCount, id: \.self) { index in
                                SegmentView(
                                    index: index,
                                    totalSegments: segmentCount,
                                    progress: isDragging ? dragProgress : animatedProgress,
                                    isAnimated: segmentAnimations[index],
                                    primaryColor: primaryColor,
                                    height: 12,
                                    reduceMotion: reduceMotion
                                )
                                .if(isInteractive) { view in
                                    view.onTapGesture {
                                        handleSegmentTap(at: index)
                                    }
                                }
                            }
                        }
                        
                        // Chapter dividers at milestones
                        HStack(spacing: 0) {
                            ForEach([0.25, 0.5, 0.75], id: \.self) { milestone in
                                Spacer()
                                    .frame(width: geometry.size.width * milestone - 10)
                                
                                ChapterDivider(
                                    milestone: milestone,
                                    isReached: animatedProgress >= milestone,
                                    primaryColor: primaryColor,
                                    glowIntensity: milestoneGlows[Int(milestone * 4) - 1]
                                )
                                
                                if milestone < 0.75 {
                                    Spacer()
                                }
                            }
                        }
                        
                        // Floating position indicator
                        VStack(spacing: 0) {
                            Circle()
                                .fill(.white)
                                .frame(width: 16, height: 16)
                                .shadow(color: .white, radius: 8)
                                .shadow(color: primaryColor.opacity(0.5), radius: 12)
                            
                            // Connector line
                            Rectangle()
                                .fill(.white.opacity(0.3))
                                .frame(width: 1, height: 20)
                        }
                        .offset(x: (isDragging ? dragProgress * geometry.size.width : positionIndicatorOffset) - 8)
                        .offset(y: -10)
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                    }
                    .frame(height: 12)
                    .onChange(of: geometry.size.width) { _, newWidth in
                        positionIndicatorOffset = newWidth * animatedProgress
                    }
                    .if(isInteractive) { view in
                        view.gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newProgress = min(1.0, max(0, value.location.x / geometry.size.width))
                                    dragProgress = newProgress
                                    isDragging = true
                                    HapticManager.shared.selectionChanged()
                                }
                                .onEnded { value in
                                    let finalProgress = min(1.0, max(0, value.location.x / geometry.size.width))
                                    handleProgressUpdate(finalProgress)
                                    isDragging = false
                                }
                        )
                    }
                }
                .frame(height: 32)
                
                // Milestone labels
                HStack {
                    Text("Start")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Spacer()
                    
                    Text("25%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(animatedProgress >= 0.25 ? 0.6 : 0.3))
                    
                    Spacer()
                    
                    Text("50%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(animatedProgress >= 0.5 ? 0.6 : 0.3))
                    
                    Spacer()
                    
                    Text("75%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(animatedProgress >= 0.75 ? 0.6 : 0.3))
                    
                    Spacer()
                    
                    Text("End")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.3))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        primaryColor.opacity(0.2),
                                        .white.opacity(0.1),
                                        primaryColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            )
        }
    }
    
    // MARK: - Helper Methods
    private func animateProgress() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            animatedProgress = progress
            positionIndicatorOffset = width * 0.85 * progress
        }
        
        // Animate segments with staggered delay
        for i in 0..<segmentCount {
            let segmentProgress = Double(i) / Double(segmentCount)
            if segmentProgress <= progress {
                let delay = Double(i) * 0.01
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        segmentAnimations[i] = true
                    }
                }
            } else {
                segmentAnimations[i] = false
            }
        }
    }
    
    private func animateDetailsAppearance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            ringScale = 1.0
        }
        
        withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
            insightsOpacity = 1.0
        }
        
        updateMilestoneGlows()
    }
    
    private func updateMilestoneGlows() {
        let milestones = [0.25, 0.5, 0.75, 1.0]
        for (index, milestone) in milestones.enumerated() {
            if progress >= milestone - 0.05 && progress <= milestone + 0.05 {
                withAnimation(.easeInOut(duration: 0.5)) {
                    milestoneGlows[index] = 0.8
                }
                withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
                    milestoneGlows[index] = 0.3
                }
            }
        }
    }
    
    // MARK: - Interaction Handlers
    private func handleSegmentTap(at index: Int) {
        guard isInteractive else { return }
        
        let segmentProgress = Double(index + 1) / Double(segmentCount)
        handleProgressUpdate(segmentProgress)
        
        // Visual feedback
        HapticManager.shared.lightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            segmentAnimations[index] = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                segmentAnimations[index] = true
            }
        }
    }
    
    private func handleProgressUpdate(_ newProgress: Double) {
        guard let pageCount = book.pageCount else { return }
        
        let newPage = Int(newProgress * Double(pageCount))
        
        // Update via callback or directly through viewModel
        if let onProgressChange = onProgressChange {
            onProgressChange(newProgress)
        } else {
            viewModel.updateBookProgress(book, currentPage: newPage)
        }
        
        // Haptic feedback
        HapticManager.shared.pageTurn()
        
        // Update animations
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            animatedProgress = newProgress
            dragProgress = newProgress
        }
    }
    
    // MARK: - New Helper Methods
    private func setupInitialState() {
        // Initialize segment animations array
        segmentAnimations = Array(repeating: false, count: segmentCount)
        
        // Check for recent activity
        if let lastActivity = UserDefaults.standard.object(forKey: "lastReadingActivity_\(book.id)") as? Date {
            recentActivity = Date().timeIntervalSince(lastActivity) < 3600 // Within last hour
        }
        
        // Animate entrance
        if !hasAppeared {
            hasAppeared = true
            withAnimation(reduceMotion ? .linear(duration: 0.3) : SmoothAnimationType.gentle.animation.delay(0.2)) {
                animateProgress()
            }
            
            // Show pick-up animation if recent
            if recentActivity && !reduceMotion {
                showPickUpAnimation()
            }
        }
    }
    
    private func handleProgressChange(oldValue: Int, newValue: Int) {
        // Calculate reading velocity
        let timeDelta = Date().timeIntervalSince(lastUpdateTime)
        let pagesDelta = abs(newValue - oldValue)
        if timeDelta > 0 {
            readingVelocity = Double(pagesDelta) / timeDelta * 60 // Pages per minute
        }
        lastUpdateTime = Date()
        
        // Update recent activity
        UserDefaults.standard.set(Date(), forKey: "lastReadingActivity_\(book.id)")
        recentActivity = true
        
        // Check for milestone celebrations
        checkMilestones(oldProgress: Double(oldValue) / Double(book.pageCount ?? 1),
                       newProgress: Double(newValue) / Double(book.pageCount ?? 1))
        
        // Haptic feedback
        HapticManager.shared.pageTurn()
        
        // Animate progress update
        animateProgress()
    }
    
    private func checkMilestones(oldProgress: Double, newProgress: Double) {
        let milestones = [0.25, 0.5, 0.75, 1.0]
        
        for milestone in milestones {
            if oldProgress < milestone && newProgress >= milestone {
                // Trigger celebration
                celebrateMilestone(milestone)
                break
            }
        }
    }
    
    private func celebrateMilestone(_ milestone: Double) {
        guard !reduceMotion else {
            HapticManager.shared.success()
            return
        }
        
        showMilestoneCelebration = true
        
        // Celebration animation sequence
        withAnimation(SmoothAnimationType.bouncy.animation) {
            celebrationScale = 1.3
        }
        
        withAnimation(SmoothAnimationType.bouncy.animation.delay(0.2)) {
            celebrationScale = 1.0
        }
        
        // Enhanced haptic pattern for milestones
        HapticManager.shared.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            HapticManager.shared.lightTap()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            HapticManager.shared.lightTap()
        }
        
        // Reset celebration state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showMilestoneCelebration = false
        }
    }
    
    private func showPickUpAnimation() {
        // Subtle pulse animation for recent activity
        withAnimation(SmoothAnimationType.gentle.animation.repeatCount(2, autoreverses: true)) {
            positionIndicatorOffset += 5
        }
    }
    
    // MARK: - Accessibility
    private var voiceOverLabel: String {
        "Reading progress timeline for \(book.title)"
    }
    
    private var voiceOverValue: String {
        let percentage = progressPercentage
        let pages = "Page \(book.currentPage) of \(book.pageCount ?? 0)"
        let remaining = "\(pagesRemaining) pages remaining"
        
        var milestoneInfo = ""
        if percentage >= 100 {
            milestoneInfo = ". Book completed!"
        } else if percentage >= 75 {
            milestoneInfo = ". Past 75% milestone"
        } else if percentage >= 50 {
            milestoneInfo = ". Past halfway point"
        } else if percentage >= 25 {
            milestoneInfo = ". Past 25% milestone"
        }
        
        return "\(percentage)% complete. \(pages). \(remaining)\(milestoneInfo)"
    }
} // This SHOULD close the struct but compiler says it's extraneous

// MARK: - View Extension
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Supporting Views
struct SegmentView: View {
    let index: Int
    let totalSegments: Int
    let progress: Double
    let isAnimated: Bool
    let primaryColor: Color
    var height: CGFloat = 8
    
    private var segmentProgress: Double {
        Double(index) / Double(totalSegments)
    }
    
    private var isActive: Bool {
        segmentProgress <= progress
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                isActive && isAnimated ?
                LinearGradient(
                    colors: [
                        primaryColor.opacity(0.9),
                        primaryColor.opacity(0.7)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(
                    colors: [Color.white.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .scaleEffect(isAnimated ? 1.0 : 0.8)
            .opacity(isAnimated ? 1.0 : 0.5)
            .shadow(
                color: isActive && isAnimated ? primaryColor.opacity(0.4) : .clear,
                radius: 2
            )
    }
}

struct MilestoneMarker: View {
    let isReached: Bool
    let primaryColor: Color
    
    var body: some View {
        Circle()
            .fill(isReached ? primaryColor : Color.white.opacity(0.3))
            .frame(width: 2, height: 2)
            .shadow(color: isReached ? primaryColor : .clear, radius: 2)
    }
}

struct ChapterDivider: View {
    let milestone: Double
    let isReached: Bool
    let primaryColor: Color
    let glowIntensity: Double
    
    var body: some View {
        VStack(spacing: 0) {
            // Diamond marker
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                primaryColor.opacity(glowIntensity),
                                primaryColor.opacity(glowIntensity * 0.3),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .blur(radius: 5)
                
                // Diamond shape
                Rectangle()
                    .fill(isReached ? primaryColor : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(45))
                    .overlay {
                        Rectangle()
                            .stroke(
                                isReached ? Color.white.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 0.5
                            )
                            .frame(width: 8, height: 8)
                            .rotationEffect(.degrees(45))
                    }
            }
            
            // Divider line
            Rectangle()
                .fill(isReached ? primaryColor.opacity(0.5) : Color.white.opacity(0.2))
                .frame(width: 1, height: 20)
        }
        .offset(y: -4)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 40) {
            // Compact view
            AmbientReadingProgressView(
                book: Book.mockBook(currentPage: 127, totalPages: 354),
                width: 350,
                showDetailed: false
            )
            
            // Detailed view
            AmbientReadingProgressView(
                book: Book.mockBook(currentPage: 220, totalPages: 354),
                width: 350,
                showDetailed: true
            )
        }
        .padding()
    }
    .environmentObject(LibraryViewModel())
}

// MARK: - Mock Extension for Preview
extension Book {
    static func mockBook(currentPage: Int, totalPages: Int) -> Book {
        var book = Book(
            id: "mock-id",
            title: "Sample Book",
            author: "John Doe",
            publishedYear: "2024",
            coverImageURL: nil,
            isbn: "1234567890",
            description: "A sample book for preview",
            pageCount: totalPages
        )
        book.currentPage = currentPage
        return book
    }
}