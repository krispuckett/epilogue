import SwiftUI

// MARK: - Collapsible Notification Section (iOS 26 Lockscreen Style)
struct CollapsibleNotificationSection: View {
    let section: SmartSection
    @Binding var expandedSections: Set<UUID>
    let onNoteTap: (Note) -> Void
    let onDelete: (Note) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var showingDeleteConfirmation = false
    @State private var noteToDelete: Note?
    
    private var isExpanded: Bool {
        expandedSections.contains(section.id)
    }
    
    private var visibleNotes: [Note] {
        if isExpanded {
            return section.notes
        } else {
            return Array(section.notes.prefix(3))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if isExpanded {
                        expandedSections.remove(section.id)
                    } else {
                        expandedSections.insert(section.id)
                    }
                }
                HapticManager.shared.lightTap()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        if !isExpanded && section.notes.count > 0 {
                            Text(section.notes.first?.content ?? "")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if !isExpanded && section.notes.count > 1 {
                            Text("\(section.notes.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Collapsed Stack Preview
            if !isExpanded && section.notes.count > 1 {
                ZStack(alignment: .top) {
                    // Background cards for stack effect
                    if section.notes.count > 2 {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.02))
                            .frame(height: 60)
                            .offset(y: 8)
                            .scaleEffect(x: 0.94)
                    }
                    
                    if section.notes.count > 1 {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 60)
                            .offset(y: 4)
                            .scaleEffect(x: 0.97)
                    }
                    
                    // Top card
                    notificationCard(for: section.notes[0], isTopCard: true)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            
            // Expanded Content
            if isExpanded {
                LazyVStack(spacing: 8) {
                    ForEach(section.notes) { note in
                        notificationCard(for: note)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }
    
    @ViewBuilder
    private func notificationCard(for note: Note, isTopCard: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon based on type
            Image(systemName: note.type == .quote ? "quote.bubble.fill" : "note.text")
                .font(.system(size: 14))
                .foregroundStyle(note.type == .quote ? Color.yellow.opacity(0.8) : Color.blue.opacity(0.8))
                .frame(width: 24, height: 24)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                // Content
                Text(note.content)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: !isExpanded)
                
                // Metadata
                HStack(spacing: 6) {
                    if let bookTitle = note.bookTitle {
                        Text(bookTitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text(note.dateCreated, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .if(isExpanded) { view in
            view
                .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        onDelete(note)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                    
                    Button {
                        onNoteTap(note)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
        }
        .onTapGesture {
            if isExpanded {
                onNoteTap(note)
            }
        }
    }
}

