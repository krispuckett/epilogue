import SwiftUI

struct ChatInputBar: View {
    let onStartGeneralChat: () -> Void
    let onSelectBook: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Question icon
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
            
            // Tappable input area
            Button {
                onStartGeneralChat()
            } label: {
                HStack {
                    Text("Ask your books anything...")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            
            // Book selector button
            Button {
                onSelectBook()
            } label: {
                Image(systemName: "book.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56) // Consistent height with ThreadInputField
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}