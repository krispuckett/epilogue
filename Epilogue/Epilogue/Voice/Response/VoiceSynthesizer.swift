import AVFoundation
import Speech
import Combine
import UIKit

class VoiceSynthesizer: NSObject, ObservableObject {
    @Published var isSpeaking = false
    @Published var currentUtterance: String = ""
    
    private let synthesizer = AVSpeechSynthesizer()
    private var continuations: [CheckedContinuation<Void, Never>] = []
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureSynthesizer()
    }
    
    private func configureSynthesizer() {
        // Configure for high-quality synthesis
        AVSpeechSynthesisVoice.speechVoices() // Pre-load voices
    }
    
    func speak(_ text: String, voice: VoiceStyle = .default) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                self.continuations.append(continuation)
                self.currentUtterance = text
                self.isSpeaking = true
                
                let utterance = AVSpeechUtterance(string: text)
                
                // Configure voice
                switch voice {
                case .default:
                    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                case .literary:
                    utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Ava")
                case .assistant:
                    utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Zoe")
                }
                
                // Configure speech parameters
                utterance.rate = 0.52 // Slightly faster than default
                utterance.pitchMultiplier = 1.0
                utterance.volume = 0.9
                utterance.preUtteranceDelay = 0.1
                utterance.postUtteranceDelay = 0.2
                
                self.synthesizer.speak(utterance)
            }
        }
    }
    
    func speakWithEmphasis(_ segments: [(text: String, emphasis: Emphasis)]) async {
        for segment in segments {
            let utterance = AVSpeechUtterance(string: segment.text)
            
            switch segment.emphasis {
            case .normal:
                utterance.rate = 0.52
                utterance.pitchMultiplier = 1.0
            case .slow:
                utterance.rate = 0.4
                utterance.pitchMultiplier = 0.95
            case .emphasized:
                utterance.rate = 0.48
                utterance.pitchMultiplier = 1.1
                utterance.volume = 1.0
            case .whispered:
                utterance.rate = 0.45
                utterance.pitchMultiplier = 0.8
                utterance.volume = 0.6
            }
            
            await speak(utterance.speechString)
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        
        // Resume all waiting continuations
        continuations.forEach { $0.resume() }
        continuations.removeAll()
        
        isSpeaking = false
        currentUtterance = ""
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func resume() {
        synthesizer.continueSpeaking()
    }
    
    enum VoiceStyle {
        case `default`
        case literary  // For reading quotes
        case assistant // For responses
    }
    
    enum Emphasis {
        case normal
        case slow
        case emphasized
        case whispered
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension VoiceSynthesizer: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.currentUtterance = ""
            
            // Resume the first continuation
            if let continuation = self?.continuations.first {
                self?.continuations.removeFirst()
                continuation.resume()
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.currentUtterance = ""
            
            // Resume all continuations
            self?.continuations.forEach { $0.resume() }
            self?.continuations.removeAll()
        }
    }
}

// MARK: - Voice Feedback Manager
class VoiceFeedbackManager: NSObject, ObservableObject {
    static let shared = VoiceFeedbackManager()
    
    private let synthesizer = VoiceSynthesizer()
    private let haptics = UINotificationFeedbackGenerator()
    
    private override init() {
        super.init()
        haptics.prepare()
    }
    
    func confirmAction(_ message: String) async {
        haptics.notificationOccurred(.success)
        await synthesizer.speak(message, voice: .assistant)
    }
    
    func announceError(_ message: String) async {
        haptics.notificationOccurred(.error)
        await synthesizer.speak(message, voice: .assistant)
    }
    
    func readQuote(_ quote: String, author: String?) async {
        // Read quote with literary voice
        await synthesizer.speak(quote, voice: .literary)
        
        // Pause
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Read attribution
        if let author = author {
            await synthesizer.speak("By \(author)", voice: .default)
        }
    }
}