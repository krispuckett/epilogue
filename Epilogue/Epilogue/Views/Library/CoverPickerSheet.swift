import SwiftUI
import PhotosUI

/// Sheet for selecting a custom book cover
/// Allows choosing from photo library, camera, or reverting to API cover
struct CoverPickerSheet: View {
    let book: BookModel
    @Binding var isPresented: Bool
    let onCoverChanged: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // Current cover preview
                Section {
                    HStack {
                        Spacer()
                        currentCoverPreview
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Cover selection options
                Section {
                    // Photo Library
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }

                    // Camera
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                } header: {
                    Text("Select New Cover")
                }

                // Revert option (only if custom cover is set and API cover exists)
                if book.isCustomCover && book.coverImageURL != nil {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                isProcessing = true
                                await book.revertToAPICover()
                                isProcessing = false
                                onCoverChanged()
                                isPresented = false
                            }
                        } label: {
                            Label("Revert to Original Cover", systemImage: "arrow.uturn.backward")
                        }
                    } footer: {
                        Text("Restore the cover from the book's online listing.")
                    }
                }

                // Error message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Change Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .overlay {
                if isProcessing {
                    processingOverlay
                }
            }
            .onChange(of: selectedItem) { oldItem, newItem in
                guard let item = newItem else { return }
                processSelectedPhoto(item)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView { image in
                    if let image = image {
                        Task {
                            await processImage(image)
                        }
                    }
                    showingCamera = false
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var currentCoverPreview: some View {
        VStack(spacing: 8) {
            if let data = book.coverImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4)
            } else if book.coverImageURL != nil {
                // Cover image (cached for offline)
                SharedBookCoverView(
                    coverURL: book.coverImageURL,
                    width: 107,
                    height: 160
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
            } else {
                placeholderCover
            }

            if book.isCustomCover {
                Text("Custom Cover")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 107, height: 160)
            .overlay {
                Image(systemName: "book.closed")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Processing cover...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Photo Processing

    private func processSelectedPhoto(_ item: PhotosPickerItem) {
        isProcessing = true
        errorMessage = nil

        Task {
            defer {
                isProcessing = false
                selectedItem = nil
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    errorMessage = "Failed to load image"
                    return
                }

                await processImage(image)
            } catch {
                errorMessage = "Failed to load image: \(error.localizedDescription)"
            }
        }
    }

    private func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        await book.setCustomCover(image)

        isProcessing = false
        onCoverChanged()
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isPresented = true

    Color.clear
        .sheet(isPresented: $isPresented) {
            CoverPickerSheet(
                book: BookModel(
                    id: "test",
                    title: "The Great Gatsby",
                    author: "F. Scott Fitzgerald"
                ),
                isPresented: $isPresented,
                onCoverChanged: {}
            )
        }
}
