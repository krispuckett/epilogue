import SwiftUI
import Combine

// MARK: - Motion Preference System
enum MotionPreference: String, CaseIterable {
    case system = "System Default"
    case none = "No Motion"
    case subtle = "Subtle Motion"
    case full = "Full Motion"
    
    var description: String {
        switch self {
        case .system: return "Follow iOS accessibility settings"
        case .none: return "Opacity and color transitions only"
        case .subtle: return "Reduced blur with gentle animations"
        case .full: return "Complete ethereal blur effects"
        }
    }
    
    var iconName: String {
        switch self {
        case .system: return "gear"
        case .none: return "circle"
        case .subtle: return "circle.lefthalf.filled"
        case .full: return "circle.fill"
        }
    }
}

// MARK: - Motion Sensitivity Manager
@MainActor
class MotionSensitivityManager: ObservableObject {
    static let shared = MotionSensitivityManager()
    
    @Published var userPreference: MotionPreference = .system
    @Published var effectivePreference: MotionPreference = .full
    @Published var systemReduceMotion: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadUserPreference()
        observeSystemSettings()
        updateEffectivePreference()
    }
    
    private func loadUserPreference() {
        if let stored = UserDefaults.standard.string(forKey: "motion_preference"),
           let preference = MotionPreference(rawValue: stored) {
            userPreference = preference
        }
    }
    
    private func observeSystemSettings() {
        systemReduceMotion = UIAccessibility.isReduceMotionEnabled
        
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.systemReduceMotion = UIAccessibility.isReduceMotionEnabled
                self?.updateEffectivePreference()
            }
            .store(in: &cancellables)
        
        $userPreference
            .sink { [weak self] newPreference in
                UserDefaults.standard.set(newPreference.rawValue, forKey: "motion_preference")
                self?.updateEffectivePreference()
            }
            .store(in: &cancellables)
    }
    
    private func updateEffectivePreference() {
        switch userPreference {
        case .system:
            effectivePreference = systemReduceMotion ? .none : .full
        case .none, .subtle, .full:
            effectivePreference = userPreference
        }
    }
}

// MARK: - Adaptive Animation Parameters
struct AdaptiveAnimationParameters {
    let motionLevel: MotionPreference
    
    // Blur parameters
    var maxBlur: Double {
        switch motionLevel {
        case .none, .system: return 0
        case .subtle: return 6  // 30% of full
        case .full: return 20
        }
    }
    
    var breathingBlurRange: ClosedRange<Double> {
        switch motionLevel {
        case .none, .system: return 0...0
        case .subtle: return 1...2
        case .full: return 2...5
        }
    }
    
    var characterBlurRange: ClosedRange<Double> {
        switch motionLevel {
        case .none, .system: return 0...0
        case .subtle: return 0...3
        case .full: return 0...8
        }
    }
    
    // Timing parameters
    var characterRevealDuration: Double {
        switch motionLevel {
        case .none: return 0.08  // Slower for opacity-only
        case .system, .subtle: return 0.06
        case .full: return 0.05
        }
    }
    
    var fadeInDuration: Double {
        switch motionLevel {
        case .none: return 1.2  // Longer for gentler feel
        case .system, .subtle: return 1.0
        case .full: return 0.8
        }
    }
    
    // Alternative effects for reduced motion
    var useOpacityPulse: Bool {
        motionLevel == .none
    }
    
    var useColorTemperature: Bool {
        motionLevel == .none || motionLevel == .subtle
    }
    
    var useWeightAnimation: Bool {
        motionLevel == .none
    }
    
    var opacityRange: ClosedRange<Double> {
        switch motionLevel {
        case .none: return 0.4...1.0
        case .system, .subtle: return 0.6...1.0
        case .full: return 0.8...1.0
        }
    }
    
    var scaleRange: ClosedRange<Double> {
        switch motionLevel {
        case .none: return 0.98...1.0  // Very subtle
        case .system, .subtle: return 0.95...1.0
        case .full: return 0.9...1.0
        }
    }
}

// MARK: - Accessible Ethereal Text Modifier
struct AccessibleEtherealText: ViewModifier {
    let text: String
    let isAnimating: Bool
    @StateObject private var motionManager = MotionSensitivityManager.shared
    @State private var revealedCharacters = Set<Int>()
    @State private var breathingPhase: Double = 0
    @State private var colorTemperature: Double = 0
    
    private var parameters: AdaptiveAnimationParameters {
        AdaptiveAnimationParameters(motionLevel: motionManager.effectivePreference)
    }
    
    func body(content: Content) -> some View {
        Group {
            switch motionManager.effectivePreference {
            case .none:
                reducedMotionView
            case .subtle:
                subtleMotionView
            case .full, .system:
                fullMotionView
            }
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
    }
    
    // MARK: - No Motion View (Opacity & Typography)
    private var reducedMotionView: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .fontWeight(fontWeight(for: index))
                    .opacity(opacity(for: index))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                Color.white.opacity(1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .animation(
                        .easeInOut(duration: parameters.fadeInDuration),
                        value: revealedCharacters.contains(index)
                    )
            }
        }
        .modifier(BreathingOpacity(phase: breathingPhase, range: parameters.opacityRange))
    }
    
    // MARK: - Subtle Motion View (Reduced Blur)
    private var subtleMotionView: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .blur(radius: subtleBlur(for: index))
                    .opacity(opacity(for: index))
                    .scaleEffect(scale(for: index))
                    .foregroundStyle(temperatureGradient(for: index))
                    .animation(
                        .easeOut(duration: parameters.fadeInDuration),
                        value: revealedCharacters.contains(index)
                    )
            }
        }
    }
    
    // MARK: - Full Motion View (Complete Effects)
    private var fullMotionView: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .blur(radius: fullBlur(for: index))
                    .opacity(opacity(for: index))
                    .scaleEffect(scale(for: index))
                    .rotation3DEffect(
                        .degrees(revealedCharacters.contains(index) ? 0 : 5),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8),
                        value: revealedCharacters.contains(index)
                    )
            }
        }
    }
    
    // MARK: - Effect Calculations
    private func fontWeight(for index: Int) -> Font.Weight {
        guard parameters.useWeightAnimation else { return .regular }
        return revealedCharacters.contains(index) ? .medium : .light
    }
    
    private func opacity(for index: Int) -> Double {
        let range = parameters.opacityRange
        return revealedCharacters.contains(index) ? range.upperBound : range.lowerBound
    }
    
    private func scale(for index: Int) -> Double {
        let range = parameters.scaleRange
        return revealedCharacters.contains(index) ? range.upperBound : range.lowerBound
    }
    
    private func subtleBlur(for index: Int) -> Double {
        guard !revealedCharacters.contains(index) else {
            return breathingPhase * parameters.breathingBlurRange.upperBound * 0.3
        }
        return parameters.characterBlurRange.upperBound * 0.3
    }
    
    private func fullBlur(for index: Int) -> Double {
        guard !revealedCharacters.contains(index) else {
            return breathingPhase * parameters.breathingBlurRange.upperBound * 0.5
        }
        return parameters.characterBlurRange.upperBound
    }
    
    private func temperatureGradient(for index: Int) -> LinearGradient {
        let warmth = revealedCharacters.contains(index) ? 1.0 : 0.7
        return LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.95 * warmth, blue: 0.9 * warmth),
                Color(red: 1.0, green: 1.0, blue: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func startAnimation() {
        // Character reveal animation
        let batchSize = 5
        var currentIndex = 0
        
        Timer.scheduledTimer(withTimeInterval: parameters.characterRevealDuration, repeats: true) { timer in
            let endIndex = min(currentIndex + batchSize, text.count)
            for i in currentIndex..<endIndex {
                revealedCharacters.insert(i)
            }
            
            if endIndex >= text.count {
                timer.invalidate()
            }
            currentIndex = endIndex
        }
        
        // Breathing animation
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            breathingPhase = 1.0
        }
        
        // Color temperature animation
        if parameters.useColorTemperature {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                colorTemperature = 1.0
            }
        }
    }
}

// MARK: - Breathing Opacity Modifier
struct BreathingOpacity: ViewModifier {
    let phase: Double
    let range: ClosedRange<Double>
    
    func body(content: Content) -> some View {
        content
            .opacity(range.lowerBound + (range.upperBound - range.lowerBound) * phase)
    }
}

// MARK: - Motion Preference Picker View
struct MotionPreferencePicker: View {
    @StateObject private var motionManager = MotionSensitivityManager.shared
    @State private var showingInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Motion Preferences")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            
            ForEach(MotionPreference.allCases, id: \.self) { preference in
                HStack {
                    Image(systemName: preference.iconName)
                        .frame(width: 24)
                        .foregroundStyle(motionManager.userPreference == preference ? .primary : .secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preference.rawValue)
                            .font(.subheadline)
                        Text(preference.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if motionManager.userPreference == preference {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(motionManager.userPreference == preference ? 
                              Color.primary.opacity(0.1) : Color.clear)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        motionManager.userPreference = preference
                    }
                }
            }
            
            if showingInfo {
                InfoCard()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
            }
        }
        .padding()
    }
}

// MARK: - Educational Info Card
struct InfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("About Ambient Effects", systemImage: "sparkles")
                .font(.subheadline.bold())
            
            Text("Ambient mode creates a contemplative reading experience through gentle visual effects. These settings let you customize the motion level to your comfort.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(
                    icon: "circle",
                    title: "No Motion",
                    description: "Uses opacity and typography changes only"
                )
                
                FeatureRow(
                    icon: "circle.lefthalf.filled",
                    title: "Subtle Motion",
                    description: "Gentle blur with reduced intensity"
                )
                
                FeatureRow(
                    icon: "circle.fill",
                    title: "Full Motion",
                    description: "Complete ethereal blur effects"
                )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - View Extension
extension View {
    func accessibleEtherealText(_ text: String, isAnimating: Bool = true) -> some View {
        modifier(AccessibleEtherealText(text: text, isAnimating: isAnimating))
    }
    
    func adaptiveBlur(radius: Double) -> some View {
        modifier(AdaptiveBlur(radius: radius))
    }
}

// MARK: - Adaptive Blur Modifier
struct AdaptiveBlur: ViewModifier {
    let radius: Double
    @StateObject private var motionManager = MotionSensitivityManager.shared
    
    func body(content: Content) -> some View {
        let parameters = AdaptiveAnimationParameters(motionLevel: motionManager.effectivePreference)
        let adaptedRadius = min(radius, parameters.maxBlur)
        
        content
            .blur(radius: adaptedRadius)
    }
}

// MARK: - Debug View for Testing
struct AccessibilityDebugView: View {
    @StateObject private var motionManager = MotionSensitivityManager.shared
    @State private var sampleText = "The ethereal mist of words"
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Current settings display
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Settings")
                    .font(.caption.bold())
                
                HStack {
                    Text("User Preference:")
                    Text(motionManager.userPreference.rawValue)
                        .bold()
                }
                .font(.caption)
                
                HStack {
                    Text("Effective Setting:")
                    Text(motionManager.effectivePreference.rawValue)
                        .bold()
                }
                .font(.caption)
                
                HStack {
                    Text("System Reduce Motion:")
                    Text(motionManager.systemReduceMotion ? "ON" : "OFF")
                        .bold()
                }
                .font(.caption)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Test animation
            VStack(spacing: 16) {
                Text("Test Animation")
                    .font(.caption.bold())
                
                Text(sampleText)
                    .accessibleEtherealText(sampleText, isAnimating: isAnimating)
                    .frame(height: 30)
                
                Button("Toggle Animation") {
                    isAnimating.toggle()
                }
                .buttonStyle(.bordered)
            }
            
            // Settings picker
            MotionPreferencePicker()
        }
        .padding()
    }
}