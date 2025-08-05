import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.bottom, 8)
            
            // Title
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.9))
            
            // Message
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            // Optional button
            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(buttonTitle)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Specific Empty States

extension EmptyStateView {
    static var noNotes: EmptyStateView {
        EmptyStateView(
            icon: "note.text",
            title: "No Notes Yet",
            message: "Start capturing your thoughts, quotes, and questions from your reading journey."
        )
    }
    
    static var noBooks: EmptyStateView {
        EmptyStateView(
            icon: "books.vertical",
            title: "Your Library is Empty",
            message: "Add your first book to start tracking your reading journey.",
            buttonTitle: "Add Book",
            buttonAction: {
                // This will be connected to the actual add book action
            }
        )
    }
    
    static var noSearchResults: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results Found",
            message: "Try adjusting your search terms or filters."
        )
    }
}

// MARK: - Preview
#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            EmptyStateView.noNotes
        }
    }
}
#endif