import SwiftUI

struct QuoteHighlighterView: View {
    let image: UIImage?
    let extractedText: String
    let onSave: (String, Int?) -> Void
    
    @State private var selectedText = ""
    @State private var pageNumber: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Page image with extracted text overlay
                    if let image = image {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                    }
                    
                    // Extracted text (selectable)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("EXTRACTED TEXT")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .tracking(1.2)
                            
                            // Text editor for selecting/editing the quote
                            TextEditor(text: $selectedText)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                                .frame(minHeight: 100)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    
                    // Page number input
                    HStack {
                        Text("Page Number (optional)")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("", text: $pageNumber)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .textFieldStyle(.plain)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Highlight Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Quote") {
                        let pageNum = Int(pageNumber)
                        onSave(selectedText.isEmpty ? extractedText : selectedText, pageNum)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
        }
        .onAppear {
            // Pre-fill with extracted text
            selectedText = extractedText
        }
    }
}