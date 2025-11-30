//
//  AmbientPresenceStatesExperiment.swift
//  Epilogue
//
//  Developer experiment for tuning ambient presence states
//

import SwiftUI

// MARK: - Presence State Definition
enum AmbientPresenceState: String, CaseIterable {
    case listening = "Listening"
    case thinking = "Thinking"
    case responding = "Responding"
    case resting = "Resting"
    case contemplative = "Contemplative"

    var description: String {
        switch self {
        case .listening: return "Ready to receive input"
        case .thinking: return "Processing your question"
        case .responding: return "AI is speaking"
        case .resting: return "Idle, not recording"
        case .contemplative: return "Long silence, deep reading"
        }
    }

    // Default parameters for each state
    var defaultBreathingCycle: Double {
        switch self {
        case .listening: return 2.5
        case .thinking: return 4.0
        case .responding: return 1.8
        case .resting: return 6.0
        case .contemplative: return 10.0
        }
    }

    var defaultPulseIntensity: Double {
        switch self {
        case .listening: return 0.6
        case .thinking: return 0.8
        case .responding: return 0.9
        case .resting: return 0.3
        case .contemplative: return 0.15
        }
    }

    var defaultColorSaturation: Double {
        switch self {
        case .listening: return 1.0
        case .thinking: return 0.7  // Cooler tones
        case .responding: return 1.2  // Warmer, more inviting
        case .resting: return 0.5  // Desaturated
        case .contemplative: return 0.3  // Nearly grayscale
        }
    }

    var defaultGlassIntensity: Double {
        switch self {
        case .listening: return 1.0
        case .thinking: return 0.9
        case .responding: return 1.0
        case .resting: return 0.6
        case .contemplative: return 0.4
        }
    }
}

// MARK: - Main Experiment View
struct AmbientPresenceStatesExperiment: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedState: AmbientPresenceState = .listening

    // Tunable parameters
    @State private var breathingCycle: Double = 2.5
    @State private var pulseIntensity: Double = 0.6
    @State private var colorSaturation: Double = 1.0
    @State private var glassIntensity: Double = 1.0

    // Animation state
    @State private var breathingPhase: Double = 0
    @State private var isAutoPlaying = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // MARK: - State Preview
                    statePreviewSection

                    Divider()

                    // MARK: - State Selector
                    stateSelectorSection

                    Divider()

                    // MARK: - Parameter Controls
                    parameterControlsSection

                    Divider()

                    // MARK: - Transition Testing
                    transitionTestingSection
                }
                .padding(24)
            }
            .background(Color.black)
            .navigationTitle("Ambient Presence States")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .onChange(of: selectedState) { _, newState in
            loadStateDefaults(newState)
        }
        .onAppear {
            startBreathingAnimation()
        }
    }

    // MARK: - State Preview Section
    private var statePreviewSection: some View {
        VStack(spacing: 16) {
            Text("Current State Preview")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            // Orb preview with current parameters
            ZStack {
                // Background for contrast
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 300)

                // Simulated orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.549, blue: 0.259)
                                    .opacity(pulseIntensity * breathingEffect),
                                Color(red: 1.0, green: 0.549, blue: 0.259)
                                    .opacity(pulseIntensity * 0.3 * breathingEffect)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: orbSize, height: orbSize)
                    .saturation(colorSaturation)
                    .blur(radius: 20)
                    .overlay {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: orbSize * 0.6, height: orbSize * 0.6)
                    }
                    .glassEffect(.regular, in: Circle())
                    .opacity(glassIntensity)
            }

            // State info
            VStack(spacing: 8) {
                Text(selectedState.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(selectedState.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - State Selector Section
    private var stateSelectorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select State")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AmbientPresenceState.allCases, id: \.self) { state in
                        Button {
                            selectedState = state
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(selectedState == state ?
                                          Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.3) :
                                          Color.white.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                    .overlay {
                                        Text("\(Int(state.defaultBreathingCycle))s")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.white)
                                    }

                                Text(state.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Parameter Controls Section
    private var parameterControlsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Adjust Parameters")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            // Breathing Cycle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Breathing Cycle")
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("\(breathingCycle, specifier: "%.1f")s")
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                        .fontWeight(.medium)
                }

                Slider(value: $breathingCycle, in: 0.5...15.0, step: 0.1)
                    .tint(Color(red: 1.0, green: 0.549, blue: 0.259))

                Text("Duration of one breathing cycle (inhale + exhale)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Pulse Intensity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pulse Intensity")
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("\(Int(pulseIntensity * 100))%")
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                        .fontWeight(.medium)
                }

                Slider(value: $pulseIntensity, in: 0.0...1.0, step: 0.05)
                    .tint(Color(red: 1.0, green: 0.549, blue: 0.259))

                Text("Brightness variation during breathing")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Color Saturation
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Color Saturation")
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("\(Int(colorSaturation * 100))%")
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                        .fontWeight(.medium)
                }

                Slider(value: $colorSaturation, in: 0.0...1.5, step: 0.05)
                    .tint(Color(red: 1.0, green: 0.549, blue: 0.259))

                Text("Color vibrancy (>1.0 for warmer, <1.0 for cooler)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Glass Intensity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Glass Intensity")
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("\(Int(glassIntensity * 100))%")
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                        .fontWeight(.medium)
                }

                Slider(value: $glassIntensity, in: 0.0...1.0, step: 0.05)
                    .tint(Color(red: 1.0, green: 0.549, blue: 0.259))

                Text("Liquid glass effect prominence")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Reset button
            Button {
                loadStateDefaults(selectedState)
            } label: {
                Text("Reset to Defaults")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Transition Testing Section
    private var transitionTestingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test State Transitions")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            Text("Quickly cycle through states to test transitions")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 12) {
                Button {
                    cycleToNextState()
                } label: {
                    Text("Next State")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.2))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button {
                    startAutoTransitions()
                } label: {
                    Text(isAutoPlaying ? "Stop Auto" : "Auto Play")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Computed Properties
    private var orbSize: CGFloat {
        let baseSize: CGFloat = 120
        let breathingVariation = sin(breathingPhase * .pi * 2) * 10
        return baseSize + breathingVariation
    }

    private var breathingEffect: Double {
        // Sine wave for breathing effect (0.0 to 1.0)
        return (sin(breathingPhase * .pi * 2) + 1) / 2
    }

    // MARK: - Helper Methods
    private func loadStateDefaults(_ state: AmbientPresenceState) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            breathingCycle = state.defaultBreathingCycle
            pulseIntensity = state.defaultPulseIntensity
            colorSaturation = state.defaultColorSaturation
            glassIntensity = state.defaultGlassIntensity
        }
    }

    private func startBreathingAnimation() {
        withAnimation(.linear(duration: breathingCycle).repeatForever(autoreverses: false)) {
            breathingPhase = 1.0
        }
    }

    private func cycleToNextState() {
        let allStates = AmbientPresenceState.allCases
        if let currentIndex = allStates.firstIndex(of: selectedState) {
            let nextIndex = (currentIndex + 1) % allStates.count
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedState = allStates[nextIndex]
            }
        }
    }

    private func startAutoTransitions() {
        isAutoPlaying.toggle()

        if isAutoPlaying {
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
                if !isAutoPlaying {
                    timer.invalidate()
                    return
                }
                cycleToNextState()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AmbientPresenceStatesExperiment()
}
