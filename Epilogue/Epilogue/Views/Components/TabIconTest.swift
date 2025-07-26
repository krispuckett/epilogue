import SwiftUI

struct TabIconTest: View {
    var body: some View {
        VStack(spacing: 40) {
            Text("Tab Icon Test")
                .font(.title)
            
            VStack(spacing: 20) {
                Text("Glass Icons:")
                HStack(spacing: 30) {
                    VStack {
                        Image("glass-book-open")
                            .resizable()
                            .frame(width: 30, height: 30)
                        Text("glass-book-open")
                            .font(.caption)
                    }
                    
                    VStack {
                        Image("glass-feather")
                            .resizable()
                            .frame(width: 30, height: 30)
                        Text("glass-feather")
                            .font(.caption)
                    }
                    
                    VStack {
                        Image("glass-msgs")
                            .resizable()
                            .frame(width: 30, height: 30)
                        Text("glass-msgs")
                            .font(.caption)
                    }
                }
            }
            
            Divider()
            
            VStack(spacing: 20) {
                Text("Simple Icons:")
                HStack(spacing: 30) {
                    VStack {
                        Image("simple-book")
                            .resizable()
                            .frame(width: 30, height: 30)
                        Text("simple-book")
                            .font(.caption)
                    }
                    
                    VStack {
                        Image("simple-feather")
                            .resizable()
                            .frame(width: 30, height: 30)
                        Text("simple-feather")
                            .font(.caption)
                    }
                    
                    VStack {
                        Image("simple-chat")
                            .resizable()
                            .frame(width: 30, height: 30)
                        Text("simple-chat")
                            .font(.caption)
                    }
                }
            }
            
            Divider()
            
            VStack(spacing: 20) {
                Text("Using UIImage:")
                HStack(spacing: 30) {
                    if let uiImage = UIImage(named: "glass-book-open") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 30, height: 30)
                    } else {
                        Text("Not found")
                            .foregroundColor(.red)
                    }
                    
                    if let uiImage = UIImage(named: "glass-feather") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 30, height: 30)
                    } else {
                        Text("Not found")
                            .foregroundColor(.red)
                    }
                    
                    if let uiImage = UIImage(named: "glass-msgs") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 30, height: 30)
                    } else {
                        Text("Not found")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    TabIconTest()
}