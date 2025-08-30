import SwiftUI

// MARK: - Isolated Test View for MeshGradient
// This is completely separate from your production code
// Use this to test if MeshGradient works well before implementing

struct MeshGradientTestView: View {
    // Test with Lord of the Rings colors (red + gold)
    @State private var showOriginal = true
    @State private var animateGradient = false
    
    // Your current colors extracted from a book (matching actual ColorPalette structure)
    let testBookColors = ColorPalette(
        primary: Color(red: 0.8, green: 0.2, blue: 0.2),    // Red
        secondary: Color(red: 0.9, green: 0.7, blue: 0.3),  // Gold
        accent: Color(red: 1.0, green: 0.55, blue: 0.26),   // Your amber
        background: Color(red: 0.6, green: 0.3, blue: 0.2), // Brown for background
        textColor: Color.white,
        luminance: 0.5,
        isMonochromatic: false,
        extractionQuality: 0.9
    )
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Toggle to compare - INVERTED for clarity
                Toggle("Show MeshGradient", isOn: .init(
                    get: { !showOriginal },
                    set: { showOriginal = !$0 }
                ))
                    .padding(.horizontal)
                    .tint(DesignSystem.Colors.primaryAccent)
                
                // Side by side comparison
                HStack(spacing: 20) {
                    // CURRENT: Your existing gradient
                    VStack {
                        Text("CURRENT")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        testBookColors.primary,
                                        testBookColors.secondary,
                                        testBookColors.background
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 150, height: 200)
                            .overlay {
                                Text("Linear\nGradient")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                            }
                    }
                    .opacity(showOriginal ? 1 : 0.3)
                    
                    // NEW: MeshGradient test
                    VStack {
                        Text("MESH GRADIENT")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        if #available(iOS 18.0, *) {
                            // Simplified MeshGradient to avoid CPU spike
                            MeshGradient(
                                width: 3,
                                height: 3,
                                points: [
                                    // Top row
                                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                                    // Middle row  
                                    .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                                    // Bottom row
                                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                                ],
                                colors: [
                                    // Simplified colors - no opacity modifications
                                    testBookColors.primary,
                                    testBookColors.accent,
                                    testBookColors.secondary,
                                    
                                    testBookColors.background,
                                    testBookColors.accent,
                                    testBookColors.primary,
                                    
                                    testBookColors.secondary,
                                    testBookColors.background,
                                    testBookColors.accent
                                ]
                            )
                            .frame(width: 150, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay {
                                    Text("Mesh\nGradient")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                }
                        } else {
                            // Fallback for older iOS
                            Text("MeshGradient requires iOS 18+")
                                .frame(width: 150, height: 200)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(16)
                        }
                    }
                    .opacity(showOriginal ? 0.3 : 1)
                }
                .padding()
                
                // Full width preview
                VStack(spacing: 10) {
                    Text("Full Width Preview")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    if #available(iOS 18.0, *) {
                        BookAtmosphereTest(
                            colors: testBookColors,
                            useMesh: !showOriginal,  // This will show mesh when toggle is ON
                            animate: false  // Disabled animation to prevent CPU spike
                        )
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    } else {
                        Text("MeshGradient requires iOS 18+")
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Safety note
                Text("This is a test view - nothing here affects your app")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            .navigationTitle("MeshGradient Test")
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Colors.surfaceBackground)
        }
    }
}

// MARK: - Test Component
@available(iOS 18.0, *)
struct BookAtmosphereTest: View {
    let colors: ColorPalette
    let useMesh: Bool
    let animate: Bool
    
    var body: some View {
        ZStack {
            if useMesh {
                // Simplified Mesh gradient - no animation to avoid CPU spike
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        // Static points only
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.5, 0.5], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1]
                    ],
                    colors: [
                        // Use solid colors only - no opacity
                        colors.primary,
                        colors.accent,
                        colors.secondary,
                        
                        colors.accent,
                        colors.primary,
                        colors.background,
                        
                        colors.secondary,
                        colors.background,
                        colors.primary
                    ]
                )
                .ignoresSafeArea()
            } else {
                // Original linear gradient
                LinearGradient(
                    colors: [
                        colors.primary,
                        colors.secondary,
                        colors.background,
                        colors.accent.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            // Sample content overlay
            VStack {
                Text("Lord of the Rings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("J.R.R. Tolkien")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Preview
#Preview("MeshGradient Test") {
    MeshGradientTestView()
        .preferredColorScheme(.dark)
}

#Preview("Direct Comparison") {
    HStack {
        // Your current gradient
        LinearGradient(
            colors: [.red, .orange, .brown],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        if #available(iOS 18.0, *) {
            // New mesh gradient
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    .red, .red.opacity(0.8), .orange,
                    .red.opacity(0.6), .orange, .orange.opacity(0.7),
                    .brown, .orange.opacity(0.8), .brown.opacity(0.8)
                ]
            )
        }
    }
    .frame(height: 300)
}