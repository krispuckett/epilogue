import SwiftUI

struct AmbientReadingProgressView_Test: View {
    let book: Book
    
    var body: some View {
        Text("Test")
    }
}

// MARK: - View Extension
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}