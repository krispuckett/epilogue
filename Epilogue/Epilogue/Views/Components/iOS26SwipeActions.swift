import SwiftUI

// MARK: - iOS 26 Style Swipe Actions
struct iOS26SwipeActionsModifier: ViewModifier {
    let actions: [SwipeAction]
    
    @State private var offset: CGFloat = 0
    @State private var initialOffset: CGFloat = 0
    @State private var isShowingActions = false
    @State private var hapticTriggered = false
    @GestureState private var isDragging = false
    
    private let actionButtonSize: CGFloat = 56
    private let actionButtonSpacing: CGFloat = 12
    private let swipeThreshold: CGFloat = 80
    private let maxSwipeDistance: CGFloat = 200
    
    private var totalActionsWidth: CGFloat {
        CGFloat(actions.count) * actionButtonSize + CGFloat(actions.count - 1) * actionButtonSpacing + 24
    }
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Action buttons background
            if isShowingActions {
                HStack(spacing: actionButtonSpacing) {
                    ForEach(actions) { action in
                        actionButton(for: action)
                    }
                }
                .padding(.trailing, 12)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
            
            // Main content
            content
                .offset(x: offset)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: offset)
                .gesture(
                    DragGesture()
                        .updating($isDragging) { _, state, _ in
                            state = true
                        }
                        .onChanged { value in
                            handleDragChange(value)
                        }
                        .onEnded { value in
                            handleDragEnd(value)
                        }
                )
        }
        .clipped()
    }
    
    private func actionButton(for action: SwipeAction) -> some View {
        Button {
            // Haptic feedback
            if action.isDestructive {
                HapticManager.shared.warning()
            } else {
                HapticManager.shared.mediumTap()
            }
            
            // Execute action
            action.handler()
            
            // Close swipe actions
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                offset = 0
                isShowingActions = false
            }
        } label: {
            ZStack {
                Circle()
                    .fill(action.backgroundColor)
                    .frame(width: actionButtonSize, height: actionButtonSize)
                
                Image(systemName: action.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(isShowingActions ? 1.0 : 0.8)
        .opacity(isShowingActions ? 1.0 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(isShowingActions ? 0.05 : 0), value: isShowingActions)
    }
    
    private func handleDragChange(_ value: DragGesture.Value) {
        let translation = value.translation.width
        
        // Only allow left swipe (negative translation)
        if translation < 0 {
            // Calculate offset with resistance
            let resistance = 1.0 - min(abs(translation) / (maxSwipeDistance * 2), 0.5)
            offset = initialOffset + translation * resistance
            
            // Clamp offset
            offset = max(-maxSwipeDistance, offset)
            
            // Trigger haptic when crossing threshold
            if abs(offset) > swipeThreshold && !hapticTriggered {
                HapticManager.shared.lightTap()
                hapticTriggered = true
            }
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        let translation = value.translation.width
        let velocity = value.predictedEndTranslation.width - translation
        
        hapticTriggered = false
        
        if translation < -swipeThreshold || velocity < -200 {
            // Show actions
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                offset = -totalActionsWidth
                isShowingActions = true
                initialOffset = -totalActionsWidth
            }
        } else {
            // Hide actions
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                offset = 0
                isShowingActions = false
                initialOffset = 0
            }
        }
    }
}

// MARK: - Swipe Action Model
struct SwipeAction: Identifiable {
    let id = UUID()
    let icon: String
    let backgroundColor: Color
    let isDestructive: Bool
    let handler: () -> Void
    
    init(icon: String, backgroundColor: Color, isDestructive: Bool = false, handler: @escaping () -> Void) {
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.isDestructive = isDestructive
        self.handler = handler
    }
}

// MARK: - View Extension
extension View {
    func iOS26SwipeActions(_ actions: [SwipeAction]) -> some View {
        modifier(iOS26SwipeActionsModifier(actions: actions))
    }
    
    // Convenience method for common actions
    func iOS26SwipeToDelete(onDelete: @escaping () -> Void, additionalActions: [SwipeAction] = []) -> some View {
        let deleteAction = SwipeAction(
            icon: "trash.fill",
            backgroundColor: Color(red: 1.0, green: 0.3, blue: 0.3),
            isDestructive: true,
            handler: onDelete
        )
        
        let allActions = additionalActions + [deleteAction]
        return self.iOS26SwipeActions(allActions)
    }
}

// MARK: - Contextual Swipe Actions
struct ContextualSwipeActionsModifier: ViewModifier {
    let content: any View
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    
    @State private var offset: CGFloat = 0
    @State private var activeDirection: SwipeDirection = .none
    @GestureState private var isDragging = false
    
    enum SwipeDirection {
        case none, leading, trailing
    }
    
    func body(content: Content) -> some View {
        ZStack {
            // Leading actions (right swipe)
            if activeDirection == .leading && !leadingActions.isEmpty {
                HStack(spacing: 12) {
                    ForEach(leadingActions) { action in
                        SwipeActionButton(action: action, direction: .leading)
                    }
                    Spacer()
                }
                .padding(.leading, 12)
            }
            
            // Trailing actions (left swipe)
            if activeDirection == .trailing && !trailingActions.isEmpty {
                HStack(spacing: 12) {
                    Spacer()
                    ForEach(trailingActions) { action in
                        SwipeActionButton(action: action, direction: .trailing)
                    }
                }
                .padding(.trailing, 12)
            }
            
            // Main content
            AnyView(content)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .updating($isDragging) { _, state, _ in
                            state = true
                        }
                        .onChanged { value in
                            handleDrag(value)
                        }
                        .onEnded { value in
                            handleDragEnd(value)
                        }
                )
        }
    }
    
    private func handleDrag(_ value: DragGesture.Value) {
        let translation = value.translation.width
        
        if translation > 0 && !leadingActions.isEmpty {
            activeDirection = .leading
            offset = min(translation * 0.7, 150)
        } else if translation < 0 && !trailingActions.isEmpty {
            activeDirection = .trailing
            offset = max(translation * 0.7, -150)
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = 0
            activeDirection = .none
        }
    }
}

// MARK: - Swipe Action Button Component
struct SwipeActionButton: View {
    let action: SwipeAction
    let direction: ContextualSwipeActionsModifier.SwipeDirection
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action.handler()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(action.backgroundColor)
                    .frame(width: 56, height: 56)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                Image(systemName: action.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(isPressed ? 0.8 : 1.0)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed)
    }
}

// MARK: - Glass Effect Swipe Actions (iOS 26 Specific)
struct GlassSwipeActionsModifier: ViewModifier {
    let actions: [SwipeAction]
    
    @State private var offset: CGFloat = 0
    @State private var isShowingActions = false
    @State private var selectedAction: SwipeAction?
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Glass background for actions
            if isShowingActions {
                HStack(spacing: 8) {
                    ForEach(actions) { action in
                        Button {
                            selectedAction = action
                            HapticManager.shared.mediumTap()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                action.handler()
                                withAnimation {
                                    isShowingActions = false
                                    offset = 0
                                }
                            }
                        } label: {
                            Image(systemName: action.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(action.isDestructive ? Color.red : .white)
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular, in: Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            action.backgroundColor.opacity(0.3),
                                            lineWidth: 1
                                        )
                                }
                        }
                        .scaleEffect(selectedAction?.id == action.id ? 0.9 : 1.0)
                    }
                }
                .padding(.trailing, 12)
            }
            
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -150)
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -50 {
                                withAnimation(.spring()) {
                                    offset = -120
                                    isShowingActions = true
                                }
                            } else {
                                withAnimation(.spring()) {
                                    offset = 0
                                    isShowingActions = false
                                }
                            }
                        }
                )
        }
    }
}

extension View {
    func glassSwipeActions(_ actions: [SwipeAction]) -> some View {
        modifier(GlassSwipeActionsModifier(actions: actions))
    }
}