import SwiftUI
import WebKit
import Foundation
import Combine

private struct DiscordUser: Decodable {
    let username: String
}

private struct DiscordSession: Identifiable {
    let id = UUID()
    let token: String?
}

@MainActor
private final class DiscordClient: ObservableObject {
    @Published var token = ""
    @Published var connecting = false
    @Published var error: String?
    @Published var session: DiscordSession?
    private var connection: Task<Void, Never>?

    func connect() {
        guard !connecting else { return }
        let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, !candidate.contains(where: { $0.isWhitespace }) else {
            error = "Saisis un token sans espace."
            return
        }
        connecting = true
        error = nil
        connection = Task {
            defer { connecting = false }
            // Ephemeral networking avoids persisting the authorization header or response.
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            let network = URLSession(configuration: configuration,
                                     delegate: NoDiscordRedirects(), delegateQueue: nil)
            defer { network.invalidateAndCancel() }
            var request = URLRequest(url: URL(string: "https://discord.com/api/v10/users/@me")!)
            request.setValue(candidate, forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await network.data(for: request)
                try Task.checkCancellation()
                guard let status = (response as? HTTPURLResponse)?.statusCode else {
                    error = "Réponse Discord inconnue. Réessaie."
                    return
                }
                switch status {
                case 200:
                    _ = try JSONDecoder().decode(DiscordUser.self, from: data)
                    token = ""
                    session = DiscordSession(token: candidate)
                case 401: error = "Token refusé ou expiré. Tu peux utiliser la connexion classique."
                case 403: error = "Discord refuse cette connexion. Essaie la connexion classique."
                case 429: error = "Trop de tentatives. Patiente avant de réessayer."
                default: error = "Discord est indisponible (\(status)). Réessaie plus tard."
                }
            } catch is CancellationError {
                // Navigation cancelled the attempt.
            } catch {
                if !Task.isCancelled {
                    self.error = "Connexion impossible. Vérifie ton réseau ou utilise la connexion classique."
                }
            }
        }
    }

    func cancel() {
        connection?.cancel()
        connection = nil
        token = ""
    }
}

private final class NoDiscordRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct DiscordPage: View {
    @EnvironmentObject private var audio: AudioStudioEngine
    @StateObject private var client = DiscordClient()

    var body: some View {
        Form {
            Section {
                Label("Discord sur iPhone", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.headline)
                Text("Ouvre tes serveurs et tes messages. Les appels utilisent le vocal web de Discord ; leur compatibilité sur iPhone reste à tester.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Se connecter avec Discord") {
                    client.token = ""
                    client.error = nil
                    client.session = DiscordSession(token: nil)
                }
                .disabled(client.connecting)
            }
            Section("Connexion par token") {
                SecureField("Token de ton compte", text: $client.token)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(client.connecting)
                Button(action: client.connect) {
                    HStack {
                        Text(client.connecting ? "Vérification…" : "Connecter mon compte")
                        if client.connecting { Spacer(); ProgressView() }
                    }
                }
                .disabled(client.connecting || client.token.isEmpty)
                Text("Le token est transmis à Discord uniquement. Après arrêt complet de l’app ou déconnexion, une nouvelle connexion sera nécessaire.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = client.error {
                    Text(error).foregroundStyle(.orange).accessibilityLabel("Erreur : \(error)")
                }
            }
            Section {
                Text("Les effets du Studio et le soundboard restent locaux : ils ne sont pas envoyés dans les appels Discord.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Discord")
        .onDisappear { client.cancel() }
        .fullScreenCover(item: $client.session) { session in
            DiscordBrowser(session: session) {
                client.session = nil
                client.cancel()
            }
            .onAppear { audio.stop() }
        }
    }
}

@MainActor
private final class DiscordBrowserState: ObservableObject {
    @Published var loading = true
    @Published var error: String?
    weak var webView: WKWebView?

    func reload() {
        error = nil
        guard let webView else { return }
        let url = webView.url ?? URL(string: "https://discord.com/channels/@me")!
        webView.load(URLRequest(url: url))
    }

    func close() {
        guard let webView else { return }
        webView.stopLoading()
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.configuration.userContentController.removeAllUserScripts()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
        // The data store is nonpersistent and belongs to this session only.
        let store = webView.configuration.websiteDataStore
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                         modifiedSince: .distantPast, completionHandler: {})
    }
}

private struct DiscordBrowser: View {
    let session: DiscordSession
    let logout: () -> Void
    @StateObject private var state = DiscordBrowserState()
    @State private var confirmLogout = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if state.loading { ProgressView().frame(maxWidth: .infinity).padding(6) }
                if let error = state.error {
                    VStack(spacing: 12) {
                        Text(error).multilineTextAlignment(.center)
                        Button("Réessayer", action: state.reload)
                    }.padding()
                }
                DiscordWebView(session: session, state: state)
            }
            .navigationTitle("Discord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Déconnexion") { confirmLogout = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: state.reload) { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Recharger Discord")
                }
            }
            .confirmationDialog("Fermer la session Discord ?", isPresented: $confirmLogout,
                                titleVisibility: .visible) {
                Button("Se déconnecter", role: .destructive) {
                    state.close()
                    logout()
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct DiscordWebView: UIViewRepresentable {
    let session: DiscordSession
    @ObservedObject var state: DiscordBrowserState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let controller = configuration.userContentController
        if let token = session.token,
           let url = Bundle.main.url(forResource: "DiscordSession", withExtension: "js"),
           let bootstrap = try? String(contentsOf: url, encoding: .utf8),
           let encoded = try? JSONEncoder().encode(token),
           let literal = String(data: encoded, encoding: .utf8) {
            controller.addUserScript(WKUserScript(source: "\(bootstrap)(\(literal));",
                                                  injectionTime: .atDocumentStart,
                                                  forMainFrameOnly: true))
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        // Request Discord's desktop web interface instead of the mobile app promotion.
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        state.webView = webView
        webView.load(URLRequest(url: URL(string: "https://discord.com/channels/@me")!))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeAllUserScripts()
        webView.loadHTMLString("", baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let state: DiscordBrowserState
        init(state: DiscordBrowserState) { self.state = state }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.loading = true
            state.error = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.loading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) { showError(error) }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
                     withError error: Error) { showError(error) }

        private func showError(_ error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            state.loading = false
            state.error = "Impossible de charger Discord. Vérifie ta connexion puis réessaie."
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            state.loading = false
            state.error = "Discord s’est interrompu. Appuie sur Réessayer."
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.cancel); return }
            // Captcha and other embedded frames are required by the standard login.
            if let frame = action.targetFrame, !frame.isMainFrame {
                decisionHandler(.allow)
                return
            }
            if url.scheme == "https", url.host == "discord.com" {
                if action.targetFrame == nil {
                    decisionHandler(.cancel)
                    webView.load(action.request)
                } else { decisionHandler(.allow) }
            } else {
                decisionHandler(.cancel)
                if action.navigationType == .linkActivated,
                   ["https", "http"].contains(url.scheme ?? "") {
                    UIApplication.shared.open(url)
                }
            }
        }

        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            // iOS asks the user for access. Never silently grant microphone or camera.
            decisionHandler(origin.protocol == "https" && origin.host == "discord.com" ? .prompt : .deny)
        }
    }
}
