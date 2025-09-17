import SwiftUI
import AVKit

struct CreditsView: View {
    @State private var player: AVPlayer?
    @State private var isVideoLoaded = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    // Animation states
    @State private var titleOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var videoOpacity: Double = 0

    var body: some View {
        ZStack {
            // Theme-appropriate background
            SubtleThemedBackground()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    // Video Section with Glass Card
                    if let player = player {
                        VStack(spacing: 0) {
                            VideoPlayer(player: player)
                                .frame(height: 200)
                                .cornerRadius(16)
                                .opacity(videoOpacity)
                                .onAppear {
                                    player.play()
                                    player.actionAtItemEnd = .none

                                    // Loop the video
                                    NotificationCenter.default.addObserver(
                                        forName: .AVPlayerItemDidPlayToEndTime,
                                        object: player.currentItem,
                                        queue: .main
                                    ) { _ in
                                        player.seek(to: .zero)
                                        player.play()
                                    }
                                }
                        }
                        .padding()
                        .glassEffect(
                            .regular.tint(themeManager.currentTheme.primaryAccent.opacity(0.1)),
                            in: RoundedRectangle(cornerRadius: 24)
                        )
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }

                    // Main Credits Card
                    VStack(spacing: 24) {
                        // Epilogue Logo/Title
                        VStack(spacing: 8) {
                            Text("EPILOGUE")
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(themeManager.currentTheme.primaryAccent)
                                .opacity(titleOpacity)

                            Text("Your AI Reading Companion")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .opacity(titleOpacity)
                        }
                        .padding(.bottom, 8)

                        Divider()
                            .background(themeManager.currentTheme.primaryAccent.opacity(0.3))

                        // Creator Section
                        VStack(spacing: 16) {
                            Text("CREATED BY")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(themeManager.currentTheme.primaryAccent.opacity(0.8))
                                .tracking(2)

                            Text("Kris Puckett")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .opacity(contentOpacity)

                        // Special Thanks Section
                        VStack(spacing: 20) {
                            Text("SPECIAL THANKS")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(themeManager.currentTheme.primaryAccent.opacity(0.8))
                                .tracking(2)
                                .padding(.top, 8)

                            VStack(spacing: 12) {
                                ThanksRow(icon: "heart.fill", text: "Our Beta Testers", subtitle: "For invaluable feedback")
                                ThanksRow(icon: "swift", text: "Swift Community", subtitle: "For amazing tools")
                                ThanksRow(icon: "sparkles", text: "Apple", subtitle: "For iOS 26 & Foundation Models")
                                ThanksRow(icon: "brain", text: "Perplexity", subtitle: "For powerful AI capabilities")
                                ThanksRow(icon: "person.fill", text: "You", subtitle: "For reading with Epilogue")
                            }
                        }
                        .opacity(contentOpacity)

                        Divider()
                            .background(themeManager.currentTheme.primaryAccent.opacity(0.3))

                        // Version & Links
                        VStack(spacing: 16) {
                            Text("VERSION \(appVersion) (\(buildNumber))")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .tracking(1)

                            HStack(spacing: 24) {
                                Link(destination: URL(string: "https://readepilogue.com")!) {
                                    Label("Website", systemImage: "globe")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(themeManager.currentTheme.primaryAccent)
                                }

                                Link(destination: URL(string: "https://twitter.com/readepilogue")!) {
                                    Label("Twitter", systemImage: "at")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(themeManager.currentTheme.primaryAccent)
                                }
                            }
                        }
                        .opacity(contentOpacity)

                        // Made with Love
                        HStack(spacing: 4) {
                            Text("Made with")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))

                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .scaleEffect(contentOpacity)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(1),
                                    value: contentOpacity
                                )

                            Text("in San Francisco")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.top, 8)
                        .opacity(contentOpacity)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                    .glassEffect(
                        .regular.tint(themeManager.currentTheme.primaryAccent.opacity(0.05)),
                        in: RoundedRectangle(cornerRadius: 32)
                    )
                    .padding(.horizontal)

                    // Copyright
                    Text("© 2025 Epilogue. All rights reserved.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 40)
                        .opacity(contentOpacity)
                }
            }
        }
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6), .white.opacity(0.1))
                }
            }
        }
        .onAppear {
            loadVideo()
            animateContent()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func loadVideo() {
        if let videoURL = Bundle.main.url(forResource: "readEpilogue", withExtension: "mp4") {
            player = AVPlayer(url: videoURL)
            player?.isMuted = true // Mute by default for autoplay
            isVideoLoaded = true
        }
    }

    private func animateContent() {
        withAnimation(.easeOut(duration: 0.5)) {
            titleOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            videoOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            contentOpacity = 1
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Supporting Views

struct ThanksRow: View {
    let icon: String
    let text: String
    let subtitle: String
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(themeManager.currentTheme.primaryAccent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CreditsView()
    }
    .preferredColorScheme(.dark)
}