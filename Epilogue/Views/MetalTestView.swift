import SwiftUI

struct MetalTestView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Metal background
                MetalLiteraryView()
                    .ignoresSafeArea()
                
                // Test overlay
                VStack {
                    Text("Metal Particle System Test")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                    
                    Spacer()
                    
                    Text("5000 GPU particles with physics")
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                }
                .padding()
            }
            .navigationTitle("Metal Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MetalTestView()
}