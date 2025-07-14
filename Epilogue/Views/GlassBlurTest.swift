import SwiftUI

struct GlassBlurTest: View {
    var body: some View {
        ZStack {
            // Scrollable background with distinct patterns to see blur
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Create a pattern of shapes and text that will show blur clearly
                    ForEach(0..<50) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<10) { column in
                                ZStack {
                                    Rectangle()
                                        .fill(Color(
                                            hue: Double((row + column) % 10) / 10,
                                            saturation: 1,
                                            brightness: 1
                                        ))
                                    
                                    // Add some text to make blur more obvious
                                    Text("●")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 50, height: 50)
                            }
                        }
                    }
                    
                    // Add some larger text elements
                    ForEach(0..<5) { index in
                        Text("GLASS BLUR TEST \(index)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.black)
                            .padding()
                            .background(Color.white)
                    }
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                VStack(spacing: 5) {
                    Text("Glass Blur Test")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .shadow(radius: 5)
                    
                    Text("Scroll background to see blur effect")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 2)
                }
                .padding(.top, 50)
                
                // Test 1: Just glassEffect
                VStack {
                    Text("Plain .glassEffect()")
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    
                    Text("If glass works, background should blur")
                        .foregroundStyle(.white)
                        .padding()
                        .frame(width: 300, height: 80)
                        .glassEffect()
                }
                
                // Test 2: Glass in shape
                VStack {
                    Text(".glassEffect(in: shape)")
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    
                    Text("Glass with RoundedRectangle")
                        .foregroundStyle(.white)
                        .padding()
                        .frame(width: 300, height: 80)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                }
                
                // Test 3: Glass on empty view
                VStack {
                    Text("Glass on Color.clear")
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    
                    Color.clear
                        .frame(width: 300, height: 80)
                        .glassEffect()
                        .overlay(
                            Text("Should see blurred background")
                                .foregroundStyle(.white)
                        )
                }
                
                // Test 4: Comparison with materials
                VStack(spacing: 15) {
                    Text("Glass vs Materials")
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("Glass")
                                .font(.caption)
                                .foregroundStyle(.white)
                            
                            Color.clear
                                .frame(width: 120, height: 80)
                                .glassEffect()
                        }
                        
                        VStack {
                            Text("UltraThin")
                                .font(.caption)
                                .foregroundStyle(.white)
                            
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 120, height: 80)
                        }
                    }
                }
                
                // Test 5: Glass container approach
                VStack {
                    Text("GlassEffectContainer")
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    
                    GlassEffectContainer {
                        HStack(spacing: 20) {
                            Text("Inside Container 1")
                                .foregroundStyle(.white)
                                .padding()
                                .glassEffect()
                            
                            Text("Inside Container 2")
                                .foregroundStyle(.white)
                                .padding()
                                .glassEffect()
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    GlassBlurTest()
}