import SwiftUI

// MARK: - Display Name Setup View
/// Prompts user to set their display name for social features.
/// Can be shown inline or as a sheet.

struct DisplayNameSetupView: View {
    let onComplete: (String) -> Void

    @State private var displayName: String = ""
    @FocusState private var isFocused: Bool

    @AppStorage("userDisplayName") private var savedDisplayName: String = ""

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "person.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            // Text
            VStack(spacing: 8) {
                Text("What should we call you?")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("This name will be shown to friends you read with.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Input
            TextField("Your name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit {
                    saveName()
                }
                .padding(.horizontal)

            // Save button
            Button {
                saveName()
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(displayName.isEmpty ? Color.secondary : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(displayName.isEmpty)
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            if !savedDisplayName.isEmpty {
                displayName = savedDisplayName
            }
            isFocused = true
        }
    }

    private func saveName() {
        guard !displayName.isEmpty else { return }
        savedDisplayName = displayName
        onComplete(displayName)
    }
}

// MARK: - Display Name Setup Sheet

struct DisplayNameSetupSheet: View {
    let onComplete: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            DisplayNameSetupView(onComplete: onComplete)
                .navigationTitle("Set Your Name")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onDismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Display Name Prompt Banner
/// A subtle banner that prompts user to set their name

struct DisplayNamePromptBanner: View {
    let onSetup: () -> Void

    @AppStorage("userDisplayName") private var savedDisplayName: String = ""
    @AppStorage("hasDeclinedNameSetup") private var hasDeclined: Bool = false

    var body: some View {
        if savedDisplayName.isEmpty && !hasDeclined {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set up sharing")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Add your name to share with friends")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Set up") {
                    onSetup()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    hasDeclined = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Preview

#Preview {
    DisplayNameSetupView(onComplete: { name in
        print("Name set: \(name)")
    })
}

#Preview("Banner") {
    VStack {
        DisplayNamePromptBanner(onSetup: {})
    }
    .padding()
}
