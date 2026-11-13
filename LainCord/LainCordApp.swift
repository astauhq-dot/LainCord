import SwiftUI

@main
struct LainCordApp: App {
    @StateObject private var audio = AudioStudioEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audio)
                .preferredColorScheme(.dark)
        }
    }
}
