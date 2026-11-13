import Foundation
import AVFoundation
import Combine

/// Local microphone monitoring and voice processing. It does not connect to Discord.
enum VoicePreset: String, CaseIterable, Identifiable {
    case natural = "Naturel"
    case clear = "Clarté HD"
    case deep = "Voix grave"
    case radio = "Radio"
    case echo = "Écho"
    case room = "Réverbération"
    case lofi = "Lo-Fi"

    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .natural: "Aucun effet"
        case .clear: "Présence et brillance"
        case .deep: "Timbre plus bas"
        case .radio: "Bande étroite"
        case .echo: "Retard audible"
        case .room: "Ambiance de pièce"
        case .lofi: "Son vintage"
        }
    }
    var symbol: String {
        switch self {
        case .natural: "waveform"
        case .clear: "sparkles"
        case .deep: "waveform.path"
        case .radio: "antenna.radiowaves.left.and.right"
        case .echo: "repeat"
        case .room: "square.3.layers.3d"
        case .lofi: "dot.radiowaves.left.and.right"
        }
    }
}

@MainActor
final class AudioStudioEngine: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var errorText: String?
    @Published var preset: VoicePreset = .natural { didSet { applyPreset() } }
    @Published var gainDB: Double = 0 { didSet { applyParameters() } }
    @Published var outputVolume: Double = 75 { didSet { applyParameters() } }
    @Published var isMuted = false { didSet { applyParameters() } }
    @Published var bassDB: Double = 0 { didSet { applyParameters() } }
    @Published var presenceDB: Double = 0 { didSet { applyParameters() } }
    @Published var airDB: Double = 0 { didSet { applyParameters() } }
    @Published var reverbPercent: Double = 0 { didSet { applyParameters() } }
    @Published var echoPercent: Double = 0 { didSet { applyParameters() } }

    private let engine = AVAudioEngine()
    private let micMixer = AVAudioMixerNode()
    private let equalizer = AVAudioUnitEQ(numberOfBands: 5)
    private let distortion = AVAudioUnitDistortion()
    private let delay = AVAudioUnitDelay()
    private let reverb = AVAudioUnitReverb()
    private let pitch = AVAudioUnitTimePitch()
    private var graphConfigured = false

    init() {
        equalizer.bands[0].filterType = .lowShelf
        equalizer.bands[0].frequency = 160
        equalizer.bands[1].filterType = .parametric
        equalizer.bands[1].frequency = 3_000
        equalizer.bands[1].bandwidth = 1.2
        equalizer.bands[2].filterType = .highShelf
        equalizer.bands[2].frequency = 8_500
        equalizer.bands[3].filterType = .highPass
        equalizer.bands[3].frequency = 80
        equalizer.bands[4].filterType = .lowPass
        equalizer.bands[4].frequency = 17_000
        for band in equalizer.bands { band.bypass = true }
        distortion.loadFactoryPreset(.speechRadioTower)
        reverb.loadFactoryPreset(.mediumRoom)
        delay.feedback = 12
        delay.delayTime = 0.27
        pitch.rate = 1
        applyPreset()
    }

    func toggleMonitoring() {
        if isRunning { stop(); return }
        // Ask before touching the microphone. No token or account credentials are read.
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted { self.start() }
                else { self.errorText = "Autorise le microphone dans Réglages > LainCord." }
            }
        }
    }

    private func configureGraph() {
        guard !graphConfigured else { return }
        engine.attach(micMixer)
        engine.attach(equalizer)
        engine.attach(distortion)
        engine.attach(delay)
        engine.attach(reverb)
        engine.attach(pitch)
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        engine.connect(input, to: micMixer, format: inputFormat)
        engine.connect(micMixer, to: equalizer, format: inputFormat)
        engine.connect(equalizer, to: distortion, format: inputFormat)
        engine.connect(distortion, to: delay, format: inputFormat)
        engine.connect(delay, to: reverb, format: inputFormat)
        engine.connect(reverb, to: pitch, format: inputFormat)
        engine.connect(pitch, to: engine.mainMixerNode, format: inputFormat)
        graphConfigured = true
        applyParameters()
    }

    private func start() {
        do {
            errorText = nil
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            configureGraph()
            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
            errorText = "Impossible d'activer le micro : \(error.localizedDescription)"
            engine.stop()
        }
    }

    func stop() {
        engine.stop()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func resetEqualizer() {
        bassDB = 0
        presenceDB = 0
        airDB = 0
    }

    private func applyPreset() {
        // Presets modify real AVAudioUnit effects; no remote service is involved.
        distortion.wetDryMix = 0
        pitch.pitch = 0
        equalizer.bands[3].bypass = true
        equalizer.bands[4].bypass = true
        switch preset {
        case .natural:
            bassDB = 0; presenceDB = 0; airDB = 0; reverbPercent = 0; echoPercent = 0
        case .clear:
            bassDB = 2; presenceDB = 4; airDB = 3; reverbPercent = 0; echoPercent = 0
        case .deep:
            bassDB = 5; presenceDB = -1; airDB = -2; reverbPercent = 0; echoPercent = 0
            pitch.pitch = -320
        case .radio:
            bassDB = -8; presenceDB = 5; airDB = -8; reverbPercent = 0; echoPercent = 0
            equalizer.bands[3].frequency = 340
            equalizer.bands[4].frequency = 3_400
            equalizer.bands[3].bypass = false
            equalizer.bands[4].bypass = false
            distortion.wetDryMix = 12
        case .echo:
            bassDB = 0; presenceDB = 0; airDB = 0; reverbPercent = 0; echoPercent = 38
        case .room:
            bassDB = 0; presenceDB = 1; airDB = 0; reverbPercent = 35; echoPercent = 0
        case .lofi:
            bassDB = 3; presenceDB = -2; airDB = -7; reverbPercent = 8; echoPercent = 0
            equalizer.bands[4].frequency = 5_000
            equalizer.bands[4].bypass = false
            distortion.wetDryMix = 8
        }
        applyParameters()
    }

    private func applyParameters() {
        micMixer.outputVolume = isMuted ? 0 : 1
        equalizer.globalGain = Float(gainDB)
        engine.mainMixerNode.outputVolume = Float(outputVolume / 100)
        for i in 0..<3 { equalizer.bands[i].bypass = false }
        equalizer.bands[0].gain = Float(bassDB)
        equalizer.bands[1].gain = Float(presenceDB)
        equalizer.bands[2].gain = Float(airDB)
        delay.wetDryMix = Float(echoPercent)
        reverb.wetDryMix = Float(reverbPercent)
    }
}
