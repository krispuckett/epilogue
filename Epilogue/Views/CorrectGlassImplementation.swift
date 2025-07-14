import SwiftUI

struct CorrectGlassImplementation: View {
    @Namespace private var namespace
    
    var body: some View {
        ZStack {
            // Colorful animated background
            LinearGradient(
                colors: [.purple, .blue, .cyan, .green, .yellow, .orange, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Text("iOS 26 Glass Effects - Correct Implementation")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 50)
                    
                    // CORRECT: No background before glass effect
                    VStack(spacing: 10) {
                        Text("Correct Glass Implementation")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        // Basic glass - NO BACKGROUND
                        Button {
                            // Action
                        } label: {
                            Text("Basic Glass")
                                .foregroundStyle(.white)
                                .frame(width: 200, height: 60)
                        }
                        .glassEffect()
                    }
                    
                    // Glass with tinting
                    VStack(spacing: 10) {
                        Text("Glass with Tinting")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 15) {
                            Button {
                                // Action
                            } label: {
                                Label("Purple", systemImage: "star.fill")
                                    .foregroundStyle(.white)
                                    .frame(width: 100, height: 60)
                            }
                            .glassEffect()
                            
                            Button {
                                // Action
                            } label: {
                                Label("Blue", systemImage: "heart.fill")
                                    .foregroundStyle(.white)
                                    .frame(width: 100, height: 60)
                            }
                            .glassEffect()
                        }
                    }
                    
                    // Glass container with multiple elements
                    VStack(spacing: 10) {
                        Text("Glass Container")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        GlassEffectContainer {
                            VStack(spacing: 20) {
                                ForEach(0..<3) { index in
                                    Button {
                                        // Action
                                    } label: {
                                        HStack {
                                            Image(systemName: "star.fill")
                                            Text("Item \(index + 1)")
                                        }
                                        .foregroundStyle(.white)
                                        .frame(width: 200, height: 50)
                                    }
                                    .glassEffect()
                                    .glassEffectID("item\(index)", in: namespace)
                                }
                            }
                        }
                    }
                    
                    // Interactive glass
                    VStack(spacing: 10) {
                        Text("Interactive Glass")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Button {
                            // Action
                        } label: {
                            Label("Interactive", systemImage: "hand.tap.fill")
                                .foregroundStyle(.white)
                                .frame(width: 200, height: 60)
                        }
                        .glassEffect()
                    }
                    
                    // Glass with shape
                    VStack(spacing: 10) {
                        Text("Glass with Custom Shape")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Button {
                            // Action
                        } label: {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                                .frame(width: 100, height: 100)
                        }
                        .glassEffect(in: Circle())
                    }
                    
                    // Comparison: Wrong vs Right
                    VStack(spacing: 10) {
                        Text("Wrong vs Right Implementation")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 20) {
                            // WRONG - with background
                            VStack {
                                Text("Wrong")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                
                                Button {
                                    // Action
                                } label: {
                                    Text("Opaque")
                                        .foregroundStyle(.white)
                                        .frame(width: 100, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.2)))
                                }
                                .glassEffect()
                            }
                            
                            // RIGHT - no background
                            VStack {
                                Text("Right")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                
                                Button {
                                    // Action
                                } label: {
                                    Text("Glass")
                                        .foregroundStyle(.white)
                                        .frame(width: 100, height: 50)
                                }
                                .glassEffect()
                            }
                        }
                    }
                    
                    // Different glass effects
                    VStack(spacing: 10) {
                        Text("Glass Effect Variations")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        VStack(spacing: 15) {
                            Button {
                                // Action
                            } label: {
                                Text("Standard Glass")
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .glassEffect()
                            
                            Button {
                                // Action
                            } label: {
                                Text("Glass in RoundedRectangle")
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .glassEffect(in: RoundedRectangle(cornerRadius: 25))
                            
                            Button {
                                // Action
                            } label: {
                                Text("Glass in Capsule")
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .glassEffect(in: Capsule())
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
    }
}

// Backward compatibility extension from the research
extension View {
    @ViewBuilder
    func glassedEffect(in shape: some Shape, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background {
                shape.fill(.ultraThinMaterial)
            }
        }
    }
}

#Preview {
    CorrectGlassImplementation()
}