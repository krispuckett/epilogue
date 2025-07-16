import SwiftUI

// Simple test to verify the glass menu works as expected
struct SimpleGlassMenu: View {
    @State private var showingOptions = false
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            // Note card simulation
            VStack(alignment: .leading, spacing: 12) {
                Text("Test Quote")
                    .font(.custom("Georgia", size: 24))
                    .foregroundStyle(.black)
                
                Text("AUTHOR NAME")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.8))
            }
            .padding(32)
            .background(Color(red: 0.98, green: 0.97, blue: 0.96))
            .cornerRadius(12)
            .onLongPressGesture(minimumDuration: 0.5) {
                print("Long press detected!")
                showingOptions = true
            }
        }
        .overlay(alignment: .bottom) {
            if showingOptions {
                // Glass menu
                ZStack {
                    // Backdrop
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingOptions = false
                        }
                    
                    // Menu container
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 0) {
                            // Drag indicator
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 36, height: 5)
                                .padding(.vertical, 16)
                            
                            // Menu items
                            VStack(spacing: 1) {
                                MenuRow(title: "Share as Image", icon: "square.and.arrow.up") {
                                    print("Share tapped")
                                    showingOptions = false
                                }
                                
                                MenuRow(title: "Copy Quote", icon: "doc.on.doc") {
                                    print("Copy tapped")
                                    showingOptions = false
                                }
                                
                                MenuRow(title: "Edit", icon: "pencil") {
                                    print("Edit tapped")
                                    showingOptions = false
                                }
                                
                                MenuRow(title: "Delete", icon: "trash", isDestructive: true) {
                                    print("Delete tapped")
                                    showingOptions = false
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingOptions)
    }
}

struct MenuRow: View {
    let title: String
    let icon: String
    var isDestructive = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.5)
            }
            .foregroundStyle(isDestructive ? Color.red : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.001))
        }
    }
}

#Preview {
    SimpleGlassMenu()
}