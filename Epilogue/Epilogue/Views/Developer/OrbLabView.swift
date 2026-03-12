import SwiftUI
import CoreMotion
import AVFoundation

/// Developer tool for live-tweaking ambient orb shader parameters.
/// Gated behind gandalfMode. Shows a large orb preview with all params adjustable,
/// including gyroscope parallax, audio reactivity, depth layers, and palette editing.
struct OrbLabView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config = OrbShaderConfig.golden
    @State private var isPressed = false
    @State private var showExportCopied = false

    // Sensor toggles
    @State private var gyroEnabled = false
    @State private var audioEnabled = false

    // Sensor managers
    @State private var motionManager = CMMotionManager()
    @State private var audioEngine = AVAudioEngine()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                orbPreview
                parameterList
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            stopGyro()
            stopAudio()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.1), in: Circle())
            }

            Spacer()

            Text("Orb Lab")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            HStack(spacing: 12) {
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Orb Preview

    private var orbPreview: some View {
        MetalShaderView(
            isPressed: $isPressed,
            size: CGSize(width: 200, height: 200),
            config: config,
            iterations: 36
        )
        .frame(width: 200, height: 200)
        .clipShape(Circle())
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPressed = false
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Parameters

    private var parameterList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                motionSection
                turbulenceSection
                bloomSection
                paletteSection
                toneSection
                maskSection
                pressSection
                secondaryColorSection
                parallaxSection
                audioSection
                depthLayerSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Sections

    private var motionSection: some View {
        paramSection("Motion") {
            paramSlider("Speed", value: $config.speed, range: 0.1...6.0)
            paramSlider("Rotation Base", value: $config.rotationBase, range: 0.0...1.0)
            paramSlider("Rotation Speed", value: $config.rotationSpeed, range: 0.0...0.3)
        }
    }

    private var turbulenceSection: some View {
        paramSection("Turbulence") {
            paramSlider("Amplitude", value: $config.turbAmplitude, range: 0.0...1.0)
            paramSlider("Freq Mix", value: $config.freqMix, range: 0.0...1.0)
            paramSlider("Circle Size", value: $config.circleSize, range: 0.01...0.5)
            paramSlider("Smoothing", value: $config.smoothing, range: 0.1...4.0)
        }
    }

    private var bloomSection: some View {
        paramSection("Bloom") {
            paramSlider("Intensity", value: $config.bloomIntensity, range: 0.0...2.0)
            paramSlider("Mix", value: $config.bloomMix, range: 0.0...10.0)
            paramSlider("Clamp", value: $config.bloomClamp, range: 10.0...500.0)
        }
    }

    private var paletteSection: some View {
        paramSection("Palette (cosine)") {
            paramSlider("Sweep", value: $config.paletteSweep, range: 0.0...1.0)
            paramSlider("Color Tint", value: $config.colorTint, range: 0.5...3.0)
            // a vector
            sectionLabel("a (base)")
            paramSlider("a.R", value: $config.palAR, range: 0.0...1.0)
            paramSlider("a.G", value: $config.palAG, range: 0.0...1.0)
            paramSlider("a.B", value: $config.palAB, range: 0.0...1.0)
            // b vector
            sectionLabel("b (amplitude)")
            paramSlider("b.R", value: $config.palBR, range: 0.0...1.0)
            paramSlider("b.G", value: $config.palBG, range: 0.0...1.0)
            paramSlider("b.B", value: $config.palBB, range: 0.0...1.0)
            // c vector
            sectionLabel("c (frequency)")
            paramSlider("c.R", value: $config.palCR, range: 0.0...3.0)
            paramSlider("c.G", value: $config.palCG, range: 0.0...3.0)
            paramSlider("c.B", value: $config.palCB, range: 0.0...3.0)
            // d vector
            sectionLabel("d (phase)")
            paramSlider("d.R", value: $config.palDR, range: 0.0...1.0)
            paramSlider("d.G", value: $config.palDG, range: 0.0...1.0)
            paramSlider("d.B", value: $config.palDB, range: 0.0...1.0)
        }
    }

    private var toneSection: some View {
        paramSection("Tone & Output") {
            paramSlider("Brightness", value: $config.brightness, range: 0.2...3.0)
            paramSlider("Tonemap Gain", value: $config.tonemapGain, range: 0.5...10.0)
        }
    }

    private var maskSection: some View {
        paramSection("Circle Mask") {
            paramSlider("Inner Edge", value: $config.maskInner, range: 0.0...0.5)
            paramSlider("Outer Edge", value: $config.maskOuter, range: 0.3...0.8)
        }
    }

    private var pressSection: some View {
        paramSection("Press") {
            paramSlider("Boost", value: $config.pressBoost, range: 1.0...2.0)
            paramSlider("Smoothing", value: $config.pressSmoothing, range: 0.01...0.5)
        }
    }

    private var secondaryColorSection: some View {
        paramSection("Secondary Color") {
            paramSlider("Blend", value: $config.secondaryBlend, range: 0.0...1.0)
            paramSlider("R", value: $config.secondaryR, range: 0.0...1.0)
            paramSlider("G", value: $config.secondaryG, range: 0.0...1.0)
            paramSlider("B", value: $config.secondaryB, range: 0.0...1.0)
        }
    }

    private var parallaxSection: some View {
        paramSection("Parallax (Gyroscope)") {
            HStack {
                Text("Gyro Input")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Toggle("", isOn: $gyroEnabled)
                    .labelsHidden()
                    .tint(.cyan)
                    .onChange(of: gyroEnabled) { _, on in
                        if on { startGyro() } else { stopGyro() }
                    }
            }
            .frame(height: 28)

            paramSlider("Amount", value: $config.parallaxAmount, range: 0.0...0.15)

            if !gyroEnabled {
                paramSlider("Manual X", value: $config.parallaxX, range: -1.0...1.0)
                paramSlider("Manual Y", value: $config.parallaxY, range: -1.0...1.0)
            } else {
                readout("Tilt X", value: config.parallaxX)
                readout("Tilt Y", value: config.parallaxY)
            }
        }
    }

    private var audioSection: some View {
        paramSection("Audio Reactivity") {
            HStack {
                Text("Mic Input")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Toggle("", isOn: $audioEnabled)
                    .labelsHidden()
                    .tint(.orange)
                    .onChange(of: audioEnabled) { _, on in
                        if on { startAudio() } else { stopAudio() }
                    }
            }
            .frame(height: 28)

            paramSlider("Reactivity", value: $config.audioReactivity, range: 0.0...2.0)

            if !audioEnabled {
                paramSlider("Manual Level", value: $config.audioLevel, range: 0.0...1.0)
            } else {
                readout("Level", value: config.audioLevel)
            }
        }
    }

    private var depthLayerSection: some View {
        paramSection("Depth Layer") {
            paramSlider("Scale", value: $config.depthLayerScale, range: 0.0...3.0)
            paramSlider("Blend", value: $config.depthLayerBlend, range: 0.0...1.0)
            paramSlider("Speed", value: $config.depthLayerSpeed, range: 0.1...3.0)
        }
    }

    // MARK: - Gyroscope

    private func startGyro() {
        guard motionManager.isDeviceMotionAvailable else { return }
        config.parallaxAmount = max(config.parallaxAmount, 0.05)
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let attitude = motion?.attitude else { return }
            config.parallaxX = Float(attitude.roll).clamped(to: -1.0...1.0)
            config.parallaxY = Float(attitude.pitch).clamped(to: -1.0...1.0)
        }
    }

    private func stopGyro() {
        motionManager.stopDeviceMotionUpdates()
        config.parallaxX = 0
        config.parallaxY = 0
    }

    // MARK: - Audio

    private func startAudio() {
        config.audioReactivity = max(config.audioReactivity, 0.5)

        let inputNode = audioEngine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        // Guard: simulator or devices with no mic return 0 channels / 0 sample rate
        guard hwFormat.channelCount > 0, hwFormat.sampleRate > 0 else {
            #if DEBUG
            print("Audio input unavailable (no mic on simulator?)")
            #endif
            audioEnabled = false
            return
        }

        // Use a standard mono format to avoid format mismatches
        guard let tapFormat = AVAudioFormat(standardFormatWithSampleRate: hwFormat.sampleRate,
                                            channels: 1) else {
            audioEnabled = false
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)

            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            let normalized = Swift.min(rms * 10.0, 1.0)

            DispatchQueue.main.async {
                self.config.audioLevel = normalized
            }
        }

        do {
            try audioEngine.start()
        } catch {
            #if DEBUG
            print("Audio engine failed to start: \(error)")
            #endif
            audioEnabled = false
        }
    }

    private func stopAudio() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        config.audioLevel = 0
    }

    // MARK: - UI Helpers

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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.25))
            .padding(.top, 4)
    }

    private func paramSlider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 110, alignment: .leading)

            Slider(value: value, in: range)
                .tint(.white.opacity(0.4))

            Text(String(format: "%.3f", value.wrappedValue))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 50, alignment: .trailing)
        }
        .frame(height: 28)
    }

    private func readout(_ label: String, value: Float) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 110, alignment: .leading)

            // Simple bar visualization
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(.cyan.opacity(0.5))
                        .frame(width: geo.size.width * CGFloat((value + 1.0) / 2.0).clamped(to: 0...1))
                }
            }
            .frame(height: 6)

            Text(String(format: "%.3f", value))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.6))
                .frame(width: 50, alignment: .trailing)
        }
        .frame(height: 28)
    }
}

// MARK: - Float clamping

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
