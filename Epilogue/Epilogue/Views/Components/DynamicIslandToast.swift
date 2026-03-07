import SwiftUI
import SwiftData
import CoreMotion

// MARK: - Dynamic Island Toast

/// A toast that morphs from the Dynamic Island position
/// Supports taller content than standard toasts for rich experiences
struct DynamicIslandToast<Content: View>: View {
    @Binding var isPresented: Bool
    let content: () -> Content

    // Animation state
    @State private var phase: ToastPhase = .hidden
    @State private var contentOpacity: Double = 0

    // Dynamic Island dimensions (iPhone 14 Pro+)
    private let islandWidth: CGFloat = 126
    private let islandHeight: CGFloat = 37
    private let islandTopOffset: CGFloat = 11

    // Toast dimensions
    private let toastWidth: CGFloat = UIScreen.main.bounds.width - 32
    private let toastHeight: CGFloat = 200
    private let cornerRadius: CGFloat = 28

    enum ToastPhase {
        case hidden
        case appearing
        case expanded
        case dismissing
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Dimming layer
                Color.black
                    .opacity(dimmingOpacity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }

                // Toast container
                VStack {
                    toastContainer
                        .frame(width: currentWidth, height: currentHeight)
                        .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(shadowOpacity), radius: 30, y: 15)
                        .opacity(toastOpacity)
                        .offset(y: currentYOffset)
                        .onTapGesture {
                            dismiss()
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, islandTopOffset)
            }
        }
        .ignoresSafeArea()
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                showToast()
            } else if phase != .hidden {
                dismiss()
            }
        }
    }

    // MARK: - Toast Container

    private var toastContainer: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)

            // Content
            content()
                .opacity(contentOpacity)
        }
    }

    // MARK: - Animation Properties

    private var currentWidth: CGFloat {
        switch phase {
        case .hidden:
            return islandWidth
        case .appearing:
            return toastWidth * 0.9
        case .expanded:
            return toastWidth
        case .dismissing:
            return islandWidth
        }
    }

    private var currentHeight: CGFloat {
        switch phase {
        case .hidden:
            return islandHeight
        case .appearing:
            return toastHeight * 0.7
        case .expanded:
            return toastHeight
        case .dismissing:
            return islandHeight
        }
    }

    private var currentCornerRadius: CGFloat {
        switch phase {
        case .hidden, .dismissing:
            return islandHeight / 2
        case .appearing:
            return cornerRadius + 4
        case .expanded:
            return cornerRadius
        }
    }

    private var currentYOffset: CGFloat {
        switch phase {
        case .hidden:
            return 0
        case .appearing:
            return 8
        case .expanded:
            return 16
        case .dismissing:
            return 0
        }
    }

    private var toastOpacity: Double {
        switch phase {
        case .hidden:
            return 0
        case .appearing, .expanded:
            return 1
        case .dismissing:
            return 0
        }
    }

    private var dimmingOpacity: Double {
        switch phase {
        case .hidden, .dismissing:
            return 0
        case .appearing:
            return 0.3
        case .expanded:
            return 0.5
        }
    }

    private var shadowOpacity: Double {
        switch phase {
        case .hidden, .dismissing:
            return 0
        case .appearing:
            return 0.3
        case .expanded:
            return 0.4
        }
    }

    // MARK: - Animation Sequence

    private func showToast() {
        // Phase 1: Start appearing
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            phase = .appearing
        }

        // Phase 2: Expand fully
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                phase = .expanded
            }
        }

        // Phase 3: Fade in content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.25)) {
                contentOpacity = 1
            }
        }
    }

    private func dismiss() {
        SensoryFeedback.light()

        // Fade out content
        withAnimation(.easeIn(duration: 0.15)) {
            contentOpacity = 0
        }

        // Morph back to island
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                phase = .dismissing
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            phase = .hidden
            isPresented = false
        }
    }
}

// MARK: - View Modifier Extension

extension View {
    /// Presents a toast that animates from the Dynamic Island
    /// - Parameters:
    ///   - isPresented: Binding to control toast visibility
    ///   - content: The content to display in the toast
    func dynamicIslandToast<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self

            if isPresented.wrappedValue {
                DynamicIslandToast(isPresented: isPresented, content: content)
                    .transition(.identity)
            }
        }
    }
}

// MARK: - Welcome Back Toast Content

/// Content for the welcome back toast - taller format
struct WelcomeBackToastContent: View {
    let book: BookModel
    let colorPalette: ColorPalette?

    // Subtle motion
    @State private var motionManager = CMMotionManager()
    @State private var pitch: Double = 0
    @State private var roll: Double = 0

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Welcome back"
        }
    }

    private var progressPercent: Double {
        guard let totalPages = book.pageCount, totalPages > 0 else { return 0 }
        return Double(book.currentPage) / Double(totalPages)
    }

    private var bookCoverImage: UIImage? {
        guard let data = book.coverImageData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ZStack {
            // Atmospheric gradient
            atmosphericGradient

            // Content
            HStack(spacing: 20) {
                // Book cover
                if let image = bookCoverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 135)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                        .rotation3DEffect(
                            .degrees(roll * 0.6),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .rotation3DEffect(
                            .degrees(-pitch * 0.6),
                            axis: (x: 1, y: 0, z: 0)
                        )
                }

                // Text content
                VStack(alignment: .leading, spacing: 8) {
                    Text(greeting)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    Text(book.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(book.author)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    // Progress
                    progressBar
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: roll * 0.3, y: pitch * 0.3)
            }
            .padding(20)
        }
        .onAppear {
            setupMotion()
        }
        .onDisappear {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    // MARK: - Atmospheric Gradient

    private var atmosphericGradient: some View {
        Group {
            if let palette = colorPalette {
                let colors = [palette.primary, palette.secondary, palette.accent, palette.background]
                let enhanced = colors.map { enhanceColor($0) }

                ZStack {
                    LinearGradient(
                        stops: [
                            .init(color: enhanced[0].opacity(0.9), location: 0.0),
                            .init(color: enhanced[1].opacity(0.6), location: 0.35),
                            .init(color: enhanced[2].opacity(0.4), location: 0.65),
                            .init(color: enhanced[3].opacity(0.3), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [enhanced[2].opacity(0.35), Color.clear],
                        center: .topTrailing,
                        startRadius: 10,
                        endRadius: 180
                    )

                    Color.black.opacity(0.15)
                }
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.15, blue: 0.3),
                        Color(red: 0.15, green: 0.12, blue: 0.25),
                        Color(red: 0.1, green: 0.1, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let enhancedSaturation = min(saturation * 1.3, 1.0)
        let enhancedBrightness = max(brightness, 0.4)

        return Color(hue: Double(hue), saturation: Double(enhancedSaturation), brightness: Double(enhancedBrightness))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.9), .white.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * progressPercent, 4), height: 4)
                }
            }
            .frame(height: 4)

            Text("\(Int(progressPercent * 100))% complete")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Motion

    private func setupMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion = motion else { return }

            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.9)) {
                pitch = motion.attitude.pitch * 5
                roll = motion.attitude.roll * 5
            }
        }
    }
}

// MARK: - Welcome Back Toast View

/// Complete welcome back toast with data loading
struct WelcomeBackToast: View {
    @Binding var isPresented: Bool
    let book: BookModel

    @State private var colorPalette: ColorPalette?

    var body: some View {
        WelcomeBackToastContent(book: book, colorPalette: colorPalette)
            .task {
                await extractColors()
            }
    }

    private func extractColors() async {
        guard let imageData = book.coverImageData,
              let image = UIImage(data: imageData) else { return }

        let extractor = OKLABColorExtractor()
        if let palette = try? await extractor.extractPalette(from: image, imageSource: "welcome_toast") {
            await MainActor.run {
                colorPalette = palette
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContainer: View {
        @State private var showToast = true

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    Button("Show Toast") {
                        showToast = true
                    }
                    .foregroundStyle(.white)
                }
            }
            .dynamicIslandToast(isPresented: $showToast) {
                // Mock content
                HStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 90, height: 135)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Good evening")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))

                        Text("The Brothers Karamazov")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Fyodor Dostoevsky")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))

                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: 4)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .blue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
    }

    return PreviewContainer()
}
