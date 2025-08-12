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
        
        print("🎬 Ambient session manager started")
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
        print("🎬 Ambient session ended - Duration: \(formatDuration(duration))")
        
        // Reset
        sessionDuration = 0
        sessionStartTime = nil
    }
    
    func pauseSession() {
        sessionTimer?.invalidate()
        print("⏸️ Ambient session paused")
    }
    
    func resumeSession() {
        startSessionTimer()
        print("▶️ Ambient session resumed")
    }
    
    // MARK: - Audio Configuration
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
    }
    
    private func configureBackgroundAudio() {
        do {
            try audioSession?.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers]
            )
            try audioSession?.setActive(true)
            print("🔊 Audio session configured for ambient mode")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    private func resetAudioSession() {
        do {
            try audioSession?.setActive(false)
        } catch {
            print("❌ Failed to reset audio session: \(error)")
        }
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        if backgroundTask != .invalid {
            backgroundModeActive = true
            print("📱 Background task started")
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        backgroundModeActive = false
        print("📱 Background task ended")
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

