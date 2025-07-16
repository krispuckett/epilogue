import SwiftUI

struct TestGlassMenu: View {
    @State private var showingMenu = false
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            VStack {
                Text("Long press to test glass menu")
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .onLongPressGesture {
                        print("Long press detected")
                        showingMenu = true
                    }
            }
        }
        .overlay {
            if showingMenu {
                // Test glass menu
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingMenu = false
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 1) {
                            Button("Option 1") {
                                print("Option 1 tapped")
                                showingMenu = false
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            
                            Button("Option 2") {
                                print("Option 2 tapped")
                                showingMenu = false
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        .foregroundStyle(.white)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                        .padding()
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(), value: showingMenu)
    }
}

#Preview {
    TestGlassMenu()
}