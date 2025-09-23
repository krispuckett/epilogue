import SwiftUI
import AVKit

// MARK: - Advanced Onboarding View
struct AdvancedOnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var player: AVPlayer?
    @State private var showContent = false
    @State private var showButton = false
    @State private var viewOpacity: Double = 0
    @State private var pageTransition: Bool = false
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
            videoName: "readEpilogue", // Still using placeholder until you add this video
            videoExtension: "mp4",
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
            videoName: "readEpilogue", // Still using placeholder until you add this video
            videoExtension: "mp4",
            title: "Smart Notes",
            subtitle: "Never lose a thought or quote",
            description: "Every capture is automatically organized by book and session."
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
                    pageContent(for: pages[index])
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
    private func pageContent(for page: OnboardingPage) -> some View {
        switch page.type {
        case .shaderScreen:
            shaderWelcomeScreen(page: page)
        case .video:
            videoScreen(page: page)
        }
    }


    // MARK: - Welcome Screen with Shader
    @ViewBuilder
    private func shaderWelcomeScreen(page: OnboardingPage) -> some View {
        VStack(spacing: 40) {
                Spacer()

                // Larger Metal shader with smooth entrance
                Color.clear
                    .frame(width: 200, height: 200)
                    .overlay(
                        MetalShaderView(isPressed: .constant(false), size: CGSize(width: 200, height: 200))
                            .allowsHitTesting(false)
                    )
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(showContent ? 0 : 30),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )

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
                        .padding(.horizontal, 40)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
                
                // Progress indicator - moved above button
                VStack(spacing: 20) {
                    PageIndicator(currentPage: currentPage, pageCount: pages.count)
                        .opacity(showButton ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.9), value: showButton)
                    
                    // Continue button - closer to safe area
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)) {
                            pageTransition = true
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                completeOnboarding()
                            }

                            // Reset states for next page
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showContent = false
                                showButton = false
                                pageTransition = false
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
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                }
                .padding(.bottom, 40)
            }
            .onAppear {
                // Staggered animations for smooth entrance
                withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2)) {
                    showContent = true
                }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.8)) {
                    showButton = true
                }
            }
        }

    // MARK: - Video Screen with Text
    @ViewBuilder
    private func videoScreen(page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
                // Reduced top spacing - video closer to top
                Spacer()
                    .frame(height: 50)

                // Animated video container
                Group {
                    if let videoName = page.videoName,
                       let videoExt = page.videoExtension,
                       let videoURL = Bundle.main.url(forResource: videoName, withExtension: videoExt) {
                        VideoPlayer(player: player ?? AVPlayer(url: videoURL))
                            .aspectRatio(9.0/16.0, contentMode: .fit)
                            .frame(height: UIScreen.main.bounds.height * 0.55) // Larger video
                            .cornerRadius(24)
                            .padding(.horizontal, 30) // Less padding for larger video
                            .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
                            .disabled(true)
                            .scaleEffect(showContent ? 1 : 0.9)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .blur(radius: showContent ? 0 : 5)
                            .onAppear {
                                // Reset and animate for smooth entrance
                                showContent = false
                                showButton = false

                                withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.1)) {
                                    showContent = true
                                }
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6)) {
                                    showButton = true
                                }
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

                // Reduced spacing between video and text
                Spacer()
                    .frame(height: 30)

                // Text content with entrance animation
                VStack(spacing: 10) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showButton ? 1 : 0)
                        .offset(y: showButton ? 0 : 20)

                    if !page.subtitle.isEmpty {
                        Text(page.subtitle.uppercased())
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(1.5)
                            .opacity(showButton ? 1 : 0)
                            .offset(y: showButton ? 0 : 15)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.05), value: showButton)
                    }

                    Text(page.description)
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 40)
                        .padding(.top, 4)
                        .opacity(showButton ? 1 : 0)
                        .offset(y: showButton ? 0 : 10)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showButton)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 1.05).combined(with: .opacity)
                ))

                Spacer()

                // Progress indicator and navigation
                VStack(spacing: 20) {
                    // Progress indicator - moved above buttons
                    PageIndicator(currentPage: currentPage, pageCount: pages.count)
                        .opacity(showButton ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: showButton)

                    // Navigation buttons
                    HStack {
                        // Back button with animation
                        if currentPage > 0 {
                            Button {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)) {
                                    pageTransition = true
                                    currentPage -= 1

                                    // Reset states
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        showContent = false
                                        showButton = false
                                        pageTransition = false
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 50, height: 50)
                                    .glassEffect(.regular, in: Circle())
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .opacity(showButton ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: showButton)
                        }

                        Spacer()

                        // Continue button with animation
                        Button {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0)) {
                                pageTransition = true
                                if currentPage < pages.count - 1 {
                                    currentPage += 1
                                } else {
                                    completeOnboarding()
                                }

                                // Reset states
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showContent = false
                                    showButton = false
                                    pageTransition = false
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
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .opacity(showButton ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: showButton)
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 40)
            }
        }

    private func completeOnboarding() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            showContent = false
            showButton = false
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            viewOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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