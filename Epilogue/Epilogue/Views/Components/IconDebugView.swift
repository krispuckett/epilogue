import SwiftUI

struct IconDebugView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Icon Debug View")
                .font(.title)
            
            HStack(spacing: 30) {
                VStack {
                    Image("24-book-open")
                        .resizable()
                        .frame(width: 30, height: 30)
                    Text("Book Open")
                        .font(.caption)
                }
                
                VStack {
                    Image("24-feather")
                        .resizable()
                        .frame(width: 30, height: 30)
                    Text("Feather")
                        .font(.caption)
                }
                
                VStack {
                    Image("24-msgs")
                        .resizable()
                        .frame(width: 30, height: 30)
                    Text("Messages")
                        .font(.caption)
                }
            }
            
            Divider()
            
            Text("SF Symbol Fallbacks")
                .font(.headline)
            
            HStack(spacing: 30) {
                VStack {
                    Image(systemName: "book.fill")
                        .font(.title)
                    Text("book.fill")
                        .font(.caption)
                }
                
                VStack {
                    Image(systemName: "pencil")
                        .font(.title)
                    Text("pencil")
                        .font(.caption)
                }
                
                VStack {
                    Image(systemName: "message.fill")
                        .font(.title)
                    Text("message.fill")
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview {
    IconDebugView()
}