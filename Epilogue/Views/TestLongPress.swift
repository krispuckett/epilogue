import SwiftUI

struct TestLongPress: View {
    @State private var showingOptions = false
    @State private var showingEdit = false
    
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            VStack {
                Text("Test Card")
                    .foregroundStyle(.white)
                    .padding(40)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .onTapGesture {
                        print("Tap detected")
                        showingEdit = true
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        print("Long press detected")
                        showingOptions = true
                    }
                
                Text("Options: \(showingOptions ? "YES" : "NO")")
                    .foregroundStyle(.white)
                Text("Edit: \(showingEdit ? "YES" : "NO")")
                    .foregroundStyle(.white)
            }
        }
        .overlay {
            if showingOptions {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingOptions = false
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 0) {
                            Text("Options Menu")
                                .padding()
                            
                            Button("Edit") {
                                showingOptions = false
                                showingEdit = true
                            }
                            .padding()
                            
                            Button("Delete") {
                                showingOptions = false
                            }
                            .padding()
                        }
                        .foregroundStyle(.white)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                        .padding()
                    }
                }
            }
            
            if showingEdit && !showingOptions {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingEdit = false
                        }
                    
                    VStack {
                        Text("Edit Sheet")
                            .foregroundStyle(.white)
                            .padding(100)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
        }
    }
}

#Preview {
    TestLongPress()
}