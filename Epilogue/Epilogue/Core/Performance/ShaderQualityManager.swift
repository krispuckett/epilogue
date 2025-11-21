import Foundation
import UIKit
import OSLog
import Combine
import SwiftUI

private let logger = Logger(subsystem: "com.epilogue", category: "ShaderQuality")

// MARK: - Shader Quality Levels

enum ShaderQuality: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case ultra = 3

    var iterations: Int32 {
        switch self {
        case .low: return 12
        case .medium: return 20
        case .high: return 28
        case .ultra: return 36
        }
    }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .ultra: return "Ultra"
        }
    }
}

// MARK: - Device Performance Tier

enum DevicePerformanceTier {
    case low        // iPhone 11 and older, SE 2nd gen
    case medium     // iPhone 12, 13
    case high       // iPhone 14, 15
    case ultra      // iPhone 15 Pro, 16, 16 Pro

    var recommendedQuality: ShaderQuality {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .ultra: return .ultra
        }
    }
}

// MARK: - Shader Quality Manager

@MainActor
final class ShaderQualityManager: ObservableObject {
    static let shared = ShaderQualityManager()

    @Published var currentQuality: ShaderQuality
    @Published var userPreferredQuality: ShaderQuality?
    @Published var thermalState: ProcessInfo.ThermalState = .nominal

    private let deviceTier: DevicePerformanceTier
    private var thermalStateObserver: Any?

    private init() {
        // Detect device performance tier
        self.deviceTier = ShaderQualityManager.detectDeviceTier()

        // Start with recommended quality for device
        self.currentQuality = deviceTier.recommendedQuality

        // Monitor thermal state
        self.thermalState = ProcessInfo.processInfo.thermalState
        setupThermalMonitoring()

        logger.info("🎨 ShaderQualityManager initialized - Device tier: \(String(describing: self.deviceTier)), Quality: \(self.currentQuality.displayName)")
    }

    // MARK: - Public API

    /// Get current iterations for shader rendering
    var currentIterations: Int32 {
        return effectiveQuality.iterations
    }

    /// Get effective quality (accounting for thermal throttling)
    var effectiveQuality: ShaderQuality {
        // Use user preference if set
        let baseQuality = userPreferredQuality ?? currentQuality

        // Apply thermal throttling
        return applyThermalThrottling(to: baseQuality)
    }

    /// Set user preferred quality level
    func setPreferredQuality(_ quality: ShaderQuality?) {
        userPreferredQuality = quality
        updateCurrentQuality()

        logger.info("🎨 User set preferred quality: \(quality?.displayName ?? "Auto")")
    }

    // MARK: - Private Methods

    private func setupThermalMonitoring() {
        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleThermalStateChange()
            }
        }
    }

    private func handleThermalStateChange() {
        thermalState = ProcessInfo.processInfo.thermalState
        updateCurrentQuality()

        logger.info("🌡️ Thermal state changed: \(self.thermalStateString(self.thermalState))")
    }

    private func updateCurrentQuality() {
        let newQuality = effectiveQuality
        if newQuality != currentQuality {
            currentQuality = newQuality
            logger.info("🎨 Quality adjusted to: \(newQuality.displayName)")
        }
    }

    private func applyThermalThrottling(to quality: ShaderQuality) -> ShaderQuality {
        switch thermalState {
        case .nominal, .fair:
            return quality

        case .serious:
            // Drop one quality level
            let newRawValue = max(quality.rawValue - 1, ShaderQuality.low.rawValue)
            return ShaderQuality(rawValue: newRawValue) ?? .low

        case .critical:
            // Force to low quality
            return .low

        @unknown default:
            return quality
        }
    }

    private static func detectDeviceTier() -> DevicePerformanceTier {
        // Get device identifier
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Map iPhone models to performance tiers
        // Format: iPhone{generation},{variant}
        if identifier.hasPrefix("iPhone") {
            let components = identifier.components(separatedBy: ",")
            guard let modelNumber = components.first?.replacingOccurrences(of: "iPhone", with: ""),
                  let generation = Int(modelNumber) else {
                return .medium // Default fallback
            }

            // iPhone 16,x = iPhone 16 series -> Ultra
            // iPhone 15,x = iPhone 15 series (15 Pro = Ultra, regular = High)
            // iPhone 14,x = iPhone 14 series -> High
            // iPhone 13,x = iPhone 13 series -> Medium
            // iPhone 12,x and older = Low to Medium

            switch generation {
            case 16...: return .ultra      // iPhone 16 and newer
            case 15: return .ultra          // iPhone 15 (includes Pro)
            case 14: return .high           // iPhone 14
            case 13: return .medium         // iPhone 13
            default: return .low            // iPhone 12 and older
            }
        }

        // Simulator or unknown device - use high as safe default
        if identifier.contains("Simulator") {
            return .high
        }

        return .medium // Fallback
    }

    private func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    deinit {
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
