import SwiftUI
import AVKit

struct CreditsView: View {
    @State private var player: AVPlayer?
    @State private var isVideoLoaded = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    // Animation states
    @State private var contentOpacity: Double = 0
    @State private var videoOpacity: Double = 0

    var body: some View {
        ZStack {
            // Full-screen video background
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
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
            } else {
                // Fallback background
                Color.black
                    .ignoresSafeArea()
            }

            // Amber gradient overlay from top to bottom
            VStack {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.clear, location: 0.5),
                        .init(color: themeManager.currentTheme.primaryAccent.opacity(0.15), location: 0.7),
                        .init(color: themeManager.currentTheme.primaryAccent.opacity(0.3), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.6)
                .ignoresSafeArea()
            }

            // Content overlay
            VStack {
                Spacer()

                // Compact Credits Card
                VStack(spacing: 20) {
                    // Title
                    VStack(spacing: 6) {
                        Text("EPILOGUE")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("Your ambient reading companion")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    // Creator
                    VStack(spacing: 4) {
                        Text("by")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))

                        Text("Kris Puckett")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    // Thanks
                    Text("Thanks to beta testers, Perplexity, Apple,\nClaude Code, and readers everywhere.")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    // Twitter Link
                    Link(destination: URL(string: "https://twitter.com/krispuckett")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "at")
                                .font(.system(size: 14))
                            Text("krispuckett")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(themeManager.currentTheme.primaryAccent)
                    }
                    .padding(.top, 4)

                    // Made with soul
                    HStack(spacing: 4) {
                        Text("Made with soul in")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))

                        Text("Denver, CO")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.top, 8)
                }
                .padding(28)
                .frame(maxWidth: .infinity)
                .glassEffect(
                    .regular.tint(Color.black.opacity(0.3)),
                    in: RoundedRectangle(cornerRadius: 24)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .opacity(contentOpacity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.8))
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

// MARK: - Preview

#Preview {
    NavigationStack {
        CreditsView()
    }
    .preferredColorScheme(.dark)
}