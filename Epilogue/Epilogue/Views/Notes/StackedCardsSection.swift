import SwiftUI

// MARK: - Stacked Cards Section
struct StackedCardsSection: View {
    let section: SmartSection
    @Binding var expandedSections: Set<UUID>
    let onNoteTap: (Note) -> Void
    let onDelete: (Note) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @Namespace private var animation
    
    private var isExpanded: Bool {
        expandedSections.contains(section.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            sectionHeader
            
            // Card Stack
            if !section.notes.isEmpty {
                if !isExpanded {
                    collapsedStack
                } else {
                    expandedStack
                }
            }
        }
    }
    
    // MARK: - Section Header
    private var sectionHeader: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if isExpanded {
                    expandedSections.remove(section.id)
                } else {
                    expandedSections.insert(section.id)
                }
            }
            DesignSystem.HapticFeedback.light()
        } label: {
            HStack {
                Text(section.title)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(0.5)
                
                Text("(\(section.notes.count))")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Collapsed Stack
    private var collapsedStack: some View {
        ZStack(alignment: .top) {
            // Show up to 3 cards in reverse order so top card is on top
            ForEach(Array(section.notes.prefix(3).enumerated().reversed()), id: \.element.id) { index, note in
                if index == 0 {
                    topCard(note: note)
                } else {
                    backgroundCard(at: index)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.bottom, 12)
    }
    
    // MARK: - Expanded Stack
    private var expandedStack: some View {
        VStack(spacing: -140) {  // Negative spacing for overlap
            ForEach(Array(section.notes.enumerated()), id: \.element.id) { index, note in
                expandedCard(note: note, at: index)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.bottom, CGFloat(section.notes.count) * 8 + 20)
    }
    
    // MARK: - Top Card (Collapsed)
    @ViewBuilder
    private func topCard(note: Note) -> some View {
        Group {
            if note.type == .quote {
                SimpleQuoteCard(note: note)
            } else {
                SimpleNoteCard(note: note)
            }
        }
        .zIndex(100)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                _ = expandedSections.insert(section.id)
            }
        }
        .contextMenu {
            Button {
                onNoteTap(note)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete(note)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Background Card (Collapsed)
    @ViewBuilder
    private func backgroundCard(at index: Int) -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
            .fill(Color(white: index == 1 ? 0.08 : 0.06))
            .frame(height: 150)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(Color(white: 0.1), lineWidth: 0.5)
            )
            .offset(y: CGFloat(index) * 2.5)  // Very tight 2.5pt stacking
            .scaleEffect(1.0 - (CGFloat(index) * 0.01))  // Subtle scale
            .zIndex(Double(10 - index))
    }
    
    // MARK: - Expanded Card
    @ViewBuilder
    private func expandedCard(note: Note, at index: Int) -> some View {
        let card = Group {
            if note.type == .quote {
                SimpleQuoteCard(note: note)
            } else {
                SimpleNoteCard(note: note)
            }
        }
        
        card
            .offset(y: CGFloat(index) * 8)  // Progressive offset
            .scaleEffect(1.0 - (CGFloat(index) * 0.015))
            .zIndex(Double(100 - index))
            .animation(
                .spring(response: 0.4, dampingFraction: 0.75)
                    .delay(Double(index) * 0.03),
                value: isExpanded
            )
            .allowsHitTesting(index == 0)  // Only top card interactive
            .if(index == 0) { view in
                view
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 25)))
                    .scaleEffect(isDragging ? 1.02 : 1.0)
                    .onTapGesture {
                        onNoteTap(note)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                                isDragging = true
                            }
                            .onEnded { value in
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    if abs(value.translation.width) > 120 {
                                        onDelete(note)
                                    }
                                    dragOffset = .zero
                                    isDragging = false
                                }
                            }
                    )
                    .contextMenu {
                        Button {
                            onNoteTap(note)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            onDelete(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
    }
}