import SwiftUI

/// Bottom-sheet control panel for real-time parametric tweaking
/// of the Fluid Ambient Gradient. Inspired by Josh Puckett's Dial Kit.
struct FluidGradientControlPanel: View {
    @Binding var config: FluidAmbientConfig
    @Binding var colorSet: FluidLabColorSet
    @Binding var isPresented: Bool
    let availableColors: [PaletteColorOption]
    var onReExtract: (() -> Void)?

    // MARK: - Sheet State

    /// Height of collapsed state (handle + title bar only)
    private let collapsedHeight: CGFloat = 56
    /// Maximum expanded height as fraction of screen — half screen for live gradient preview
    private let maxExpandedFraction: CGFloat = 0.52

    @State private var sheetOffset: CGFloat = 0
    @State private var isExpanded = true  // Auto-expand on show
    @State private var selectedRole: ColorRole?
    @State private var showExportCopied = false

    private var expandedHeight: CGFloat {
        UIScreen.main.bounds.height * maxExpandedFraction
    }

    private var currentHeight: CGFloat {
        isExpanded ? expandedHeight : collapsedHeight
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Drag handle + title — only THIS area responds to sheet drag
                    VStack(spacing: 0) {
                        dragHandle
                        titleBar
                    }
                    .contentShape(Rectangle())
                    .gesture(sheetDragGesture)

                    if isExpanded {
                        Divider()
                            .background(.white.opacity(0.1))

                        scrollContent
                    }
                }
                .frame(height: max(collapsedHeight, currentHeight + sheetOffset))
                .frame(maxWidth: .infinity)
                .glassEffect(
                    .regular.tint(.black.opacity(0.5)),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        topTrailingRadius: 20,
                        style: .continuous
                    )
                )
                .shadow(color: .black.opacity(0.5), radius: 24, y: -4)
            }
        }
        .ignoresSafeArea(.all)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 10) {
            // Close button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.1), in: Circle())
            }

            Spacer()

            Text("Fluid Lab")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            HStack(spacing: 12) {
                // Export
                Button {
                    UIPasteboard.general.string = config.exportString
                    showExportCopied = true
                    SensoryFeedback.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showExportCopied = false
                    }
                } label: {
                    Image(systemName: showExportCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(showExportCopied ? .green : .white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.1), in: Circle())
                }

                // Reset to golden
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        config = .golden
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.1), in: Circle())
                }

                // Expand/collapse
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.1), in: Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, isExpanded ? 8 : 10)
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                colorPicker

                paramSection("Color") {
                    paramSlider("Intensity", value: $config.colorIntensity, range: 0.1...1.0)
                    paramSlider("Accent", value: $config.accentInfluence, range: 0.0...0.8)
                    paramSlider("Secondary", value: $config.secondarySpread, range: 0.0...0.8)
                    paramSlider("Temperature", value: $config.colorTemperature, range: -0.5...0.5)
                }

                paramSection("Noise") {
                    paramSlider("Amplitude", value: $config.noiseAmplitude, range: 0.0...0.25)
                    paramSlider("Scale", value: $config.noiseScale, range: 1.0...5.0)
                    paramSlider("Warp", value: $config.warpIntensity, range: 0.2...3.0)
                    paramSlider("Swirl", value: $config.swirlAmount, range: 0.0...2.0)
                }

                paramSection("Origin") {
                    paramSlider("X", value: $config.originX, range: 0.0...1.0)
                    paramSlider("Y", value: $config.originY, range: 0.0...1.0)
                }

                paramSection("Color Mix") {
                    paramSlider("Background", value: $config.backgroundBlend, range: 0.0...0.6)
                    paramSlider("Complement", value: $config.complementaryMix, range: 0.0...0.5)
                }

                paramSection("Ripple") {
                    paramSlider("Intensity", value: $config.rippleIntensity, range: 0.0...0.3)
                    paramSlider("Frequency", value: $config.rippleFrequency, range: 5.0...40.0)
                    paramSlider("Speed", value: $config.rippleSpeed, range: 0.5...8.0)
                }

                paramSection("Fade") {
                    paramSlider("Dark Start", value: $config.darkFadeStart, range: 0.1...0.6)
                    paramSlider("Vignette", value: $config.vignetteStrength, range: 0.0...1.0)
                    paramSlider("Exponent", value: $config.fadeExponent, range: 0.5...3.0)
                }

                paramSection("Post Processing") {
                    paramSlider("Contrast", value: $config.contrast, range: 0.5...2.0)
                    paramSlider("Saturation", value: $config.saturationBoost, range: 0.5...2.0)
                    paramSlider("Grain", value: $config.grainAmount, range: 0.0...0.08)
                    paramSlider("Bloom", value: $config.bloomStrength, range: 0.0...0.4)
                    paramSlider("Brightness", value: $config.brightnessBoost, range: 0.5...2.0)
                }

                paramSection("Motion") {
                    paramSlider("Speed", value: $config.animationSpeed, range: 0.0...3.0)
                }

                presetButtons
                reExtractButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Sheet Drag Gesture

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // Negative translation = dragging up (expand)
                // Positive translation = dragging down (collapse/dismiss)
                let translation = value.translation.height

                if isExpanded {
                    // When expanded, only allow dragging down (positive)
                    sheetOffset = min(0, translation)
                } else {
                    // When collapsed, allow dragging up (negative) to expand
                    sheetOffset = max(-(expandedHeight - collapsedHeight), min(0, translation))
                }
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let translation = value.translation.height

                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    sheetOffset = 0

                    if isExpanded {
                        // If dragged down significantly or with velocity, collapse
                        if translation > 100 || velocity > 300 {
                            if translation > 250 || velocity > 600 {
                                // Dismiss entirely
                                isPresented = false
                            } else {
                                isExpanded = false
                            }
                        }
                    } else {
                        // If dragged up significantly or with velocity, expand
                        if translation < -50 || velocity < -200 {
                            isExpanded = true
                        } else if translation > 80 || velocity > 400 {
                            // Dragged down while collapsed = dismiss
                            isPresented = false
                        }
                    }
                }
            }
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PALETTE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1.5)
                .padding(.top, 12)

            // Role assignment row
            HStack(spacing: 8) {
                ForEach(ColorRole.allCases) { role in
                    roleButton(role)
                }
            }

            // Available colors grid + custom picker
            if let role = selectedRole {
                availableColorsGrid

                HStack(spacing: 10) {
                    Text("Custom")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))

                    ColorPicker("", selection: roleBinding(role), supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(0.85)
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func roleButton(_ role: ColorRole) -> some View {
        let isSelected = selectedRole == role
        let currentColor = roleColor(role)

        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedRole = selectedRole == role ? nil : role
            }
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(currentColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .strokeBorder(.white, lineWidth: isSelected ? 2 : 0.5)
                            .opacity(isSelected ? 1.0 : 0.3)
                    )

                Text(role.shortLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(isSelected ? 0.9 : 0.4))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var availableColorsGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
            spacing: 6
        ) {
            ForEach(availableColors) { option in
                Button {
                    assignColor(option.color)
                } label: {
                    VStack(spacing: 3) {
                        Circle()
                            .fill(option.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                            )

                        Text(option.name.prefix(5))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func roleColor(_ role: ColorRole) -> Color {
        switch role {
        case .primary: colorSet.primary
        case .secondary: colorSet.secondary
        case .accent: colorSet.accent
        case .background: colorSet.background
        case .complementary: colorSet.complementary
        }
    }

    private func roleBinding(_ role: ColorRole) -> Binding<Color> {
        switch role {
        case .primary: $colorSet.primary
        case .secondary: $colorSet.secondary
        case .accent: $colorSet.accent
        case .background: $colorSet.background
        case .complementary: $colorSet.complementary
        }
    }

    private func assignColor(_ color: Color) {
        guard let role = selectedRole else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            switch role {
            case .primary: colorSet.primary = color
            case .secondary: colorSet.secondary = color
            case .accent: colorSet.accent = color
            case .background: colorSet.background = color
            case .complementary: colorSet.complementary = color
            }
        }
    }

    // MARK: - Section & Slider (Orb Lab pattern)

    private func paramSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1.5)
                .padding(.top, 12)
                .padding(.bottom, 2)

            content()
        }
    }

    private func paramSlider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 100, alignment: .leading)

            Slider(value: value, in: range)
                .tint(.white.opacity(0.4))

            Text(String(format: "%.3f", value.wrappedValue))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 50, alignment: .trailing)
        }
        .frame(height: 28)
    }

    // MARK: - Presets

    private var presetButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRESETS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1.5)
                .padding(.top, 12)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 8
            ) {
                presetButton("Golden") {
                    config = FluidAmbientConfig.golden
                }
                presetButton("Vibrant") { config = FluidAmbientConfig(for: .vibrant) }
                presetButton("Dark") { config = FluidAmbientConfig(for: .dark) }
                presetButton("Muted") { config = FluidAmbientConfig(for: .muted) }
                presetButton("Subtle") {
                    config.colorIntensity = 0.35
                    config.noiseAmplitude = 0.03
                    config.warpIntensity = 0.5
                    config.animationSpeed = 0.3
                    config.vignetteStrength = 0.1
                    config.grainAmount = 0.015
                    config.contrast = 0.9
                }
                presetButton("Nebula") {
                    config.colorIntensity = 0.80
                    config.noiseAmplitude = 0.20
                    config.warpIntensity = 2.5
                    config.accentInfluence = 0.5
                    config.complementaryMix = 0.25
                    config.backgroundBlend = 0.3
                    config.vignetteStrength = 0.6
                    config.contrast = 1.3
                    config.saturationBoost = 1.4
                    config.originY = 0.3
                    config.animationSpeed = 0.6
                }
                presetButton("Ripple") {
                    config.rippleIntensity = 0.15
                    config.rippleFrequency = 18.0
                    config.rippleSpeed = 2.5
                    config.warpIntensity = 1.5
                    config.noiseAmplitude = 0.12
                    config.animationSpeed = 1.2
                }
                presetButton("Ink") {
                    config.colorIntensity = 0.50
                    config.noiseAmplitude = 0.08
                    config.warpIntensity = 1.8
                    config.accentInfluence = 0.15
                    config.complementaryMix = 0.0
                    config.backgroundBlend = 0.35
                    config.vignetteStrength = 0.5
                    config.contrast = 1.4
                    config.saturationBoost = 0.7
                    config.darkFadeStart = 0.20
                    config.animationSpeed = 0.4
                }
                presetButton("Ocean") {
                    config.colorIntensity = 0.70
                    config.noiseAmplitude = 0.15
                    config.warpIntensity = 1.8
                    config.rippleIntensity = 0.20
                    config.rippleFrequency = 12.0
                    config.rippleSpeed = 1.8
                    config.secondarySpread = 0.5
                    config.complementaryMix = 0.10
                    config.vignetteStrength = 0.35
                    config.animationSpeed = 0.8
                }
            }
        }
    }

    @ViewBuilder
    private func presetButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                action()
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Re-extract

    private var reExtractButton: some View {
        Group {
            if let reExtract = onReExtract {
                paramSection("Actions") {
                    Button {
                        reExtract()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.trianglehead.2.clockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("Re-extract Colors")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

// MARK: - Color Role

enum ColorRole: String, CaseIterable, Identifiable {
    case primary, secondary, accent, background, complementary

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .primary: "PRI"
        case .secondary: "SEC"
        case .accent: "ACC"
        case .background: "BG"
        case .complementary: "CMP"
        }
    }
}
