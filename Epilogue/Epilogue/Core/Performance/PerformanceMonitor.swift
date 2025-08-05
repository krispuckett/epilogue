import Foundation
import SwiftUI
import Combine
import os.log
import QuartzCore

// MARK: - Performance Monitor
@MainActor
final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    @Published private(set) var fps: Double = 120
    @Published private(set) var frameDrops: Int = 0
    @Published private(set) var mainThreadBlocks: Int = 0
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.epilogue", category: "Performance")
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var frameDropThreshold: CFTimeInterval = 1.0 / 60.0 // 60 FPS threshold
    
    // Performance tracking
    private var performanceMetrics: [String: PerformanceMetric] = [:]
    private let metricsQueue = DispatchQueue(label: "com.epilogue.performance", qos: .utility)
    
    private init() {
        setupDisplayLink()
    }
    
    // MARK: - Public Methods
    
    func startMeasuring(_ operation: String) -> PerformanceMeasurement {
        let measurement = PerformanceMeasurement(operation: operation)
        measurement.onComplete = { [weak self] duration in
            self?.recordMetric(operation: operation, duration: duration)
        }
        return measurement
    }
    
    func measureAsync<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let start = CACurrentMediaTime()
        defer {
            let duration = CACurrentMediaTime() - start
            recordMetric(operation: operation, duration: duration)
        }
        return try await block()
    }
    
    func measure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let start = CACurrentMediaTime()
        defer {
            let duration = CACurrentMediaTime() - start
            recordMetric(operation: operation, duration: duration)
        }
        return try block()
    }
    
    func detectMainThreadBlock(threshold: TimeInterval = 0.016) { // 16ms = 1 frame at 60fps
        let start = CACurrentMediaTime()
        DispatchQueue.main.async { [weak self] in
            let duration = CACurrentMediaTime() - start
            if duration > threshold {
                self?.mainThreadBlocks += 1
                self?.logger.warning("Main thread blocked for \\(duration * 1000, format: .fixed(precision: 2))ms")
            }
        }
    }
    
    func logPerformanceReport() {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            logger.info("=== Performance Report ===")
            logger.info("Current FPS: \\(self.fps, format: .fixed(precision: 1))")
            logger.info("Frame Drops: \\(self.frameDrops)")
            logger.info("Main Thread Blocks: \\(self.mainThreadBlocks)")
            
            for (operation, metric) in self.performanceMetrics.sorted(by: { $0.key < $1.key }) {
                let avg = metric.totalDuration / Double(metric.count)
                logger.info("\\(operation): avg=\\(avg * 1000, format: .fixed(precision: 2))ms, count=\\(metric.count)")
            }
        }
    }
    
    func reset() {
        frameDrops = 0
        mainThreadBlocks = 0
        performanceMetrics.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .current, forMode: .common)
    }
    
    @objc private func updateFPS(_ displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }
        
        let deltaTime = displayLink.timestamp - lastTimestamp
        lastTimestamp = displayLink.timestamp
        
        // Detect frame drops
        if deltaTime > frameDropThreshold * 1.5 { // 1.5x threshold for frame drop
            frameDrops += 1
        }
        
        // Calculate FPS
        frameCount += 1
        if frameCount % 10 == 0 { // Update FPS every 10 frames
            fps = 1.0 / deltaTime
        }
    }
    
    private func recordMetric(operation: String, duration: CFTimeInterval) {
        metricsQueue.async { [weak self] in
            if let existing = self?.performanceMetrics[operation] {
                self?.performanceMetrics[operation] = PerformanceMetric(
                    count: existing.count + 1,
                    totalDuration: existing.totalDuration + duration
                )
            } else {
                self?.performanceMetrics[operation] = PerformanceMetric(
                    count: 1,
                    totalDuration: duration
                )
            }
            
            // Log slow operations
            if duration > 0.1 { // 100ms
                self?.logger.warning("Slow operation '\\(operation)': \\(duration * 1000, format: .fixed(precision: 2))ms")
            }
        }
    }
}

// MARK: - Performance Metric
private struct PerformanceMetric {
    let count: Int
    let totalDuration: CFTimeInterval
}

// MARK: - Performance Measurement
class PerformanceMeasurement {
    let operation: String
    let startTime: CFTimeInterval
    var onComplete: ((CFTimeInterval) -> Void)?
    
    init(operation: String) {
        self.operation = operation
        self.startTime = CACurrentMediaTime()
    }
    
    deinit {
        let duration = CACurrentMediaTime() - startTime
        onComplete?(duration)
    }
}

// MARK: - Performance Optimized ViewModifier
struct PerformanceOptimized: ViewModifier {
    let enableProMotion: Bool
    
    func body(content: Content) -> some View {
        content
            .drawingGroup() // Flatten view hierarchy for better performance
            .compositingGroup() // Reduce overdraw
            .animation(.interpolatingSpring(mass: 1, stiffness: 500, damping: 30), value: enableProMotion)
    }
}

extension View {
    func performanceOptimized(enableProMotion: Bool = true) -> some View {
        modifier(PerformanceOptimized(enableProMotion: enableProMotion))
    }
}