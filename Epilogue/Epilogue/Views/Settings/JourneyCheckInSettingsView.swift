import SwiftUI

/// Settings UI for reading journey check-ins
struct JourneyCheckInSettingsView: View {
    @ObservedObject private var checkInManager = JourneyCheckInManager.shared

    @State private var showingPermissionAlert = false
    @State private var hasRequestedPermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enable/disable toggle
            Toggle(isOn: $checkInManager.checkInsEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check-in Reminders")
                        .foregroundStyle(.primary)

                    Text("Gentle nudges to reflect on your reading")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(ThemeManager.shared.currentTheme.primaryAccent)
            .onChange(of: checkInManager.checkInsEnabled) { _, newValue in
                if newValue && !hasRequestedPermission {
                    requestNotificationPermission()
                }
            }

            if checkInManager.checkInsEnabled {
                Divider()
                    .padding(.vertical, 4)

                // Frequency picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Frequency")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Check-in Frequency", selection: $checkInManager.checkInFrequency) {
                        ForEach(JourneyCheckInManager.CheckInFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName)
                                .tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()
                    .padding(.vertical, 4)

                // Preferred time picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferred Time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "Check-in Time",
                        selection: $checkInManager.preferredCheckInTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            // Check if we already have permission
            Task {
                hasRequestedPermission = await checkInManager.checkNotificationPermission()
            }
        }
        .alert("Enable Notifications", isPresented: $showingPermissionAlert) {
            Button("Not Now", role: .cancel) {
                checkInManager.checkInsEnabled = false
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Epilogue needs permission to send you gentle check-in reminders. You can enable this in Settings.")
        }
    }

    private func requestNotificationPermission() {
        Task {
            let granted = await checkInManager.requestNotificationPermission()
            if !granted {
                await MainActor.run {
                    showingPermissionAlert = true
                }
            }
            hasRequestedPermission = true
        }
    }
}

#Preview {
    Form {
        Section {
            JourneyCheckInSettingsView()
        } header: {
            Text("Reading Journey")
        }
    }
    .formStyle(.grouped)
}
