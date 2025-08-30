import SwiftUI
import Combine

// MARK: - Batch Selection Manager
@MainActor
final class BatchSelectionManager: ObservableObject {
    @Published var isSelectionMode = false
    @Published var selectedItems: Set<UUID> = []
    @Published var showingDeleteConfirmation = false
    
    var hasSelection: Bool {
        !selectedItems.isEmpty
    }
    
    var selectionCount: Int {
        selectedItems.count
    }
    
    var needsConfirmation: Bool {
        selectedItems.count > 5
    }
    
    func enterSelectionMode() {
        isSelectionMode = true
        selectedItems.removeAll()
        DesignSystem.HapticFeedback.light()
    }
    
    func exitSelectionMode() {
        isSelectionMode = false
        selectedItems.removeAll()
        DesignSystem.HapticFeedback.light()
    }
    
    func toggleSelection(for id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
            DesignSystem.HapticFeedback.light()
        } else {
            selectedItems.insert(id)
            DesignSystem.HapticFeedback.medium()
        }
    }
    
    func selectAll(items: [Note]) {
        selectedItems = Set(items.map { $0.id })
        DesignSystem.HapticFeedback.medium()
    }
    
    func deselectAll() {
        selectedItems.removeAll()
        DesignSystem.HapticFeedback.light()
    }
    
    func deleteSelected() {
        if needsConfirmation {
            showingDeleteConfirmation = true
        } else {
            performDelete()
        }
    }
    
    func performDelete() {
        let count = selectedItems.count
        
        // Exit selection mode
        exitSelectionMode()
        
        // Show undo with batch description
        let description = count == 1 ? "note" : "\(count) notes"
        UndoManager.shared.showUndo(
            message: "Deleted \(description)",
            action: {
                // Undo action would restore the deleted items
                // This would need to be implemented based on your data model
            }
        )
        
        DesignSystem.HapticFeedback.warning()
    }
    
    func isSelected(_ id: UUID) -> Bool {
        selectedItems.contains(id)
    }
}

// MARK: - Batch Selection Navigation Bar
struct BatchSelectionNavigationBar: View {
    @ObservedObject var selectionManager: BatchSelectionManager
    let allItems: [Note]
    let onDelete: (Set<UUID>) -> Void
    
    var body: some View {
        HStack {
            // Cancel button (leading)
            Button("Cancel") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectionManager.exitSelectionMode()
                }
            }
            .font(.system(size: 17))
            .foregroundStyle(DesignSystem.Colors.primaryAccent)
            
            Spacer()
            
            // Selection count (center)
            Text("\(selectionManager.selectionCount) Selected")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .animation(DesignSystem.Animation.easeQuick, value: selectionManager.selectionCount)
            
            Spacer()
            
            // Action buttons (trailing)
            HStack(spacing: 16) {
                // Select All / Deselect All
                Button(selectionManager.selectionCount == allItems.count ? "Deselect All" : "Select All") {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        if selectionManager.selectionCount == allItems.count {
                            selectionManager.deselectAll()
                        } else {
                            selectionManager.selectAll(items: allItems)
                        }
                    }
                }
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.8))
                
                // Delete button
                Button {
                    if selectionManager.needsConfirmation {
                        selectionManager.showingDeleteConfirmation = true
                    } else {
                        onDelete(selectionManager.selectedItems)
                        selectionManager.performDelete()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(selectionManager.hasSelection ? .red : DesignSystem.Colors.textQuaternary)
                }
                .disabled(!selectionManager.hasSelection)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .frame(height: 44)
    }
}

// MARK: - Selection Indicator
struct SelectionIndicator: View {
    let isSelected: Bool
    let isSelectionMode: Bool
    
    var body: some View {
        if isSelectionMode {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 24, height: 24)
                
                if isSelected {
                    Circle()
                        .fill(DesignSystem.Colors.primaryAccent)
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .strokeBorder(.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - iOS 26 Delete Confirmation Toast
struct BatchDeleteConfirmationToast: View {
    @ObservedObject var selectionManager: BatchSelectionManager
    let onConfirm: () -> Void
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon and title
            VStack(spacing: 16) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 50, weight: .regular))
                    .foregroundStyle(.red)
                
                VStack(spacing: 8) {
                    Text("Delete \(selectionManager.selectionCount) Notes")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("This action cannot be undone. All selected notes and quotes will be permanently deleted.")
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Action buttons
            VStack(spacing: 16) {
                // Delete button - iOS 26 style
                Button {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        selectionManager.showingDeleteConfirmation = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onConfirm()
                    }
                } label: {
                    Text("Delete \(selectionManager.selectionCount) Notes")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                .fill(.red)
                        }
                }
                .buttonStyle(.plain)
                
                // Cancel button - iOS 26 style
                Button {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        selectionManager.showingDeleteConfirmation = false
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                .fill(.white.opacity(0.10))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
        .padding(.vertical, 32)
        .glassEffect(in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Selectable Note Card Wrapper
struct SelectableNoteCard: View {
    let note: Note
    @ObservedObject var selectionManager: BatchSelectionManager
    let content: AnyView
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Selection indicator
            if selectionManager.isSelectionMode {
                SelectionIndicator(
                    isSelected: selectionManager.isSelected(note.id),
                    isSelectionMode: selectionManager.isSelectionMode
                )
                .padding(.trailing, 12)
                .onTapGesture {
                    selectionManager.toggleSelection(for: note.id)
                }
            }
            
            // Note content
            content
                .onTapGesture {
                    if selectionManager.isSelectionMode {
                        selectionManager.toggleSelection(for: note.id)
                    } else {
                        onTap()
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    if !selectionManager.isSelectionMode {
                        selectionManager.enterSelectionMode()
                        selectionManager.toggleSelection(for: note.id)
                    }
                }
        }
        .animation(DesignSystem.Animation.easeQuick, value: selectionManager.isSelectionMode)
    }
}