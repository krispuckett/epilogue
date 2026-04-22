import SwiftUI
import SwiftData

struct AddReadingSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LibraryViewModel.self) private var libraryViewModel

    let book: Book
    let bookModel: BookModel?
    let colorPalette: ColorPalette?
    var onSaved: (() -> Void)? = nil

    @State private var startPage: String
    @State private var endPage: String
    @State private var durationMinutes: String = "30"
    @State private var sessionDate: Date = Date()
    @FocusState private var focusedField: Field?

    enum Field {
        case startPage, endPage, durationMinutes
    }

    init(book: Book, bookModel: BookModel?, colorPalette: ColorPalette?, onSaved: (() -> Void)? = nil) {
        self.book = book
        self.bookModel = bookModel
        self.colorPalette = colorPalette
        self.onSaved = onSaved
        let currentPage = bookModel?.currentPage ?? book.currentPage
        _startPage = State(initialValue: "\(max(0, currentPage - 10))")
        _endPage = State(initialValue: "\(currentPage)")
    }

    private var accentColor: Color {
        guard let palette = colorPalette else { return Color.warmAmber }
        return enhanceColor(palette.primary)
    }

    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        saturation = min(saturation * 1.4, 1.0)
        brightness = max(brightness, 0.4)
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }

    private var pagesReadValue: Int {
        let start = Int(startPage) ?? 0
        let end = Int(endPage) ?? 0
        return max(0, end - start)
    }

    private var durationSeconds: TimeInterval {
        let minutes = Double(durationMinutes) ?? 0
        return max(0, minutes * 60)
    }

    private var canSave: Bool {
        guard let start = Int(startPage), let end = Int(endPage), let minutes = Double(durationMinutes) else {
            return false
        }
        return start >= 0 && end >= start && minutes > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Pages row
                VStack(spacing: 14) {
                    HStack(spacing: 20) {
                        numberField(
                            title: "START PAGE",
                            text: $startPage,
                            field: .startPage
                        )

                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.white.opacity(0.3))

                        numberField(
                            title: "CURRENT PAGE",
                            text: $endPage,
                            field: .endPage
                        )
                    }

                    Text("\(pagesReadValue) page\(pagesReadValue == 1 ? "" : "s") read")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(0.5)
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                }

                // Duration + date
                VStack(spacing: 20) {
                    HStack {
                        Text("DURATION")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(1)
                        Spacer()
                        TextField("30", text: $durationMinutes)
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .durationMinutes)
                            .keyboardType(.numberPad)
                        Text("min")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Divider().background(Color.white.opacity(0.08))

                    HStack {
                        Text("WHEN")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(1)
                        Spacer()
                        DatePicker(
                            "",
                            selection: $sessionDate,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(accentColor)
                    }
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle("Log Reading Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: saveSession) {
                    Text("Save Session")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(canSave ? Color.white : Color.white.opacity(0.4))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .glassEffect(.regular.tint(accentColor.opacity(canSave ? 0.3 : 0.08)), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(accentColor.opacity(canSave ? 0.4 : 0.15), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }

    private func numberField(title: String, text: Binding<String>, field: Field) -> some View {
        VStack(spacing: 8) {
            TextField("0", text: text)
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(width: 90)
                .focused($focusedField, equals: field)
                .keyboardType(.numberPad)

            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)
        }
        .padding(8)
        .overlay {
            if focusedField == field {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(0.5), lineWidth: 1)
            }
        }
    }

    private func saveSession() {
        guard canSave else { return }

        // Resolve (or create) a BookModel so the session links to persistent storage
        let model: BookModel
        if let existing = bookModel {
            model = existing
        } else {
            model = BookModel(from: book)
            modelContext.insert(model)
        }

        let start = Int(startPage) ?? 0
        let end = Int(endPage) ?? start
        let duration = durationSeconds

        let session = ReadingSession(bookModel: model, startPage: start)
        session.startDate = sessionDate
        session.endDate = sessionDate.addingTimeInterval(duration)
        session.endPage = end
        session.pagesRead = max(0, end - start)
        session.duration = duration
        modelContext.insert(session)

        // Also update the book's current page if the end page advances progress
        if end > model.currentPage {
            model.currentPage = end
            libraryViewModel.updateCurrentPage(for: book, to: end)
        }

        try? modelContext.save()
        SensoryFeedback.success()
        onSaved?()
        dismiss()
    }
}
