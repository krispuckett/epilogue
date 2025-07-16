import SwiftUI

struct GlassTransitionTest: View {
    @State private var showPalette = false
    @State private var selectedTransition = 0
    @Namespace private var glassNamespace
    
    let transitions = ["Identity", "Matched Geometry", "Materialize"]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.purple, .blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Transition selector
                Picker("Glass Transition", selection: $selectedTransition) {
                    ForEach(0..<transitions.count, id: \.self) { index in
                        Text(transitions[index]).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .glassEffect()
                
                Spacer()
                
                // Toggle button
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showPalette.toggle()
                    }
                } label: {
                    Label(showPalette ? "Hide Palette" : "Show Palette", 
                          systemImage: showPalette ? "xmark.circle" : "plus.circle")
                        .frame(width: 200, height: 50)
                }
                .glassEffect()
                .padding(.bottom, 100)
            }
            
            // Test palette with different transitions
            if showPalette {
                VStack {
                    Spacer()
                    
                    TestCommandPalette(
                        isPresented: $showPalette,
                        transitionType: selectedTransition,
                        namespace: glassNamespace
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct TestCommandPalette: View {
    @Binding var isPresented: Bool
    let transitionType: Int
    let namespace: Namespace.ID
    @State private var commandText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
            
            // Input field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.6))
                
                TextField("Test glass transitions...", text: $commandText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isFocused)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Action button
            Button {
                withAnimation {
                    isPresented = false
                }
            } label: {
                Text("Dismiss")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .applyGlassTransition(type: transitionType, namespace: namespace)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
}

extension View {
    @ViewBuilder
    func applyGlassTransition(type: Int, namespace: Namespace.ID) -> some View {
        switch type {
        case 0:
            // Identity transition
            self.glassEffect(
                in: RoundedRectangle(cornerRadius: 24),
                transition: .identity
            )
        case 1:
            // Matched geometry transition
            self.glassEffect(
                in: RoundedRectangle(cornerRadius: 24),
                transition: .matchedGeometry,
                isSource: true
            )
            .matchedGeometryEffect(id: "glass", in: namespace)
        case 2:
            // Materialize transition
            self.glassEffect(
                in: RoundedRectangle(cornerRadius: 24),
                transition: .materialize
            )
        default:
            self.glassEffect(in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

#Preview {
    GlassTransitionTest()
}