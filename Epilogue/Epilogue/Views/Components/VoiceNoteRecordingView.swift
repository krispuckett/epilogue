import SwiftUI
import Combine
import SwiftData

struct VoiceNoteRecordingView: View {
    @Binding var isPresented: Bool
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @EnvironmentObject var notesViewModel: NotesViewModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var waveformAnimation = false
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal while recording
                }
            
            VStack(spacing: 30) {
                // Title
                Text("Recording Voice Note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                
                // Waveform visualization
                HStack(spacing: 4) {
                    ForEach(0..<20) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.26))
                            .frame(width: 4, height: randomHeight(for: index))
                            .animation(
                                .easeInOut(duration: 0.5)
                                .delay(Double(index) * 0.05)
                                .repeatForever(autoreverses: true),
                                value: waveformAnimation
                            )
                    }
                }
                .frame(height: 80)
                .padding(.horizontal, 40)
                
                // Duration
                Text(timeString(from: recordingDuration))
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
                
                // Transcribed text preview
                if !voiceManager.transcribedText.isEmpty {
                    Text(voiceManager.transcribedText)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 40)
                }
                
                // Controls
                HStack(spacing: 40) {
                    // Cancel button
                    Button {
                        cancelRecording()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.3), .white.opacity(0.1))
                    }
                    
                    // Stop button
                    Button {
                        stopRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26))
                                .frame(width: 80, height: 80)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .scaleEffect(isProcessing ? 0.8 : 1.0)
                    .disabled(isProcessing)
                }
                .padding(.top, 20)
            }
            .padding(40)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
            .scaleEffect(showSuccess ? 0.95 : 1.0)
            .opacity(showSuccess ? 0 : 1)
            
            // Success indicator
            if showSuccess {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)
                    
                    Text("Note Saved!")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            startRecording()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - Methods
    
    private func startRecording() {
        voiceManager.startAmbientListening()
        waveformAnimation = true
        
        // Start duration timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
        
        HapticManager.shared.mediumTap()
    }
    
    private func stopRecording() {
        guard !isProcessing else { return }
        
        isProcessing = true
        timer?.invalidate()
        voiceManager.stopListening()
        
        HapticManager.shared.success()
        
        // Save the transcribed text as a note
        let transcribedText = voiceManager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !transcribedText.isEmpty {
            saveVoiceNote(transcribedText)
        } else {
            // No text detected
            cancelRecording()
        }
    }
    
    private func saveVoiceNote(_ text: String) {
        // Create note with voice indicator
        let noteContent = "🎙️ \(text)"
        
        // Save to SwiftData
        let capturedNote = CapturedNote(
            content: noteContent,
            book: nil,
            pageNumber: nil,
            timestamp: Date(),
            source: .voice
        )
        
        modelContext.insert(capturedNote)
        
        do {
            try modelContext.save()
            
            // Also add to NotesViewModel for compatibility
            let note = Note(
                type: .note,
                content: noteContent,
                bookId: nil,
                bookTitle: nil,
                author: nil,
                pageNumber: nil
            )
            notesViewModel.addNote(note)
            
            // Show success
            withAnimation(.spring()) {
                showSuccess = true
            }
            
            // Dismiss after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isPresented = false
            }
            
        } catch {
            print("Failed to save voice note: \(error)")
            cancelRecording()
        }
    }
    
    private func cancelRecording() {
        timer?.invalidate()
        voiceManager.stopListening()
        HapticManager.shared.lightTap()
        isPresented = false
    }
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        voiceManager.stopListening()
        voiceManager.clearWhisperTranscription()
    }
    
    private func randomHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 20
        let amplitude = voiceManager.currentAmplitude
        let randomFactor = CGFloat.random(in: 0.5...1.5)
        let indexFactor = sin(CGFloat(index) * 0.3 + recordingDuration)
        
        return baseHeight + (CGFloat(amplitude) * 100 * randomFactor * abs(indexFactor))
    }
    
    private func timeString(from duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
}

// MARK: - Voice Note Button Overlay

struct VoiceNoteButtonOverlay: View {
    @Binding var showVoiceRecording: Bool
    
    var body: some View {
        if showVoiceRecording {
            VoiceNoteRecordingView(isPresented: $showVoiceRecording)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}