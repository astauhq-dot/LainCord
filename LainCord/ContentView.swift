import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum Palette {
    static let background = Color(red: 0.055, green: 0.062, blue: 0.083)
    static let panel = Color(red: 0.10, green: 0.11, blue: 0.145)
    static let border = Color.white.opacity(0.085)
    static let muted = Color(red: 0.63, green: 0.66, blue: 0.73)
    static let accent = Color(red: 0.61, green: 0.68, blue: 1.0)
    static let green = Color(red: 0.36, green: 0.85, blue: 0.64)
}

struct ContentView: View {
    @EnvironmentObject private var audio: AudioStudioEngine
    @StateObject private var soundboard = SoundboardManager()

    var body: some View {
        TabView {
            NavigationStack { DiscordPage() }
                .tabItem { Label("Discord", systemImage: "bubble.left.and.bubble.right") }
            NavigationStack { HomePage() }
                .tabItem { Label("Accueil", systemImage: "house") }
            NavigationStack { StudioPage() }
                .tabItem { Label("Studio", systemImage: "slider.horizontal.3") }
            NavigationStack { SoundboardPage(manager: soundboard) }
                .tabItem { Label("Soundboard", systemImage: "square.grid.2x2") }
            NavigationStack { SettingsPage() }
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
        .tint(Palette.accent)
        .toolbarBackground(Palette.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

private struct LainCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.border, lineWidth: 1))
    }
}

private struct BrandHeader: View {
    let subtitle: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(Palette.accent)
                Image(systemName: "waveform").font(.title2.weight(.bold)).foregroundStyle(Palette.background)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("LainCord").font(.system(size: 28, weight: .bold, design: .rounded))
                Text(subtitle).font(.caption).foregroundStyle(Palette.muted)
            }
            Spacer()
        }
    }
}

private struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(Palette.muted)
            .padding(.top, 8)
    }
}

private struct HomePage: View {
    @EnvironmentObject private var audio: AudioStudioEngine
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BrandHeader(subtitle: "Studio audio mobile · iOS")
                    .padding(.top, 16)
                LainCard {
                    HStack(spacing: 12) {
                        Image(systemName: audio.isRunning ? "waveform.circle.fill" : "mic.slash.circle")
                            .font(.system(size: 32)).foregroundStyle(audio.isRunning ? Palette.green : Palette.muted)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Monitoring micro").font(.headline)
                            Text(audio.isRunning ? "Actif sur cet iPhone" : "Inactif")
                                .font(.subheadline).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Circle().fill(audio.isRunning ? Palette.green : Palette.muted)
                            .frame(width: 9, height: 9)
                    }
                    Text("Les effets sont traités localement sur ton appareil. Utilise un casque pour éviter les retours audio.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                        .padding(.top, 9)
                }
                SectionTitle(text: "Presets rapides")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(VoicePreset.allCases) { preset in
                        Button {
                            audio.preset = preset
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: preset.symbol).font(.title2).foregroundStyle(Palette.accent)
                                Text(preset.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text(preset.subtitle).font(.caption).foregroundStyle(Palette.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                            .padding(15)
                            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 17))
                            .overlay(RoundedRectangle(cornerRadius: 17)
                                .stroke(audio.preset == preset ? Palette.accent : Palette.border,
                                        lineWidth: audio.preset == preset ? 1.6 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                SectionTitle(text: "Connexion Discord")
                LainCard {
                    Label("Ouvre l’onglet Discord", systemImage: "bubble.left.and.bubble.right")
                        .font(.subheadline.weight(.semibold))
                    Text("Connecte ton compte avec la connexion classique ou ton token. Les appels web sont expérimentaux sur iPhone ; les effets du Studio restent locaux.")
                        .font(.footnote).foregroundStyle(Palette.muted).padding(.top, 3)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 30)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

private struct StudioPage: View {
    @EnvironmentObject private var audio: AudioStudioEngine
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BrandHeader(subtitle: "Traitement de la voix")
                    .padding(.top, 15)
                LainCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Écoute locale").font(.headline)
                            Text(audio.isRunning ? "Micro activé" : "Micro désactivé")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Image(systemName: audio.isRunning ? "waveform" : "mic.slash")
                            .foregroundStyle(audio.isRunning ? Palette.green : Palette.muted)
                            .font(.title2)
                    }
                    HStack(spacing: 10) {
                        Button(action: audio.toggleMonitoring) {
                            Label(audio.isRunning ? "Arrêter" : "Activer le micro",
                                  systemImage: audio.isRunning ? "stop.fill" : "mic.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accent)
                        Button { audio.isMuted.toggle() } label: {
                            Image(systemName: audio.isMuted ? "mic.slash.fill" : "mic.fill")
                                .frame(width: 48, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!audio.isRunning)
                    }
                    .padding(.top, 9)
                    Text("Branche un casque avant d'activer l'écoute pour éviter le larsen.")
                        .font(.caption).foregroundStyle(Palette.muted)
                    if let error = audio.errorText {
                        Text(error).font(.footnote).foregroundStyle(.orange)
                    }
                }
                SectionTitle(text: "Presets")
                LainCard {
                    Picker("Preset", selection: $audio.preset) {
                        ForEach(VoicePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }.pickerStyle(.menu).tint(Palette.accent)
                }
                SectionTitle(text: "Niveaux")
                LainCard {
                    StudioSlider(label: "Gain micro", value: $audio.gainDB, range: -12...24,
                                 unit: " dB", step: 1)
                    StudioSlider(label: "Volume sortie", value: $audio.outputVolume,
                                 range: 0...100, unit: "%", step: 1)
                }
                SectionTitle(text: "Égaliseur 3 bandes")
                LainCard {
                    StudioSlider(label: "Graves · 160 Hz", value: $audio.bassDB,
                                 range: -12...12, unit: " dB", step: 0.5)
                    StudioSlider(label: "Présence · 3 kHz", value: $audio.presenceDB,
                                 range: -12...12, unit: " dB", step: 0.5)
                    StudioSlider(label: "Air · 8,5 kHz", value: $audio.airDB,
                                 range: -12...12, unit: " dB", step: 0.5)
                    Button("Réinitialiser l'EQ", action: audio.resetEqualizer)
                        .font(.footnote.weight(.medium)).tint(Palette.accent)
                }
                SectionTitle(text: "Effets")
                LainCard {
                    StudioSlider(label: "Réverbération", value: $audio.reverbPercent,
                                 range: 0...100, unit: "%", step: 1)
                    StudioSlider(label: "Écho", value: $audio.echoPercent,
                                 range: 0...100, unit: "%", step: 1)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 32)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

private struct StudioSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let step: Double
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(value, specifier: "%.0f")\(unit)")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.muted)
            }
            Slider(value: $value, in: range, step: step).tint(Palette.accent)
        }
        .padding(.vertical, 6)
    }
}

private struct SoundboardPage: View {
    @ObservedObject var manager: SoundboardManager
    @State private var isImporting = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                BrandHeader(subtitle: "Soundboard & fichiers locaux")
                    .padding(.top, 15)
                LainCard {
                    Text("Importe tes sons").font(.headline)
                    Text("MP3, WAV, M4A… Tes fichiers restent sur l'iPhone et sont joués sur sa sortie audio. Aucun son n'est envoyé dans un salon Discord.")
                        .font(.subheadline).foregroundStyle(Palette.muted).padding(.top, 4)
                    Button { isImporting = true } label: {
                        Label("Ajouter des sons", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Palette.accent).padding(.top, 12)
                }
                SectionTitle(text: "Lecture")
                LainCard {
                    StudioSlider(label: "Volume soundboard", value: $manager.volume,
                                 range: 0...100, unit: "%", step: 1)
                    Button(action: manager.stop) {
                        Label("Arrêter la lecture", systemImage: "stop.circle")
                    }
                    .font(.subheadline).tint(Palette.accent)
                    .disabled(manager.playingID == nil)
                }
                SectionTitle(text: "Mes sons · \(manager.clips.count)")
                if manager.clips.isEmpty {
                    LainCard {
                        Image(systemName: "music.note.list")
                            .font(.largeTitle).foregroundStyle(Palette.muted)
                        Text("Aucun son importé").font(.headline).padding(.top, 4)
                        Text("Utilise le bouton Ajouter des sons pour créer ta bibliothèque.")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                } else {
                    ForEach(manager.clips) { clip in
                        LainCard {
                            HStack(spacing: 12) {
                                Button { manager.toggle(clip) } label: {
                                    Image(systemName: manager.playingID == clip.id ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 34)).foregroundStyle(Palette.accent)
                                }
                                Text(clip.title).font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                Spacer(minLength: 4)
                                Button(role: .destructive) { manager.delete(clip) } label: {
                                    Image(systemName: "trash").font(.body)
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                            }
                        }
                    }
                }
                if let error = manager.errorText {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 32)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): manager.importFiles(urls)
            case .failure(let error): manager.errorText = error.localizedDescription
            }
        }
    }
}

private struct SettingsPage: View {
    @EnvironmentObject private var audio: AudioStudioEngine
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                BrandHeader(subtitle: "Version iPhone · projet source")
                    .padding(.top, 15)
                SectionTitle(text: "Audio")
                LainCard {
                    Label("Microphone", systemImage: "mic")
                        .font(.headline)
                    Text("Permission demandée lors de la première activation du studio.")
                        .font(.footnote).foregroundStyle(Palette.muted).padding(.top, 2)
                    Button("Ouvrir les réglages iOS") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.footnote).tint(Palette.accent).padding(.top, 7)
                }
                SectionTitle(text: "Fonctions disponibles")
                LainCard {
                    FeatureRow(name: "Monitoring microphone", supported: true)
                    FeatureRow(name: "EQ, gain et effets vocaux", supported: true)
                    FeatureRow(name: "Presets audio", supported: true)
                    FeatureRow(name: "Soundboard local", supported: true)
                }
                SectionTitle(text: "Fonctions non portées")
                LainCard {
                    Text("Serveurs et messages : disponibles via le client web dans l’onglet Discord. Connexion et appels à vérifier sur iPhone.").font(.footnote).foregroundStyle(Palette.muted)
                    FeatureRow(name: "Injection du micro dans Discord", supported: false)
                    FeatureRow(name: "Stream et partage d'écran", supported: false)
                    Text("Cette version utilise le client web Discord. Les modules audio natifs de LeanCord Windows ne sont pas portés. Le vocal en arrière-plan et le partage d’écran ne sont pas garantis.")
                        .font(.footnote).foregroundStyle(Palette.muted).padding(.top, 10)
                }
                Text("LainCord est un projet indépendant et n'est ni affilié ni approuvé par Discord.")
                    .font(.caption2).foregroundStyle(Palette.muted)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 18).padding(.bottom, 30)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

private struct FeatureRow: View {
    let name: String
    let supported: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: supported ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(supported ? Palette.green : Palette.muted)
            Text(name).font(.subheadline)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
