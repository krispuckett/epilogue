import SwiftUI
import AVKit
import AVFoundation

// MARK: - Advanced Onboarding View
struct AdvancedOnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var players: [Int: AVPlayer] = [:]
    @State private var pageAnimationComplete = false
    @State private var viewOpacity: Double = 0
    @State private var pageTransition: Bool = false
    @State private var pageVisibility: [Int: Bool] = [:]
    @State private var viewBlur: CGFloat = 0
    @StateObject private var themeManager = ThemeManager.shared

    private let pages = [
        OnboardingPage(
            type: .shaderScreen,
            videoName: nil,
            videoExtension: nil,
            title: "Welcome to Epilogue",
            subtitle: "Your Ambient Reading Companion",
            description: "Read naturally, capture everything. Just talk while you read—Epilogue handles quotes, notes, and questions automatically."
        ),
        OnboardingPage(
            type: .video,
            videoName: "onboarding_ambient_mode",
            videoExtension: "mov",
            title: "Ambient Mode",
            subtitle: "Get lost in your book, not your phone",
            description: "Tap the orb and start talking. Epilogue listens while you read—capturing quotes, thoughts, and questions without interrupting your flow."
        ),
        OnboardingPage(
            type: .video,
            videoName: "onboarding_capture",
            videoExtension: "mov",
            title: "Capture Instantly",
            subtitle: "YOUR THOUGHTS, ONE TAP AWAY",
            description: "The plus button is always there. Quote something beautiful, note an insight, or ask a question."
        ),
        OnboardingPage(
            type: .video,
            videoName: "onboarding_library",
            videoExtension: "mov",
            title: "Your Library",
            subtitle: "CURATE YOUR PERSONAL COLLECTION",
            description: "Add books by searching, scanning covers, or importing from Goodreads."
        ),
        OnboardingPage(
            type: .video,
            videoName: "onboarding_session",
            videoExtension: "mov",
            title: "Your Reading Sessions",
            subtitle: "Every conversation preserved",
            description: "Review your thoughts, explore AI insights, and see your reading journey unfold over time."
        )
    ]

    var body: some View {
        ZStack {
            // Permanent ambient gradient background - exactly like LibraryView
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
            
            // Subtle darkening overlay for better readability - exactly like LibraryView
            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
            
            // TabView for swipe navigation
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageContent(for: pages[index], index: index)
                        .tag(index)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)
            
            // Top-right skip button
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Skip →")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                Spacer()
            }
            
            // Static bottom controls - always visible
            VStack {
                Spacer()
                
                HStack(alignment: .center) {
                    // Progress indicators on left
                    PageIndicator(currentPage: currentPage, pageCount: pages.count)
                        .scaleEffect(0.7)
                    
                    Spacer()
                    
                    // Small continue button on right
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)) {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                completeOnboarding()
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 40)
                        .glassEffect(.regular, in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20) // Increased from 10 to give more breathing room
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .opacity(viewOpacity)
        .blur(radius: viewBlur)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                viewOpacity = 1
            }
        }
    }

    @ViewBuilder
    private func pageContent(for page: OnboardingPage, index: Int) -> some View {
        switch page.type {
        case .shaderScreen:
            shaderWelcomeScreen(page: page, index: index)
        case .video:
            videoScreen(page: page, index: index)
        }
    }


    // MARK: - Welcome Screen with Shader
    @ViewBuilder
    private func shaderWelcomeScreen(page: OnboardingPage, index: Int) -> some View {
        VStack(spacing: 40) {
            Spacer()

            // Larger Metal shader with smooth entrance
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.currentTheme.primaryAccent.opacity(0.3),
                                themeManager.currentTheme.primaryAccent.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 20)
                    .scaleEffect(currentPage == index ? 1.2 : 0.8)
                    .opacity(currentPage == index ? 0.6 : 0)
                
                Color.clear
                    .frame(width: 200, height: 200)
                    .overlay(
                        MetalShaderView(isPressed: .constant(false), size: CGSize(width: 200, height: 200))
                            .allowsHitTesting(false)
                    )
                    .scaleEffect(currentPage == index ? 1 : 0.7)
                    .opacity(currentPage == index ? 1 : 0.3)
                    .rotation3DEffect(
                        .degrees(Double(index - currentPage) * 15),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.75), value: currentPage)

            // Content
            VStack(spacing: 20) {
                Text(page.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle.uppercased())
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1.5)

                Text(page.description)
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
                    .minimumScaleFactor(0.9)
                    .lineLimit(4)
            }

            Spacer()
            
            // Extra spacer to account for bottom controls
            Spacer()
                .frame(height: 80)
        }
    }

    // MARK: - Video Screen with Text
    @ViewBuilder
    private func videoScreen(page: OnboardingPage, index: Int) -> some View {
        VStack(spacing: 0) {
            // Top toolbar area with back button
            HStack {
                if currentPage > 0 {
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)) {
                            currentPage -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular, in: Circle())
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20) // Increased to prevent button cutoff

            // Video container - LARGER
            if let videoName = page.videoName,
               let videoExt = page.videoExtension,
               let videoURL = Bundle.main.url(forResource: videoName, withExtension: videoExt) {
                    
                    // Create player if needed
                    let player: AVPlayer = {
                        if let existingPlayer = players[index] {
                            return existingPlayer
                        } else {
                            let newPlayer = AVPlayer(url: videoURL)
                            newPlayer.isMuted = true
                            newPlayer.actionAtItemEnd = .none
                            
                            // Loop video
                            NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: newPlayer.currentItem,
                                queue: .main
                            ) { _ in
                                newPlayer.seek(to: .zero)
                                newPlayer.play()
                            }
                            
                            players[index] = newPlayer
                            return newPlayer
                        }
                    }()
                    
                    // Display video
                    CleanVideoPlayer(player: player)
                        .aspectRatio(9.0/16.0, contentMode: .fit)
                        .frame(height: UIScreen.main.bounds.height * 0.6)
                        .scaleEffect(currentPage == index ? 1 : 0.95)
                        .opacity(currentPage == index ? 1 : 0.8)
                        .offset(y: -48) // Move video up by 48px
                        .onAppear {
                            player.seek(to: .zero)
                            player.play()
                        }
                        .onDisappear {
                            player.pause()
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: currentPage)
                } else {
                    // Fallback if no video
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: UIScreen.main.bounds.height * 0.6)
                        .overlay(
                            Text("Video Preview")
                                .foregroundColor(.white.opacity(0.5))
                        )
                        .offset(y: -48) // Move fallback up by 48px too
                }

                // Text content
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .scaleEffect(currentPage == index ? 1 : 0.9)
                        .opacity(currentPage == index ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.1), value: currentPage)

                    if !page.subtitle.isEmpty {
                        Text(page.subtitle.uppercased())
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(1.5)
                            .scaleEffect(currentPage == index ? 1 : 0.9)
                            .opacity(currentPage == index ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.15), value: currentPage)
                    }

                    Text(page.description)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 30)
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(currentPage == index ? 1 : 0.9)
                        .opacity(currentPage == index ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.2), value: currentPage)
                }
                .padding(.top, -4) // Move text up by 24px (20 - 24 = -4)

                Spacer()
                
                // Extra spacer to account for bottom controls
                Spacer()
                    .frame(height: 80)
            }
        }

    private func completeOnboarding() {
        // Add blur effect during fade out for smoother transition
        withAnimation(.easeOut(duration: 0.5)) {
            viewBlur = 15
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            viewOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

// MARK: - Data Model
struct OnboardingPage {
    enum PageType {
        case shaderScreen
        case video
    }

    let type: PageType
    let videoName: String?
    let videoExtension: String?
    let title: String
    let subtitle: String
    let description: String
}

// MARK: - Page Indicator
struct PageIndicator: View {
    let currentPage: Int
    let pageCount: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentPage)
            }
        }
    }
}

// MARK: - Custom Video Player
struct CleanVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(player: player)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
    
    class PlayerUIView: UIView {
        private let playerLayer = AVPlayerLayer()
        
        init(player: AVPlayer) {
            super.init(frame: .zero)
            
            // Ensure the view itself is transparent
            backgroundColor = .clear
            isOpaque = false
            
            // Configure player layer for transparency
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspect // Use aspect to maintain proper video dimensions
            playerLayer.backgroundColor = UIColor.clear.cgColor
            playerLayer.isOpaque = false
            
            // Add the layer
            layer.addSublayer(playerLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            // Ensure player layer fills the entire view
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}

// MARK: - Preview
#Preview {
    AdvancedOnboardingView {
        print("Onboarding completed")
    }
    .preferredColorScheme(.dark)
}