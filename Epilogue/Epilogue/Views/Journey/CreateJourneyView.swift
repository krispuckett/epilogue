import SwiftUI
import SwiftData

// MARK: - Create Journey View
/// Conversational interface for creating a new reading journey
struct CreateJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var manager = ReadingJourneyManager.shared
    @Query(filter: #Predicate<BookModel> { $0.isInLibrary }, sort: \BookModel.dateAdded)
    private var libraryBooks: [BookModel]

    @State private var step: CreationStep = .welcome
    @State private var selectedBooks: Set<String> = []
    @State private var userIntent: String = ""
    @State private var timeframe: String = ""
    @State private var readingPattern: String = "Flexible"
    @State private var isCreating: Bool = false

    // Deduplicated books (only unique by book.id)
    private var uniqueLibraryBooks: [BookModel] {
        var seen = Set<String>()
        return libraryBooks.filter { book in
            if seen.contains(book.id) {
                return false
            } else {
                seen.insert(book.id)
                return true
            }
        }
    }

    enum CreationStep {
        case welcome
        case selectBooks
        case setIntent
        case setPreferences
        case creating
        case complete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Minimal gradient background
                minimalGradientBackground

                ScrollView {
                    VStack(spacing: 32) {
                        switch step {
                        case .welcome:
                            welcomeStep
                        case .selectBooks:
                            selectBooksStep
                        case .setIntent:
                            setIntentStep
                        case .setPreferences:
                            setPreferencesStep
                        case .creating:
                            creatingStep
                        case .complete:
                            completeStep
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.vertical, 40)
                }
            }
            .navigationTitle("Create Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step != .creating && step != .complete {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    // MARK: - Background
    private var minimalGradientBackground: some View {
        ZStack {
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Welcome Step
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "map.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))

            VStack(spacing: 12) {
                Text("Let's Plan Your Reading")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Text("I'll help you create a thoughtful reading timeline that honors your goals and gives you breathing room.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 16) {
                InfoCard(
                    icon: "book.fill",
                    title: "Select Your Books",
                    description: "Choose what you want to read"
                )

                InfoCard(
                    icon: "bubble.left.fill",
                    title: "Share Your Intent",
                    description: "Tell me what you're hoping for"
                )

                InfoCard(
                    icon: "sparkles",
                    title: "Get Your Timeline",
                    description: "I'll suggest a thoughtful reading order"
                )
            }
            .padding(.top, 16)

            Button(action: { withAnimation { step = .selectBooks } }) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 1.0, green: 0.549, blue: 0.259))
                    )
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Select Books Step
    private var selectBooksStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Books")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Text("Choose the books you want to include in your reading journey. I'll help you figure out a good order.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if uniqueLibraryBooks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))

                    Text("No books in your library yet")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(uniqueLibraryBooks, id: \.localId) { book in
                        BookSelectionRow(
                            book: book,
                            isSelected: selectedBooks.contains(book.id)
                        ) {
                            toggleBookSelection(book)
                        }
                    }
                }
            }

            Button(action: { withAnimation { step = .setIntent } }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedBooks.isEmpty ? Color.white.opacity(0.1) : Color(red: 1.0, green: 0.549, blue: 0.259))
                    )
            }
            .disabled(selectedBooks.isEmpty)
        }
    }

    // MARK: - Set Intent Step
    private var setIntentStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("What's Your Goal?")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Text("Share what you're hoping to get from your reading. This helps me create a timeline that makes sense for you.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Examples:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))

                VStack(alignment: .leading, spacing: 8) {
                    ExampleIntentButton(
                        text: "I want to read more classics",
                        userIntent: $userIntent
                    )
                    ExampleIntentButton(
                        text: "Looking for something lighter this month",
                        userIntent: $userIntent
                    )
                    ExampleIntentButton(
                        text: "Diving deep into philosophy",
                        userIntent: $userIntent
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Your intent")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                TextField("Tell me what you're hoping for...", text: $userIntent, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .padding()
                    .lineLimit(3...6)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }

            Spacer()

            Button(action: { withAnimation { step = .setPreferences } }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(userIntent.isEmpty ? Color.white.opacity(0.1) : Color(red: 1.0, green: 0.549, blue: 0.259))
                    )
            }
            .disabled(userIntent.isEmpty)
        }
    }

    // MARK: - Set Preferences Step
    private var setPreferencesStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("A Few Preferences")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)

                Text("These help create a timeline that works for you.")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 20) {
                // Timeframe
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))

                        Text("Timeframe")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        Text("(optional)")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    TextField("This month, this season, by end of year...", text: $timeframe)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(16)
                        .glassEffect(in: .rect(cornerRadius: 12))
                }

                // Reading pattern
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))

                        Text("Reading Pattern")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Picker("Reading pattern", selection: $readingPattern) {
                        Text("Flexible").tag("Flexible")
                        Text("Morning").tag("Morning")
                        Text("Evening").tag("Evening")
                        Text("Weekend").tag("Weekend")
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)
                }
            }

            Spacer()

            Button(action: createJourney) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))

                    Text("Create Journey")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 1.0, green: 0.549, blue: 0.259))
                )
            }
        }
    }

    // MARK: - Creating Step
    private var creatingStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            VStack(spacing: 12) {
                Text("Creating Your Journey")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Text("Analyzing your books and preferences...")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()
        }
    }

    // MARK: - Complete Step
    private var completeStep: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 80)

                // Success icon with animation effect
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 30)

                    // Inner glow
                    Circle()
                        .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.2))
                        .frame(width: 100, height: 100)
                        .blur(radius: 15)

                    // Icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.549, blue: 0.259),
                                    Color(red: 1.0, green: 0.649, blue: 0.359)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 20) {
                    Text("Journey Created!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(spacing: 12) {
                        Text("Your personalized reading timeline is ready.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))

                        Text("Remember: this is a companion, not a strict schedule. Adjust anytime it doesn't feel right.")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineSpacing(3)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                }

                VStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 15, weight: .semibold))

                            Text("View Your Journey")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 1.0, green: 0.549, blue: 0.259))
                        )
                    }

                    Text("You can adjust your journey anytime")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 8)

                Spacer()
                    .frame(height: 80)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Helper Methods

    private func toggleBookSelection(_ book: BookModel) {
        if selectedBooks.contains(book.id) {
            selectedBooks.remove(book.id)
        } else {
            selectedBooks.insert(book.id)
        }
    }

    private func createJourney() {
        step = .creating

        Task {
            let books = uniqueLibraryBooks.filter { selectedBooks.contains($0.id) }

            let preferences = ReadingPreferences(
                timeframe: timeframe.isEmpty ? nil : timeframe,
                readingPattern: readingPattern,
                pace: nil,
                mood: nil
            )

            do {
                _ = try await manager.createJourneyFromConversation(
                    books: books,
                    userIntent: userIntent,
                    timeframe: timeframe.isEmpty ? nil : timeframe,
                    preferences: preferences
                )

                await MainActor.run {
                    withAnimation {
                        step = .complete
                    }
                }
            } catch {
                print("❌ Failed to create journey: \(error)")
                // Handle error - for now just dismiss
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}

struct BookSelectionRow: View {
    let book: BookModel
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Book cover
                AsyncImage(url: URL(string: book.coverImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                }
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)

                    Text(book.author)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.549, blue: 0.259) : Color.white.opacity(0.3))
            }
            .padding(12)
            .glassEffect(in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.5) : Color.clear,
                        lineWidth: isSelected ? 1.5 : 0
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ExampleIntentButton: View {
    let text: String
    @Binding var userIntent: String

    private var isSelected: Bool {
        userIntent == text
    }

    var body: some View {
        Button(action: { userIntent = text }) {
            HStack {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white.opacity(0.95) : .white.opacity(0.7))

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.up.forward")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.549, blue: 0.259) : .white.opacity(0.4))
            }
            .padding(12)
            .glassEffect(in: .rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.5) : Color.clear,
                        lineWidth: isSelected ? 1.5 : 0
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    CreateJourneyView()
        .modelContainer(for: [BookModel.self, ReadingJourney.self])
}
