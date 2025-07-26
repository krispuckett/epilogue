import SwiftUI
import SwiftData
import Combine
import Accelerate
import AVFoundation

// MARK: - Voice Waveform Gradient View
struct VoiceWaveformGradient: View {
    @Binding var audioLevel: Float
    @Binding var isRecording: Bool
    @State private var waveformData: [Float] = Array(repeating: 0, count: 100)
    @State private var displayLink: CADisplayLink?
    @State private var phase: Double = 0
    
    // Waveform parameters
    let waveCount = 100
    let baseHeight: CGFloat = 40
    let maxAmplitude: CGFloat = 60
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawWaveform(context: context, size: size)
            }
        }
        .frame(height: baseHeight + maxAmplitude)
        .onChange(of: audioLevel) { _, newLevel in
            updateWaveform(with: newLevel)
        }
        .onAppear {
            startDisplayLink()
        }
        .onDisappear {
            displayLink?.invalidate()
        }
    }
    
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: DisplayLinkTarget(update: {
            phase += 0.02
            if !isRecording {
                // Smooth decay when not recording
                for i in 0..<waveformData.count {
                    waveformData[i] *= 0.95
                }
            }
        }), selector: #selector(DisplayLinkTarget.update))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func updateWaveform(with level: Float) {
        guard isRecording else { return }
        
        // Shift array left
        for i in 0..<(waveformData.count - 1) {
            waveformData[i] = waveformData[i + 1]
        }
        
        // Add new value with some randomness for organic feel
        let randomFactor = Float.random(in: 0.8...1.2)
        waveformData[waveformData.count - 1] = level * randomFactor
    }
    
    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let segmentWidth = size.width / CGFloat(waveCount)
        
        // Create gradient colors
        let gradientStops: [Gradient.Stop] = [
            .init(color: Color(red: 1.0, green: 0.35, blue: 0.1).opacity(0.8), location: 0),
            .init(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6), location: 0.5),
            .init(color: Color(red: 1.0, green: 0.7, blue: 0.4).opacity(0.4), location: 1)
        ]
        
        // Draw each segment
        for i in 0..<waveCount {
            let x = CGFloat(i) * segmentWidth
            let normalizedIndex = CGFloat(i) / CGFloat(waveCount)
            
            // Calculate height with sine wave modulation
            let sineOffset = sin(phase + normalizedIndex * .pi * 4) * 0.3
            let amplitude = CGFloat(waveformData[i]) * maxAmplitude * (1 + sineOffset)
            let height = baseHeight + amplitude
            
            // Create gradient for this segment
            let gradient = Gradient(stops: gradientStops)
            
            // Draw the segment
            let rect = CGRect(
                x: x,
                y: size.height - height,
                width: segmentWidth - 1,
                height: height
            )
            
            let path = Path { path in
                path.addRoundedRect(
                    in: rect,
                    cornerSize: CGSize(width: segmentWidth / 2, height: segmentWidth / 2)
                )
            }
            
            context.fill(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: rect.midX, y: rect.minY),
                    endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                )
            )
            
            // Add glow effect for active segments
            if amplitude > 10 {
                var glowContext = context
                glowContext.addFilter(.blur(radius: 2))
                glowContext.fill(
                    path,
                    with: .color(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3))
                )
            }
        }
    }
}

// MARK: - Display Link Target
private class DisplayLinkTarget {
    var updateHandler: () -> Void
    
    init(update: @escaping () -> Void) {
        self.updateHandler = update
    }
    
    @objc func update(_ displayLink: CADisplayLink) {
        updateHandler()
    }
}

// MARK: - Audio Level Monitor
@MainActor
final class AudioLevelMonitor: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isRecording = false
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    
    func startMonitoring() {
        setupAudioEngine()
        startRecording()
    }
    
    func stopMonitoring() {
        isRecording = false
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let inputNode = inputNode else { return }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        audioFormat = recordingFormat
        
        // Install tap to monitor audio levels
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }
    
    private func startRecording() {
        do {
            try audioEngine?.start()
            isRecording = true
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))
        
        // Calculate RMS (Root Mean Square) for audio level
        var rms: Float = 0
        vDSP_rmsqv(channelDataArray, 1, &rms, vDSP_Length(channelDataArray.count))
        
        // Convert to decibels and normalize
        let decibels = 20 * log10(rms)
        let normalizedLevel = (decibels + 60) / 60 // Normalize from -60dB to 0dB
        
        DispatchQueue.main.async {
            self.audioLevel = max(0, min(1, normalizedLevel))
        }
    }
}

// MARK: - Integrated Voice Waveform Input Bar
struct VoiceWaveformInputBar: View {
    @Binding var navigationPath: NavigationPath
    @State private var inputText = ""
    @State private var isAmbientModeActive = false
    @State private var showingBookPicker = false
    @StateObject private var audioMonitor = AudioLevelMonitor()
    @FocusState private var isTextFieldFocused: Bool
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Voice waveform visualization
            if isAmbientModeActive {
                VoiceWaveformGradient(
                    audioLevel: $audioMonitor.audioLevel,
                    isRecording: $audioMonitor.isRecording
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Input controls
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    // Microphone button
                    Button {
                        HapticManager.shared.mediumTap()
                        isAmbientModeActive.toggle()
                        if isAmbientModeActive {
                            audioMonitor.startMonitoring()
                        } else {
                            audioMonitor.stopMonitoring()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isAmbientModeActive ? Color.warmAmber : Color.warmAmber.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: isAmbientModeActive ? "mic.fill" : "mic")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(isAmbientModeActive ? .white : Color.warmAmber)
                                .scaleEffect(isAmbientModeActive ? 1.1 : 1.0)
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAmbientModeActive)
                    }
                    .glassEffect(in: Circle())
                    
                    // Text input field
                    HStack(spacing: 8) {
                        TextField("Ask, note, or quote...", text: $inputText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .focused($isTextFieldFocused)
                            .lineLimit(1...4)
                            .disabled(isAmbientModeActive)
                            .opacity(isAmbientModeActive ? 0.5 : 1.0)
                        
                        if !inputText.isEmpty {
                            Button {
                                handleSubmit()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white, Color.warmAmber)
                            }
                        } else {
                            Button {
                                showingBookPicker = true
                            } label: {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.warmAmber.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                isAmbientModeActive ? Color.warmAmber.opacity(0.3) : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAmbientModeActive)
        .sheet(isPresented: $showingBookPicker) {
            BookPickerSheet { book in
                handleBookSelection(book)
            }
            .environmentObject(libraryViewModel)
        }
    }
    
    private func handleSubmit() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        HapticManager.shared.lightTap()
        
        // Create or navigate to general chat thread
        let descriptor = FetchDescriptor<ChatThread>(
            predicate: #Predicate { thread in
                thread.bookId == nil
            }
        )
        
        do {
            let threads = try modelContext.fetch(descriptor)
            let generalThread = threads.first ?? ChatThread()
            
            if threads.isEmpty {
                modelContext.insert(generalThread)
            }
            
            let chatMessage = ThreadedChatMessage(
                content: inputText,
                isUser: true,
                timestamp: Date()
            )
            generalThread.messages.append(chatMessage)
            generalThread.lastMessageDate = Date()
            
            try? modelContext.save()
            navigationPath.append(generalThread)
        } catch {
            print("Error accessing threads: \(error)")
        }
        
        inputText = ""
        isTextFieldFocused = false
    }
    
    private func handleBookSelection(_ book: Book) {
        let bookId = book.localId
        let descriptor = FetchDescriptor<ChatThread>(
            predicate: #Predicate { thread in
                thread.bookId == bookId
            }
        )
        
        do {
            let threads = try modelContext.fetch(descriptor)
            let bookThread = threads.first ?? ChatThread(book: book)
            
            if threads.isEmpty {
                modelContext.insert(bookThread)
                try? modelContext.save()
            }
            
            navigationPath.append(bookThread)
        } catch {
            print("Error accessing threads: \(error)")
        }
        
        showingBookPicker = false
    }
}