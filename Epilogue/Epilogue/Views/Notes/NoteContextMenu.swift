import SwiftUI

struct NoteContextMenu: View {
    let note: Note
    let sourceRect: CGRect
    @Binding var isPresented: Bool
    @EnvironmentObject var notesViewModel: NotesViewModel
    @State private var containerOpacity: Double = 0
    @State private var containerScale: CGFloat = 0.8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Invisible backdrop for tap dismissal
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissMenu()
                    }
                
                // Positioned popover
                VStack(spacing: 0) {
                    // Menu options
                    VStack(spacing: 0) {
                        // Share as image (for quotes)
                        if note.type == .quote {
                            ContextMenuButton(
                                icon: "square.and.arrow.up",
                                title: "Share as Image",
                                action: {
                                    shareAsImage()
                                    dismissMenu()
                                }
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.15))
                        }
                        
                        // Copy text
                        ContextMenuButton(
                            icon: "doc.on.doc",
                            title: note.type == .quote ? "Copy Quote" : "Copy Note",
                            action: {
                                copyText()
                                dismissMenu()
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.15))
                        
                        // Edit
                        ContextMenuButton(
                            icon: "pencil",
                            title: "Edit",
                            action: {
                                dismissMenu()
                                // Send notification to trigger edit mode
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    NotificationCenter.default.post(name: Notification.Name("EditNote"), object: note)
                                }
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.15))
                        
                        // Delete
                        ContextMenuButton(
                            icon: "trash",
                            title: "Delete",
                            isDestructive: true,
                            action: {
                                deleteNote()
                                dismissMenu()
                            }
                        )
                    }
                }
                .frame(width: 260) // Consistent with BookContextMenu
                .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                .scaleEffect(containerScale)
                .opacity(containerOpacity)
                .position(calculatePosition(in: geometry))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                containerOpacity = 1
                containerScale = 1
            }
        }
    }
    
    private func calculatePosition(in geometry: GeometryProxy) -> CGPoint {
        let menuHeight: CGFloat = note.type == .quote ? 220 : 180 // Adjust based on content
        let menuWidth: CGFloat = 260
        let padding: CGFloat = 8
        
        // Calculate x position - center on the note
        var x = sourceRect.midX
        
        // Ensure menu doesn't go off screen horizontally
        if x - menuWidth/2 < padding {
            x = menuWidth/2 + padding
        } else if x + menuWidth/2 > geometry.size.width - padding {
            x = geometry.size.width - menuWidth/2 - padding
        }
        
        // Calculate y position - show centered on the note
        var y = sourceRect.midY
        
        // If it would go off screen at bottom, adjust upward
        if y + menuHeight/2 > geometry.size.height - 100 {
            y = geometry.size.height - 100 - menuHeight/2
        }
        
        // If it would go off screen at top, adjust downward
        if y - menuHeight/2 < 100 {
            y = 100 + menuHeight/2
        }
        
        return CGPoint(x: x, y: y)
    }
    
    private func dismissMenu() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            containerOpacity = 0
            containerScale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
    
    private func shareAsImage() {
        HapticManager.shared.mediumTap()
        // Create shareable image view
        let shareView = ShareableQuoteView(note: note)
        let renderer = ImageRenderer(content: shareView)
        renderer.scale = 3.0 // High resolution
        
        if let image = renderer.uiImage {
            let activityController = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                activityController.popoverPresentationController?.sourceView = rootViewController.view
                rootViewController.present(activityController, animated: true)
            }
        }
    }
    
    private func copyText() {
        HapticManager.shared.softTap()
        var textToCopy = note.content
        
        if note.type == .quote {
            // Format quote with attribution
            if let author = note.author {
                textToCopy = "\"\(note.content)\"\n\n— \(author)"
                if let bookTitle = note.bookTitle {
                    textToCopy += ", \(bookTitle)"
                }
                if let pageNumber = note.pageNumber {
                    textToCopy += ", p. \(pageNumber)"
                }
            } else {
                textToCopy = "\"\(note.content)\""
            }
        }
        
        SecureClipboard.copyText(textToCopy)
    }
    
    private func deleteNote() {
        HapticManager.shared.warning()
        // Use sync-aware deletion
        notesViewModel.deleteNoteWithSync(note)
    }
}

// Context menu button component (reusable)
private struct ContextMenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .opacity(0.3)
            }
            .foregroundStyle(isDestructive ? Color.red : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Shareable quote view for image generation
private struct ShareableQuoteView: View {
    let note: Note
    
    var body: some View {
        VStack(spacing: 20) {
            // Large quote mark
            Text("\u{201C}")
                .font(.custom("Georgia", size: 80))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Quote content
            Text(note.content)
                .font(.custom("Georgia", size: 28))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Attribution
            if let author = note.author {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 60, height: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(author.uppercased())
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .kerning(1.5)
                        
                        if let bookTitle = note.bookTitle {
                            Text(bookTitle)
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .italic()
                        }
                        
                        if let pageNumber = note.pageNumber {
                            Text("Page \(pageNumber)")
                                .font(.system(size: 12, weight: .regular))
                                .opacity(0.8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(40)
        .frame(width: 600, height: 600)
        .background(Color(red: 0.98, green: 0.97, blue: 0.96))
    }
}