import SwiftUI

/// A simple progress indicator that replaces the problematic system ProgressView
struct SimpleProgressIndicator: View {
    let tintColor: Color
    let scale: CGFloat
    
    init(tintColor: Color = DesignSystem.Colors.primaryAccent, scale: CGFloat = 1.0) {
        self.tintColor = tintColor
        self.scale = scale
    }
    
    var body: some View {
        CircularProgressView(
            progress: 0,
            accentColor: tintColor,
            isIndeterminate: true
        )
        .frame(width: 20 * scale, height: 20 * scale)
    }
}

#Preview {
    SimpleProgressIndicator()
        .padding()
        .background(Color.black)
}