import SwiftUI
import RealityKit
import SwiftData
import Combine

// MARK: - The Reading Room
// An immersive 3D space where you can interact with your books

struct ReadingRoomView: View {
    @Query(sort: \BookModel.dateAdded, order: .reverse) private var allBooks: [BookModel]
    @StateObject private var bookManager = InteractiveBookManager()

    // Scene state
    @State private var sceneRoot: Entity?
    @State private var isLoading = true
    @State private var currentPalette: ColorPalette?

    // Gesture state
    @State private var isDragging = false
    @State private var draggedBook: InteractiveBookEntity?
    @State private var dragOffset: SIMD3<Float> = .zero
    @State private var lastDragPosition: CGPoint = .zero

    // Camera/rotation
    @State private var sceneRotation: Float = 0
    @State private var targetRotation: Float = 0
    @State private var autoRotate = true

    // UI State
    @State private var showControls = true

    // Animation
    @State private var floatPhase: Float = 0
    @State private var dustMotes: [Entity] = []

    private let colorExtractor = OKLABColorExtractor()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Atmospheric background
                atmosphericBackground
                    .ignoresSafeArea()

                // 3D Scene
                RealityView { content in
                    let scene = await createScene()
                    sceneRoot = scene
                    content.add(scene)
                } update: { content in
                    updateScene()
                }
                .gesture(combinedGestures)

                // UI Overlay
                VStack {
                    headerView
                        .padding(.top, 60)

                    Spacer()

                    if let selected = bookManager.selectedBook {
                        selectedBookInfo(selected)
                    }

                    controlsView
                        .padding(.bottom, 40)
                }
                .opacity(showControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showControls)

                // Loading overlay
                if isLoading {
                    loadingView
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAutoRotation()
        }
        .preferredColorScheme(.dark)
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
    }

    // MARK: - Gestures

    private var combinedGestures: some Gesture {
        SimultaneousGesture(
            dragGesture,
            SimultaneousGesture(tapGesture, rotationGesture)
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if !isDragging {
                    // Start drag - try to pick up a book
                    isDragging = true
                    autoRotate = false

                    // In a real implementation, we'd raycast to find which book
                    // For now, move the selected book
                    if let selected = bookManager.selectedBook {
                        draggedBook = selected
                        selected.enableDynamicPhysics()
                        SensoryFeedback.light()  // Pick up feel
                    }
                }

                if let book = draggedBook {
                    // Convert screen drag to 3D movement
                    let deltaX = Float(value.translation.width) * 0.002
                    let deltaY = Float(-value.translation.height) * 0.002

                    book.root.position.x += deltaX - dragOffset.x
                    book.root.position.y += deltaY - dragOffset.y
                    dragOffset = SIMD3<Float>(deltaX, deltaY, 0)
                } else {
                    // No book selected - rotate scene
                    let delta = Float(value.translation.width) * 0.005
                    targetRotation = sceneRotation + delta
                }
            }
            .onEnded { value in
                isDragging = false
                dragOffset = .zero

                if let book = draggedBook {
                    // Apply throw velocity based on gesture
                    let velocityX = Float(value.velocity.width) * 0.0005
                    let velocityY = Float(-value.velocity.height) * 0.0005

                    // Check if this was a throw (high velocity)
                    let speed = sqrt(velocityX * velocityX + velocityY * velocityY)
                    if speed > 0.1 {
                        SensoryFeedback.medium()  // Throw feel
                    } else {
                        SensoryFeedback.soft()    // Gentle drop
                    }

                    book.applyImpulse(
                        SIMD3<Float>(velocityX, velocityY, 0),
                        torque: SIMD3<Float>(
                            Float.random(in: -0.5...0.5),
                            Float.random(in: -0.5...0.5),
                            Float.random(in: -0.5...0.5)
                        )
                    )
                    draggedBook = nil

                    // Re-enable kinematic after settling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        book.enableKinematicPhysics()
                    }
                } else {
                    sceneRotation = targetRotation
                }

                // Resume auto-rotation after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    autoRotate = true
                }
            }
    }

    private var tapGesture: some Gesture {
        TapGesture(count: 1)
            .onEnded {
                if let selected = bookManager.selectedBook {
                    // If book is open, close it. Otherwise toggle open
                    if selected.isOpen {
                        selected.close()
                        SensoryFeedback.soft()  // Soft thud for closing
                    } else {
                        selected.open()
                        SensoryFeedback.medium()  // Satisfying open feel
                    }
                } else {
                    // Select first book if none selected
                    if let first = bookManager.books.first {
                        bookManager.selectBook(first)
                        SensoryFeedback.light()
                    }
                }
            }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard let selected = bookManager.selectedBook, selected.isOpen else { return }

                let horizontalSwipe = abs(value.translation.width) > abs(value.translation.height)
                guard horizontalSwipe else { return }

                if value.translation.width < -50 {
                    // Swipe left - next page
                    if selected.currentPage < selected.totalPages - 1 {
                        selected.flipToNextPage()
                        // Page turn feel - light crisp tap
                        SensoryFeedback.selection()
                    }
                } else if value.translation.width > 50 {
                    // Swipe right - previous page
                    if selected.currentPage > 0 {
                        selected.flipToPreviousPage()
                        SensoryFeedback.selection()
                    }
                }
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                if let book = bookManager.selectedBook {
                    let rotation = Float(angle.radians)
                    book.root.orientation = simd_quatf(angle: rotation, axis: SIMD3<Float>(0, 1, 0))
                }
            }
    }

    // MARK: - Scene

    @MainActor
    private func createScene() async -> Entity {
        let root = Entity()

        // Lighting setup
        addLighting(to: root)

        // Add ground plane (invisible, for physics)
        addGroundPlane(to: root)

        // Create single book - the most recently added or currently reading
        if let bookToShow = allBooks.first {
            let bookEntity = await bookManager.createBook(from: bookToShow)
            root.addChild(bookEntity.root)

            // Center the book, slightly tilted for drama
            bookEntity.root.position = SIMD3<Float>(0, 0, 0)
            bookEntity.root.orientation = simd_quatf(angle: 0.1, axis: SIMD3<Float>(0, 1, 0))

            // Select it
            bookManager.selectBook(bookEntity)

            // Extract palette for background
            await extractPalette(from: bookToShow)
        }

        // Add atmospheric dust motes
        addDustMotes(to: root)

        isLoading = false
        return root
    }

    private func addDustMotes(to root: Entity) {
        let moteCount = 40

        // Tiny glowing sphere for dust mote
        let moteMesh = MeshResource.generateSphere(radius: 0.002)

        for _ in 0..<moteCount {
            let mote = Entity()

            // Subtle golden/warm glow material
            var material = UnlitMaterial()
            let brightness = Float.random(in: 0.4...0.8)
            material.color = .init(tint: UIColor(
                red: CGFloat(brightness),
                green: CGFloat(brightness * 0.9),
                blue: CGFloat(brightness * 0.7),
                alpha: CGFloat(Float.random(in: 0.3...0.6))
            ))

            mote.components.set(ModelComponent(mesh: moteMesh, materials: [material]))

            // Random position in the scene volume
            mote.position = SIMD3<Float>(
                Float.random(in: -1.5...1.5),
                Float.random(in: -0.5...0.8),
                Float.random(in: -1.5...1.5)
            )

            root.addChild(mote)
            dustMotes.append(mote)
        }
    }

    private func addLighting(to root: Entity) {
        // Key light - main dramatic light from upper right
        let keyLight = Entity()
        var keyComponent = PointLightComponent()
        keyComponent.intensity = 150000
        keyComponent.attenuationRadius = 20
        keyComponent.color = .init(white: 1.0, alpha: 1.0)
        keyLight.components.set(keyComponent)
        keyLight.position = SIMD3<Float>(2.5, 2.5, 3.5)
        root.addChild(keyLight)

        // Fill light - softer from left
        let fillLight = Entity()
        var fillComponent = PointLightComponent()
        fillComponent.intensity = 60000
        fillComponent.attenuationRadius = 18
        fillComponent.color = .init(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)  // Slightly cool
        fillLight.components.set(fillComponent)
        fillLight.position = SIMD3<Float>(-2.5, 1.5, 2.5)
        root.addChild(fillLight)

        // Rim light - creates edge definition from behind
        let rimLight = Entity()
        var rimComponent = PointLightComponent()
        rimComponent.intensity = 40000
        rimComponent.attenuationRadius = 15
        rimComponent.color = .init(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)  // Slightly warm
        rimLight.components.set(rimComponent)
        rimLight.position = SIMD3<Float>(0, 2, -3)
        root.addChild(rimLight)

        // Bottom accent - subtle uplight for drama
        let bottomLight = Entity()
        var bottomComponent = PointLightComponent()
        bottomComponent.intensity = 25000
        bottomComponent.attenuationRadius = 12
        bottomLight.components.set(bottomComponent)
        bottomLight.position = SIMD3<Float>(0, -1.5, 1.5)
        root.addChild(bottomLight)

        // Ambient fill from front-center
        let ambientLight = Entity()
        var ambientComponent = PointLightComponent()
        ambientComponent.intensity = 30000
        ambientComponent.attenuationRadius = 25
        ambientLight.components.set(ambientComponent)
        ambientLight.position = SIMD3<Float>(0, 0.5, 4)
        root.addChild(ambientLight)
    }

    private func addGroundPlane(to root: Entity) {
        let ground = Entity()
        ground.name = "ground"

        // Invisible collision plane
        let groundShape = ShapeResource.generateBox(width: 10, height: 0.01, depth: 10)
        ground.components.set(CollisionComponent(shapes: [groundShape]))

        var physicsBody = PhysicsBodyComponent()
        physicsBody.mode = .static
        ground.components.set(physicsBody)

        ground.position = SIMD3<Float>(0, -0.3, 0)
        root.addChild(ground)
    }

    private func updateScene() {
        guard let root = sceneRoot else { return }

        // Smooth rotation interpolation
        sceneRotation += (targetRotation - sceneRotation) * 0.1

        // Auto-rotate when not interacting
        if autoRotate && !isDragging {
            targetRotation += 0.0008  // Slower rotation
        }

        // Apply rotation to scene
        root.orientation = simd_quatf(angle: sceneRotation, axis: SIMD3<Float>(0, 1, 0))

        // Update floating phase
        floatPhase += 0.02

        // Animate books with subtle floating motion
        for (index, book) in bookManager.books.enumerated() {
            let phaseOffset = Float(index) * 0.5
            let floatY = sin(floatPhase + phaseOffset) * 0.008
            let floatX = cos(floatPhase * 0.7 + phaseOffset) * 0.003

            // Only apply floating when not being dragged
            if draggedBook?.bookId != book.bookId {
                book.root.position.y += floatY * 0.1
                book.root.position.x += floatX * 0.1
            }
        }

        // Animate dust motes
        for (index, mote) in dustMotes.enumerated() {
            let phase = floatPhase * 0.3 + Float(index) * 0.8
            mote.position.y += sin(phase) * 0.0003
            mote.position.x += cos(phase * 0.7) * 0.0002

            // Slowly drift upward and reset
            mote.position.y += 0.0001
            if mote.position.y > 0.8 {
                mote.position.y = -0.5
                mote.position.x = Float.random(in: -1.5...1.5)
                mote.position.z = Float.random(in: -1.5...1.5)
            }
        }
    }

    private func extractPalette(from book: BookModel) async {
        var image: UIImage?
        if let data = book.coverImageData {
            image = UIImage(data: data)
        } else if let urlString = book.coverImageURL, let url = URL(string: urlString) {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                image = UIImage(data: data)
            }
        }

        if let img = image {
            currentPalette = try? await colorExtractor.extractPalette(from: img, imageSource: book.title)
        }
    }

    // MARK: - Auto Rotation

    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            // Animation handled in updateScene
        }
    }

    // MARK: - Views

    private var atmosphericBackground: some View {
        Group {
            if let palette = currentPalette {
                BookAtmosphericGradientView(
                    colorPalette: palette,
                    intensity: 0.85,
                    audioLevel: 0
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.04, blue: 0.12),
                        Color.black,
                        Color(red: 0.04, green: 0.08, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .animation(.easeInOut(duration: 0.8), value: currentPalette?.primary)
    }

    private var headerView: some View {
        Text("THE READING ROOM")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(4)
            .foregroundStyle(.white.opacity(0.5))
    }

    private func selectedBookInfo(_ book: InteractiveBookEntity) -> some View {
        VStack(spacing: 8) {
            Text(book.bookTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Label(book.isOpen ? "Open" : "Closed", systemImage: book.isOpen ? "book.fill" : "book.closed.fill")
                Label("Page \(book.currentPage + 1)/\(book.totalPages)", systemImage: "doc.text")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 16)
    }

    private var controlsView: some View {
        VStack(spacing: 6) {
            Text("Tap to open • Swipe to flip pages")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Text("Drag to move • Fling to throw")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text("Entering the reading room...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }
}

// MARK: - Preview

#Preview {
    ReadingRoomView()
}
