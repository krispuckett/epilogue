import SwiftUI

struct TestWhisperKitView: View {
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("WhisperKit Test")
                .font(.largeTitle)
            
            // Status
            HStack {
                Circle()
                    .fill(voiceManager.isListening ? Color.green : Color.red)
                    .frame(width: 20, height: 20)
                
                Text(voiceManager.isListening ? "Recording" : "Not Recording")
            }
            
            // Apple Transcription
            VStack(alignment: .leading) {
                Text("Apple Speech Recognition:")
                    .font(.headline)
                Text(voiceManager.transcribedText.isEmpty ? "No transcription yet" : voiceManager.transcribedText)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Whisper Transcription
            VStack(alignment: .leading) {
                Text("WhisperKit:")
                    .font(.headline)
                Text(voiceManager.whisperTranscribedText.isEmpty ? "No transcription yet" : voiceManager.whisperTranscribedText)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Control Button
            Button(action: {
                if voiceManager.isListening {
                    voiceManager.stopListening()
                } else {
                    voiceManager.startAmbientListening()
                }
            }) {
                Label(
                    voiceManager.isListening ? "Stop Recording" : "Start Recording",
                    systemImage: voiceManager.isListening ? "stop.circle.fill" : "mic.circle.fill"
                )
                .font(.title2)
                .padding()
                .background(voiceManager.isListening ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}