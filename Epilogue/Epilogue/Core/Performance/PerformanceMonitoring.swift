import Foundation
import UIKit
import OSLog
import QuartzCore
import Combine
import SwiftUI

private let logger = Logger(subsystem: "com.epilogue", category: "Performance")

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let appLaunchTime: TimeInterval
    let memoryUsage: MemoryUsage
    let cpuUsage: Double
    let diskUsage: DiskUsage
    let networkLatency: TimeInterval
    let frameRate: Double
    let batteryLevel: Float
    let thermalState: ProcessInfo.ThermalState
}

struct MemoryUsage {
    let used: Int64  // Bytes
    let available: Int64  // Bytes
    let total: Int64  // Bytes
    let pressure: MemoryPressure

    var usedMB: Double { Double(used) / 1024 / 1024 }
    var availableMB: Double { Double(available) / 1024 / 1024 }
    var totalMB: Double { Double(total) / 1024 / 1024 }
    var percentUsed: Double { Double(used) / Double(total) * 100 }
}

enum MemoryPressure {
    case normal
    case warning
    case urgent
    case critical
}

struct DiskUsage {
    let used: Int64  // Bytes
    let available: Int64  // Bytes
    let total: Int64  // Bytes

    var usedGB: Double { Double(used) / 1024 / 1024 / 1024 }
    var availableGB: Double { Double(available) / 1024 / 1024 / 1024 }
    var totalGB: Double { Double(total) / 1024 / 1024 / 1024 }
    var percentUsed: Double { Double(used) / Double(total) * 100 }
}

// MARK: - Performance Monitor

@MainActor
final class PerformanceMonitorService: ObservableObject {
    static let shared = PerformanceMonitorService()

    @Published var currentMetrics: PerformanceMetrics?
    @Published var isMonitoring = false
    @Published var frameDropCount = 0
    @Published var memoryWarningCount = 0

    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var frameCount = 0
    private var appLaunchTime: TimeInterval = 0
    private var metricsTimer: Timer?
    private var networkMonitor: NetworkMonitor?

    // Performance thresholds
    private let targetFrameRate: Double = 60.0
    private let frameDropThreshold: Double = 50.0
    private let memoryWarningThreshold: Double = 80.0  // Percent
    private let cpuWarningThreshold: Double = 80.0  // Percent

    private init() {
        setupMonitoring()
    }

    // MARK: - Public Methods

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        appLaunchTime = ProcessInfo.processInfo.systemUptime

        startFrameRateMonitoring()
        startMetricsCollection()
        startMemoryMonitoring()
        startNetworkMonitoring()

        logger.info("Performance monitoring started")
        Analytics.shared.track(.appLaunched(launchTime: appLaunchTime))
    }

    func stopMonitoring() {
        isMonitoring = false

        displayLink?.invalidate()
        displayLink = nil
        metricsTimer?.invalidate()
        metricsTimer = nil

        logger.info("Performance monitoring stopped")
    }

    func measureAsync<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let result = try await block()
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            logger.debug("Performance: \(name) took \(String(format: "%.3f", duration))s")
            Analytics.shared.timing(name, time: duration)

            if duration > 1.0 {
                logger.warning("Slow operation: \(name) took \(String(format: "%.3f", duration))s")
            }

            return result
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.error("Performance: \(name) failed after \(String(format: "%.3f", duration))s")
            throw error
        }
    }

    func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let result = try block()
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            logger.debug("Performance: \(name) took \(String(format: "%.3f", duration))s")
            Analytics.shared.timing(name, time: duration)

            if duration > 0.5 {
                logger.warning("Slow operation: \(name) took \(String(format: "%.3f", duration))s")
            }

            return result
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.error("Performance: \(name) failed after \(String(format: "%.3f", duration))s")
            throw error
        }
    }

    func trackScreenLoad(_ screenName: String, loadTime: TimeInterval) {
        logger.debug("Screen '\(screenName)' loaded in \(String(format: "%.3f", loadTime))s")
        Analytics.shared.track(.screenLoaded(screenName: screenName, loadTime: loadTime))

        if loadTime > 1.0 {
            logger.warning("Slow screen load: '\(screenName)' took \(String(format: "%.3f", loadTime))s")
            CrashReporter.shared.addBreadcrumb(
                "Slow screen load: \(screenName) (\(String(format: "%.1f", loadTime))s)",
                category: "performance",
                level: .warning
            )
        }
    }

    func trackImageLoad(url: String, loadTime: TimeInterval, cacheHit: Bool) {
        Analytics.shared.track(.imageLoaded(url: url, loadTime: loadTime, cacheHit: cacheHit))

        if !cacheHit && loadTime > 2.0 {
            logger.warning("Slow image load: \(String(format: "%.3f", loadTime))s for \(url)")
        }
    }

    // MARK: - Private Methods

    private func setupMonitoring() {
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        // Listen for thermal state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThermalStateChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    private func startFrameRateMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrameRate))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func startMetricsCollection() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.collectMetrics()
            }
        }
    }

    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkMemoryUsage()
            }
        }
    }

    private func startNetworkMonitoring() {
        networkMonitor = NetworkMonitor()
        networkMonitor?.startMonitoring()
    }

    @objc private func updateFrameRate(_ displayLink: CADisplayLink) {
        frameCount += 1

        let timestamp = displayLink.timestamp
        if lastFrameTimestamp == 0 {
            lastFrameTimestamp = timestamp
            return
        }

        let elapsed = timestamp - lastFrameTimestamp
        if elapsed >= 1.0 {
            let fps = Double(frameCount) / elapsed

            if fps < frameDropThreshold {
                frameDropCount += 1
                logger.warning("Frame drop detected: \(String(format: "%.1f", fps)) FPS")

                CrashReporter.shared.addBreadcrumb(
                    "Frame drop: \(String(format: "%.1f", fps)) FPS",
                    category: "performance",
                    level: .warning
                )
            }

            frameCount = 0
            lastFrameTimestamp = timestamp
        }
    }

    @objc private func handleMemoryWarning() {
        memoryWarningCount += 1
        logger.warning("Memory warning received (count: \(self.memoryWarningCount))")

        CrashReporter.shared.addBreadcrumb(
            "Memory warning #\(self.memoryWarningCount)",
            category: "memory",
            level: .warning
        )

        Analytics.shared.track(
            AnalyticsEvent(
                name: "memory_warning",
                category: .performance,
                properties: ["warning_count": self.memoryWarningCount]
            )
        )

        // Clear caches
        ResponseCache.shared.cleanExpiredEntries()
        // ColorPaletteCache.shared.clearCache() // Not available
        // SharedBookCoverManager.shared.clearMemoryCache() // Not available
    }

    @objc private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState

        logger.info("Thermal state changed: \(self.thermalStateString(thermalState))")

        if thermalState == .serious || thermalState == .critical {
            logger.warning("Device thermal state is \(self.thermalStateString(thermalState))")

            // Reduce performance-intensive operations
            stopMonitoring()
        }
    }

    private func collectMetrics() {
        let metrics = PerformanceMetrics(
            appLaunchTime: ProcessInfo.processInfo.systemUptime - appLaunchTime,
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage(),
            diskUsage: getDiskUsage(),
            networkLatency: networkMonitor?.latency ?? 0,
            frameRate: Double(frameCount),
            batteryLevel: UIDevice.current.batteryLevel,
            thermalState: ProcessInfo.processInfo.thermalState
        )

        currentMetrics = metrics

        // Log warnings for concerning metrics
        if metrics.memoryUsage.percentUsed > memoryWarningThreshold {
            logger.warning("High memory usage: \(String(format: "%.1f", metrics.memoryUsage.percentUsed))%")
        }

        if metrics.cpuUsage > cpuWarningThreshold {
            logger.warning("High CPU usage: \(String(format: "%.1f", metrics.cpuUsage))%")
        }
    }

    private func checkMemoryUsage() {
        let usage = getMemoryUsage()

        Analytics.shared.setValue("memory_used_mb", value: usage.usedMB)
        Analytics.shared.setValue("memory_percent", value: usage.percentUsed)

        if usage.pressure == .critical {
            logger.critical("Critical memory pressure detected")
            handleMemoryWarning()
        }
    }

    private func getMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let used = result == KERN_SUCCESS ? info.resident_size : 0
        let total = ProcessInfo.processInfo.physicalMemory
        let available = Int64(total) - Int64(used)

        let percentUsed = Double(used) / Double(total) * 100
        let pressure: MemoryPressure = {
            switch percentUsed {
            case 0..<50: return .normal
            case 50..<70: return .warning
            case 70..<85: return .urgent
            default: return .critical
            }
        }()

        return MemoryUsage(
            used: Int64(used),
            available: available,
            total: Int64(total),
            pressure: pressure
        )
    }

    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Double(info.user_time.seconds + info.system_time.seconds)
        }
        return 0
    }

    private func getDiskUsage() -> DiskUsage {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentDirectory.path)
            let total = attributes[.systemSize] as? Int64 ?? 0
            let free = attributes[.systemFreeSize] as? Int64 ?? 0
            let used = total - free

            return DiskUsage(used: used, available: free, total: total)
        } catch {
            logger.error("Failed to get disk usage: \(error.localizedDescription)")
            return DiskUsage(used: 0, available: 0, total: 0)
        }
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
}

// MARK: - Network Monitor

private class NetworkMonitor {
    var latency: TimeInterval = 0
    private var pingTimer: Timer?

    func startMonitoring() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await self.measureNetworkLatency()
            }
        }
    }

    func stopMonitoring() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func measureNetworkLatency() async {
        let url = URL(string: "https://www.google.com")!
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            _ = try await URLSession.shared.data(from: url)
            latency = CFAbsoluteTimeGetCurrent() - startTime
        } catch {
            latency = -1  // Indicate network error
        }
    }
}

// MARK: - Performance Profiling

struct PerformanceProfilerService {
    static func profile<T>(_ name: String, _ block: () throws -> T) rethrows -> T {
        return try PerformanceMonitorService.shared.measure(name, block: block)
    }

    static func profileAsync<T>(_ name: String, _ block: () async throws -> T) async rethrows -> T {
        return try await PerformanceMonitorService.shared.measureAsync(name, block: block)
    }
}