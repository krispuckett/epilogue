import SwiftUI
import Combine

// MARK: - Palette State
enum PaletteState: Equatable {
    case hidden
    case appearing
    case visible
    case dismissing
}

// MARK: - Palette Transition Coordinator
@MainActor
final class PaletteTransitionCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var state: PaletteState = .hidden
    @Published private(set) var isKeyboardVisible = false
    @Published private(set) var backdropOpacity: Double = 0
    @Published private(set) var paletteScale: CGFloat = 0.92
    @Published private(set) var paletteOpacity: Double = 0
    @Published private(set) var paletteOffset: CGFloat = 20
    
    // MARK: - Animation Configurations
    private let enterAnimation = Animation.spring(response: 0.35, dampingFraction: 0.85)
    private let exitAnimation = Animation.spring(response: 0.25, dampingFraction: 0.95)
    private let contentAnimation = DesignSystem.Animation.easeQuick
    private let backdropAnimation = DesignSystem.Animation.easeStandard
    
    // MARK: - Timing Constants
    private let keyboardDismissDelay: TimeInterval = 0.05 // 50ms before palette
    private let transitionDebounceInterval: TimeInterval = 0.1
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var transitionTask: Task<Void, Never>?
    private var keyboardObserver: NSObjectProtocol?
    
    init() {
        setupKeyboardObservers()
    }
    
    deinit {
        if let observer = keyboardObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    func show() {
        // Cancel any ongoing transition
        transitionTask?.cancel()
        
        guard state == .hidden || state == .dismissing else { return }
        
        transitionTask = Task { @MainActor in
            // Update state
            state = .appearing
            
            // Show backdrop first
            withAnimation(backdropAnimation) {
                backdropOpacity = 0.3
            }
            
            // Show palette with spring animation
            withAnimation(enterAnimation) {
                paletteScale = 1.0
                paletteOpacity = 1.0
                paletteOffset = 0
            }
            
            // Wait for animation to complete
            try? await Task.sleep(nanoseconds: 350_000_000) // 350ms
            
            guard !Task.isCancelled else { return }
            state = .visible
        }
    }
    
    func dismiss(completion: (() -> Void)? = nil) {
        // Cancel any ongoing transition
        transitionTask?.cancel()
        
        guard state == .visible || state == .appearing else {
            completion?()
            return
        }
        
        transitionTask = Task { @MainActor in
            // Update state
            state = .dismissing
            
            // Dismiss keyboard first if visible
            if isKeyboardVisible {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                              to: nil, from: nil, for: nil)
                
                // Wait for keyboard dismiss delay
                try? await Task.sleep(nanoseconds: UInt64(keyboardDismissDelay * 1_000_000_000))
            }
            
            // Animate palette out
            withAnimation(exitAnimation) {
                paletteScale = 0.92
                paletteOpacity = 0
                paletteOffset = 20
            }
            
            // Fade out backdrop
            withAnimation(backdropAnimation.delay(0.1)) {
                backdropOpacity = 0
            }
            
            // Wait for animations to complete
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            guard !Task.isCancelled else { return }
            
            // Final state update
            state = .hidden
            
            // Call completion on main queue
            await MainActor.run {
                completion?()
            }
        }
    }
    
    func handleContentChange() {
        guard state == .visible else { return }
        
        // Animate content changes smoothly
        withAnimation(contentAnimation) {
            // Trigger view updates
            objectWillChange.send()
        }
    }
    
    // MARK: - Interrupt Handling
    
    func handleInterrupt() {
        // Cancel ongoing transitions
        transitionTask?.cancel()
        
        // Immediately hide everything
        Task { @MainActor in
            state = .hidden
            backdropOpacity = 0
            paletteScale = 0.92
            paletteOpacity = 0
            paletteOffset = 20
            
            // Dismiss keyboard
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                          to: nil, from: nil, for: nil)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupKeyboardObservers() {
        // Keyboard will show
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] _ in
                self?.isKeyboardVisible = true
            }
            .store(in: &cancellables)
        
        // Keyboard will hide
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.isKeyboardVisible = false
            }
            .store(in: &cancellables)
        
        // Interactive dismiss tracking
        keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboardFrameChange(notification)
        }
    }
    
    private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first else { return }
        
        // Check if keyboard is being interactively dismissed
        let screenHeight = window.bounds.height
        let keyboardTop = screenHeight - endFrame.origin.y
        
        if keyboardTop < endFrame.height * 0.5 && state == .visible {
            // Keyboard is being dismissed interactively
            dismiss()
        }
    }
}

// MARK: - View Modifier
struct PaletteTransition: ViewModifier {
    @ObservedObject var coordinator: PaletteTransitionCoordinator
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(coordinator.paletteScale)
            .opacity(coordinator.paletteOpacity)
            .offset(y: coordinator.paletteOffset)
    }
}

extension View {
    func paletteTransition(_ coordinator: PaletteTransitionCoordinator) -> some View {
        modifier(PaletteTransition(coordinator: coordinator))
    }
}

// MARK: - Environment Key
private struct PaletteTransitionCoordinatorKey: EnvironmentKey {
    static let defaultValue = PaletteTransitionCoordinator()
}

extension EnvironmentValues {
    var paletteTransitionCoordinator: PaletteTransitionCoordinator {
        get { self[PaletteTransitionCoordinatorKey.self] }
        set { self[PaletteTransitionCoordinatorKey.self] = newValue }
    }
}