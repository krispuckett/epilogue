import SwiftUI

struct GlassOptionsMenu: View {
    let note: Note
    @Binding var isPresented: Bool
    @EnvironmentObject var notesViewModel: NotesViewModel
    @State private var containerOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissMenu()
                }
            
            VStack {
                Spacer()
                
                // Glass container
                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 16)
                    
                    // Menu options
                    VStack(spacing: 0) {
                        // Share as image (for quotes)
                        if note.type == .quote {
                            MenuButton(
                                icon: "square.and.arrow.up",
                                title: "Share as Image",
                                action: {
                                    shareAsImage()
                                    dismissMenu()
                                }
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                        
                        // Copy text
                        MenuButton(
                            icon: "doc.on.doc",
                            title: note.type == .quote ? "Copy Quote" : "Copy Note",
                            action: {
                                copyText()
                                dismissMenu()
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Edit
                        MenuButton(
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
                            .background(Color.white.opacity(0.1))
                        
                        // Delete
                        MenuButton(
                            icon: "trash",
                            title: "Delete",
                            isDestructive: true,
                            action: {
                                deleteNote()
                                dismissMenu()
                            }
                        )
                    }
                    .padding(.bottom, 6)
                }
                .frame(maxWidth: 280) // Narrow width like iOS popovers
                .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            Color.white.opacity(0.2),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
                .padding(.horizontal, 40) // More padding from edges
                .padding(.bottom, 20)
                .opacity(containerOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                containerOpacity = 1
            }
        }
    }
    
    private func dismissMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            containerOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }
    
    private func shareAsImage() {
        HapticManager.shared.mediumImpact()
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
        HapticManager.shared.success()
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
        
        UIPasteboard.general.string = textToCopy
    }
    
    private func deleteNote() {
        HapticManager.shared.warning()
        notesViewModel.deleteNote(note)
    }
}

// Menu button component
private struct MenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.4)
            }
            .foregroundStyle(isDestructive ? Color.red : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.001))
        }
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