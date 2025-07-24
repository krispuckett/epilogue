import SwiftUI
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var yaw: Double = 0
    
    // Smoothed values for more natural movement
    @Published var smoothPitch: Double = 0
    @Published var smoothRoll: Double = 0
    
    private let smoothingFactor = 0.1
    
    init() {
        startMotionUpdates()
    }
    
    deinit {
        stopMotionUpdates()
    }
    
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Raw values
            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
            self.yaw = motion.attitude.yaw
            
            // Apply smoothing for more natural movement
            self.smoothPitch = self.smoothPitch * (1 - self.smoothingFactor) + self.pitch * self.smoothingFactor
            self.smoothRoll = self.smoothRoll * (1 - self.smoothingFactor) + self.roll * self.smoothingFactor
        }
    }
    
    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    // Convert motion to normalized values for UI use
    var normalizedTiltX: Double {
        // Roll affects horizontal tilt, clamped to reasonable range
        return max(-1, min(1, smoothRoll / .pi))
    }
    
    var normalizedTiltY: Double {
        // Pitch affects vertical tilt, clamped to reasonable range
        return max(-1, min(1, smoothPitch / .pi))
    }
    
    // Light position based on device orientation
    var lightPosition: CGPoint {
        CGPoint(
            x: 0.5 + normalizedTiltX * 0.3,
            y: 0.3 + normalizedTiltY * 0.3
        )
    }
}