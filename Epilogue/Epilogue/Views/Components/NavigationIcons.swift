import SwiftUI

// MARK: - Library Icon (Book Open)
struct LibraryIcon: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Main book shape
            Path { path in
                // Left page
                path.move(to: CGPoint(x: 2, y: 6))
                path.addLine(to: CGPoint(x: 2, y: 18))
                path.addCurve(
                    to: CGPoint(x: 11, y: 19),
                    control1: CGPoint(x: 2, y: 18.5),
                    control2: CGPoint(x: 6, y: 19)
                )
                path.addLine(to: CGPoint(x: 11, y: 7))
                path.closeSubpath()
                
                // Right page
                path.move(to: CGPoint(x: 22, y: 6))
                path.addLine(to: CGPoint(x: 22, y: 18))
                path.addCurve(
                    to: CGPoint(x: 13, y: 19),
                    control1: CGPoint(x: 22, y: 18.5),
                    control2: CGPoint(x: 18, y: 19)
                )
                path.addLine(to: CGPoint(x: 13, y: 7))
                path.closeSubpath()
            }
            .fill(isSelected ? Color.warmAmber : Color.gray.opacity(0.6))
            
            // Center spine
            Rectangle()
                .fill(isSelected ? Color.warmAmber.opacity(0.8) : Color.gray.opacity(0.5))
                .frame(width: 2, height: 13)
                .position(x: 12, y: 13)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Notes Icon (Box Archive)
struct NotesIcon: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Box top (paper/document)
            Path { path in
                path.move(to: CGPoint(x: 5, y: 2))
                path.addLine(to: CGPoint(x: 19, y: 2))
                path.addLine(to: CGPoint(x: 19, y: 11))
                path.addLine(to: CGPoint(x: 5, y: 11))
                path.closeSubpath()
            }
            .fill(isSelected ? Color.warmAmber.opacity(0.7) : Color.gray.opacity(0.4))
            
            // Box bottom
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.warmAmber : Color.gray.opacity(0.6))
                .frame(width: 20, height: 12)
                .offset(y: 5)
            
            // Archive slot/handle
            RoundedRectangle(cornerRadius: 1)
                .fill(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                .frame(width: 8, height: 2)
                .offset(y: 5)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Chat Icon (Messages)
struct ChatIcon: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // First bubble
            Path { path in
                path.move(to: CGPoint(x: 4, y: 5))
                path.addQuadCurve(
                    to: CGPoint(x: 16, y: 5),
                    control: CGPoint(x: 10, y: 3)
                )
                path.addQuadCurve(
                    to: CGPoint(x: 16, y: 12),
                    control: CGPoint(x: 18, y: 8.5)
                )
                path.addQuadCurve(
                    to: CGPoint(x: 10, y: 14),
                    control: CGPoint(x: 14, y: 14)
                )
                // Tail
                path.addLine(to: CGPoint(x: 8, y: 16))
                path.addLine(to: CGPoint(x: 9, y: 14))
                path.addQuadCurve(
                    to: CGPoint(x: 4, y: 12),
                    control: CGPoint(x: 6, y: 14)
                )
                path.closeSubpath()
            }
            .fill(isSelected ? Color.warmAmber.opacity(0.9) : Color.gray.opacity(0.5))
            
            // Second bubble
            Path { path in
                path.move(to: CGPoint(x: 8, y: 10))
                path.addQuadCurve(
                    to: CGPoint(x: 20, y: 10),
                    control: CGPoint(x: 14, y: 8)
                )
                path.addQuadCurve(
                    to: CGPoint(x: 20, y: 17),
                    control: CGPoint(x: 22, y: 13.5)
                )
                path.addQuadCurve(
                    to: CGPoint(x: 14, y: 19),
                    control: CGPoint(x: 18, y: 19)
                )
                // Tail
                path.addLine(to: CGPoint(x: 16, y: 21))
                path.addLine(to: CGPoint(x: 15, y: 19))
                path.addQuadCurve(
                    to: CGPoint(x: 8, y: 17),
                    control: CGPoint(x: 10, y: 19)
                )
                path.closeSubpath()
            }
            .fill(isSelected ? Color.warmAmber : Color.gray.opacity(0.6))
        }
        .frame(width: 24, height: 24)
    }
}