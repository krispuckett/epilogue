import SwiftUI
import AVKit

// MARK: - Advanced Onboarding View
struct AdvancedOnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var player: AVPlayer?
    @State private var pageAnimationComplete = false
    @State private var viewOpacity: Double = 0
    @State private var pageTransition: Bool = false
    @State private var pageVisibility: [Int: Bool] = [:]
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
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0), value: currentPage)
        }
        .opacity(viewOpacity)
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
                Color.clear
                    .frame(width: 200, height: 200)
                    .overlay(
                        MetalShaderView(isPressed: .constant(false), size: CGSize(width: 200, height: 200))
                            .allowsHitTesting(false)
                    )
                    .scaleEffect(currentPage == index ? 1 : 0.5)
                    .opacity(currentPage == index ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(currentPage == index ? 0 : 30),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
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
                
                // Progress indicator and button - consistent with video screens
                VStack(spacing: 16) {
                    PageIndicator(currentPage: currentPage, pageCount: pages.count)
                        .opacity(currentPage == index ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.9), value: currentPage)
                    
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)) {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                completeOnboarding()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Get Started")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 30)
                        .frame(height: 50)
                        .glassEffect(in: Capsule())
                    }
                    .opacity(currentPage == index ? 1 : 0)
                    .offset(y: currentPage == index ? 0 : 20)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.8), value: currentPage)
                }
                .padding(.bottom, 40)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: currentPage)
        }

    // MARK: - Video Screen with Text
    @ViewBuilder
    private func videoScreen(page: OnboardingPage, index: Int) -> some View {
        ZStack {
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
                        .opacity(currentPage == index ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPage)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 0) // Position right at safe area

                // Animated video container positioned right below safe area
                Group {
                    if let videoName = page.videoName,
                       let videoExt = page.videoExtension,
                       let videoURL = Bundle.main.url(forResource: videoName, withExtension: videoExt) {
                        ZStack {
                            VideoPlayer(player: player ?? AVPlayer(url: videoURL))
                                .aspectRatio(9.0/16.0, contentMode: .fit)
                                .frame(height: UIScreen.main.bounds.height * 0.52) // Larger video
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .disabled(true)
                            
                            // Animated frame overlay
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .frame(height: UIScreen.main.bounds.height * 0.52)
                                .aspectRatio(9.0/16.0, contentMode: .fit)
                                .scaleEffect(currentPage == index ? 1.0 : 1.1)
                                .opacity(currentPage == index ? 1 : 0)
                                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: currentPage)
                        }
                        .padding(.horizontal, 25)
                        .padding(.top, 15)
                        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
                            .scaleEffect(currentPage == index ? 1 : 0.9)
                            .opacity(currentPage == index ? 1 : 0)
                            .offset(y: currentPage == index ? 0 : 50)
                            .blur(radius: currentPage == index ? 0 : 5)
                            .onAppear {
                                if currentPage == index {
                                    let newPlayer = AVPlayer(url: videoURL)
                                    newPlayer.isMuted = false
                                    newPlayer.play()
                                    newPlayer.actionAtItemEnd = .none

                                    NotificationCenter.default.addObserver(
                                        forName: .AVPlayerItemDidPlayToEndTime,
                                        object: newPlayer.currentItem,
                                        queue: .main
                                    ) { _ in
                                        newPlayer.seek(to: .zero)
                                        newPlayer.play()
                                    }

                                    self.player = newPlayer
                                }
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryAccent.opacity(0.3),
                                        Color.black.opacity(0.5)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .aspectRatio(9.0/16.0, contentMode: .fit)
                            .frame(height: UIScreen.main.bounds.height * 0.45)
                            .padding(.horizontal, 40)
                    }
                }
                .transition(.scale.combined(with: .opacity))

                // Reduced spacing due to larger video
                Spacer()
                    .frame(height: 15)

                // Text content with entrance animation
                VStack(spacing: 10) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(currentPage == index ? 1 : 0)
                        .offset(y: currentPage == index ? 0 : 20)

                    if !page.subtitle.isEmpty {
                        Text(page.subtitle.uppercased())
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(1.5)
                            .opacity(currentPage == index ? 1 : 0)
                            .offset(y: currentPage == index ? 0 : 15)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.05), value: currentPage)
                    }

                    Text(page.description)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 30)
                        .padding(.top, 4)
                        .minimumScaleFactor(0.9)
                        .lineLimit(3)
                        .opacity(currentPage == index ? 1 : 0)
                        .offset(y: currentPage == index ? 0 : 10)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: currentPage)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 1.05).combined(with: .opacity)
                ))

                Spacer()
            }
            
            // Fixed position continue button and progress indicator
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // Progress indicator
                    PageIndicator(currentPage: currentPage, pageCount: pages.count)
                        .opacity(currentPage == index ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: currentPage)
                    
                    // Continue button - centered
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)) {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                completeOnboarding()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 30)
                        .frame(height: 50)
                        .glassEffect(.regular, in: Capsule())
                    }
                    .opacity(currentPage == index ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: currentPage)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.4)) {
            viewOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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

// MARK: - Preview
#Preview {
    AdvancedOnboardingView {
        print("Onboarding completed")
    }
    .preferredColorScheme(.dark)
}