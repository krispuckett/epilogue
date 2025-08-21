import SwiftUI
import Combine

// MARK: - Centralized Animation Timing Constants
enum AmbientAnimationTiming {
    static let characterRevealDuration: Double = 0.05
    static let fadeInDuration: Double = 0.8
    static let fadeOutDuration: Double = 0.3
    static let breathingCycleDuration: Double = 3.0
    static let dissolveDuration: Double = 0.8
    static let waveCollapseDelay: Double = 0.3
    
    // Blur limits (as per guidelines)
    static let minBlur: Double = 0
    static let maxBlur: Double = 20
    static let breathingBlurRange: ClosedRange<Double> = 2...5
    static let characterBlurRange: ClosedRange<Double> = 0...8
    static let dissolveBlurRange: ClosedRange<Double> = 0...15
    
    // Performance thresholds
    static let targetFrameTime: Double = 0.002 // 2ms target
    static let characterBatchSize: Int = 5
    static let maxConcurrentAnimations: Int = 10
}

// MARK: - Blur Interpolation Utilities
struct BlurInterpolation {
    // Easing functions
    static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
    
    static func easeOut(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }
    
    static func elasticOut(_ t: Double) -> Double {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        let p = 0.3
        let s = p / 4
        return pow(2, -10 * t) * sin((t - s) * (2 * .pi) / p) + 1
    }
    
    static func interpolate(from: Double, to: Double, progress: Double, easing: (Double) -> Double = easeInOut) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        let easedProgress = easing(clampedProgress)
        return from + (to - from) * easedProgress
    }
    
    // Cached blur value generator
    private static var blurCache = [String: Double]()
    private static let cacheQueue = DispatchQueue(label: "com.epilogue.blurcache", attributes: .concurrent)
    
    static func cachedBlur(for key: String, generator: () -> Double) -> Double {
        cacheQueue.sync {
            if let cached = blurCache[key] {
                return cached
            }
            let value = generator()
            cacheQueue.async(flags: .barrier) {
                blurCache[key] = value
            }
            return value
        }
    }
    
    static func clearCache() {
        cacheQueue.async(flags: .barrier) {
            blurCache.removeAll()
        }
    }
}

// MARK: - Ambient Blur Animator
@MainActor
class AmbientBlurAnimator: ObservableObject {
    static let shared = AmbientBlurAnimator()
    
    @Published var globalBreathingPhase: Double = 0
    @Published var isReducedMotionEnabled: Bool = false
    @Published var performanceQuality: PerformanceQuality = .high
    @Published var debugMode: Bool = false
    
    private var animationTimers: [UUID: Timer] = [:]
    private var frameTimeMonitor: FrameTimeMonitor?
    private let animationQueue = DispatchQueue(label: "com.epilogue.animations", qos: .userInteractive)
    
    enum PerformanceQuality {
        case low, medium, high
        
        var blurMultiplier: Double {
            switch self {
            case .low: return 0.5
            case .medium: return 0.75
            case .high: return 1.0
            }
        }
        
        var updateFrequency: Double {
            switch self {
            case .low: return 0.033 // 30fps
            case .medium: return 0.020 // 50fps
            case .high: return 0.016 // 60fps
            }
        }
    }
    
    private init() {
        setupReducedMotionObserver()
        startGlobalBreathingAnimation()
        if debugMode {
            startPerformanceMonitoring()
        }
    }
    
    private func setupReducedMotionObserver() {
        isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func reduceMotionChanged() {
        isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }
    
    private func startGlobalBreathingAnimation() {
        guard !isReducedMotionEnabled else { return }
        
        Timer.scheduledTimer(withTimeInterval: performanceQuality.updateFrequency, repeats: true) { _ in
            Task { @MainActor in
                let time = Date().timeIntervalSinceReferenceDate
                let normalizedTime = (time / AmbientAnimationTiming.breathingCycleDuration).truncatingRemainder(dividingBy: 1)
                self.globalBreathingPhase = BlurInterpolation.easeInOut(normalizedTime)
            }
        }
    }
    
    func getBreathingBlur() -> Double {
        guard !isReducedMotionEnabled else { return AmbientAnimationTiming.breathingBlurRange.lowerBound }
        
        let range = AmbientAnimationTiming.breathingBlurRange
        return BlurInterpolation.interpolate(
            from: range.lowerBound,
            to: range.upperBound,
            progress: globalBreathingPhase
        ) * performanceQuality.blurMultiplier
    }
    
    // Character batch animation system
    func animateCharacterBatch(
        totalCount: Int,
        onUpdate: @escaping (Set<Int>) -> Void,
        completion: (() -> Void)? = nil
    ) -> UUID {
        let animationID = UUID()
        var revealedIndices = Set<Int>()
        var currentBatch = 0
        
        let timer = Timer.scheduledTimer(
            withTimeInterval: AmbientAnimationTiming.characterRevealDuration,
            repeats: true
        ) { timer in
            Task { @MainActor in
                let startIndex = currentBatch * AmbientAnimationTiming.characterBatchSize
                let endIndex = min(startIndex + AmbientAnimationTiming.characterBatchSize, totalCount)
                
                for i in startIndex..<endIndex {
                    revealedIndices.insert(i)
                }
                
                onUpdate(revealedIndices)
                
                if endIndex >= totalCount {
                    timer.invalidate()
                    self.animationTimers.removeValue(forKey: animationID)
                    completion?()
                }
                
                currentBatch += 1
            }
        }
        
        animationTimers[animationID] = timer
        return animationID
    }
    
    func cancelAnimation(_ id: UUID) {
        animationTimers[id]?.invalidate()
        animationTimers.removeValue(forKey: id)
    }
    
    func cancelAllAnimations() {
        animationTimers.values.forEach { $0.invalidate() }
        animationTimers.removeAll()
    }
    
    // Performance monitoring
    private func startPerformanceMonitoring() {
        frameTimeMonitor = FrameTimeMonitor { [weak self] avgFrameTime in
            Task { @MainActor in
                guard let self = self else { return }
                
                if avgFrameTime > 0.020 && self.performanceQuality != .low {
                    self.performanceQuality = avgFrameTime > 0.033 ? .low : .medium
                    print("⚠️ Reducing animation quality due to performance: \(self.performanceQuality)")
                } else if avgFrameTime < 0.016 && self.performanceQuality != .high {
                    self.performanceQuality = .high
                    print("✅ Restoring high quality animations")
                }
            }
        }
    }
}

// MARK: - Frame Time Monitor
private class FrameTimeMonitor {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private let maxSamples = 60
    private let callback: (CFTimeInterval) -> Void
    
    init(callback: @escaping (CFTimeInterval) -> Void) {
        self.callback = callback
        setupDisplayLink()
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(frame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func frame(displayLink: CADisplayLink) {
        if lastTimestamp != 0 {
            let frameTime = displayLink.timestamp - lastTimestamp
            frameTimes.append(frameTime)
            
            if frameTimes.count > maxSamples {
                frameTimes.removeFirst()
            }
            
            if frameTimes.count == maxSamples {
                let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
                callback(avgFrameTime)
                frameTimes.removeAll()
            }
        }
        lastTimestamp = displayLink.timestamp
    }
    
    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - Ethereal Text View Modifier
struct EtherealTextModifier: ViewModifier {
    let text: String
    let isAnimating: Bool
    @State private var revealedCharacters = Set<Int>()
    @State private var animationID: UUID?
    @StateObject private var animator = AmbientBlurAnimator.shared
    
    func body(content: Content) -> some View {
        if animator.isReducedMotionEnabled || !isAnimating {
            content
        } else {
            HStack(spacing: 0) {
                ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                    Text(String(character))
                        .blur(radius: blurValue(for: index))
                        .opacity(opacityValue(for: index))
                        .animation(.easeOut(duration: AmbientAnimationTiming.fadeInDuration), value: revealedCharacters.contains(index))
                }
            }
            .onAppear {
                startAnimation()
            }
            .onDisappear {
                if let id = animationID {
                    animator.cancelAnimation(id)
                }
            }
        }
    }
    
    private func blurValue(for index: Int) -> Double {
        guard !revealedCharacters.contains(index) else {
            return animator.getBreathingBlur() * 0.3 // Subtle breathing on revealed text
        }
        
        let key = "\(text.prefix(index + 1))"
        return BlurInterpolation.cachedBlur(for: key) {
            AmbientAnimationTiming.characterBlurRange.upperBound * animator.performanceQuality.blurMultiplier
        }
    }
    
    private func opacityValue(for index: Int) -> Double {
        revealedCharacters.contains(index) ? 1.0 : 0.3
    }
    
    private func startAnimation() {
        animationID = animator.animateCharacterBatch(
            totalCount: text.count,
            onUpdate: { indices in
                revealedCharacters = indices
            }
        )
    }
}

extension View {
    func etherealText(_ text: String, isAnimating: Bool = true) -> some View {
        modifier(EtherealTextModifier(text: text, isAnimating: isAnimating))
    }
}

// MARK: - Debug Overlay
struct AmbientBlurDebugOverlay: View {
    @StateObject private var animator = AmbientBlurAnimator.shared
    @State private var frameRate: Double = 60
    @State private var memoryUsage: Double = 0
    
    var body: some View {
        if animator.debugMode {
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance Monitor")
                    .font(.caption.bold())
                
                HStack {
                    Circle()
                        .fill(performanceColor)
                        .frame(width: 8, height: 8)
                    Text("\(Int(frameRate)) FPS")
                        .font(.caption2.monospaced())
                }
                
                Text("Quality: \(qualityText)")
                    .font(.caption2)
                
                Text("Memory: \(String(format: "%.1f", memoryUsage)) MB")
                    .font(.caption2)
                
                Text("Breathing: \(String(format: "%.2f", animator.globalBreathingPhase))")
                    .font(.caption2)
            }
            .padding(8)
            .background(.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(8)
            .onAppear {
                startMonitoring()
            }
        }
    }
    
    private var performanceColor: Color {
        switch animator.performanceQuality {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .red
        }
    }
    
    private var qualityText: String {
        switch animator.performanceQuality {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateMemoryUsage()
        }
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0
        }
    }
}