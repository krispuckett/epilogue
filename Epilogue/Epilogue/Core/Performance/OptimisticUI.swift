import SwiftUI
import Combine

// MARK: - Optimistic Update Manager
@MainActor
final class OptimisticUpdateManager: ObservableObject {
    static let shared = OptimisticUpdateManager()
    
    @Published fileprivate(set) var pendingUpdates: [String: OptimisticUpdate] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Public Methods
    
    func performOptimisticUpdate<T>(
        id: String,
        immediate: @escaping () -> Void,
        commit: @escaping () async throws -> T,
        rollback: @escaping () -> Void
    ) {
        // Perform immediate UI update
        immediate()
        
        // Track pending update
        let update = OptimisticUpdate(id: id, rollback: rollback)
        pendingUpdates[id] = update
        
        // Perform actual operation
        Task {
            do {
                _ = try await commit()
                // Success - remove from pending
                pendingUpdates.removeValue(forKey: id)
            } catch {
                // Failure - rollback
                await MainActor.run {
                    rollback()
                    pendingUpdates.removeValue(forKey: id)
                }
            }
        }
    }
    
    func hasPendingUpdate(id: String) -> Bool {
        pendingUpdates[id] != nil
    }
}

// MARK: - Optimistic Update
struct OptimisticUpdate {
    let id: String
    let rollback: () -> Void
}


// MARK: - Optimistic View Modifier
struct OptimisticUIModifier: ViewModifier {
    let isPending: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isPending ? 0.7 : 1.0)
            .overlay {
                if isPending {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isPending)
    }
}


// MARK: - Optimistic Toggle
struct OptimisticToggle: View {
    let title: String
    @Binding var isOn: Bool
    let onChange: (Bool) async throws -> Void
    
    @State private var isPending = false
    @State private var optimisticValue: Bool?
    
    private var displayValue: Bool {
        optimisticValue ?? isOn
    }
    
    var body: some View {
        Toggle(title, isOn: .constant(displayValue))
            .opacity(isPending ? 0.7 : 1.0)
            .allowsHitTesting(!isPending)
            .onTapGesture {
                performOptimisticToggle()
            }
    }
    
    private func performOptimisticToggle() {
        let newValue = !displayValue
        _ = isOn
        
        // Optimistic update
        optimisticValue = newValue
        isPending = true
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Task {
            do {
                try await onChange(newValue)
                await MainActor.run {
                    isOn = newValue
                    optimisticValue = nil
                    isPending = false
                }
            } catch {
                // Rollback
                await MainActor.run {
                    optimisticValue = nil
                    isPending = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func optimisticUI(isPending: Bool) -> some View {
        modifier(OptimisticUIModifier(isPending: isPending))
    }
}