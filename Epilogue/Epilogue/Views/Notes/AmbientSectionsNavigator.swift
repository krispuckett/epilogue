import SwiftUI

// MARK: - Ambient Sections Navigator
struct AmbientSectionsNavigator: View {
    @Binding var isShowing: Bool
    let sections: [SmartSection]
    let onSectionTap: (SmartSection) -> Void
    
    @State private var selectedSection: SmartSection?
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    
    var body: some View {
        ZStack {
            // Ambient backdrop
            if isShowing {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Sections panel
            HStack(spacing: 0) {
                if isShowing {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        Text("SECTIONS")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .kerning(2)
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                            .padding(.top, 50)
                            .padding(.bottom, 20)
                            .padding(.leading, 28)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(sections) { section in
                                    SectionRow(
                                        section: section,
                                        isSelected: selectedSection?.id == section.id
                                    )
                                    .onTapGesture {
                                        selectedSection = section
                                        HapticManager.shared.lightTap()
                                        
                                        // Animate selection then navigate
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            onSectionTap(section)
                                            withAnimation(.spring(response: 0.3)) {
                                                isShowing = false
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 40)
                        }
                        .frame(maxHeight: 500)
                        
                        Spacer()
                    }
                    .frame(width: 280)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        // Right edge highlight
                        HStack {
                            Spacer()
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.05),
                                            Color.clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 1)
                        }
                    )
                    .offset(x: dragOffset)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .gesture(
                        DragGesture()
                            .updating($isDragging) { _, state, _ in
                                state = true
                            }
                            .onChanged { value in
                                if value.translation.width < 0 {
                                    dragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                if value.translation.width < -100 {
                                    withAnimation(.spring(response: 0.3)) {
                                        isShowing = false
                                    }
                                }
                                dragOffset = 0
                            }
                    )
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Section Row
struct SectionRow: View {
    let section: SmartSection
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Em dash prefix
            Text("—")
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(isSelected ? 0.8 : 0.3))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                // Section title
                HStack(spacing: 8) {
                    Text(section.title.uppercased())
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(isSelected ? 1 : 0.85))
                    
                    Text("(\(section.notes.count))")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                }
                
                // Preview of first few items
                if isSelected || isHovered {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(section.notes.prefix(3)) { note in
                            HStack(spacing: 6) {
                                Text("·")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.3))
                                
                                Text(note.content)
                                    .font(.system(size: 11, weight: .regular, design: .default))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.leading, 4)
                        }
                        
                        if section.notes.count > 3 {
                            Text("+ \(section.notes.count - 3) more")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.3))
                                .padding(.leading, 10)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }
            }
            
            Spacer()
        }
        .padding(.vertical, isSelected ? 14 : 10)
        .padding(.horizontal, 28)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.02))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Edge Swipe Modifier
struct EdgeSwipeGesture: ViewModifier {
    @Binding var isShowingNavigator: Bool
    let sections: [SmartSection]
    let onSectionTap: (SmartSection) -> Void
    
    @State private var dragStartLocation: CGPoint = .zero
    @GestureState private var isDragging = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .updating($isDragging) { value, state, _ in
                            if dragStartLocation == .zero {
                                dragStartLocation = value.startLocation
                            }
                            state = true
                        }
                        .onChanged { value in
                            // Check if swipe started from left edge
                            if value.startLocation.x < 20 && value.translation.width > 50 {
                                if !isShowingNavigator {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        isShowingNavigator = true
                                    }
                                    HapticManager.shared.mediumTap()
                                }
                            }
                        }
                        .onEnded { _ in
                            dragStartLocation = .zero
                        }
                )
            
            AmbientSectionsNavigator(
                isShowing: $isShowingNavigator,
                sections: sections,
                onSectionTap: onSectionTap
            )
        }
    }
}

extension View {
    func ambientSectionsNavigator(
        isShowing: Binding<Bool>,
        sections: [SmartSection],
        onSectionTap: @escaping (SmartSection) -> Void
    ) -> some View {
        modifier(EdgeSwipeGesture(
            isShowingNavigator: isShowing,
            sections: sections,
            onSectionTap: onSectionTap
        ))
    }
}