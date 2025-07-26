import SwiftUI

// MARK: - Swipeable Chat Card
struct SwipeableChatCard: View {
    let thread: ChatThread
    let isSelected: Bool
    let isSelectionMode: Bool
    let onDelete: () -> Void
    let onArchive: () -> Void
    let onToggleSelection: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var hasTriggeredFeedback = false
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    private let actionThreshold: CGFloat = -80
    private let maxOffset: CGFloat = -160
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Background actions
            HStack(spacing: 0) {
                // Archive button
                Button {
                    withAnimation(.spring()) {
                        offset = 0
                    }
                    HapticManager.shared.success()
                    onArchive()
                } label: {
                    VStack {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 20))
                        Text("Archive")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 80)
                    .frame(maxHeight: .infinity)
                    .background(Color.blue)
                }
                
                // Delete button
                Button {
                    withAnimation(.spring()) {
                        offset = 0
                    }
                    HapticManager.shared.success()
                    onDelete()
                } label: {
                    VStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20))
                        Text("Delete")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 80)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                }
            }
            .opacity(offset < -20 ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: offset < -20)
            
            // Main content
            BookChatCard(
                thread: thread,
                onDelete: onDelete
            )
            .environmentObject(libraryViewModel)
            .offset(x: offset)
            .overlay {
                // Selection overlay
                if isSelectionMode {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(isSelected ? 0.2 : 0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(isSelected ? Color.warmAmber : Color.clear, lineWidth: 2)
                        }
                        .overlay {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(isSelected ? Color.warmAmber : .white.opacity(0.6))
                                    .padding(16)
                                Spacer()
                            }
                        }
                        .allowsHitTesting(true)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                HapticManager.shared.lightTap()
                                onToggleSelection()
                            }
                        }
                }
            }
            .gesture(
                isSelectionMode ? nil : DragGesture()
                    .onChanged { value in
                        isDragging = true
                        
                        // Only allow left swipe
                        if value.translation.width < 0 {
                            // Apply resistance when swiping beyond max
                            if value.translation.width < maxOffset {
                                let overflow = value.translation.width - maxOffset
                                offset = maxOffset + (overflow * 0.3)
                            } else {
                                offset = value.translation.width
                            }
                            
                            // Haptic feedback when crossing threshold
                            if offset < actionThreshold && !hasTriggeredFeedback {
                                HapticManager.shared.lightTap()
                                hasTriggeredFeedback = true
                            } else if offset > actionThreshold && hasTriggeredFeedback {
                                hasTriggeredFeedback = false
                            }
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        hasTriggeredFeedback = false
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            // If swiped past threshold, show actions
                            if offset < actionThreshold {
                                offset = maxOffset
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Swipeable General Chat Card
struct SwipeableGeneralChatCard: View {
    let messageCount: Int
    let lastMessage: ThreadedChatMessage?
    let isSelected: Bool
    let isSelectionMode: Bool
    let onDelete: () -> Void
    let onArchive: () -> Void
    let onToggleSelection: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var hasTriggeredFeedback = false
    
    private let actionThreshold: CGFloat = -80
    private let maxOffset: CGFloat = -160
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Background actions
            HStack(spacing: 0) {
                // Archive button
                Button {
                    withAnimation(.spring()) {
                        offset = 0
                    }
                    HapticManager.shared.success()
                    onArchive()
                } label: {
                    VStack {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 20))
                        Text("Archive")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 80)
                    .frame(maxHeight: .infinity)
                    .background(Color.blue)
                }
                
                // Delete button
                Button {
                    withAnimation(.spring()) {
                        offset = 0
                    }
                    HapticManager.shared.success()
                    onDelete()
                } label: {
                    VStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20))
                        Text("Delete")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 80)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                }
            }
            .opacity(offset < -20 ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: offset < -20)
            
            // Main content
            GeneralChatCard(
                messageCount: messageCount,
                lastMessage: lastMessage
            )
            .offset(x: offset)
            .overlay {
                // Selection overlay
                if isSelectionMode {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(isSelected ? 0.2 : 0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(isSelected ? Color.warmAmber : Color.clear, lineWidth: 2)
                        }
                        .overlay {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(isSelected ? Color.warmAmber : .white.opacity(0.6))
                                    .padding(16)
                                Spacer()
                            }
                        }
                        .allowsHitTesting(true)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                HapticManager.shared.lightTap()
                                onToggleSelection()
                            }
                        }
                }
            }
            .gesture(
                isSelectionMode ? nil : DragGesture()
                    .onChanged { value in
                        isDragging = true
                        
                        // Only allow left swipe
                        if value.translation.width < 0 {
                            // Apply resistance when swiping beyond max
                            if value.translation.width < maxOffset {
                                let overflow = value.translation.width - maxOffset
                                offset = maxOffset + (overflow * 0.3)
                            } else {
                                offset = value.translation.width
                            }
                            
                            // Haptic feedback when crossing threshold
                            if offset < actionThreshold && !hasTriggeredFeedback {
                                HapticManager.shared.lightTap()
                                hasTriggeredFeedback = true
                            } else if offset > actionThreshold && hasTriggeredFeedback {
                                hasTriggeredFeedback = false
                            }
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        hasTriggeredFeedback = false
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            // If swiped past threshold, show actions
                            if offset < actionThreshold {
                                offset = maxOffset
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}