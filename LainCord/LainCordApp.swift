import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@main
struct LainCordApp: App {
    var body: some Scene {
        WindowGroup {
            LainHome().preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class LocalVoiceStudio: ObservableObject {
    @Published private(set) var active = false
    @Published var message: String?
    @Published var muted = false { didSet { apply() } }
    @Published var gain: Double = 0 { didSet { apply() } }
    @Published var bass: Double = 0 { didSet { apply() } }
    @Published var presence: Double = 0 { didSet { apply() } }
    @Published var echo: Double = 0 { didSet { apply() } }
    @Published var reverbAmount: Double = 0 { didSet { apply() } }
    @Published var output: Double = 80 { didSet { apply() } }
    private let engine = AVAudioEngine()
    private let eq = AVAudioUnitEQ(numberOfBands: 2)
    private let delay = AVAudioUnitDelay()
    private let reverb = AVAudioUnitReverb()
    private var connected = false

    init() {
        eq.bands[0].filterType = .lowShelf
        eq.bands[0].frequency = 150
        eq.bands[0].bypass = false
        eq.bands[1].filterType = .parametric
        eq.bands[1].frequency = 3_000
        eq.bands[1].bandwidth = 1.0
        eq.bands[1].bypass = false
        delay.delayTime = 0.3
        delay.feedback = 13
        reverb.loadFactoryPreset(.mediumRoom)
        apply()
    }

    func preset(_ name: String) {
        switch name {
        case "Clarté": bass = -1; presence = 5; echo = 0; reverbAmount = 0
        case "Grave": bass = 7; presence = -3; echo = 0; reverbAmount = 0
        case "Écho": bass = 0; presence = 0; echo = 45; reverbAmount = 0
        case "Salle": bass = 0; presence = 1; echo = 0; reverbAmount = 35
        default: bass = 0; presence = 0; echo = 0; reverbAmount = 0
        }
    }

    private func apply() {
        eq.globalGain = Float(gain)
        eq.bands[0].gain = Float(bass)
        eq.bands[1].gain = Float(presence)
        delay.wetDryMix = Float(echo)
        reverb.wetDryMix = Float(reverbAmount)
        engine.mainMixerNode.outputVolume = muted ? 0 : Float(output / 100)
    }

    func toggle() {
        if active {
            engine.stop()
            try? AVAudioSession.sharedInstance().setActive(false)
            active = false
            return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] permitted in
            Task { @MainActor in
                guard let self else { return }
                if permitted { self.start() }
                else { self.message = "Autorise l’accès au micro dans Réglages > LainCord." }
            }
        }
    }

    private func start() {
        do {
            message = nil
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            if !connected {
                engine.attach(eq)
                engine.attach(delay)
                engine.attach(reverb)
                let format = engine.inputNode.outputFormat(forBus: 0)
                engine.connect(engine.inputNode, to: eq, format: format)
                engine.connect(eq, to: delay, format: format)
                engine.connect(delay, to: reverb, format: format)
                engine.connect(reverb, to: engine.mainMixerNode, format: format)
                connected = true
            }
            apply()
            try engine.start()
            active = true
        } catch {
            message = "Erreur microphone : \(error.localizedDescription)"
            engine.stop()
            active = false
        }
    }
}

struct SavedClip: Identifiable {
    let id: URL
    var name: String { id.deletingPathExtension().lastPathComponent }
}

@MainActor
final class LocalSoundboard: ObservableObject {
    @Published var clips: [SavedClip] = []
    @Published var playing: URL?
    @Published var message: String?
    private var player: AVAudioPlayer?
    private let directory: URL

    init() {
        directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LainCord Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        refresh()
    }

    func refresh() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        clips = urls.filter { ["mp3", "m4a", "wav", "aiff", "caf", "aac"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }.map { SavedClip(id: $0) }
    }

    func importFiles(_ urls: [URL]) {
        for source in urls {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let destination = directory.appendingPathComponent(UUID().uuidString.prefix(5) + "-" + source.lastPathComponent)
            do { try FileManager.default.copyItem(at: source, to: destination) }
            catch { message = "Import impossible : \(error.localizedDescription)" }
        }
        refresh()
    }

    func play(_ clip: SavedClip) {
        if playing == clip.id { stop(); return }
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: clip.id)
            player?.prepareToPlay()
            if player?.play() == true { playing = clip.id }
        } catch { message = "Lecture impossible : \(error.localizedDescription)" }
    }

    func stop() {
        player?.stop()
        player = nil
        playing = nil
    }

    func delete(_ clip: SavedClip) {
        if playing == clip.id { stop() }
        try? FileManager.default.removeItem(at: clip.id)
        refresh()
    }
}

private enum Theme {
    static let background = Color(red: 0.054, green: 0.059, blue: 0.078)
    static let surface = Color(red: 0.12, green: 0.13, blue: 0.17)
    static let accent = Color(red: 0.58, green: 0.64, blue: 1)
    static let muted = Color(red: 0.66, green: 0.69, blue: 0.75)
}

struct LainHome: View {
    @StateObject private var studio = LocalVoiceStudio()
    @StateObject private var sounds = LocalSoundboard()
    @State private var importing = false

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header("Studio vocal · local")
                        panel {
                            Label(studio.active ? "Microphone activé" : "Microphone désactivé",
                                  systemImage: studio.active ? "waveform.circle.fill" : "mic.slash")
                                .font(.headline)
                            Text("Écoute locale avec effets. Utilise un casque pour éviter les retours audio.")
                                .font(.footnote).foregroundStyle(Theme.muted)
                            Button(studio.active ? "Arrêter l’écoute" : "Activer l’écoute") { studio.toggle() }
                                .buttonStyle(.borderedProminent).tint(Theme.accent)
                            if let message = studio.message {
                                Text(message).font(.footnote).foregroundStyle(.orange)
                            }
                        }
                        Text("PRESETS").font(.caption.bold()).foregroundStyle(Theme.muted)
                        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                            ForEach(["Naturel", "Clarté", "Grave", "Écho", "Salle"], id: \.self) { name in
                                Button(name) { studio.preset(name) }
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13))
                            }
                        }
                        panel {
                            Text("Égaliseur et effets").font(.headline)
                            control("Gain micro", $studio.gain, -12...20, "dB")
                            control("Graves", $studio.bass, -12...12, "dB")
                            control("Présence", $studio.presence, -12...12, "dB")
                            control("Écho", $studio.echo, 0...100, "%")
                            control("Réverbération", $studio.reverbAmount, 0...100, "%")
                            control("Volume sortie", $studio.output, 0...100, "%")
                            Toggle("Couper le son", isOn: $studio.muted).tint(Theme.accent)
                        }
                    }.padding(18)
                }
                .background(Theme.background.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
            }.tabItem { Label("Studio", systemImage: "slider.horizontal.3") }

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header("Soundboard local")
                        panel {
                            Text("Importe tes fichiers MP3, WAV ou M4A depuis l’iPhone.")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                            Button {
                                importing = true
                            } label: {
                                Label("Ajouter un son", systemImage: "plus.circle.fill")
                            }.buttonStyle(.borderedProminent).tint(Theme.accent)
                            if let message = sounds.message {
                                Text(message).foregroundStyle(.orange).font(.footnote)
                            }
                        }
                        if sounds.clips.isEmpty {
                            panel { Text("Aucun son importé pour le moment.").foregroundStyle(Theme.muted) }
                        }
                        ForEach(sounds.clips) { clip in
                            panel {
                                HStack(spacing: 12) {
                                    Button {
                                        sounds.play(clip)
                                    } label: {
                                        Image(systemName: sounds.playing == clip.id ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.title2)
                                    }
                                    Text(clip.name).lineLimit(2)
                                    Spacer()
                                    Button(role: .destructive) { sounds.delete(clip) } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                    }.padding(18)
                }
                .background(Theme.background.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
                .fileImporter(isPresented: $importing, allowedContentTypes: [.audio],
                              allowsMultipleSelection: true) { result in
                    switch result {
                    case .success(let urls): sounds.importFiles(urls)
                    case .failure(let error): sounds.message = error.localizedDescription
                    }
                }
            }.tabItem { Label("Sons", systemImage: "music.note.list") }

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header("À propos")
                        panel {
                            Text("LainCord").font(.title2.bold())
                            Text("Version iPhone — studio audio local").foregroundStyle(Theme.muted)
                            Text("Cette version ne se connecte pas à Discord, ne lit pas les messages et n’envoie pas de son dans les salons vocaux. Aucune connexion par token de compte n’est utilisée.")
                                .font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }.padding(18)
                }.background(Theme.background.ignoresSafeArea())
            }.tabItem { Label("Infos", systemImage: "info.circle") }
        }
        .tint(Theme.accent)
    }

    private func header(_ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("LainCord").font(.system(size: 36, weight: .bold, design: .rounded))
            Text(subtitle).foregroundStyle(Theme.muted)
        }.padding(.vertical, 12)
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func control(_ name: String, _ value: Binding<Double>,
                         _ range: ClosedRange<Double>, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name).font(.subheadline)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)").font(.caption).foregroundStyle(Theme.muted)
            }
            Slider(value: value, in: range).tint(Theme.accent)
        }
    }
}
