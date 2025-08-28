import SwiftUI

// MARK: - Refined Onboarding View
struct RefinedOnboardingView: View {
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    @State private var viewOpacity: Double = 0
    @Namespace private var animation
    
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    
    // Pages with book-inspired gradient colors
    private let pages = [
        OnboardingPageData(
            icon: "glass-book-open",
            title: "Welcome to Epilogue",
            subtitle: "Your reading companion",
            description: "A beautiful space to track your reading journey, capture thoughts, and discover insights from your books.",
            gradientColors: [
                Color(red: 1.0, green: 0.55, blue: 0.26),  // Warm amber
                Color(red: 1.0, green: 0.45, blue: 0.16)   // Deep orange
            ]
        ),
        OnboardingPageData(
            icon: "circle-arrow-right",
            title: "Ambient Mode",
            subtitle: "Listen while you read",
            description: "Place your phone nearby and Epilogue listens for your thoughts and questions. No interruption to your reading flow.",
            gradientColors: [
                Color(red: 0.2, green: 0.6, blue: 0.9),  // Ocean blue
                Color(red: 0.3, green: 0.7, blue: 1.0)   // Sky blue
            ]
        ),
        OnboardingPageData(
            icon: "star-sparkle",
            title: "Smart Library",
            subtitle: "Organize beautifully",
            description: "Add books by scanning covers or searching. Your library adapts its colors to each book's cover art.",
            gradientColors: [
                Color(red: 0.6, green: 0.3, blue: 0.9),  // Royal purple
                Color(red: 0.8, green: 0.4, blue: 1.0)   // Lavender
            ]
        ),
        OnboardingPageData(
            icon: "glass-feather",
            title: "Living Notes",
            subtitle: "Never lose a thought",
            description: "Every quote, question, and insight is automatically organized. Rediscover your thoughts exactly when you need them.",
            gradientColors: [
                Color(red: 0.2, green: 0.8, blue: 0.4),  // Emerald green
                Color(red: 0.3, green: 0.9, blue: 0.5)   // Spring green
            ]
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Ambient mode style background - exactly like AmbientChatGradientView
                ambientBackground(for: currentPage)
                    .animation(.easeInOut(duration: 0.8), value: currentPage)
                
                VStack(spacing: 0) {
                    // Header with glass buttons
                    headerView
                        .padding(.top, geometry.safeAreaInsets.top + 20)
                        .padding(.horizontal, 24)
                    
                    // Centered page content
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingPageContent(
                                page: pages[index],
                                geometry: geometry
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: currentPage)
                    
                    // Bottom controls with liquid glass
                    bottomControls
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 30)
                        .padding(.horizontal, 24)
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .opacity(viewOpacity)
        .onAppear {
            haptics.prepare()
            withAnimation(.easeOut(duration: 0.6)) {
                viewOpacity = 1
            }
        }
        .onChange(of: currentPage) { _, _ in
            haptics.impactOccurred()
        }
    }
    
    // MARK: - Ambient Background (Mirrored gradients top and bottom)
    @ViewBuilder
    private func ambientBackground(for pageIndex: Int) -> some View {
        let colors = pages[pageIndex].gradientColors
        
        ZStack {
            // Deep black base
            Color.black
            
            // Top gradient
            LinearGradient(
                stops: [
                    .init(color: colors[0].opacity(0.4), location: 0.0),
                    .init(color: colors[0].opacity(0.25), location: 0.15),
                    .init(color: colors[0].opacity(0.15), location: 0.3),
                    .init(color: Color.clear, location: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Bottom gradient (mirrored)
            LinearGradient(
                stops: [
                    .init(color: colors[1].opacity(0.4), location: 0.0),
                    .init(color: colors[1].opacity(0.25), location: 0.15),
                    .init(color: colors[1].opacity(0.15), location: 0.3),
                    .init(color: Color.clear, location: 0.5)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .ignoresSafeArea()
    }
    // MARK: - Header
    private var headerView: some View {
        HStack {
            // Progress indicators - proper liquid glass
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(index <= currentPage ? 0.9 : 0.3))
                        .frame(width: index == currentPage ? 32 : 24, height: 4)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(
                .regular.tint(.white.opacity(0.05)),
                in: .capsule
            )
            
            Spacer()
            
            // Skip button with proper liquid glass
            Button {
                haptics.impactOccurred()
                completeOnboarding()
            } label: {
                Text("Skip")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .glassEffect(
                        .regular.tint(.white.opacity(0.1)),
                        in: .capsule
                    )
            }
        }
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        HStack {
            Spacer()
            
            // Main CTA - with gradient tint from current page
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentPage += 1
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 28)
                .frame(height: 54)
                .glassEffect(
                    .regular
                        .tint(pages[currentPage].gradientColors[0].opacity(0.3)),
                    in: .rect(cornerRadius: 27)
                )
            }
            
            Spacer()
        }
    }
    
    private func completeOnboarding() {
        haptics.impactOccurred()
        withAnimation(.easeInOut(duration: 0.4)) {
            viewOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onComplete()
        }
    }
}

// MARK: - Page Content (Centered)
struct OnboardingPageContent: View {
    let page: OnboardingPageData
    let geometry: GeometryProxy
    
    @State private var iconOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // CENTERED CONTENT
            VStack(spacing: 40) {
                // Much larger icon without circle background
                Image(page.icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)  // Even larger
                    .foregroundStyle(.white)
                    .opacity(iconOpacity)
                
                // Typography matching note cards
                VStack(spacing: 20) {
                    // Title - clean sans-serif like note cards
                    Text(page.title)
                        .font(.system(size: 38, weight: .regular, design: .default))
                        .foregroundStyle(.white)
                        .offset(y: textOffset)
                    
                    // Subtitle - monospaced like metadata on note cards
                    Text(page.subtitle.uppercased())
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(2)
                        .offset(y: textOffset)
                    
                    // Description - clean sans-serif
                    Text(page.description)
                        .font(.system(size: 17, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .frame(maxWidth: min(geometry.size.width * 0.85, 380))
                        .padding(.top, 8)
                        .offset(y: textOffset)
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
            Spacer() // Extra spacer to center content vertically
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                iconOpacity = 1
                textOffset = 0
            }
        }
    }
}

// MARK: - Data Model
struct OnboardingPageData {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let gradientColors: [Color]
}