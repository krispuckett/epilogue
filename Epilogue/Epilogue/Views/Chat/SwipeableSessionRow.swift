import SwiftUI

struct SwipeableSessionRow: View {
    let thread: ChatThread
    let onDelete: () -> Void
    let onArchive: () -> Void
    
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
            BookChatCard(
                thread: thread,
                onDelete: onDelete
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
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