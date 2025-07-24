import SwiftUI

struct FeatherIcon: View {
    let size: CGFloat
    
    init(size: CGFloat = 24) {
        self.size = size
    }
    
    var body: some View {
        Canvas { context, size in
            // Scale to fit the requested size
            let scale = min(size.width, size.height) / 24
            context.scaleBy(x: scale, y: scale)
            
            // First path (feather shaft)
            let path1 = Path { path in
                path.move(to: CGPoint(x: 13.9141, y: 6.04669))
                path.addCurve(
                    to: CGPoint(x: 15.1338, y: 6.6004),
                    control1: CGPoint(x: 14.3966, y: 5.89291),
                    control2: CGPoint(x: 14.9272, y: 6.12614)
                )
                path.addCurve(
                    to: CGPoint(x: 14.6152, y: 7.91681),
                    control1: CGPoint(x: 15.3541, y: 7.10678),
                    control2: CGPoint(x: 15.1216, y: 7.69643)
                )
                path.addLine(to: CGPoint(x: 14.2285, y: 8.08966))
                path.addCurve(
                    to: CGPoint(x: 5.90039, y: 15.4354),
                    control1: CGPoint(x: 10.2586, y: 9.9015),
                    control2: CGPoint(x: 7.27634, y: 12.5886)
                )
                path.addCurve(
                    to: CGPoint(x: 5.46875, y: 15.8817),
                    control1: CGPoint(x: 5.80424, y: 15.6341),
                    control2: CGPoint(x: 5.65002, y: 15.7855)
                )
                path.addLine(to: CGPoint(x: 5.46387, y: 15.8943))
                path.addCurve(
                    to: CGPoint(x: 4.00391, y: 21.1424),
                    control1: CGPoint(x: 4.46467, y: 18.3639),
                    control2: CGPoint(x: 4.0895, y: 20.4327)
                )
                path.addLine(to: CGPoint(x: 3.98633, y: 21.244))
                path.addCurve(
                    to: CGPoint(x: 2.89062, y: 22.0164),
                    control1: CGPoint(x: 3.87508, y: 21.7384),
                    control2: CGPoint(x: 3.40461, y: 22.0784)
                )
                path.addCurve(
                    to: CGPoint(x: 2.01758, y: 20.9031),
                    control1: CGPoint(x: 2.34262, y: 21.9501),
                    control2: CGPoint(x: 1.95153, y: 21.4513)
                )
                path.addLine(to: CGPoint(x: 2.07715, y: 20.4871))
                path.addCurve(
                    to: CGPoint(x: 3.83496, y: 14.6043),
                    control1: CGPoint(x: 2.25741, y: 19.3536),
                    control2: CGPoint(x: 2.74854, y: 17.129)
                )
                path.addLine(to: CGPoint(x: 3.88086, y: 14.5125))
                path.addCurve(
                    to: CGPoint(x: 4.34375, y: 14.0867),
                    control1: CGPoint(x: 3.9884, y: 14.3194),
                    control2: CGPoint(x: 4.15277, y: 14.1726)
                )
                path.addCurve(
                    to: CGPoint(x: 13.8174, y: 6.08282),
                    control1: CGPoint(x: 6.11614, y: 10.7969),
                    control2: CGPoint(x: 9.5613, y: 7.93457)
                )
                path.closeSubpath()
            }
            
            // Draw shaft with gradient
            let gradient1 = Gradient(colors: [
                Color(red: 0.341, green: 0.341, blue: 0.341),
                Color(red: 0.082, green: 0.082, blue: 0.082)
            ])
            context.fill(
                path1,
                with: .linearGradient(
                    gradient1,
                    startPoint: CGPoint(x: 8.614, y: 6),
                    endPoint: CGPoint(x: 8.614, y: 22.024)
                )
            )
            
            // Second path (feather body)
            let path2 = Path { path in
                path.move(to: CGPoint(x: 21.996, y: 2.97831))
                path.addCurve(
                    to: CGPoint(x: 20.8353, y: 2.00456),
                    control1: CGPoint(x: 21.9443, y: 2.38904),
                    control2: CGPoint(x: 21.4169, y: 1.95015)
                )
                path.addCurve(
                    to: CGPoint(x: 3.57739, y: 15.2239),
                    control1: CGPoint(x: 10.3866, y: 2.9187),
                    control2: CGPoint(x: 5.66294, y: 10.0172)
                )
                path.addCurve(
                    to: CGPoint(x: 4.09897, y: 16.4711),
                    control1: CGPoint(x: 3.38207, y: 15.7115),
                    control2: CGPoint(x: 3.61863, y: 16.2586)
                )
                path.addLine(to: CGPoint(x: 5.18087, y: 16.9499))
                path.addCurve(
                    to: CGPoint(x: 7.52185, y: 17.6962),
                    control1: CGPoint(x: 6.32808, y: 17.459),
                    control2: CGPoint(x: 7.45527, y: 17.6848)
                )
                path.addCurve(
                    to: CGPoint(x: 10.9036, y: 18.031),
                    control1: CGPoint(x: 8.74173, y: 17.919),
                    control2: CGPoint(x: 9.86938, y: 18.031)
                )
                path.addCurve(
                    to: CGPoint(x: 16.1171, y: 16.5872),
                    control1: CGPoint(x: 13.0562, y: 18.031),
                    control2: CGPoint(x: 14.8029, y: 17.5472)
                )
                path.addCurve(
                    to: CGPoint(x: 18.1023, y: 14.1039),
                    control1: CGPoint(x: 16.6465, y: 16.2),
                    control2: CGPoint(x: 17.5038, y: 15.4252)
                )
                path.addCurve(
                    to: CGPoint(x: 13.0046, y: 11.9807),
                    control1: CGPoint(x: 14.0582, y: 14.8651),
                    control2: CGPoint(x: 13.0046, y: 11.9807)
                )
                path.addCurve(
                    to: CGPoint(x: 20.6233, y: 9.36491),
                    control1: CGPoint(x: 16.1248, y: 12.7703),
                    control2: CGPoint(x: 19.6729, y: 13.0131)
                )
                path.addCurve(
                    to: CGPoint(x: 21.0697, y: 6.82729),
                    control1: CGPoint(x: 20.8218, y: 8.49059),
                    control2: CGPoint(x: 20.9483, y: 7.64435)
                )
                path.addLine(to: CGPoint(x: 21.0738, y: 6.79966))
                path.addCurve(
                    to: CGPoint(x: 21.8551, y: 3.6047),
                    control1: CGPoint(x: 21.2651, y: 5.52313),
                    control2: CGPoint(x: 21.4453, y: 4.32071)
                )
                path.addCurve(
                    to: CGPoint(x: 21.996, y: 2.97831),
                    control1: CGPoint(x: 21.961, y: 3.42108),
                    control2: CGPoint(x: 22.0159, y: 3.20542)
                )
                path.closeSubpath()
            }
            
            // Draw body with semi-transparent gradient
            let gradient2 = Gradient(colors: [
                Color(red: 0.890, green: 0.890, blue: 0.898, opacity: 0.6),
                Color(red: 0.733, green: 0.733, blue: 0.753, opacity: 0.6)
            ])
            context.fill(
                path2,
                with: .linearGradient(
                    gradient2,
                    startPoint: CGPoint(x: 12.623, y: 2),
                    endPoint: CGPoint(x: 12.623, y: 18.031)
                )
            )
            
            // Draw outline
            context.stroke(
                path2,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white,
                        Color.white.opacity(0)
                    ]),
                    startPoint: CGPoint(x: 12.754, y: 2),
                    endPoint: CGPoint(x: 12.754, y: 11.284)
                ),
                lineWidth: 0.75
            )
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        FeatherIcon(size: 24)
        FeatherIcon(size: 32)
        FeatherIcon(size: 48)
    }
    .padding()
    .background(Color.black)
}