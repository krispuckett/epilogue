import SwiftUI
import VisionKit
import Combine

// MARK: - Simple Live Quote Capture
/// Ultra-simple live text capture using DataScannerViewController
/// Apple's built-in solution - handles camera, recognition, and highlights automatically

@available(iOS 16.0, *)
struct SimpleLiveQuoteCapture: View {
    let bookContext: Book?
    let onQuoteSaved: (String, Int?) -> Void
    let onQuestionAsked: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator = DataScannerCoordinator()

    var body: some View {
        ZStack {
            // Layer 1: DataScanner (camera + text recognition + highlights built-in!)
            SimpleDataScannerRepresentable(coordinator: coordinator)
                .ignoresSafeArea()

            // Layer 2: Top Controls
            VStack {
                HStack {
                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(in: .circle)

                    Spacer()

                    // Hint
                    if coordinator.selectedText == nil {
                        Text("Tap text to select")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassEffect(in: .capsule)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()
            }

            // Layer 3: Action Pills (when text selected)
            if let selectedText = coordinator.selectedText {
                VStack {
                    Spacer()

                    HStack(spacing: 20) {
                        // Save Quote
                        SimpleActionPill(
                            icon: "quote.bubble.fill",
                            label: "Save",
                            color: .white
                        ) {
                            saveQuote(selectedText)
                        }

                        // Ask Question
                        SimpleActionPill(
                            icon: "bubble.left.and.text.bubble.right",
                            label: "Ask",
                            color: .orange
                        ) {
                            askAboutQuote(selectedText)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            coordinator.startScanning()

            #if DEBUG
            print("🎥 [SIMPLE SCANNER] Started scanning")
            #endif
        }
        .onDisappear {
            coordinator.stopScanning()

            #if DEBUG
            print("🎥 [SIMPLE SCANNER] Stopped scanning")
            #endif
        }
    }

    private func saveQuote(_ text: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onQuoteSaved(text, nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
        }
    }

    private func askAboutQuote(_ text: String) {
        let question = "What does this mean: \"\(text)\""

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onQuestionAsked(question)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
        }
    }
}

// MARK: - DataScanner Coordinator

@MainActor
class DataScannerCoordinator: NSObject, ObservableObject {
    @Published var selectedText: String?

    var dataScanner: DataScannerViewController?

    override init() {
        super.init()
        setupScanner()
    }

    private func setupScanner() {
        guard DataScannerViewController.isSupported,
              DataScannerViewController.isAvailable else {
            print("❌ DataScanner not available")
            return
        }

        // Configure for text recognition
        dataScanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true  // Auto-highlight recognized text!
        )

        dataScanner?.delegate = self
    }

    func startScanning() {
        try? dataScanner?.startScanning()
    }

    func stopScanning() {
        dataScanner?.stopScanning()
    }
}

// MARK: - DataScanner Delegate

extension DataScannerCoordinator: DataScannerViewControllerDelegate {
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        switch item {
        case .text(let text):
            // User tapped on recognized text
            selectedText = text.transcript
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            #if DEBUG
            print("✅ [SCANNER] Selected: \(text.transcript)")
            #endif

        default:
            break
        }
    }
}

// MARK: - DataScanner Representable

@available(iOS 16.0, *)
struct SimpleDataScannerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var coordinator: DataScannerCoordinator

    func makeUIViewController(context: Context) -> UIViewController {
        guard let scanner = coordinator.dataScanner else {
            // Return placeholder when scanner is unavailable
            let placeholder = UIViewController()
            placeholder.view.backgroundColor = .black

            let label = UILabel()
            label.text = "Camera text scanning is not available on this device"
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false

            placeholder.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: placeholder.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: placeholder.view.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: placeholder.view.leadingAnchor, constant: 40),
                label.trailingAnchor.constraint(equalTo: placeholder.view.trailingAnchor, constant: -40)
            ])

            return placeholder
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
        if let scanner = uiViewController as? DataScannerViewController {
            scanner.stopScanning()
        }
    }
}

// MARK: - Action Pill Component

struct SimpleActionPill: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))

                Text(label)
                    .font(.system(size: 18, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
        .glassEffect(.regular.tint(color.opacity(0.15)), in: .capsule)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .shadow(
            color: color.opacity(isPressed ? 0.4 : 0.2),
            radius: isPressed ? 16 : 8,
            y: isPressed ? 4 : 2
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        SimpleLiveQuoteCapture(
            bookContext: nil,
            onQuoteSaved: { text, page in
                print("Saved: \(text)")
            },
            onQuestionAsked: { question in
                print("Asked: \(question)")
            }
        )
    }
}
