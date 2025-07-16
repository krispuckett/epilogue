import SwiftUI

struct TestGlassOptionsMenu: View {
    @State private var showingMenu = false
    @StateObject private var notesViewModel = NotesViewModel()
    
    let testNote = Note(
        type: .quote,
        content: "Test quote content",
        author: "Test Author",
        bookTitle: "Test Book",
        pageNumber: 123,
        bookId: nil
    )
    
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            VStack {
                Button("Show Glass Options Menu") {
                    showingMenu = true
                }
                .foregroundStyle(.white)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
            }
        }
        .overlay {
            if showingMenu {
                GlassOptionsMenu(
                    note: testNote,
                    isPresented: $showingMenu,
                    showingEditSheet: .constant(false)
                )
                .environmentObject(notesViewModel)
            }
        }
    }
}

#Preview {
    TestGlassOptionsMenu()
}