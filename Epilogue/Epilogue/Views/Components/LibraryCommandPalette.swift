// LibraryCommandPalette.swift
import SwiftUI

struct LibraryCommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var commandText: String
    @State private var searchText = ""
    @State private var dragOffset: CGFloat = 0
    @FocusState private var isFocused: Bool
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    // Library/Notes focused commands
    struct Command {
        let icon: String
        let title: String
        let description: String?
        let action: CommandAction
        let isFeatured: Bool
        
        enum CommandAction {
            case scanBook
            case addBook
            case importFromGoodreads
            case createNote
            case createQuote
            case searchNotes
        }
    }
    
    let commands = [
        Command(
            icon: "camera.viewfinder",
            title: "Scan Book",
            description: "Visual Intelligence or ISBN barcode",
            action: .scanBook,
            isFeatured: true
        ),
        Command(
            icon: "magnifyingglass",
            title: "Search Books",
            description: "Find and add books to library",
            action: .addBook,
            isFeatured: true
        ),
        Command(
            icon: "square.and.arrow.down",
            title: "Import from Goodreads",
            description: "Import your Goodreads library CSV",
            action: .importFromGoodreads,
            isFeatured: true
        )
    ]
    
    private var filteredCommands: [Command] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            (command.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // Results (no search bar - simpler for quick actions)
            VStack(spacing: 0) {
                ForEach(Array(filteredCommands.enumerated()), id: \.offset) { index, command in
                    commandRow(command: command)
                        .onTapGesture {
                            handleCommandSelection(command)
                        }
                    
                    // Add divider between items
                    if index < filteredCommands.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 0.5)
                            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 50 {
                        dismiss()
                    } else {
                        withAnimation(DesignSystem.Animation.springStandard) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
    
    // MARK: - Command Row
    
    private func commandRow(command: Command) -> some View {
        HStack(spacing: 16) {
            // Icon with featured style
            ZStack {
                if command.isFeatured {
                    Circle()
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                        .frame(width: 36, height: 36)
                }
                
                Image(systemName: command.icon)
                    .font(.system(size: command.isFeatured ? 22 : 20))
                    .foregroundStyle(command.isFeatured ? DesignSystem.Colors.primaryAccent : .white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                
                if let description = command.description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    // MARK: - Actions
    
    private func handleCommandSelection(_ command: Command) {
        SensoryFeedback.light()
        
        switch command.action {
        case .scanBook:
            // Dismiss first, then trigger enhanced book scanner after a delay
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: Notification.Name("ShowEnhancedBookScanner"), object: nil)
            }
            
        case .addBook:
            // Dismiss first, then show Google Books search after a delay
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: Notification.Name("ShowBookSearch"), object: nil)
            }
            
        case .importFromGoodreads:
            // Dismiss first, then trigger Goodreads import after a delay
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: Notification.Name("ShowGoodreadsImport"), object: nil)
            }
            
        case .createNote, .createQuote, .searchNotes:
            // These are now handled through intelligent input parsing
            dismiss()
        }
    }
    
    private func dismiss() {
        withAnimation(DesignSystem.Animation.springStandard) {
            isPresented = false
        }
    }
}