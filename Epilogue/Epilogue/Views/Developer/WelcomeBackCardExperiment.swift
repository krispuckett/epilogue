import SwiftUI
import SwiftData
import CoreMotion
import Combine

/// Welcome Back Card Experiment
/// A sophisticated personalized greeting card with liquid displacement effects
/// Access from Settings > Developer Options
struct WelcomeBackCardExperiment: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [BookModel]

    // Motion tracking for parallax
    @State private var motionManager = CMMotionManager()
    @State private var pitch: Double = 0
    @State private var roll: Double = 0

    // Animation state
    @State private var time: CGFloat = 0
    @State private var isVisible: Bool = false
    @State private var colorPalette: ColorPalette?

    // Control state
    @State private var showControls: Bool = true
    @State private var shaderIntensity: CGFloat = 0.8
    @State private var shaderScale: CGFloat = 2.5
    @State private var shaderSpeed: CGFloat = 0.4
    @State private var useGyroscope: Bool = true

    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    // Mock data for simulator
    private var mockReadingData: MockReadingData {
        MockReadingData(
            currentBook: currentBookWithCover ?? MockReadingData.sampleBook,
            lastReadDate: Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date(),
            currentPage: 247,
            totalPages: 412,
            readingStreak: 12,
            timeOfDay: Calendar.current.component(.hour, from: Date())
        )
    }

    private var currentBookWithCover: BookModel? {
        books.first(where: { $0.coverImageData != nil && $0.readingStatus == ReadingStatus.currentlyReading.rawValue })
        ?? books.first(where: { $0.coverImageData != nil })
    }

    private var bookCoverImage: UIImage? {
        guard let book = currentBookWithCover,
              let imageData = book.coverImageData else {
            return nil
        }
        return UIImage(data: imageData)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Deep black background
                Color.black
                    .ignoresSafeArea()

                // Main content
                VStack(spacing: 0) {
                    Spacer()

                    // Welcome Back Card
                    welcomeBackCard
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 30)

                    Spacer()

                    // Controls
                    if showControls {
                        controlsPanel
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showControls.toggle()
                        }
                    } label: {
                        Image(systemName: showControls ? "eye.slash" : "eye")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .onAppear {
                setupMotionTracking()
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                    isVisible = true
                }
                extractColors()
            }
            .onDisappear {
                motionManager.stopDeviceMotionUpdates()
            }
            .onReceive(timer) { _ in
                time += 1/60
            }
        }
    }

    // MARK: - Welcome Back Card
    private var welcomeBackCard: some View {
        VStack(spacing: 0) {
            // Card container with liquid effect
            ZStack {
                // Atmospheric background from book
                if let image = bookCoverImage {
                    BookAtmosphericGradientWithImage(image: image)
                        .blur(radius: 30)
                        .layerEffect(
                            ShaderLibrary.liquid_displacement(
                                .boundingRect,
                                .float(time),
                                .float(shaderIntensity),
                                .float(shaderScale),
                                .float(shaderSpeed)
                            ),
                            maxSampleOffset: CGSize(width: 100, height: 100)
                        )
                } else {
                    // Fallback gradient
                    defaultGradient
                        .blur(radius: 30)
                        .layerEffect(
                            ShaderLibrary.liquid_displacement(
                                .boundingRect,
                                .float(time),
                                .float(shaderIntensity),
                                .float(shaderScale),
                                .float(shaderSpeed)
                            ),
                            maxSampleOffset: CGSize(width: 100, height: 100)
                        )
                }

                // Content overlay
                VStack(spacing: 24) {
                    // Greeting
                    VStack(spacing: 8) {
                        Text(mockReadingData.greeting)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(mockReadingData.subGreeting)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .offset(x: useGyroscope ? roll * 8 : 0, y: useGyroscope ? pitch * 8 : 0)

                    // Book info with parallax
                    if let book = currentBookWithCover {
                        VStack(spacing: 16) {
                            // Book cover with 3D effect
                            if let image = bookCoverImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                                    .rotation3DEffect(
                                        .degrees(useGyroscope ? roll * 5 : 0),
                                        axis: (x: 0, y: 1, z: 0)
                                    )
                                    .rotation3DEffect(
                                        .degrees(useGyroscope ? -pitch * 5 : 0),
                                        axis: (x: 1, y: 0, z: 0)
                                    )
                            }

                            // Book title and progress
                            VStack(spacing: 6) {
                                Text(book.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)

                                Text(book.author)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.6))

                                // Progress indicator
                                progressBar
                                    .padding(.top, 8)
                            }
                        }
                        .offset(x: useGyroscope ? roll * 4 : 0, y: useGyroscope ? pitch * 4 : 0)
                    }

                    // Reading streak badge
                    if mockReadingData.readingStreak > 0 {
                        streakBadge
                            .offset(x: useGyroscope ? roll * 2 : 0, y: useGyroscope ? pitch * 2 : 0)
                    }
                }
                .padding(32)
            }
            .frame(width: 320, height: 480)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
            // Apply parallax tilt to entire card
            .rotation3DEffect(
                .degrees(useGyroscope ? roll * 3 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .rotation3DEffect(
                .degrees(useGyroscope ? -pitch * 3 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 4)

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.9), .white.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * mockReadingData.progressPercent, height: 4)
                }
            }
            .frame(height: 4)
            .frame(width: 160)

            Text("\(Int(mockReadingData.progressPercent * 100))% complete")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Streak Badge
    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)

            Text("\(mockReadingData.readingStreak) day streak")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.white.opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Default Gradient
    private var defaultGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.2, green: 0.1, blue: 0.3), location: 0.0),
                .init(color: Color(red: 0.1, green: 0.15, blue: 0.25), location: 0.5),
                .init(color: Color.black, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Controls Panel
    private var controlsPanel: some View {
        VStack(spacing: 16) {
            // Gyroscope toggle
            Toggle(isOn: $useGyroscope) {
                Label("Gyroscope Parallax", systemImage: "gyroscope")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .tint(.white.opacity(0.8))

            Divider()
                .background(Color.white.opacity(0.2))

            // Shader intensity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Displacement Intensity")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.2f", shaderIntensity))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Slider(value: $shaderIntensity, in: 0...2)
                    .tint(.white.opacity(0.8))
            }

            // Shader scale
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Scale")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.1f", shaderScale))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Slider(value: $shaderScale, in: 0.5...5)
                    .tint(.white.opacity(0.8))
            }

            // Shader speed
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Animation Speed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.2f", shaderSpeed))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Slider(value: $shaderSpeed, in: 0...1)
                    .tint(.white.opacity(0.8))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Motion Tracking
    private func setupMotionTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard let motion = motion else { return }

            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                pitch = motion.attitude.pitch * 20
                roll = motion.attitude.roll * 20
            }
        }
    }

    // MARK: - Color Extraction
    private func extractColors() {
        guard let image = bookCoverImage else { return }

        Task {
            let extractor = OKLABColorExtractor()
            if let palette = try? await extractor.extractPalette(from: image, imageSource: "welcome_card") {
                await MainActor.run {
                    colorPalette = palette
                }
            }
        }
    }
}

// MARK: - Mock Reading Data
struct MockReadingData {
    let currentBook: BookModel?
    let lastReadDate: Date
    let currentPage: Int
    let totalPages: Int
    let readingStreak: Int
    let timeOfDay: Int

    var progressPercent: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }

    var greeting: String {
        switch timeOfDay {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<21:
            return "Good evening"
        default:
            return "Welcome back"
        }
    }

    var subGreeting: String {
        let hoursSinceReading = Calendar.current.dateComponents([.hour], from: lastReadDate, to: Date()).hour ?? 0

        if hoursSinceReading < 1 {
            return "Picking up where you left off"
        } else if hoursSinceReading < 24 {
            return "Ready to continue reading?"
        } else if hoursSinceReading < 72 {
            return "It's been a while. Let's read together."
        } else {
            return "Welcome back to your book"
        }
    }

    // Sample book for simulator without data
    static var sampleBook: BookModel? {
        nil // Will show fallback UI
    }
}

#Preview {
    WelcomeBackCardExperiment()
        .modelContainer(for: BookModel.self)
}
