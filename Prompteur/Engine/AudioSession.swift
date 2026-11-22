import AVFoundation

/// Session audio de l'app.
///
/// Régler la catégorie ou (dés)activer la session peut bloquer plusieurs
/// centaines de millisecondes : tout se fait sur une file dédiée, jamais sur
/// le fil principal, et la catégorie n'est réglée qu'une fois.
enum AudioSession {
    private static let queue = DispatchQueue(label: "com.bobprompt.audio-session", qos: .userInitiated)
    /// Lu et écrit uniquement sur `queue`.
    nonisolated(unsafe) private static var configured = false

    /// La voix et les sons jouent même en mode silencieux, mêlés à la musique
    /// d'une autre app sans la couper. À appeler au lancement.
    static func configure() {
        queue.async { configureIfNeeded() }
    }

    /// Active la session, puis exécute `work` sur la même file (hors fil principal).
    static func activate(then work: (() -> Void)? = nil) {
        queue.async {
            configureIfNeeded()
            try? AVAudioSession.sharedInstance().setActive(true)
            work?()
        }
    }

    /// À la fermeture du lecteur : rend la main aux autres apps.
    static func deactivate() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private static func configureIfNeeded() {
        guard !configured else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
        configured = true
    }
}
