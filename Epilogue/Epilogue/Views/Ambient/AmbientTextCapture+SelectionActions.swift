import SwiftUI
import VisionKit
import UIKit

// MARK: - Selection Pills Overlay
struct SelectionPillsOverlay: View {
    let selectedText: String
    let pageNumber: Int?
    let bookContext: Book?
    let onAddQuote: () -> Void
    let onAskEpilogue: () -> Void
    let onDismiss: () -> Void

    @State private var showPills = false
    @State private var pillsOffset: CGFloat = 50

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                // Add Quote Pill
                ActionPill(
                    icon: "quote.bubble.fill",
                    title: "Save Quote",
                    color: .blue,
                    action: {
                        SensoryFeedbackHelper.impact(.light)
                        onAddQuote()
                        withAnimation(.spring(response: 0.3)) {
                            showPills = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                )

                // Ask AI Pill
                ActionPill(
                    icon: "sparkles",
                    title: "Ask AI",
                    color: .purple,
                    action: {
                        SensoryFeedbackHelper.impact(.medium)
                        onAskEpilogue()
                        withAnimation(.spring(response: 0.3)) {
                            showPills = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                )

                // Copy Pill
                ActionPill(
                    icon: "doc.on.doc",
                    title: "Copy",
                    color: .gray,
                    action: {
                        UIPasteboard.general.string = selectedText
                        SensoryFeedbackHelper.selection()
                        withAnimation(.spring(response: 0.3)) {
                            showPills = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                )

                // Dismiss
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showPills = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .glassEffect(in: .circle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
            .offset(y: showPills ? 0 : pillsOffset)
            .opacity(showPills ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showPills = true
                pillsOffset = 0
            }
        }
    }
}

// MARK: - Action Pill Component
struct ActionPill: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.multicolor)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 72, height: 72)
            .glassEffect(in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                color.opacity(isPressed ? 0.6 : 0.3),
                                color.opacity(isPressed ? 0.4 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onTapGesture {
            // No-op, handled by button action
        }
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.spring(response: 0.2)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Enhanced Live Text View with Pills
struct EnhancedLiveTextImageView: View {
    let image: UIImage
    @Binding var imageAnalysisInteraction: ImageAnalysisInteraction?
    @Binding var selectedText: String
    let pageNumber: Int?
    let bookContext: Book?
    let onAddQuote: (String, Int?) -> Void
    let onAskEpilogue: (String) -> Void

    @State private var showSelectionPills = false

    var body: some View {
        ZStack {
            // Live Text implementation with image
            if let interaction = imageAnalysisInteraction {
                LiveTextContainerView(
                    image: image,
                    interaction: interaction,
                    selectedText: $selectedText,
                    onSelectionChange: { newText in
                        selectedText = newText
                        withAnimation(.spring(response: 0.3)) {
                            showSelectionPills = !newText.isEmpty
                        }
                    }
                )
            } else {
                // Show the image while analysis is loading
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // Floating pills when text is selected
            if showSelectionPills && !selectedText.isEmpty {
                SelectionPillsOverlay(
                    selectedText: selectedText,
                    pageNumber: pageNumber,
                    bookContext: bookContext,
                    onAddQuote: {
                        onAddQuote(selectedText, pageNumber)
                    },
                    onAskEpilogue: {
                        onAskEpilogue(selectedText)
                    },
                    onDismiss: {
                        withAnimation {
                            selectedText = ""
                            showSelectionPills = false
                        }
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Live Text Container View
struct LiveTextContainerView: UIViewRepresentable {
    let image: UIImage
    let interaction: ImageAnalysisInteraction
    @Binding var selectedText: String
    let onSelectionChange: (String) -> Void

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true

        // Add the interaction
        imageView.addInteraction(interaction)

        // Set up selection monitoring
        context.coordinator.interaction = interaction
        context.coordinator.startMonitoring()

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Update if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: LiveTextContainerView
        var interaction: ImageAnalysisInteraction?
        private var selectionTimer: Timer?

        init(_ parent: LiveTextContainerView) {
            self.parent = parent
        }

        func startMonitoring() {
            // Monitor for selection changes
            selectionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                self.checkSelection()
            }
        }

        private func checkSelection() {
            guard let interaction = interaction else { return }

            if interaction.hasActiveTextSelection {
                let text = interaction.selectedText
                if !text.isEmpty && text != parent.selectedText {
                    DispatchQueue.main.async {
                        self.parent.onSelectionChange(text)
                    }
                }
            } else if !parent.selectedText.isEmpty {
                DispatchQueue.main.async {
                    self.parent.onSelectionChange("")
                }
            }
        }

        deinit {
            selectionTimer?.invalidate()
        }
    }
}

// MARK: - Toast Notification Helper
extension View {
    func showToast(_ message: String, icon: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("ShowToastMessage"),
                object: message,
                userInfo: ["icon": icon]
            )
        }
    }
}

// MARK: - Text Selection View for Reading Mode
struct TextSelectionView: UIViewRepresentable {
    let text: String
    let onSelectionChange: (String) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.text = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = .systemFont(ofSize: 16)
        textView.delegate = context.coordinator

        // Configure text selection
        textView.selectedTextRange = nil

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: TextSelectionView

        init(_ parent: TextSelectionView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let selectedRange = textView.selectedTextRange else {
                parent.onSelectionChange("")
                return
            }

            let selectedText = textView.text(in: selectedRange) ?? ""
            parent.onSelectionChange(selectedText)
        }
    }
}