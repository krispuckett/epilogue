import SwiftUI

// MARK: - Preview & Demo
struct iOS26SwipeActionsPreview: View {
    @State private var items = [
        DemoItem(title: "Call Mom", subtitle: "12/31/00", icon: "phone.fill"),
        DemoItem(title: "Meeting Notes", subtitle: "Yesterday", icon: "doc.text.fill"),
        DemoItem(title: "Grocery List", subtitle: "2 days ago", icon: "cart.fill")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        DemoItemRow(item: item)
                            .iOS26SwipeActions([
                                SwipeAction(
                                    icon: "bell.slash.fill",
                                    backgroundColor: Color(red: 0.5, green: 0.5, blue: 1.0),
                                    handler: {
                                        print("Muted: \(item.title)")
                                    }
                                ),
                                SwipeAction(
                                    icon: "trash.fill",
                                    backgroundColor: Color(red: 1.0, green: 0.3, blue: 0.3),
                                    isDestructive: true,
                                    handler: {
                                        withAnimation {
                                            items.removeAll { $0.id == item.id }
                                        }
                                    }
                                )
                            ])
                    }
                }
                .padding()
            }
            .navigationTitle("iOS 26 Swipe Actions")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(UIColor.systemBackground))
        }
        .preferredColorScheme(.dark)
    }
}

struct DemoItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
}

struct DemoItemRow: View {
    let item: DemoItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: item.icon)
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                .frame(width: 40, height: 40)
                .glassEffect(.regular, in: Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                
                Text(item.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

#Preview("iOS 26 Swipe Actions") {
    iOS26SwipeActionsPreview()
}