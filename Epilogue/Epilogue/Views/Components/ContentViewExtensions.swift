import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "ContentViewExtensions")

// MARK: - Command Input Overlay

struct CommandInputOverlay: View {
    @ObservedObject var appStateCoordinator: AppStateCoordinator
    let libraryViewModel: LibraryViewModel
    let notesViewModel: NotesViewModel
    let modelContext: ModelContext
    @FocusState.Binding var isInputFocused: Bool

    // Determine the input context based on current state
    private func determineInputContext() -> InputContext {
        // Check if we're in book detail view and opening for notes
        if let currentBook = libraryViewModel.currentDetailBook,
           appStateCoordinator.isBookNoteContext {
            return .bookNote(book: currentBook)
        }
        // Default to quick actions
        return .quickActions
    }

    var body: some View {
        if appStateCoordinator.showingCommandInput {
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissCommandInput()
                    }

                VStack(spacing: 0) {
                    Spacer()

                    if appStateCoordinator.showingLibraryCommandPalette {
                        LibraryCommandPalette(
                            isPresented: $appStateCoordinator.showingLibraryCommandPalette,
                            commandText: $appStateCoordinator.commandText
                        )
                        .environmentObject(libraryViewModel)
                        .environmentObject(notesViewModel)
                        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                        .padding(.bottom, 16)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98, anchor: .bottom).combined(with: .opacity),
                            removal: .scale(scale: 0.98, anchor: .bottom).combined(with: .opacity)
                        ))
                        .zIndex(100)
                    }

                    UniversalInputBar(
                        messageText: $appStateCoordinator.commandText,
                        showingCommandPalette: .constant(false),
                        isInputFocused: $isInputFocused,
                        context: determineInputContext(),
                        onSend: {
                            processInlineCommand()
                        },
                        onMicrophoneTap: {
                            // Voice input handler
                        },
                        onCommandTap: {
                            SensoryFeedback.light()
                            withAnimation(DesignSystem.Animation.springStandard) {
                                appStateCoordinator.showingLibraryCommandPalette.toggle()
                            }
                        },
                        isRecording: .constant(false),
                        colorPalette: nil
                    )
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.bottom, 16)
                }
            }
            .interruptibleAnimation(.smooth, value: appStateCoordinator.showingLibraryCommandPalette)
            .onAppear {
                isInputFocused = true
            }
        }
    }

    private func dismissCommandInput() {
        isInputFocused = false
        appStateCoordinator.dismissCommandInput()
    }

    private func processInlineCommand() {
        let trimmedText = appStateCoordinator.commandText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else {
            dismissCommandInput()
            return
        }

        logger.debug("Processing command: '\(trimmedText)'")

        // Get current book context if we're viewing a book
        let currentBook = libraryViewModel.currentDetailBook

        // Enhance command with smart context detection
        let enhancedCommand = SmartNoteContextService.shared.enhanceCommand(
            trimmedText,
            library: libraryViewModel.books,
            currentBook: currentBook
        )

        let processor = CommandProcessingManager(
            modelContext: modelContext,
            libraryViewModel: libraryViewModel,
            notesViewModel: notesViewModel,
            bookContext: currentBook  // Pass the current book context
        )
        processor.processInlineCommand(enhancedCommand)

        SensoryFeedback.success()

        // Check if this is a book search command
        let intent = CommandParser.parse(trimmedText, books: libraryViewModel.books, notes: notesViewModel.notes)
        if case .searchLibrary = intent {
            appStateCoordinator.commandText = ""
            isInputFocused = false
        } else {
            dismissCommandInput()
        }
    }
}

// MARK: - View Extensions for Configuration

extension View {
    func setupAppearanceConfiguration() -> some View {
        self.onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    func setupSheetPresentations() -> some View {
        self
            .sheet(isPresented: .init(
                get: { AppStateCoordinator().showingPrivacySettings },
                set: { _ in }
            )) {
                NavigationStack {
                    PrivacySettingsView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    AppStateCoordinator().showingPrivacySettings = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: .init(
                get: { AppStateCoordinator().showingBookSearch },
                set: { _ in }
            )) {
                BookSearchSheet(
                    searchQuery: AppStateCoordinator().bookSearchQuery,
                    onBookSelected: { book in
                        // Handle book selection
                    }
                )
            }
            .sheet(isPresented: .init(
                get: { AppStateCoordinator().showingBatchBookSearch },
                set: { _ in }
            )) {
                BatchBookSearchSheet(
                    bookTitles: .init(
                        get: { AppStateCoordinator().batchBookTitles },
                        set: { AppStateCoordinator().batchBookTitles = $0 }
                    ),
                    onBookSelected: { book in
                        // Handle book selection
                    },
                    onComplete: {
                        // Handle completion
                    }
                )
            }
            .fullScreenCover(isPresented: .init(
                get: { AppStateCoordinator().showingBookScanner },
                set: { _ in }
            )) {
                BookScannerView()
            }
    }

    func setupAmbientMode(libraryViewModel: LibraryViewModel, notesViewModel: NotesViewModel) -> some View {
        self.fullScreenCover(isPresented: .init(
            get: { EpilogueAmbientCoordinator.shared.isActive },
            set: { _ in }
        )) {
            AmbientModeView()
                .environmentObject(libraryViewModel)
                .environmentObject(notesViewModel)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .interactiveDismissDisabled()
                .onAppear {
                    logger.info("Ambient mode launched")
                }
        }
    }
}

// MARK: - Toast Extensions

extension View {
    func glassToast(isShowing: Binding<Bool>, message: String) -> some View {
        self.modifier(GlassToastModifier(
            isShowing: isShowing,
            message: message
        ))
    }
}

struct GlassToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isShowing {
                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        .padding(.vertical, 12)
                        .glassEffect()
                        .clipShape(Capsule())
                        .padding(.top, 50)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isShowing = false
                                }
                            }
                        }
                }
            }
    }
}