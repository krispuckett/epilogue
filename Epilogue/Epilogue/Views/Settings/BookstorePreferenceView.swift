import SwiftUI

/// Settings view for choosing preferred bookstore for "Buy" links
struct BookstorePreferenceView: View {
    @State private var selectedBookstore: PresetBookstore
    @State private var customURL: String
    @State private var showingCustomURLInfo = false

    @Environment(\.dismiss) private var dismiss

    init() {
        let builder = BookstoreURLBuilder.shared
        _selectedBookstore = State(initialValue: builder.preferredBookstore)
        _customURL = State(initialValue: builder.customURLTemplate)
    }

    var body: some View {
        ZStack {
            // Atmospheric gradient background
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)

            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)

            Form {
                // MARK: - Bookstore Selection
                Section {
                    ForEach(PresetBookstore.allCases) { bookstore in
                        BookstoreOptionRow(
                            bookstore: bookstore,
                            isSelected: selectedBookstore == bookstore,
                            onSelect: {
                                selectedBookstore = bookstore
                                BookstoreURLBuilder.shared.preferredBookstore = bookstore
                                SensoryFeedback.selection()
                            }
                        )
                    }
                } header: {
                    Text("Choose Your Bookstore")
                } footer: {
                    Text("Book recommendation links will open in your preferred store.")
                }

                // MARK: - Custom URL Template (shown when custom is selected)
                if selectedBookstore == .custom {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("https://example.com/search?q={query}", text: $customURL)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .onChange(of: customURL) { _, newValue in
                                    BookstoreURLBuilder.shared.customURLTemplate = newValue
                                }

                            Button {
                                showingCustomURLInfo = true
                            } label: {
                                Label("How to format your URL", systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                            }
                        }
                    } header: {
                        Text("Custom URL Template")
                    } footer: {
                        Text("Enter a search URL with {query} where the book search terms go.")
                    }
                }

                // MARK: - Preview
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        let previewURL = BookstoreURLBuilder.shared.buildURL(
                            title: "The Odyssey",
                            author: "Homer",
                            isbn: "9780140268867"
                        )

                        Text(previewURL)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Example Link")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle("Preferred Bookstore")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCustomURLInfo) {
            CustomURLHelpSheet()
        }
    }
}

// MARK: - Bookstore Option Row

private struct BookstoreOptionRow: View {
    let bookstore: PresetBookstore
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: bookstore.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? ThemeManager.shared.currentTheme.primaryAccent : .secondary)
                    .frame(width: 28)

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookstore.rawValue)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(bookstore.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(bookstore.rawValue), \(bookstore.subtitle)")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Custom URL Help Sheet

private struct CustomURLHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom URL Template")
                                .font(.title2.bold())

                            Text("Enter a URL from your preferred bookstore with placeholders that will be replaced with book information.")
                                .foregroundStyle(.secondary)
                        }

                        // Placeholders section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Placeholders")
                                .font(.headline)

                            PlaceholderRow(
                                placeholder: "{query}",
                                description: "Book title + author combined",
                                example: "The Odyssey Homer"
                            )

                            PlaceholderRow(
                                placeholder: "{title}",
                                description: "Just the book title",
                                example: "The Odyssey"
                            )

                            PlaceholderRow(
                                placeholder: "{author}",
                                description: "Just the author name",
                                example: "Homer"
                            )

                            PlaceholderRow(
                                placeholder: "{isbn}",
                                description: "ISBN (if available)",
                                example: "9780140268867"
                            )
                        }

                        Divider()

                        // Examples section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Examples")
                                .font(.headline)

                            ExampleRow(
                                store: "Local library",
                                url: "https://mylibrary.org/search?q={query}"
                            )

                            ExampleRow(
                                store: "Indie bookstore",
                                url: "https://mybookshop.com/search/{query}"
                            )

                            ExampleRow(
                                store: "ISBN lookup",
                                url: "https://isbnsearch.org/isbn/{isbn}"
                            )
                        }

                        // Tip
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)

                            Text("Tip: Go to your bookstore, search for any book, then copy the URL and replace the search terms with {query}.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PlaceholderRow: View {
    let placeholder: String
    let description: String
    let example: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(placeholder)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)

                Text("- \(description)")
                    .foregroundStyle(.primary)
            }

            Text("Example: \(example)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExampleRow: View {
    let store: String
    let url: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store)
                .font(.subheadline.bold())

            Text(url)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        BookstorePreferenceView()
    }
    .preferredColorScheme(.dark)
}
