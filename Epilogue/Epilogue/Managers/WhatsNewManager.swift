import Foundation
import SwiftUI
import Combine

// MARK: - What's New Manager
@MainActor
class WhatsNewManager: ObservableObject {
    static let shared = WhatsNewManager()

    private let currentVersion = "1.4.0" // Update this with each release
    private let maxShowCount = 2

    @Published var shouldShow = false

    private init() {
        checkShouldShow()
    }

    private func checkShouldShow() {
        let lastVersion = UserDefaults.standard.string(forKey: "whatsNewLastVersion") ?? ""
        let showCount = UserDefaults.standard.integer(forKey: "whatsNewShowCount_\(currentVersion)")

        // Show if:
        // 1. New version (different from last shown)
        // 2. Show count < maxShowCount (max 2 times)
        if lastVersion != currentVersion && showCount < maxShowCount {
            shouldShow = true
        }
    }

    func markAsShown() {
        let showCount = UserDefaults.standard.integer(forKey: "whatsNewShowCount_\(currentVersion)")
        UserDefaults.standard.set(showCount + 1, forKey: "whatsNewShowCount_\(currentVersion)")
        UserDefaults.standard.set(currentVersion, forKey: "whatsNewLastVersion")
        shouldShow = false
    }

    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: "whatsNewLastVersion")
        UserDefaults.standard.removeObject(forKey: "whatsNewShowCount_\(currentVersion)")
        checkShouldShow()
    }
}
