import SwiftUI

// MARK: - Capture Review Queue
// Intelligent queue for reviewing low-confidence captures before saving

struct CaptureReviewQueue: View {
    @StateObject private var processor = TrueAmbientProcessor.shared
    @State private var reviewQueue: [PendingCapture] = []
    @State private var isAnimating = false
    
    struct PendingCapture: Identifiable {
        let id = UUID()
        let text: String
        let suggestedType: CaptureType
        let confidence: Float
        let timestamp: Date
        let theme: String?
        let pageReference: Int?
    }
    
    enum CaptureType {
        case quote
        case note
        case question
        
        var icon: String {
            switch self {
            case .quote: return "quote.opening"
            case .note: return "note.text"
            case .question: return "questionmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .quote: return Color(red: 0.4, green: 0.7, blue: 1.0)
            case .note: return Color(red: 1.0, green: 0.549, blue: 0.259)
            case .question: return Color(red: 0.6, green: 0.8, blue: 0.4)
            }
        }
        
        var label: String {
            switch self {
            case .quote: return "QUOTE"
            case .note: return "NOTE"
            case .question: return "QUESTION"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !reviewQueue.isEmpty {
                // Header
                HStack {
                    Label("Review Captures", systemImage: "checkmark.shield")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(reviewQueue.count) pending")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.02))
                
                // Queue items
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(reviewQueue) { capture in
                            ReviewItemView(
                                capture: capture,
                                onConfirm: {
                                    confirmCapture(capture)
                                },
                                onDiscard: {
                                    discardCapture(capture)
                                },
                                onChangeType: { newType in
                                    updateCaptureType(capture, to: newType)
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .slide.combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 300)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.001))
        )
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .opacity(reviewQueue.isEmpty ? 0 : 1)
        .scaleEffect(reviewQueue.isEmpty ? 0.9 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: reviewQueue.count)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CaptureForReview"))) { notification in
            if let data = notification.object as? [String: Any],
               let text = data["text"] as? String,
               let typeString = data["type"] as? String,
               let confidence = data["confidence"] as? Float {
                
                let type: CaptureType
                switch typeString {
                case "quote": type = .quote
                case "question": type = .question
                default: type = .note
                }
                
                let capture = PendingCapture(
                    text: text,
                    suggestedType: type,
                    confidence: confidence,
                    timestamp: Date(),
                    theme: data["theme"] as? String,
                    pageReference: data["page"] as? Int
                )
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    reviewQueue.append(capture)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func confirmCapture(_ capture: PendingCapture) {
        // Send confirmed capture back to processor
        Task {
            await processor.processDetectedText(
                capture.text,
                confidence: 0.99 // High confidence after user confirmation
            )
        }
        
        // Remove from queue
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            reviewQueue.removeAll { $0.id == capture.id }
        }
        
        SensoryFeedback.success()
    }
    
    private func discardCapture(_ capture: PendingCapture) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            reviewQueue.removeAll { $0.id == capture.id }
        }
        
        SensoryFeedback.light()
    }
    
    private func updateCaptureType(_ capture: PendingCapture, to newType: CaptureType) {
        if let index = reviewQueue.firstIndex(where: { $0.id == capture.id }) {
            reviewQueue[index] = PendingCapture(
                text: capture.text,
                suggestedType: newType,
                confidence: capture.confidence,
                timestamp: capture.timestamp,
                theme: capture.theme,
                pageReference: capture.pageReference
            )
        }
    }
}

// MARK: - Review Item View
struct ReviewItemView: View {
    let capture: CaptureReviewQueue.PendingCapture
    let onConfirm: () -> Void
    let onDiscard: () -> Void
    let onChangeType: (CaptureReviewQueue.CaptureType) -> Void
    
    @State private var isExpanded = false
    @State private var typeMenuExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with type and confidence
            HStack(spacing: 12) {
                // Type selector
                Menu {
                    ForEach([CaptureReviewQueue.CaptureType.quote, .note, .question], id: \.self) { type in
                        Button {
                            onChangeType(type)
                            typeMenuExpanded = false
                        } label: {
                            Label(type.label, systemImage: type.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: capture.suggestedType.icon)
                            .font(.system(size: 14))
                            .foregroundColor(capture.suggestedType.color)
                        
                        Text(capture.suggestedType.label)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(capture.suggestedType.color.opacity(0.15))
                    )
                }
                
                // Confidence indicator
                CaptureConfidenceBar(confidence: capture.confidence)
                    .frame(width: 60, height: 4)
                
                Spacer()
                
                // Quick actions
                HStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.green.opacity(0.15)))
                    }
                    
                    Button(action: onDiscard) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.red.opacity(0.15)))
                    }
                }
            }
            
            // Content preview
            Text(capture.text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                }
            
            // Metadata (if available)
            if capture.theme != nil || capture.pageReference != nil {
                HStack(spacing: 16) {
                    if let theme = capture.theme {
                        Label(theme, systemImage: "tag")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    if let page = capture.pageReference {
                        Label("Page \(page)", systemImage: "book.pages")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Capture Confidence Bar
struct CaptureConfidenceBar: View {
    let confidence: Float
    
    var color: Color {
        switch confidence {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .yellow
        default:
            return .orange
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.white.opacity(0.1))
                
                // Fill
                Capsule()
                    .fill(color.opacity(0.8))
                    .frame(width: geometry.size.width * CGFloat(confidence))
            }
        }
    }
}