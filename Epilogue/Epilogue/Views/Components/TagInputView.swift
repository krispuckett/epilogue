import SwiftUI

// MARK: - Tag Input View
/// Reusable component for managing tags with horizontal pills and inline add field

struct TagInputView: View {
    @Binding var tags: [String]
    var placeholder: String = "Add tag..."
    var accentColor: Color = DesignSystem.Colors.primaryAccent

    @State private var newTagText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Existing tags
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            RemovableTagPill(
                                text: tag,
                                accentColor: accentColor,
                                onRemove: { removeTag(tag) }
                            )
                        }
                    }
                }
            }

            // Add tag field
            HStack(spacing: 12) {
                Image(systemName: "tag")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))

                TextField(placeholder, text: $newTagText)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .focused($isFocused)
                    .onSubmit {
                        addTag()
                    }
                    .submitLabel(.done)

                if !newTagText.isEmpty {
                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(.white.opacity(0.03)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: newTagText.isEmpty)
        }
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            newTagText = ""
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            tags.append(trimmed)
        }
        newTagText = ""
        SensoryFeedback.light()
    }

    private func removeTag(_ tag: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            tags.removeAll { $0 == tag }
        }
        SensoryFeedback.light()
    }
}

// MARK: - Removable Tag Pill Component
/// Individual removable tag pill with X button

struct RemovableTagPill: View {
    let text: String
    var accentColor: Color = DesignSystem.Colors.primaryAccent
    let onRemove: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(accentColor.opacity(0.2))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(accentColor.opacity(0.4), lineWidth: 0.5)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }
}

// MARK: - Tag Filter Chip
/// Read-only tag chip for filtering (non-removable)

struct TagFilterChip: View {
    let text: String
    let isSelected: Bool
    var accentColor: Color = DesignSystem.Colors.primaryAccent
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            onTap()
            SensoryFeedback.light()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10))

                Text(text)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? accentColor.opacity(0.4) : .white.opacity(0.05))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? accentColor.opacity(0.6) : .white.opacity(0.1), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        TagInputView(tags: .constant(["fiction", "favorites", "to-discuss"]))

        HStack(spacing: 8) {
            TagFilterChip(text: "fiction", isSelected: true, onTap: {})
            TagFilterChip(text: "favorites", isSelected: false, onTap: {})
            TagFilterChip(text: "reading", isSelected: false, onTap: {})
        }
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
