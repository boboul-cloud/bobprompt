import AVFoundation

/// Bruitages de la machine à écrire, synthétisés (aucun fichier son).
@MainActor
final class TypewriterSound {
    static let shared = TypewriterSound()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var clacks: [AVAudioPCMBuffer] = []
    private var ding: AVAudioPCMBuffer?
    private var carriage: AVAudioPCMBuffer?
    private var ready = false
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {}

    private func prepare() {
        guard !ready else { return }
        for _ in 0..<5 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        clacks = (0..<4).map { makeClack(seed: UInt64($0) &* 7919 &+ 17, pitch: 1 + Double($0) * 0.07) }
        ding = makeDing()
        carriage = makeCarriage()
        ready = true
    }

    private var starting = false

    /// Démarre le moteur hors du fil principal ; le tout premier son est sauté.
    private func ensureRunning() -> Bool {
        prepare()
        if engine.isRunning { return true }
        guard !starting else { return false }
        starting = true
        let e = engine
        AudioSession.activate { [weak self] in
            try? e.start()
            DispatchQueue.main.async { self?.starting = false }
        }
        return false
    }

    func key() { play(clacks.randomElement(), volume: Float.random(in: 0.22...0.34)) }
    func bell() { play(ding, volume: 0.45) }
    func carriageReturn() { play(carriage, volume: 0.3) }

    func stop() {
        players.forEach { $0.stop() }
        if engine.isRunning { engine.pause() }
    }

    private func play(_ buffer: AVAudioPCMBuffer?, volume: Float) {
        guard let buffer, ensureRunning() else { return }
        let p = players[next]
        next = (next + 1) % players.count
        p.volume = volume
        p.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !p.isPlaying { p.play() }
    }

    // MARK: Synthèse

    private func buffer(seconds: Double, _ fill: (Int, Double) -> Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        b.frameLength = frames
        let data = b.floatChannelData![0]
        for i in 0..<Int(frames) { data[i] = fill(i, Double(i) / format.sampleRate) }
        return b
    }

    private func makeClack(seed: UInt64, pitch: Double) -> AVAudioPCMBuffer {
        var state = seed | 1
        var low: Float = 0
        return buffer(seconds: 0.06) { _, t in
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            let noise = Float(Double(state % 10_000) / 5_000 - 1)
            low += (noise - low) * 0.35
            let hit = Float(exp(-t / 0.006))
            let body = Float(sin(2 * .pi * 210 * pitch * t) * exp(-t / 0.018))
            return (noise - low) * hit * 0.9 + body * 0.5
        }
    }

    private func makeDing() -> AVAudioPCMBuffer {
        let f = 2_093.0
        return buffer(seconds: 1.2) { _, t in
            let env = exp(-t / 0.42)
            let s = sin(2 * .pi * f * t) + 0.35 * sin(2 * .pi * f * 2.76 * t) * exp(-t / 0.15)
                + 0.18 * sin(2 * .pi * f * 5.4 * t) * exp(-t / 0.07)
            return Float(s * env * 0.5)
        }
    }

    private func makeCarriage() -> AVAudioPCMBuffer {
        var state: UInt64 = 0x9E3779B97F4A7C15
        return buffer(seconds: 0.32) { _, t in
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            let noise = Double(state % 10_000) / 5_000 - 1
            // Cliquetis du cliquet qui accélère.
            let rate = 30 + 140 * t
            let phase = (t * rate).truncatingRemainder(dividingBy: 1)
            let click = exp(-phase * 30)
            let fade = min(1, t * 20) * exp(-t / 0.2)
            return Float(noise * click * fade * 0.7)
        }
    }
}
