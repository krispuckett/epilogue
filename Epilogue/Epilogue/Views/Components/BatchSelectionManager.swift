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
        HapticManager.shared.lightTap()
    }
    
    func exitSelectionMode() {
        isSelectionMode = false
        selectedItems.removeAll()
        HapticManager.shared.lightTap()
    }
    
    func toggleSelection(for id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
            HapticManager.shared.lightTap()
        } else {
            selectedItems.insert(id)
            HapticManager.shared.mediumTap()
        }
    }
    
    func selectAll(items: [Note]) {
        selectedItems = Set(items.map { $0.id })
        HapticManager.shared.mediumTap()
    }
    
    func deselectAll() {
        selectedItems.removeAll()
        HapticManager.shared.lightTap()
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
        
        HapticManager.shared.warning()
    }
    
    func isSelected(_ id: UUID) -> Bool {
        selectedItems.contains(id)
    }
}

// MARK: - Batch Selection Toolbar
struct BatchSelectionToolbar: View {
    @ObservedObject var selectionManager: BatchSelectionManager
    let allItems: [Note]
    let onDelete: (Set<UUID>) -> Void
    
    var body: some View {
        if selectionManager.isSelectionMode {
            HStack(spacing: 0) {
                // Cancel button
                Button("Cancel") {
                    selectionManager.exitSelectionMode()
                }
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                
                Spacer()
                
                // Selection count
                Text("\(selectionManager.selectionCount) selected")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .animation(.easeInOut(duration: 0.2), value: selectionManager.selectionCount)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    // Select All / Deselect All
                    Button(selectionManager.selectionCount == allItems.count ? "Deselect All" : "Select All") {
                        if selectionManager.selectionCount == allItems.count {
                            selectionManager.deselectAll()
                        } else {
                            selectionManager.selectAll(items: allItems)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                    
                    // Delete button
                    Button {
                        selectionManager.deleteSelected()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selectionManager.hasSelection ? .red : .white.opacity(0.3))
                    }
                    .disabled(!selectionManager.hasSelection)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                .black.opacity(0.9)
            )
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(.white.opacity(0.1)),
                alignment: .top
            )
            .animation(.easeInOut(duration: 0.3), value: selectionManager.isSelectionMode)
        }
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
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26))
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

// MARK: - Delete Confirmation Dialog
struct BatchDeleteConfirmationDialog: View {
    @ObservedObject var selectionManager: BatchSelectionManager
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "trash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                
                // Title and message
                VStack(spacing: 8) {
                    Text("Delete \(selectionManager.selectionCount) Notes")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("This action cannot be undone. All selected notes and quotes will be permanently deleted.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
                // Buttons
                VStack(spacing: 12) {
                    // Delete button
                    Button {
                        selectionManager.showingDeleteConfirmation = false
                        onConfirm()
                    } label: {
                        Text("Delete \(selectionManager.selectionCount) Notes")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Cancel button
                    Button {
                        selectionManager.showingDeleteConfirmation = false
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.black.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
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
        .animation(.easeInOut(duration: 0.2), value: selectionManager.isSelectionMode)
    }
}