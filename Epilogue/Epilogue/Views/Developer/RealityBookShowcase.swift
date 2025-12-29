import SwiftUI
import RealityKit
import SwiftData
import Combine

// MARK: - RealityKit 3D Book Showcase
// Dynamic 3D books with real covers, gradient backs, atmospheric background, and physics

struct RealityBookShowcase: View {
    @Query(sort: \BookModel.dateAdded, order: .reverse) private var books: [BookModel]
    @State private var selectedBookIndex: Int = 0
    @State private var isLoading = true
    @State private var sceneRoot: Entity?
    @State private var rotationAngle: Float = 0
    @State private var autoRotate = true
    @State private var currentPalette: ColorPalette?
    @State private var bookPalettes: [String: ColorPalette] = [:]
    @State private var physicsEnabled = false

    // Gesture state
    @State private var dragRotation: Float = 0
    @State private var lastDragRotation: Float = 0

    private let colorExtractor = OKLABColorExtractor()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Atmospheric gradient background from current book
                atmosphericBackground
                    .ignoresSafeArea()

                // 3D Scene
                RealityView { content in
                    let scene = await createScene()
                    sceneRoot = scene
                    content.add(scene)
                } update: { content in
                    if let root = sceneRoot {
                        let totalRotation = rotationAngle + dragRotation
                        root.orientation = simd_quatf(angle: totalRotation, axis: [0, 1, 0])
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            autoRotate = false
                            let delta = Float(value.translation.width) * 0.008
                            dragRotation = lastDragRotation + delta
                        }
                        .onEnded { _ in
                            lastDragRotation = dragRotation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                autoRotate = true
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            // Double tap to enable physics chaos!
                            withAnimation {
                                physicsEnabled.toggle()
                                if physicsEnabled {
                                    applyPhysicsImpulse()
                                }
                            }
                        }
                )
                .gesture(
                    TapGesture()
                        .onEnded {
                            withAnimation {
                                selectedBookIndex = (selectedBookIndex + 1) % max(1, books.count)
                                updateCurrentPalette()
                            }
                        }
                )

                // UI Overlay
                VStack {
                    // Header
                    headerView
                        .padding(.top, 60)

                    Spacer()

                    // Book info
                    bookInfoOverlay
                        .padding(.bottom, 50)
                }

                // Loading
                if isLoading {
                    loadingView
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAutoRotation()
            Task {
                await preloadBookPalettes()
                updateCurrentPalette()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Atmospheric Background

    private var atmosphericBackground: some View {
        Group {
            if let palette = currentPalette {
                BookAtmosphericGradientView(
                    colorPalette: palette,
                    intensity: 0.9,
                    audioLevel: 0
                )
            } else {
                // Default dark gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.05, blue: 0.15),
                        Color.black,
                        Color(red: 0.05, green: 0.1, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .animation(.easeInOut(duration: 0.8), value: currentPalette?.primary)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 6) {
            Text("YOUR LIBRARY")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.5))

            Text("\(books.count) Books")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Scene Creation

    @MainActor
    private func createScene() async -> Entity {
        let root = Entity()

        // Lighting setup - 3-point lighting for cinematic look
        let keyLight = createPointLight(intensity: 80000, radius: 12, position: [1.5, 1.5, 2])
        let fillLight = createPointLight(intensity: 25000, radius: 10, position: [-1.5, 0.5, 1.5])
        let rimLight = createPointLight(intensity: 15000, radius: 8, position: [0, 1, -1.5])
        let bottomLight = createPointLight(intensity: 10000, radius: 6, position: [0, -1, 0.5])

        root.addChild(keyLight)
        root.addChild(fillLight)
        root.addChild(rimLight)
        root.addChild(bottomLight)

        // Create books in carousel
        let booksToShow = Array(books.prefix(9))
        let angleStep = Float.pi * 2 / Float(max(1, booksToShow.count))
        let radius: Float = 0.45

        for (index, book) in booksToShow.enumerated() {
            let bookEntity = await createBookEntity(book: book, index: index)

            let angle = Float(index) * angleStep
            bookEntity.position = [
                sin(angle) * radius,
                0,
                cos(angle) * radius - 0.25
            ]
            bookEntity.orientation = simd_quatf(angle: angle + .pi, axis: [0, 1, 0])

            root.addChild(bookEntity)
        }

        isLoading = false
        return root
    }

    private func createPointLight(intensity: Float, radius: Float, position: SIMD3<Float>) -> Entity {
        let light = Entity()
        var component = PointLightComponent()
        component.intensity = intensity
        component.attenuationRadius = radius
        light.components.set(component)
        light.position = position
        return light
    }

    @MainActor
    private func createBookEntity(book: BookModel, index: Int) async -> Entity {
        let bookEntity = Entity()
        bookEntity.name = "book_\(index)"

        // Book dimensions
        let width: Float = 0.10
        let height: Float = 0.15
        let depth: Float = 0.018

        let mesh = MeshResource.generateBox(
            width: width,
            height: height,
            depth: depth,
            cornerRadius: 0.001
        )

        // Load cover and extract colors
        let (coverImage, palette) = await loadCoverAndPalette(for: book)

        // FRONT COVER - actual book cover texture
        var frontMaterial = PhysicallyBasedMaterial()
        frontMaterial.roughness = .init(floatLiteral: 0.35)
        frontMaterial.metallic = .init(floatLiteral: 0.0)

        if let image = coverImage, let cgImage = image.cgImage {
            if let texture = try? await TextureResource(image: cgImage, options: .init(semantic: .color)) {
                let textureParam = MaterialParameters.Texture(texture)
                frontMaterial.baseColor = .init(tint: .white, texture: textureParam)
            }
        } else {
            let hue = Float(abs(book.title.hashValue) % 360) / 360.0
            frontMaterial.baseColor = .init(tint: UIColor(hue: CGFloat(hue), saturation: 0.7, brightness: 0.5, alpha: 1.0))
        }

        // BACK COVER - gradient from book's color palette
        var backMaterial = PhysicallyBasedMaterial()
        backMaterial.roughness = .init(floatLiteral: 0.4)
        if let pal = palette {
            backMaterial.baseColor = .init(tint: UIColor(pal.secondary))
        } else {
            backMaterial.baseColor = .init(tint: UIColor(white: 0.2, alpha: 1.0))
        }

        // SPINE - dark with slight sheen
        var spineMaterial = PhysicallyBasedMaterial()
        if let pal = palette {
            spineMaterial.baseColor = .init(tint: UIColor(pal.primary).darker(by: 0.3))
        } else {
            spineMaterial.baseColor = .init(tint: UIColor(white: 0.12, alpha: 1.0))
        }
        spineMaterial.roughness = .init(floatLiteral: 0.3)
        spineMaterial.metallic = .init(floatLiteral: 0.15)

        // PAGES - cream colored
        var pagesMaterial = PhysicallyBasedMaterial()
        pagesMaterial.baseColor = .init(tint: UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0))
        pagesMaterial.roughness = .init(floatLiteral: 0.95)

        // Apply materials: [+X, -X, +Y, -Y, +Z, -Z] = [right, left, top, bottom, front, back]
        let modelComponent = ModelComponent(
            mesh: mesh,
            materials: [
                pagesMaterial,   // right (pages)
                spineMaterial,   // left (spine)
                pagesMaterial,   // top
                pagesMaterial,   // bottom
                frontMaterial,   // front (cover)
                backMaterial     // back
            ]
        )
        bookEntity.components.set(modelComponent)

        // Add physics body (disabled by default)
        var physicsBody = PhysicsBodyComponent()
        physicsBody.mode = .kinematic // Start as kinematic (non-physics)
        physicsBody.massProperties.mass = 0.3
        bookEntity.components.set(physicsBody)

        // Collision shape
        let collisionShape = ShapeResource.generateBox(width: width, height: height, depth: depth)
        bookEntity.components.set(CollisionComponent(shapes: [collisionShape]))

        return bookEntity
    }

    // MARK: - Cover & Palette Loading

    private func loadCoverAndPalette(for book: BookModel) async -> (UIImage?, ColorPalette?) {
        var image: UIImage? = nil

        // Try cached data
        if let data = book.coverImageData {
            image = UIImage(data: data)
        }

        // Try URL
        if image == nil, let urlString = book.coverImageURL, let url = URL(string: urlString) {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                image = UIImage(data: data)
            }
        }

        // Extract palette
        var palette: ColorPalette? = nil
        if let img = image {
            palette = try? await colorExtractor.extractPalette(from: img, imageSource: book.title)
            if let pal = palette {
                bookPalettes[book.id] = pal
            }
        }

        return (image, palette)
    }

    private func preloadBookPalettes() async {
        for book in books.prefix(9) {
            let (_, palette) = await loadCoverAndPalette(for: book)
            if let pal = palette {
                bookPalettes[book.id] = pal
            }
        }
    }

    private func updateCurrentPalette() {
        guard !books.isEmpty else { return }
        let book = books[min(selectedBookIndex, books.count - 1)]
        currentPalette = bookPalettes[book.id]
    }

    // MARK: - Physics

    private func applyPhysicsImpulse() {
        guard let root = sceneRoot else { return }

        for child in root.children {
            guard child.name.hasPrefix("book_") else { continue }

            // Switch to dynamic physics
            var physicsBody = PhysicsBodyComponent()
            physicsBody.mode = .dynamic
            physicsBody.massProperties.mass = 0.3
            child.components.set(physicsBody)

            // Apply random impulse
            let randomForce = SIMD3<Float>(
                Float.random(in: -0.5...0.5),
                Float.random(in: 0.3...0.8),
                Float.random(in: -0.5...0.5)
            )
            let randomTorque = SIMD3<Float>(
                Float.random(in: -0.1...0.1),
                Float.random(in: -0.2...0.2),
                Float.random(in: -0.1...0.1)
            )

            var motion = PhysicsMotionComponent()
            motion.linearVelocity = randomForce
            motion.angularVelocity = randomTorque
            child.components.set(motion)
        }

        // Reset after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task { @MainActor in
                await resetBooks()
            }
        }
    }

    @MainActor
    private func resetBooks() async {
        guard let root = sceneRoot else { return }

        let booksToShow = Array(books.prefix(9))
        let angleStep = Float.pi * 2 / Float(max(1, booksToShow.count))
        let radius: Float = 0.45

        for (index, child) in root.children.enumerated() {
            guard child.name.hasPrefix("book_") else { continue }

            // Reset to kinematic
            var physicsBody = PhysicsBodyComponent()
            physicsBody.mode = .kinematic
            child.components.set(physicsBody)
            child.components.remove(PhysicsMotionComponent.self)

            // Reset position
            let bookIndex = index - 4 // Offset for lights
            if bookIndex >= 0 && bookIndex < booksToShow.count {
                let angle = Float(bookIndex) * angleStep
                child.position = [
                    sin(angle) * radius,
                    0,
                    cos(angle) * radius - 0.25
                ]
                child.orientation = simd_quatf(angle: angle + .pi, axis: [0, 1, 0])
            }
        }

        physicsEnabled = false
    }

    // MARK: - Animation

    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            if autoRotate && !physicsEnabled {
                rotationAngle += 0.002
            }
        }
    }

    // MARK: - UI Overlays

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text("Building your showcase...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }

    private var bookInfoOverlay: some View {
        VStack(spacing: 10) {
            if !books.isEmpty {
                let book = books[min(selectedBookIndex, books.count - 1)]

                Text(book.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(book.author)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                if let pages = book.pageCount, pages > 0 {
                    Text("\(pages) pages")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Divider()
                .background(.white.opacity(0.2))
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Drag to rotate • Tap for next")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))

                Text("Double-tap for physics!")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(physicsEnabled ? .orange : .white.opacity(0.4))
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }
}

// MARK: - UIColor Extension

extension UIColor {
    func darker(by percentage: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(b - percentage, 0), alpha: a)
    }
}

// MARK: - Preview

#Preview {
    RealityBookShowcase()
}
