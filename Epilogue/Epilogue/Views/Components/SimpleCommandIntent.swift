import SwiftUI

// MARK: - Simple Command Intent (Clean like screenshots)
struct SimpleCommandIntent: View {
    @Binding var isPresented: Bool
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel

    // Quick action suggestions
    struct QuickAction: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let action: () -> Void
    }

    private var quickActions: [QuickAction] {
        [
            QuickAction(icon: "camera.viewfinder", title: "Scan book") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: Notification.Name("ShowEnhancedBookScanner"), object: nil)
                }
            },
            QuickAction(icon: "magnifyingglass", title: "Search books") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: Notification.Name("ShowBookSearch"), object: nil)
                }
            },
            QuickAction(icon: "note.text", title: "New note") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: Notification.Name("CreateNewNote"), object: nil)
                }
            }
        ]
    }

    private var contextualSuggestions: [String] {
        if inputText.isEmpty {
            return ["Add book", "Create note", "Start reading"]
        }

        let lowercased = inputText.lowercased()

        if lowercased.contains("book") || lowercased.contains("add") {
            return ["Add \"The Lord of the Rings\"", "Scan book cover", "Search for books"]
        } else if lowercased.contains("note") || lowercased.contains("write") {
            return ["Create a new note", "Add note to current book", "Write a quote"]
        } else if lowercased.contains("read") {
            return ["Start ambient reading", "Continue reading", "View reading progress"]
        }

        return ["Search for \"\(inputText)\"", "Create note about \"\(inputText)\""]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Clean input field with glass effect
            VStack(spacing: 16) {
                // Text input
                HStack(spacing: 12) {
                    TextField("What's on your mind?", text: $inputText)
                        .font(.system(size: 17))
                        .focused($isInputFocused)
                        .onSubmit {
                            handleSubmit()
                        }

                    Button {
                        if inputText.isEmpty {
                            dismiss()
                        } else {
                            handleSubmit()
                        }
                    } label: {
                        Text(inputText.isEmpty ? "Cancel" : "Create")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(inputText.isEmpty ? Color.secondary : DesignSystem.Colors.primaryAccent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))

                // Quick actions row (only when no text)
                if inputText.isEmpty {
                    HStack(spacing: 24) {
                        ForEach(quickActions) { action in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                action.action()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: action.icon)
                                        .font(.system(size: 24))
                                        .foregroundStyle(Color.secondary)
                                        .frame(width: 44, height: 44)
                                        .glassEffect(.regular, in: Circle())

                                    Text(action.title)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Contextual suggestions
                if !inputText.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(contextualSuggestions, id: \.self) { suggestion in
                            Button {
                                handleSuggestion(suggestion)
                            } label: {
                                HStack {
                                    Text(suggestion)
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.primary)

                                    Spacer()

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondary.opacity(0.5))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if suggestion != contextualSuggestions.last {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .presentationDetents([.height(inputText.isEmpty ? 200 : 280)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(.clear)
        .interactiveDismissDisabled(false)
        .onAppear {
            isInputFocused = true
        }
    }

    private func handleSubmit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Process the command
        if trimmed.lowercased().contains("book") {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: Notification.Name("ShowBookSearch"), object: nil)
            }
        } else if trimmed.lowercased().contains("note") {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: Notification.Name("CreateNewNote"), object: nil)
            }
        } else {
            // Default action - search
            dismiss()
        }
    }

    private func handleSuggestion(_ suggestion: String) {
        inputText = suggestion
        handleSubmit()
    }

    private func dismiss() {
        isInputFocused = false
        withAnimation(.interactiveSpring(response: 0.3)) {
            isPresented = false
        }
    }
}