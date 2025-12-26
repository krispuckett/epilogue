import SwiftUI
import Photos

/// Main editor view for creating and customizing quote cards
struct QuoteCardEditorView: View {
    let quoteData: QuoteCardData

    @Environment(\.dismiss) private var dismiss
    @State private var config = QuoteCardConfiguration.default
    @State private var extractedPalette: ColorPalette?
    @State private var isExporting = false
    @State private var showFormatPicker = false
    @State private var showCustomizationSheet = false
    @State private var exportError: String?
    @State private var showExportSuccess = false
    @State private var selectedSection: CustomizationSection = .template

    private enum CustomizationSection: String, CaseIterable {
        case template = "Template"
        case style = "Style"
        case elements = "Elements"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Preview area
                    previewSection
                        .padding(.top, 8)

                    // Customization controls
                    customizationPanel
                }
            }
            .navigationTitle("Create Quote Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    exportButton
                }
            }
            .task {
                await extractBookColors()
            }
            .sheet(isPresented: $showFormatPicker) {
                formatPickerSheet
            }
            .alert("Export Failed", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                if let error = exportError {
                    Text(error)
                }
            }
            .overlay {
                if showExportSuccess {
                    exportSuccessOverlay
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.black)
    }

    // MARK: - Preview Section
    private var previewSection: some View {
        GeometryReader { geo in
            let previewSize = calculatePreviewSize(in: geo.size)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    Spacer()
                        .frame(width: 20)

                    // Live preview card
                    cardPreview(size: previewSize)
                        .id("preview-\(config.template)-\(config.format)")

                    Spacer()
                        .frame(width: 20)
                }
            }
            .frame(height: geo.size.height)
        }
        .frame(height: UIScreen.main.bounds.height * 0.45)
    }

    private func cardPreview(size: CGSize) -> some View {
        let updatedData = QuoteCardData(
            text: quoteData.text,
            author: quoteData.author,
            bookTitle: quoteData.bookTitle,
            pageNumber: quoteData.pageNumber,
            bookCoverImage: quoteData.bookCoverImage,
            bookPalette: extractedPalette ?? quoteData.bookPalette
        )

        return QuoteCardTemplateView(
            data: updatedData,
            config: config,
            renderSize: config.effectiveSize
        )
        .frame(width: config.effectiveSize.width, height: config.effectiveSize.height)
        .scaleEffect(size.width / config.effectiveSize.width)
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
        .animation(DesignSystem.Animation.springStandard, value: config.template)
        .animation(DesignSystem.Animation.springStandard, value: config.format)
    }

    private func calculatePreviewSize(in containerSize: CGSize) -> CGSize {
        let maxWidth = containerSize.width - 80
        let maxHeight = containerSize.height - 40
        let aspectRatio = config.effectiveSize.width / config.effectiveSize.height

        var width = maxWidth
        var height = width / aspectRatio

        if height > maxHeight {
            height = maxHeight
            width = height * aspectRatio
        }

        return CGSize(width: width, height: height)
    }

    // MARK: - Customization Panel
    private var customizationPanel: some View {
        VStack(spacing: 0) {
            // Format selector
            formatSelector
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Divider()
                .background(Color.white.opacity(0.1))

            // Section picker
            sectionPicker
                .padding(.top, 16)

            // Section content
            ScrollView(.horizontal, showsIndicators: false) {
                switch selectedSection {
                case .template:
                    templateCarousel
                case .style:
                    styleOptions
                case .elements:
                    elementToggles
                }
            }
            .frame(height: 130)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color(white: 0.08), Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Format Selector
    private var formatSelector: some View {
        HStack(spacing: 12) {
            ForEach(QuoteCardFormat.allCases.filter { $0 != .custom }) { format in
                formatButton(format)
            }

            // Custom size button
            Button {
                showFormatPicker = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.resize")
                        .font(.system(size: 18))
                    Text("Custom")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(config.format == .custom ? .white : .white.opacity(0.5))
                .frame(width: 70, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(config.format == .custom ? Color.white.opacity(0.15) : Color.clear)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(config.format == .custom ? .white.opacity(0.3) : .white.opacity(0.1), lineWidth: 1)
                }
            }
        }
    }

    private func formatButton(_ format: QuoteCardFormat) -> some View {
        Button {
            withAnimation(DesignSystem.Animation.springStandard) {
                config.format = format
            }
            SensoryFeedback.light()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: format.displayIcon)
                    .font(.system(size: 18))
                Text(format.rawValue.replacingOccurrences(of: "Instagram ", with: ""))
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(config.format == format ? .white : .white.opacity(0.5))
            .frame(width: 70, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(config.format == format ? Color.white.opacity(0.15) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(config.format == format ? .white.opacity(0.3) : .white.opacity(0.1), lineWidth: 1)
            }
        }
    }

    // MARK: - Section Picker
    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(CustomizationSection.allCases, id: \.rawValue) { section in
                Button {
                    withAnimation(DesignSystem.Animation.springQuick) {
                        selectedSection = section
                    }
                    SensoryFeedback.selection()
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: selectedSection == section ? .semibold : .medium))
                        .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedSection == section ? Color.white.opacity(0.1) : Color.clear)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Template Carousel
    private var templateCarousel: some View {
        HStack(spacing: 16) {
            Spacer()
                .frame(width: 12)

            ForEach(QuoteCardTemplate.allCases) { template in
                templateCard(template)
            }

            Spacer()
                .frame(width: 12)
        }
        .padding(.vertical, 12)
    }

    private func templateCard(_ template: QuoteCardTemplate) -> some View {
        Button {
            withAnimation(DesignSystem.Animation.springStandard) {
                config.template = template
                // Update font to match template default
                config.font = QuoteCardFont.fontsForTemplate(template).first ?? .georgia
            }
            SensoryFeedback.medium()
        } label: {
            VStack(spacing: 10) {
                // Template preview thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(templatePreviewBackground(template))

                    Image(systemName: template.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 70, height: 70)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            config.template == template ? .white.opacity(0.5) : .white.opacity(0.1),
                            lineWidth: config.template == template ? 2 : 1
                        )
                }

                Text(template.rawValue)
                    .font(.system(size: 12, weight: config.template == template ? .semibold : .regular))
                    .foregroundStyle(config.template == template ? .white : .white.opacity(0.6))
            }
        }
        .scaleEffect(config.template == template ? 1.05 : 1.0)
        .animation(DesignSystem.Animation.springBouncy, value: config.template)
    }

    private func templatePreviewBackground(_ template: QuoteCardTemplate) -> some ShapeStyle {
        switch template {
        case .minimal:
            return AnyShapeStyle(Color(white: 0.15))
        case .bookColor:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .paper:
            return AnyShapeStyle(Color(red: 0.9, green: 0.85, blue: 0.75))
        case .bold:
            return AnyShapeStyle(Color.black)
        }
    }

    // MARK: - Style Options
    private var styleOptions: some View {
        HStack(spacing: 20) {
            Spacer()
                .frame(width: 12)

            // Font picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Font")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Menu {
                    ForEach(QuoteCardFont.fontsForTemplate(config.template)) { font in
                        Button {
                            config.font = font
                            SensoryFeedback.light()
                        } label: {
                            HStack {
                                Text(font.displayName)
                                if config.font == font {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(config.font.displayName)
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )
                }
            }

            // Alignment picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Alignment")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 4) {
                    ForEach(QuoteCardAlignment.allCases) { alignment in
                        Button {
                            config.alignment = alignment
                            SensoryFeedback.light()
                        } label: {
                            Image(systemName: alignment.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(config.alignment == alignment ? .white : .white.opacity(0.4))
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(config.alignment == alignment ? Color.white.opacity(0.15) : Color.clear)
                                )
                        }
                    }
                }
            }

            // Color scheme (for applicable templates)
            if config.template == .minimal || config.template == .bold {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    HStack(spacing: 4) {
                        ForEach(QuoteCardColorScheme.allCases) { scheme in
                            Button {
                                config.colorScheme = scheme
                                SensoryFeedback.light()
                            } label: {
                                Image(systemName: scheme.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(config.colorScheme == scheme ? .white : .white.opacity(0.4))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(config.colorScheme == scheme ? Color.white.opacity(0.15) : Color.clear)
                                    )
                            }
                        }
                    }
                }
            }

            Spacer()
                .frame(width: 12)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Element Toggles
    private var elementToggles: some View {
        HStack(spacing: 16) {
            Spacer()
                .frame(width: 12)

            elementToggle("Author", isOn: $config.showAuthor, icon: "person")
            elementToggle("Book Title", isOn: $config.showBookTitle, icon: "book")
            elementToggle("Page #", isOn: $config.showPageNumber, icon: "number")
            elementToggle("Watermark", isOn: $config.showWatermark, icon: "seal")

            Spacer()
                .frame(width: 12)
        }
        .padding(.vertical, 16)
    }

    private func elementToggle(_ title: String, isOn: Binding<Bool>, icon: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            SensoryFeedback.light()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isOn.wrappedValue ? Color.white.opacity(0.15) : Color.clear)
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isOn.wrappedValue ? .white : .white.opacity(0.3))
                }
                .overlay {
                    Circle()
                        .strokeBorder(isOn.wrappedValue ? .white.opacity(0.3) : .white.opacity(0.1), lineWidth: 1)
                        .frame(width: 50, height: 50)
                }

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? .white : .white.opacity(0.4))
            }
        }
    }

    // MARK: - Export Button
    private var exportButton: some View {
        Button {
            exportQuoteCard()
        } label: {
            HStack(spacing: 6) {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("Export")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.15))
            )
        }
        .disabled(isExporting)
    }

    // MARK: - Format Picker Sheet
    private var formatPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preset formats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Presets")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(QuoteCardFormat.allCases) { format in
                            Button {
                                config.format = format
                                if format != .custom {
                                    showFormatPicker = false
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: format.displayIcon)
                                        .font(.system(size: 28))
                                    Text(format.rawValue)
                                        .font(.system(size: 13, weight: .medium))
                                    Text("\(Int(format.size.width))×\(Int(format.size.height))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(config.format == format ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(config.format == format ? .blue : .clear, lineWidth: 2)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Custom size controls
                if config.format == .custom {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Size")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Width")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                TextField("Width", value: $config.customWidth, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Height")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                TextField("Height", value: $config.customHeight, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Export Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showFormatPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Export Success Overlay
    private var exportSuccessOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Saved to Photos")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .transition(.scale.combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showExportSuccess = false
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func extractBookColors() async {
        guard let coverImage = quoteData.bookCoverImage else { return }

        let extractor = OKLABColorExtractor()
        if let palette = try? await extractor.extractPalette(from: coverImage, imageSource: "Quote Card") {
            await MainActor.run {
                extractedPalette = palette
            }
        }
    }

    private func exportQuoteCard() {
        isExporting = true
        SensoryFeedback.medium()

        Task { @MainActor in
            // Build the final data with palette
            let finalData = QuoteCardData(
                text: quoteData.text,
                author: quoteData.author,
                bookTitle: quoteData.bookTitle,
                pageNumber: quoteData.pageNumber,
                bookCoverImage: quoteData.bookCoverImage,
                bookPalette: extractedPalette ?? quoteData.bookPalette
            )

            // Create the full-size card view
            let cardView = QuoteCardTemplateView(
                data: finalData,
                config: config,
                renderSize: config.effectiveSize
            )

            // Render to image
            let image: UIImage
            if #available(iOS 16.0, *) {
                image = ImageRenderer.renderModern(
                    view: cardView,
                    size: config.effectiveSize,
                    scale: 3.0 // Retina quality
                )
            } else {
                image = ImageRenderer.render(
                    view: cardView,
                    size: config.effectiveSize
                )
            }

            // Show share sheet
            presentShareSheet(with: image)

            isExporting = false
        }
    }

    private func presentShareSheet(with image: UIImage) {
        let activityController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {

            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }

            activityController.completionWithItemsHandler = { activityType, completed, _, _ in
                if completed {
                    SensoryFeedback.success()
                    if activityType == .saveToCameraRoll {
                        withAnimation {
                            showExportSuccess = true
                        }
                    }
                }
            }

            // iPad popover configuration
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = topController.view
                popover.sourceRect = CGRect(
                    x: topController.view.bounds.midX,
                    y: topController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }

            topController.present(activityController, animated: true)
        }
    }
}

// MARK: - Preview
#Preview {
    QuoteCardEditorView(
        quoteData: QuoteCardData(
            text: "It is our choices, Harry, that show what we truly are, far more than our abilities.",
            author: "Albus Dumbledore",
            bookTitle: "Harry Potter and the Chamber of Secrets",
            pageNumber: 333
        )
    )
}
