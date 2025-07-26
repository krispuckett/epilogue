import Foundation
import UIKit
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AdaptiveQualityManager")

// MARK: - Adaptive Quality Manager
@MainActor
class AdaptiveQualityManager: ObservableObject {
    @Published var currentQuality: QualityLevel = .balanced
    @Published var batteryLevel: Float = 1.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var isLowPowerMode: Bool = false
    @Published var processingInterval: TimeInterval = 3.0
    
    // Whisper model selection
    @Published var whisperModel: String = "base"
    @Published var useReducedPrecision: Bool = false
    
    // Processing settings
    @Published var enableVAD: Bool = true
    @Published var enableParallelProcessing: Bool = true
    @Published var maxConcurrentTasks: Int = 3
    
    private var cancellables = Set<AnyCancellable>()
    private var batteryMonitor: Timer?
    
    enum QualityLevel: String, CaseIterable {
        case maximum = "Maximum Quality"
        case balanced = "Balanced"
        case efficient = "Battery Efficient"
        case minimal = "Minimal"
        
        var description: String {
            switch self {
            case .maximum: return "Best accuracy, highest battery usage"
            case .balanced: return "Good accuracy, moderate battery usage"
            case .efficient: return "Decent accuracy, low battery usage"
            case .minimal: return "Basic functionality, minimal battery usage"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        // Monitor battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        batteryMonitor = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateBatteryLevel()
        }
        
        // Monitor low power mode
        NotificationCenter.default.publisher(for: NSNotification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.updatePowerState()
            }
            .store(in: &cancellables)
        
        // Monitor thermal state
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &cancellables)
        
        // Initial update
        updateBatteryLevel()
        updatePowerState()
        updateThermalState()
    }
    
    // MARK: - Monitoring Updates
    
    private func updateBatteryLevel() {
        batteryLevel = UIDevice.current.batteryLevel
        
        // Adjust quality based on battery
        adjustQualityForBattery(batteryLevel)
        
        logger.info("Battery level: \(Int(self.batteryLevel * 100))%")
    }
    
    private func updatePowerState() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if isLowPowerMode {
            logger.info("Low power mode enabled - reducing quality")
            setQualityLevel(.efficient)
        }
    }
    
    private func updateThermalState() {
        thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .serious, .critical:
            logger.warning("Device overheating - switching to minimal quality")
            setQualityLevel(.minimal)
        case .fair:
            logger.info("Device warm - reducing quality")
            if currentQuality == .maximum {
                setQualityLevel(.balanced)
            }
        default:
            break
        }
    }
    
    // MARK: - Quality Adjustment
    
    func adjustQualityForBattery(_ level: Float) {
        let previousQuality = currentQuality
        
        switch level {
        case 0..<0.2:
            setQualityLevel(.minimal)
        case 0.2..<0.5:
            if !isLowPowerMode {
                setQualityLevel(.efficient)
            }
        case 0.5..<0.8:
            if !isLowPowerMode && thermalState == .nominal {
                setQualityLevel(.balanced)
            }
        default:
            if !isLowPowerMode && thermalState == .nominal {
                setQualityLevel(.maximum)
            }
        }
        
        if previousQuality != currentQuality {
            logger.info("Quality adjusted from \(previousQuality.rawValue) to \(self.currentQuality.rawValue)")
        }
    }
    
    func setQualityLevel(_ level: QualityLevel) {
        currentQuality = level
        
        switch level {
        case .maximum:
            whisperModel = "small"
            useReducedPrecision = false
            processingInterval = 1.0
            enableVAD = true
            enableParallelProcessing = true
            maxConcurrentTasks = 4
            
        case .balanced:
            whisperModel = "base"
            useReducedPrecision = false
            processingInterval = 3.0
            enableVAD = true
            enableParallelProcessing = true
            maxConcurrentTasks = 3
            
        case .efficient:
            whisperModel = "base"
            useReducedPrecision = true
            processingInterval = 5.0
            enableVAD = true
            enableParallelProcessing = false
            maxConcurrentTasks = 2
            
        case .minimal:
            whisperModel = "tiny"
            useReducedPrecision = true
            processingInterval = 10.0
            enableVAD = false // Process everything to reduce complexity
            enableParallelProcessing = false
            maxConcurrentTasks = 1
        }
        
        // Post notification for components to adjust
        NotificationCenter.default.post(
            name: Notification.Name("QualityLevelChanged"),
            object: level
        )
    }
    
    // MARK: - Public Methods
    
    func shouldProcessAudio() -> Bool {
        // Skip processing if device is too hot
        if thermalState == .critical {
            return false
        }
        
        // Skip if battery is critically low and not charging
        if batteryLevel < 0.05 && UIDevice.current.batteryState != .charging {
            return false
        }
        
        return true
    }
    
    func getProcessingDelay() -> TimeInterval {
        // Add delay based on current conditions
        var delay = processingInterval
        
        if thermalState == .serious {
            delay *= 2
        }
        
        if batteryLevel < 0.1 {
            delay *= 1.5
        }
        
        return delay
    }
    
    func getOptimalWhisperConfig() -> WhisperOptimalConfig {
        return WhisperOptimalConfig(
            model: whisperModel,
            useGPU: !useReducedPrecision,
            chunkDuration: currentQuality == .minimal ? 5.0 : 10.0,
            enableTimestamps: currentQuality != .minimal,
            enableWordTimestamps: currentQuality == .maximum,
            temperature: 0.0,
            suppressBlank: true
        )
    }
    
    func getFoundationModelsConfig() -> FoundationModelsConfig {
        return FoundationModelsConfig(
            useReducedPrecision: useReducedPrecision,
            maxTokens: currentQuality == .minimal ? 20 : 50,
            enableEntityExtraction: currentQuality != .minimal,
            enableSentimentAnalysis: currentQuality == .maximum || currentQuality == .balanced,
            cacheResults: true
        )
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        logger.info("Started adaptive quality monitoring")
    }
    
    func stopMonitoring() {
        batteryMonitor?.invalidate()
        batteryMonitor = nil
        cancellables.removeAll()
        
        logger.info("Stopped adaptive quality monitoring")
    }
    
    func getBatteryImpact() -> Float {
        // Estimate battery impact based on current settings
        let baseImpact: Float
        
        switch currentQuality {
        case .maximum: baseImpact = 0.8
        case .balanced: baseImpact = 0.5
        case .efficient: baseImpact = 0.3
        case .minimal: baseImpact = 0.1
        }
        
        // Adjust for current conditions
        var impact = baseImpact
        
        if enableParallelProcessing {
            impact *= 1.2
        }
        
        if thermalState != .nominal {
            impact *= 0.8 // Throttled
        }
        
        return min(impact, 1.0)
    }
    
    // MARK: - Manual Override
    
    func forceQualityLevel(_ level: QualityLevel, duration: TimeInterval = 300) {
        logger.info("Manual quality override: \(level.rawValue) for \(duration)s")
        
        setQualityLevel(level)
        
        // Reset after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.updateBatteryLevel() // Re-evaluate based on current conditions
        }
    }
}

// MARK: - Configuration Types

struct WhisperOptimalConfig {
    let model: String
    let useGPU: Bool
    let chunkDuration: TimeInterval
    let enableTimestamps: Bool
    let enableWordTimestamps: Bool
    let temperature: Float
    let suppressBlank: Bool
}

struct FoundationModelsConfig {
    let useReducedPrecision: Bool
    let maxTokens: Int
    let enableEntityExtraction: Bool
    let enableSentimentAnalysis: Bool
    let cacheResults: Bool
}


// MARK: - Performance Profiler

class PerformanceProfiler {
    static let shared = PerformanceProfiler()
    
    private var measurements: [String: [TimeInterval]] = [:]
    
    func measure<T>(_ label: String, block: () async throws -> T) async rethrows -> T {
        let start = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(start)
        
        measurements[label, default: []].append(duration)
        
        // Keep only last 100 measurements
        if measurements[label]!.count > 100 {
            measurements[label]!.removeFirst()
        }
        
        return result
    }
    
    func getAverageTime(for label: String) -> TimeInterval? {
        guard let times = measurements[label], !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }
    
    func getReport() -> String {
        var report = "Performance Report:\n"
        
        for (label, times) in measurements.sorted(by: { $0.key < $1.key }) {
            let avg = times.reduce(0, +) / Double(times.count)
            let min = times.min() ?? 0
            let max = times.max() ?? 0
            
            report += "\(label): avg=\(String(format: "%.3f", avg))s, min=\(String(format: "%.3f", min))s, max=\(String(format: "%.3f", max))s\n"
        }
        
        return report
    }
}