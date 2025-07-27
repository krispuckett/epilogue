import SwiftUI
import AVFoundation
import Combine

// MARK: - Privacy Indicator View
struct PrivacyIndicator: View {
    let isListening: Bool
    let isRecording: Bool
    @State private var pulseAnimation = false
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 12) {
            // Recording status icon
            ZStack {
                // Glow effect when active
                if isListening || isRecording {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.red.opacity(glowOpacity),
                                    Color.red.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                
                // Core indicator
                Circle()
                    .fill(isListening || isRecording ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                    )
            }
            
            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                
                if isListening || isRecording {
                    Text("Tap to stop")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Privacy shield icon
            Image(systemName: isListening || isRecording ? "lock.shield" : "lock.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(isListening || isRecording ? .orange : .green)
                .symbolEffect(.pulse, options: .repeating, value: isListening || isRecording)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isListening || isRecording ? Color.red.opacity(0.5) : Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            pulseAnimation = true
        }
        .onChange(of: isListening || isRecording) { _, isActive in
            withAnimation(.easeInOut(duration: 0.3)) {
                glowOpacity = isActive ? 0.5 : 0.3
            }
        }
    }
    
    private var statusText: String {
        if isRecording {
            return "Recording audio"
        } else if isListening {
            return "Microphone active"
        } else {
            return "Microphone off"
        }
    }
}

// MARK: - Auto-Stop Manager
@MainActor
class AutoStopManager: ObservableObject {
    static let shared = AutoStopManager()
    
    @Published var isEnabled = true
    @Published var silenceThreshold: TimeInterval = 30.0 // 30 seconds
    @Published var maxDuration: TimeInterval = 300.0 // 5 minutes
    @Published var timeRemaining: TimeInterval = 0
    @Published var warningShown = false
    
    private var silenceTimer: Timer?
    private var durationTimer: Timer?
    private var startTime: Date?
    
    private init() {}
    
    func startMonitoring() {
        startTime = Date()
        timeRemaining = maxDuration
        warningShown = false
        
        // Start duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTimeRemaining()
        }
    }
    
    func stopMonitoring() {
        silenceTimer?.invalidate()
        durationTimer?.invalidate()
        silenceTimer = nil
        durationTimer = nil
        startTime = nil
        timeRemaining = 0
        warningShown = false
    }
    
    func resetSilenceTimer() {
        silenceTimer?.invalidate()
        
        guard isEnabled else { return }
        
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { _ in
            NotificationCenter.default.post(name: .autoStopTriggered, object: "silence")
        }
    }
    
    private func updateTimeRemaining() {
        guard let start = startTime else { return }
        
        let elapsed = Date().timeIntervalSince(start)
        timeRemaining = max(0, maxDuration - elapsed)
        
        // Show warning at 30 seconds remaining
        if timeRemaining <= 30 && !warningShown {
            warningShown = true
            NotificationCenter.default.post(name: .autoStopWarning, object: nil)
        }
        
        // Trigger auto-stop at max duration
        if timeRemaining <= 0 {
            NotificationCenter.default.post(name: .autoStopTriggered, object: "duration")
            stopMonitoring()
        }
    }
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @ObservedObject var autoStopManager = AutoStopManager.shared
    @AppStorage("microphonePermissionShown") private var permissionShown = false
    @AppStorage("privacyNoticeAccepted") private var privacyAccepted = false
    @State private var showingPermissionAlert = false
    
    var body: some View {
        List {
            Section {
                // Privacy notice
                if !privacyAccepted {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Privacy Notice", systemImage: "hand.raised.fill")
                            .font(.headline)
                        
                        Text("• Audio is processed locally on your device")
                            .font(.caption)
                        Text("• No recordings are stored permanently")
                            .font(.caption)
                        Text("• You can stop listening at any time")
                            .font(.caption)
                        
                        Button("Accept & Continue") {
                            privacyAccepted = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding(.vertical, 8)
                }
                
                // Microphone permission status
                HStack {
                    Label("Microphone Access", systemImage: "mic.fill")
                    Spacer()
                    Text(microphoneStatus)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    checkMicrophonePermission()
                }
            } header: {
                Text("Permissions")
            }
            
            Section {
                // Auto-stop toggle
                Toggle(isOn: $autoStopManager.isEnabled) {
                    Label("Auto-Stop Listening", systemImage: "timer")
                }
                
                // Silence threshold
                if autoStopManager.isEnabled {
                    VStack(alignment: .leading) {
                        Text("Stop after silence")
                            .font(.subheadline)
                        
                        Picker("Silence Duration", selection: $autoStopManager.silenceThreshold) {
                            Text("15 seconds").tag(15.0)
                            Text("30 seconds").tag(30.0)
                            Text("1 minute").tag(60.0)
                            Text("2 minutes").tag(120.0)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Max duration
                    VStack(alignment: .leading) {
                        Text("Maximum session length")
                            .font(.subheadline)
                        
                        Picker("Max Duration", selection: $autoStopManager.maxDuration) {
                            Text("2 minutes").tag(120.0)
                            Text("5 minutes").tag(300.0)
                            Text("10 minutes").tag(600.0)
                            Text("30 minutes").tag(1800.0)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            } header: {
                Text("Auto-Stop Settings")
            } footer: {
                Text("Automatically stops listening after a period of silence or when the maximum duration is reached.")
            }
            
            Section {
                // Visual indicators
                HStack {
                    Label("Show Recording Indicator", systemImage: "record.circle")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                
                HStack {
                    Label("Blur Screen When Active", systemImage: "eye.slash")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                
                HStack {
                    Label("Haptic Feedback", systemImage: "waveform")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } header: {
                Text("Privacy Indicators")
            } footer: {
                Text("These features help you stay aware when the microphone is active.")
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Microphone Permission", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable microphone access in Settings to use voice features.")
        }
    }
    
    private var microphoneStatus: String {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return "Allowed"
        case .denied:
            return "Denied"
        case .undetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func checkMicrophonePermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .denied:
            showingPermissionAlert = true
        case .undetermined:
            Task {
                _ = await AVAudioApplication.requestRecordPermission()
            }
        default:
            break
        }
    }
}

// MARK: - Auto-Stop Warning View
struct AutoStopWarningView: View {
    let timeRemaining: TimeInterval
    let onDismiss: () -> Void
    let onExtend: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            
            Text("Session Ending Soon")
                .font(.system(size: 20, weight: .semibold))
            
            Text("\(Int(timeRemaining)) seconds remaining")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button("Stop Now") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Add 5 Minutes") {
                    onExtend()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 20)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let autoStopTriggered = Notification.Name("autoStopTriggered")
    static let autoStopWarning = Notification.Name("autoStopWarning")
}

// MARK: - Privacy Blur Effect
struct PrivacyBlurModifier: ViewModifier {
    let isActive: Bool
    @State private var blurRadius: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .blur(radius: blurRadius)
            .animation(.easeInOut(duration: 0.3), value: blurRadius)
            .onChange(of: isActive) { _, newValue in
                blurRadius = newValue ? 10 : 0
            }
            .overlay {
                if isActive {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func privacyBlur(isActive: Bool) -> some View {
        modifier(PrivacyBlurModifier(isActive: isActive))
    }
}