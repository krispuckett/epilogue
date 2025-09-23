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
            // Full-screen video background - scaled to fill
            GeometryReader { geometry in
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
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
            }
            .ignoresSafeArea()


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
            }
            .ignoresSafeArea()

            // Content overlay
            VStack {
                Spacer()

                // Compact Credits Card
                VStack(spacing: 12) {
                    // Title
                    VStack(spacing: 4) {
                        Text("EPILOGUE")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("Your ambient reading companion")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    // Thanks
                    Text("Thanks to beta testers, Perplexity, Apple,\nClaude Code, and readers everywhere.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 4)

                    // Made with soul + Twitter Link
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("Made with soul in")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))

                            Text("Denver, CO")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))

                        Link(destination: URL(string: "https://twitter.com/krispuckett")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "at")
                                    .font(.system(size: 11))
                                Text("krispuckett")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                            }
                            .foregroundStyle(themeManager.currentTheme.primaryAccent)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8) // Much closer to safe area
                .opacity(contentOpacity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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