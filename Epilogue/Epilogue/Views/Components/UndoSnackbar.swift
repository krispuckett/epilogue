import SwiftUI
import Combine

// MARK: - Undo Action
struct UndoAction {
    let id = UUID()
    let message: String
    let action: () -> Void
    let timestamp = Date()
}

// MARK: - Undo Manager
@MainActor
final class UndoManager: ObservableObject {
    static let shared = UndoManager()
    
    @Published private(set) var currentAction: UndoAction?
    @Published private(set) var timeRemaining: TimeInterval = 0
    
    private var timer: Timer?
    private let undoDuration: TimeInterval = 5.0
    
    private init() {}
    
    func showUndo(message: String, action: @escaping () -> Void) {
        // Cancel any existing undo
        cancelCurrentUndo()
        
        let undoAction = UndoAction(message: message, action: action)
        currentAction = undoAction
        timeRemaining = undoDuration
        
        // Start countdown timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.timeRemaining -= 0.1
            
            if self.timeRemaining <= 0 {
                self.dismissUndo()
            }
        }
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + undoDuration) { [weak self] in
            if self?.currentAction?.id == undoAction.id {
                self?.dismissUndo()
            }
        }
    }
    
    func performUndo() {
        guard let action = currentAction else { return }
        
        cancelCurrentUndo()
        action.action()
        
        // Haptic feedback
        HapticManager.shared.success()
    }
    
    func dismissUndo() {
        timer?.invalidate()
        timer = nil
        currentAction = nil
        timeRemaining = 0
    }
    
    private func cancelCurrentUndo() {
        timer?.invalidate()
        timer = nil
        currentAction = nil
        timeRemaining = 0
    }
}

// MARK: - Undo Snackbar View
struct UndoSnackbar: View {
    @StateObject private var undoManager = UndoManager.shared
    
    var body: some View {
        if let action = undoManager.currentAction {
            snackbarContent(for: action)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(1000)
        }
    }
    
    @ViewBuilder
    private func snackbarContent(for action: UndoAction) -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "trash.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.8))
                
                // Message
                Text(action.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Progress indicator
                UndoCircularProgressView(
                    progress: 1.0 - (undoManager.timeRemaining / 5.0),
                    lineWidth: 2
                )
                .frame(width: 20, height: 20)
                .foregroundStyle(.white.opacity(0.6))
                
                // Undo button
                Button(action: undoManager.performUndo) {
                    Text("UNDO")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.15))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .sensoryFeedback(.impact(flexibility: .soft), trigger: undoManager.currentAction?.id)
                
                // Dismiss button
                Button(action: undoManager.dismissUndo) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Above tab bar
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Undo Circular Progress View
private struct UndoCircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Swipe to Delete Modifier
struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void
    let undoAction: () -> Void
    let itemDescription: String
    
    @State private var offset: CGSize = .zero
    @State private var isDeleting = false
    
    private let deleteThreshold: CGFloat = -100
    private let hapticThreshold: CGFloat = -80
    @State private var hasTriggeredHaptic = false
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .background(
                // Red delete background
                HStack {
                    Spacer()
                    
                    VStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                        
                        Text("Delete")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 80)
                    .opacity(offset.width < -20 ? 1 : 0)
                    .scaleEffect(offset.width < deleteThreshold ? 1.1 : 1.0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.red)
                .cornerRadius(16)
                .clipped()
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow left swipe
                        if value.translation.width < 0 {
                            offset = CGSize(width: max(value.translation.width, -120), height: 0)
                            
                            // Haptic feedback at threshold
                            if offset.width < hapticThreshold && !hasTriggeredHaptic {
                                HapticManager.shared.lightTap()
                                hasTriggeredHaptic = true
                            } else if offset.width > hapticThreshold {
                                hasTriggeredHaptic = false
                            }
                        }
                    }
                    .onEnded { value in
                        if offset.width < deleteThreshold {
                            // Delete action
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                offset = CGSize(width: -500, height: 0)
                                isDeleting = true
                            }
                            
                            // Perform delete with undo option
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDelete()
                                UndoManager.shared.showUndo(
                                    message: "Deleted \(itemDescription)",
                                    action: undoAction
                                )
                                HapticManager.shared.mediumTap()
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                offset = .zero
                            }
                        }
                        hasTriggeredHaptic = false
                    }
            )
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: offset)
    }
}

// MARK: - View Extension
extension View {
    func swipeToDelete(
        onDelete: @escaping () -> Void,
        undoAction: @escaping () -> Void,
        itemDescription: String
    ) -> some View {
        modifier(SwipeToDeleteModifier(
            onDelete: onDelete,
            undoAction: undoAction,
            itemDescription: itemDescription
        ))
    }
}