import Foundation
import AVFoundation
import UniformTypeIdentifiers
import Combine

struct LocalSound: Identifiable, Hashable {
    let id: String
    let title: String
    let fileURL: URL
}

/// Local-only audio clips. Files are copied to the app's sandbox.
@MainActor
final class SoundboardManager: ObservableObject {
    @Published private(set) var clips: [LocalSound] = []
    @Published private(set) var playingID: String?
    @Published var volume: Double = 85 { didSet { player?.volume = Float(volume / 100) } }
    @Published var errorText: String?
    private var player: AVAudioPlayer?
    private let folder: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = docs.appendingPathComponent("LainCord-Soundboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder,
                       includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        clips = urls.filter { ["mp3", "wav", "m4a", "aac", "caf", "aiff", "ogg"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { LocalSound(id: $0.lastPathComponent, title: $0.deletingPathExtension().lastPathComponent, fileURL: $0) }
    }

    func importFiles(_ urls: [URL]) {
        errorText = nil
        for original in urls {
            let scoped = original.startAccessingSecurityScopedResource()
            defer { if scoped { original.stopAccessingSecurityScopedResource() } }
            let safeName = original.lastPathComponent.replacingOccurrences(of: "/", with: "_")
            let destination = folder.appendingPathComponent(String(UUID().uuidString.prefix(6)) + "_" + safeName)
            do { try FileManager.default.copyItem(at: original, to: destination) }
            catch { errorText = "Un fichier n'a pas pu être importé : \(error.localizedDescription)" }
        }
        reload()
    }

    func toggle(_ clip: LocalSound) {
        if playingID == clip.id { stop(); return }
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: clip.fileURL)
            player?.volume = Float(volume / 100)
            player?.prepareToPlay()
            if player?.play() == true { playingID = clip.id }
            else { errorText = "Lecture impossible pour ce fichier." }
        } catch { errorText = "Fichier audio illisible : \(error.localizedDescription)" }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    func delete(_ clip: LocalSound) {
        if playingID == clip.id { stop() }
        do { try FileManager.default.removeItem(at: clip.fileURL); reload() }
        catch { errorText = "Suppression impossible : \(error.localizedDescription)" }
    }
}
