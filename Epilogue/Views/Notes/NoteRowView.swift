import SwiftUI
import SwiftData

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            Text(note.content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                if let pageRef = note.pageReference {
                    Label("Page \(pageRef)", systemImage: "book.pages")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let chapterRef = note.chapterReference {
                    Text("• \(chapterRef)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(note.dateModified, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(note.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            if let attachments = note.attachmentData, !attachments.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "paperclip")
                        .font(.caption)
                    Text("\(attachments.count) attachment\(attachments.count == 1 ? "" : "s")")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}