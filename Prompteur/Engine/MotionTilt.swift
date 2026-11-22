import CoreMotion
import Observation

/// Inclinaison de l'appareil, lissée, autour de la position de départ.
/// Sert à la parallaxe des modes 3D.
@MainActor
@Observable
final class MotionTilt {
    /// Roulis (gauche/droite) et tangage (avant/arrière), entre -1 et 1.
    private(set) var x: Double = 0
    private(set) var y: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var reference: CMAttitude?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        reference = nil
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated { self?.update(motion.attitude) }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        x = 0
        y = 0
    }

    /// La position actuelle devient la position neutre.
    func recenter() { reference = nil }

    private func update(_ attitude: CMAttitude) {
        guard let a = attitude.copy() as? CMAttitude else { return }
        if reference == nil { reference = a.copy() as? CMAttitude }
        if let ref = reference { a.multiply(byInverseOf: ref) }
        let nx = max(-1, min(1, a.roll / 0.45))
        let ny = max(-1, min(1, a.pitch / 0.45))
        x += (nx - x) * 0.18
        y += (ny - y) * 0.18
    }
}
