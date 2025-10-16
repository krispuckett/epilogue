import SwiftUI

// MARK: - ContentSizeCategory Extensions

extension ContentSizeCategory {
    /// Returns true if this content size category is an accessibility size
    var isAccessibilitySize: Bool {
        switch self {
        case .accessibilityMedium,
             .accessibilityLarge,
             .accessibilityExtraLarge,
             .accessibilityExtraExtraLarge,
             .accessibilityExtraExtraExtraLarge:
            return true
        default:
            return false
        }
    }
}
