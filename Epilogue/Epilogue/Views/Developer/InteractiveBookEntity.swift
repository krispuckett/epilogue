import SwiftUI
import RealityKit
import Combine

// MARK: - Interactive 3D Book Entity
// A fully interactive book with openable covers, page flipping, and physics

@MainActor
final class InteractiveBookEntity {
    // MARK: - Entities
    let root: Entity
    private let spine: Entity
    private let frontCover: Entity
    private let backCover: Entity
    private let pagesBlock: Entity
    private var pageEntities: [Entity] = []

    // MARK: - State
    private(set) var isOpen: Bool = false
    private(set) var currentPage: Int = 0
    private(set) var totalPages: Int = 8
    private var coverOpenProgress: Float = 0
    private var targetCoverProgress: Float = 0

    // MARK: - Book Data
    let bookId: String
    let bookTitle: String
    private var coverTexture: TextureResource?
    private var palette: ColorPalette?

    // MARK: - Dimensions (scaled up for better visibility)
    private let coverWidth: Float = 0.22
    private let coverHeight: Float = 0.32
    private let coverThickness: Float = 0.006
    private let spineWidth: Float = 0.045
    private let pagesWidth: Float = 0.21
    private let pagesHeight: Float = 0.31
    private let pagesDepth: Float = 0.04

    // MARK: - Animation
    private var displayLink: CADisplayLink?
    private let openAngle: Float = -2.6 // ~149 degrees open

    // Page curl animation state
    private var pageFlipProgress: [Int: Float] = [:]
    private var targetPageProgress: [Int: Float] = [:]

    // MARK: - Initialization

    init(bookId: String, title: String, coverImage: UIImage?, palette: ColorPalette?) {
        self.bookId = bookId
        self.bookTitle = title
        self.palette = palette

        // Create entity hierarchy
        root = Entity()
        root.name = "book_\(bookId)"

        spine = Entity()
        spine.name = "spine"

        frontCover = Entity()
        frontCover.name = "frontCover"

        backCover = Entity()
        backCover.name = "backCover"

        pagesBlock = Entity()
        pagesBlock.name = "pages"

        // Build the structure
        root.addChild(spine)
        root.addChild(pagesBlock)
        spine.addChild(frontCover)
        spine.addChild(backCover)

        // Position spine at left edge (pivot point for covers)
        spine.position = SIMD3<Float>(-coverWidth / 2, 0, 0)

        // Build meshes
        buildSpine()
        buildCovers(coverImage: coverImage)
        buildPages()
        buildIndividualPages()

        // Add collision for interaction
        addCollisionComponents()

        // Start animation loop
        startAnimationLoop()
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Build Components

    private func buildSpine() {
        let mesh = MeshResource.generateBox(
            width: spineWidth,
            height: coverHeight,
            depth: pagesDepth + coverThickness * 2,
            cornerRadius: 0.001
        )

        var material = PhysicallyBasedMaterial()
        if let pal = palette {
            material.baseColor = .init(tint: UIColor(pal.primary).darker(by: 0.4))
        } else {
            material.baseColor = .init(tint: UIColor(white: 0.15, alpha: 1.0))
        }
        material.roughness = .init(floatLiteral: 0.3)
        material.metallic = .init(floatLiteral: 0.1)

        let spineVisual = Entity()
        spineVisual.components.set(ModelComponent(mesh: mesh, materials: [material]))
        spine.addChild(spineVisual)
    }

    private func buildCovers(coverImage: UIImage?) {
        let coverMesh = MeshResource.generateBox(
            width: coverWidth,
            height: coverHeight,
            depth: coverThickness,
            cornerRadius: 0.001
        )

        // Front cover material (with book cover texture)
        var frontMaterial = PhysicallyBasedMaterial()
        frontMaterial.roughness = .init(floatLiteral: 0.35)
        frontMaterial.metallic = .init(floatLiteral: 0.0)

        if let image = coverImage, let cgImage = image.cgImage {
            Task { @MainActor in
                if let texture = try? await TextureResource(image: cgImage, options: .init(semantic: .color)) {
                    self.coverTexture = texture
                    let textureParam = MaterialParameters.Texture(texture)
                    var updatedMaterial = PhysicallyBasedMaterial()
                    updatedMaterial.baseColor = .init(tint: .white, texture: textureParam)
                    updatedMaterial.roughness = .init(floatLiteral: 0.35)

                    // Update front cover's visual entity
                    if let visual = self.frontCover.children.first {
                        visual.components.set(ModelComponent(mesh: coverMesh, materials: [updatedMaterial]))
                    }
                }
            }
        }

        // Default front color until texture loads
        if let pal = palette {
            frontMaterial.baseColor = .init(tint: UIColor(pal.primary))
        } else {
            let hue = Float(abs(bookTitle.hashValue) % 360) / 360.0
            frontMaterial.baseColor = .init(tint: UIColor(hue: CGFloat(hue), saturation: 0.6, brightness: 0.5, alpha: 1.0))
        }

        let frontVisual = Entity()
        frontVisual.components.set(ModelComponent(mesh: coverMesh, materials: [frontMaterial]))
        // Position cover so left edge is at spine
        frontVisual.position = SIMD3<Float>(coverWidth / 2 + spineWidth / 2, 0, pagesDepth / 2 + coverThickness / 2)
        frontCover.addChild(frontVisual)

        // Back cover material
        var backMaterial = PhysicallyBasedMaterial()
        if let pal = palette {
            backMaterial.baseColor = .init(tint: UIColor(pal.secondary))
        } else {
            backMaterial.baseColor = .init(tint: UIColor(white: 0.2, alpha: 1.0))
        }
        backMaterial.roughness = .init(floatLiteral: 0.4)

        let backVisual = Entity()
        backVisual.components.set(ModelComponent(mesh: coverMesh, materials: [backMaterial]))
        // Position at back
        backVisual.position = SIMD3<Float>(coverWidth / 2 + spineWidth / 2, 0, -pagesDepth / 2 - coverThickness / 2)
        backCover.addChild(backVisual)
    }

    private func buildPages() {
        let mesh = MeshResource.generateBox(
            width: pagesWidth,
            height: pagesHeight,
            depth: pagesDepth,
            cornerRadius: 0.001
        )

        // Cream colored pages
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1.0))
        material.roughness = .init(floatLiteral: 0.95)

        pagesBlock.components.set(ModelComponent(mesh: mesh, materials: [material]))
        pagesBlock.position = SIMD3<Float>(pagesWidth / 2 - coverWidth / 2 + spineWidth / 2, 0, 0)
    }

    private func buildIndividualPages() {
        // Create individual page sheets for flipping
        let pageThickness: Float = 0.0015
        let pageWidth: Float = pagesWidth - 0.01
        let pageHeight: Float = pagesHeight - 0.01
        let pageSpacing: Float = 0.003

        for i in 0..<totalPages {
            let page = Entity()
            page.name = "page_\(i)"

            // Slight cream color variation for realism
            let colorVariation = Float.random(in: 0.94...0.98)
            var pageMaterial = PhysicallyBasedMaterial()
            pageMaterial.baseColor = .init(tint: UIColor(
                red: CGFloat(colorVariation),
                green: CGFloat(colorVariation - 0.02),
                blue: CGFloat(colorVariation - 0.06),
                alpha: 1.0
            ))
            pageMaterial.roughness = .init(floatLiteral: 0.85)

            let pageMesh = MeshResource.generateBox(
                width: pageWidth,
                height: pageHeight,
                depth: pageThickness,
                cornerRadius: 0.001
            )

            let pageVisual = Entity()
            pageVisual.components.set(ModelComponent(mesh: pageMesh, materials: [pageMaterial]))
            // Offset so page rotates from left edge (spine)
            pageVisual.position = SIMD3<Float>(pageWidth / 2, 0, 0)
            page.addChild(pageVisual)

            // Position page at spine, stacked from front to back
            let zOffset = pagesDepth / 2 - Float(i) * pageSpacing - pageSpacing
            page.position = SIMD3<Float>(-coverWidth / 2 + spineWidth / 2, 0, zOffset)

            // Initialize page flip progress
            pageFlipProgress[i] = 0
            targetPageProgress[i] = 0

            // Hide pages until book is open
            page.isEnabled = false

            root.addChild(page)
            pageEntities.append(page)
        }
    }

    private func addCollisionComponents() {
        // Add collision to root for picking up entire book
        let bookShape = ShapeResource.generateBox(
            width: coverWidth + spineWidth,
            height: coverHeight,
            depth: pagesDepth + coverThickness * 2
        )
        root.components.set(CollisionComponent(shapes: [bookShape]))

        // Add physics body (kinematic by default)
        var physicsBody = PhysicsBodyComponent()
        physicsBody.mode = .kinematic
        physicsBody.massProperties.mass = 0.4
        root.components.set(physicsBody)
    }

    // MARK: - Animation Loop

    private func startAnimationLoop() {
        displayLink = CADisplayLink(target: AnimationTarget(entity: self), selector: #selector(AnimationTarget.update))
        displayLink?.add(to: .main, forMode: .common)
    }

    func updateAnimation() {
        // Smoothly interpolate cover open progress
        let coverSpeed: Float = 0.06
        coverOpenProgress += (targetCoverProgress - coverOpenProgress) * coverSpeed

        // Apply rotation to front cover with slight bounce at end
        let angle = coverOpenProgress * openAngle
        frontCover.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))

        // Show/hide individual pages based on open state
        let shouldShowPages = coverOpenProgress > 0.3
        for page in pageEntities {
            page.isEnabled = shouldShowPages
        }

        // Animate page flips with curl effect
        let pageSpeed: Float = 0.12
        for (index, page) in pageEntities.enumerated() {
            guard let currentProgress = pageFlipProgress[index],
                  let targetProgress = targetPageProgress[index] else { continue }

            // Smooth interpolation
            let newProgress = currentProgress + (targetProgress - currentProgress) * pageSpeed
            pageFlipProgress[index] = newProgress

            // Apply page curl transform
            applyPageCurl(to: page, progress: newProgress, pageIndex: index)
        }
    }

    private func applyPageCurl(to page: Entity, progress: Float, pageIndex: Int) {
        // Page curl using rotation + slight lift + subtle scale
        // Progress: 0 = flat on right, 1 = flipped to left

        // Main rotation around spine (Y axis)
        let flipAngle = progress * -3.1 // ~178 degrees

        // Add a curl effect by rotating slightly on X axis during mid-flip
        let curlPhase = sin(progress * .pi)  // Peaks at 0.5 progress
        let curlAngle = curlPhase * 0.15     // Subtle curl

        // Slight lift during flip
        let liftAmount = curlPhase * 0.02

        // Combine rotations
        let yRotation = simd_quatf(angle: flipAngle, axis: SIMD3<Float>(0, 1, 0))
        let xRotation = simd_quatf(angle: curlAngle, axis: SIMD3<Float>(1, 0, 0))
        page.orientation = yRotation * xRotation

        // Apply lift - adjust Y position
        let baseZ = pagesDepth / 2 - Float(pageIndex) * 0.003 - 0.003
        page.position.y = liftAmount
        page.position.z = baseZ - (progress * pagesDepth * 0.8)  // Move from front to back
    }

    // MARK: - Public Actions

    func open() {
        guard !isOpen else { return }
        isOpen = true
        targetCoverProgress = 1.0
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        targetCoverProgress = 0.0

        // Reset all pages with animation
        resetAllPages()
    }

    func toggle() {
        if isOpen {
            close()
        } else {
            open()
        }
    }

    func flipToNextPage() {
        guard isOpen, currentPage < totalPages - 1 else { return }

        // Set target progress for current page to flip it
        targetPageProgress[currentPage] = 1.0
        currentPage += 1
    }

    func flipToPreviousPage() {
        guard isOpen, currentPage > 0 else { return }

        currentPage -= 1
        // Set target progress back to 0 to unflip
        targetPageProgress[currentPage] = 0.0
    }

    func flipAllPagesForward() {
        guard isOpen else { return }
        for i in 0..<totalPages {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                self.targetPageProgress[i] = 1.0
            }
        }
        currentPage = totalPages - 1
    }

    func resetAllPages() {
        for i in 0..<totalPages {
            targetPageProgress[i] = 0.0
            pageFlipProgress[i] = 0.0
        }
        currentPage = 0
    }

    // MARK: - Physics

    func enableDynamicPhysics() {
        var physicsBody = PhysicsBodyComponent()
        physicsBody.mode = .dynamic
        physicsBody.massProperties.mass = 0.4
        physicsBody.angularDamping = 0.5
        physicsBody.linearDamping = 0.3
        root.components.set(physicsBody)
    }

    func enableKinematicPhysics() {
        var physicsBody = PhysicsBodyComponent()
        physicsBody.mode = .kinematic
        root.components.set(physicsBody)
    }

    func applyImpulse(_ force: SIMD3<Float>, torque: SIMD3<Float> = .zero) {
        var motion = PhysicsMotionComponent()
        motion.linearVelocity = force
        motion.angularVelocity = torque
        root.components.set(motion)
    }
}

// MARK: - Animation Target (for CADisplayLink)

private class AnimationTarget: NSObject {
    weak var entity: InteractiveBookEntity?

    init(entity: InteractiveBookEntity) {
        self.entity = entity
    }

    @objc func update() {
        Task { @MainActor in
            entity?.updateAnimation()
        }
    }
}

// MARK: - Interactive Book Manager
// Manages multiple books in a scene

@MainActor
final class InteractiveBookManager: ObservableObject {
    @Published var books: [InteractiveBookEntity] = []
    @Published var selectedBook: InteractiveBookEntity?

    private let colorExtractor = OKLABColorExtractor()

    func createBook(from bookModel: BookModel) async -> InteractiveBookEntity {
        // Load cover image
        var coverImage: UIImage?
        if let data = bookModel.coverImageData {
            coverImage = UIImage(data: data)
        } else if let urlString = bookModel.coverImageURL, let url = URL(string: urlString) {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                coverImage = UIImage(data: data)
            }
        }

        // Extract palette
        var palette: ColorPalette?
        if let image = coverImage {
            palette = try? await colorExtractor.extractPalette(from: image, imageSource: bookModel.title)
        }

        let book = InteractiveBookEntity(
            bookId: bookModel.id,
            title: bookModel.title,
            coverImage: coverImage,
            palette: palette
        )

        books.append(book)
        return book
    }

    func selectBook(_ book: InteractiveBookEntity?) {
        selectedBook = book
    }

    func removeBook(_ book: InteractiveBookEntity) {
        books.removeAll { $0.bookId == book.bookId }
        book.root.removeFromParent()
    }

    func arrangeInCarousel(radius: Float = 0.8) {
        let angleStep = Float.pi * 2 / Float(max(1, books.count))

        for (index, book) in books.enumerated() {
            let angle = Float(index) * angleStep
            book.root.position = SIMD3<Float>(
                sin(angle) * radius,
                0,
                cos(angle) * radius
            )
            // Face center with slight tilt
            book.root.orientation = simd_quatf(angle: angle + .pi, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    func arrangeInStack() {
        let stackHeight: Float = 0.045  // Larger spacing for bigger books

        for (index, book) in books.enumerated() {
            // Offset stack slightly for visual interest
            let xOffset = Float.random(in: -0.02...0.02)
            let zOffset = Float.random(in: -0.02...0.02)

            book.root.position = SIMD3<Float>(
                xOffset,
                Float(index) * stackHeight - 0.1,  // Start lower
                zOffset
            )
            // Random rotation for natural pile look
            let randomAngle = Float.random(in: -0.15...0.15)
            book.root.orientation = simd_quatf(angle: randomAngle, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    func arrangeInFan() {
        let fanAngle: Float = 0.12
        let spacing: Float = 0.18  // Larger spacing for bigger books
        let centerIndex = Float(books.count - 1) / 2

        for (index, book) in books.enumerated() {
            let offset = Float(index) - centerIndex
            book.root.position = SIMD3<Float>(
                offset * spacing,
                abs(offset) * 0.015 - 0.05,  // Arc with lower center
                offset * 0.03  // Slight depth staggering
            )
            // Rotate to fan out
            let zRotation = simd_quatf(angle: offset * fanAngle, axis: SIMD3<Float>(0, 0, 1))
            let yRotation = simd_quatf(angle: offset * 0.1, axis: SIMD3<Float>(0, 1, 0))
            book.root.orientation = zRotation * yRotation
        }
    }

    func arrangeFloating() {
        for book in books {
            book.root.position = SIMD3<Float>(
                Float.random(in: -0.4...0.4),
                Float.random(in: -0.15...0.25),
                Float.random(in: -0.4...0.4)
            )
            // Random gentle rotation
            let randomAngle = Float.random(in: 0...(.pi * 2))
            let tilt = Float.random(in: -0.3...0.3)
            book.root.orientation = simd_quatf(angle: randomAngle, axis: SIMD3<Float>(0, 1, 0))
                * simd_quatf(angle: tilt, axis: SIMD3<Float>(1, 0, 0))
        }
    }
}
