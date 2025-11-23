import Foundation
import SwiftUI
import AVFoundation
import Combine

// MARK: - AmbientLifecycleManager
// Manages the lifecycle of ambient sessions including background audio
class AmbientLifecycleManager: ObservableObject {
    static let shared = AmbientLifecycleManager()
    
    @Published var isSessionActive: Bool = false
    @Published var sessionDuration: TimeInterval = 0
    @Published var backgroundModeActive: Bool = false
    
    // Audio session management
    private var audioSession: AVAudioSession?
    private var sessionTimer: Timer?
    private var sessionStartTime: Date?
    
    // Background task
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Session Lifecycle
    
    func startSession() {
        guard !isSessionActive else { return }
        
        isSessionActive = true
        sessionStartTime = Date()
        
        // Configure for background audio
        configureBackgroundAudio()
        
        // Start session timer
        startSessionTimer()
        
        // Begin background task for extended processing
        beginBackgroundTask()
        
        #if DEBUG
        print("🎬 Ambient session manager started")
        #endif
    }
    
    func endSession() {
        guard isSessionActive else { return }
        
        isSessionActive = false
        
        // Stop timer
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // End background task
        endBackgroundTask()
        
        // Reset audio session
        resetAudioSession()
        
        let duration = sessionDuration
        #if DEBUG
        print("🎬 Ambient session ended - Duration: \(formatDuration(duration))")
        #endif
        
        // Reset
        sessionDuration = 0
        sessionStartTime = nil
    }
    
    func pauseSession() {
        sessionTimer?.invalidate()
        #if DEBUG
        print("⏸️ Ambient session paused")
        #endif
    }
    
    func resumeSession() {
        startSessionTimer()
        #if DEBUG
        print("▶️ Ambient session resumed")
        #endif
    }
    
    // MARK: - Audio Configuration
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
    }
    
    private func configureBackgroundAudio() {
        do {
            // ✅ VOICE-OPTIMIZED: Use .voiceChat mode for better speech recognition
            // ✅ DUCK OTHERS: Lower other audio instead of stopping it
            // ✅ BLUETOOTH: Support all Bluetooth devices for ambient listening
            try audioSession?.setCategory(
                .playAndRecord,
                mode: .voiceChat,  // Optimized for voice recognition (Perplexity/ChatGPT pattern)
                options: [
                    .defaultToSpeaker,
                    .allowBluetoothHFP,  // Allow Bluetooth hands-free devices (renamed from .allowBluetooth)
                    .allowBluetoothA2DP,  // Allow high-quality Bluetooth audio
                    .duckOthers  // Lower other audio, don't stop it completely
                ]
            )

            // ✅ NOTIFY OTHERS: Properly notify other apps when we deactivate
            try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)

            #if DEBUG
            print("🔊 Audio session configured for ambient mode (voice-optimized)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to configure audio session: \(error)")
            #endif
        }
    }
    
    private func resetAudioSession() {
        do {
            // ✅ NOTIFY OTHERS: Let other apps know we're deactivating so they can resume audio
            try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("❌ Failed to reset audio session: \(error)")
            #endif
        }
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        if backgroundTask != .invalid {
            backgroundModeActive = true
            #if DEBUG
            print("📱 Background task started")
            #endif
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        backgroundModeActive = false
        #if DEBUG
        print("📱 Background task ended")
        #endif
    }
    
    // MARK: - Timer Management
    
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionDuration()
        }
    }
    
    private func updateSessionDuration() {
        guard let startTime = sessionStartTime else { return }
        sessionDuration = Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Utilities
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Live Activity Support (Future)
    
    func startLiveActivity() {
        // TODO: Implement Live Activity for ambient mode
        // This would show a minimal widget on lock screen
        // with current book and gradient
    }
    
    func updateLiveActivity(book: Book?, transcript: String) {
        // TODO: Update Live Activity content
    }
    
    func endLiveActivity() {
        // TODO: End Live Activity
    }
}

