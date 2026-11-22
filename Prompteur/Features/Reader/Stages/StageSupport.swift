import SwiftUI
import UIKit
import QuartzCore

/// Ce dont chaque mode d'affichage a besoin.
struct StageContext {
    let engine: PrompterEngine
    let document: PrompterDocument
    let settings: ReaderSettings
    let tilt: MotionTilt
    /// Couleur propre au texte (bibliothèque), pour les décors.
    let accent: Color
    /// Marges de sécurité de l'écran (encoche, barre d'accueil) : les scènes
    /// occupent tout l'écran, leurs éléments fixes doivent les éviter.
    var safeArea = EdgeInsets()
}

/// Clé qui déclenche le recalcul de la mise en lignes.
struct LayoutKey: Equatable {
    var document: UUID
    var width: Int
    var fontSize: Double
    var font: String
    var oneWordPerLine: Bool
    var uppercase: Bool
    var spacing: Double
}

/// Mise en lignes conservée entre deux images (recalculée seulement si la clé change).
/// Simple cache : volontairement non observé, il peut être rempli pendant le rendu.
final class LayoutHolder {
    private(set) var layout: LineLayout?
    private(set) var signature = 0
    private var key: LayoutKey?
    let cache = StyledLineCache()

    func update(key: LayoutKey, make: () -> LineLayout) -> LineLayout {
        if let layout, self.key == key { return layout }
        let l = make()
        self.key = key
        layout = l
        signature &+= 1
        return l
    }
}

enum StageFonts {
    static func typewriter(size: CGFloat) -> UIFont {
        UIFont(name: "AmericanTypewriter-Semibold", size: size)
            ?? UIFont(name: "AmericanTypewriter", size: size)
            ?? UIFont.monospacedSystemFont(ofSize: size, weight: .semibold)
    }

    static func crt(size: CGFloat) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }
}

extension Font {
    init(ui: UIFont) { self.init(ui as CTFont) }
}

// MARK: - Projection 3D

/// Construit les transformations 3D (perspective comprise) appliquées à des vues planes.
/// Convention Core Animation : vecteurs-lignes, `a.concatenating(b)` applique a puis b.
struct Projection3D {
    /// Distance de la caméra au plan z = 0.
    var cameraDistance: CGFloat

    static func translate(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CATransform3D {
        CATransform3DMakeTranslation(x, y, z)
    }

    static func rotateX(_ a: CGFloat) -> CATransform3D { CATransform3DMakeRotation(a, 1, 0, 0) }
    static func rotateY(_ a: CGFloat) -> CATransform3D { CATransform3DMakeRotation(a, 0, 1, 0) }
    static func rotateZ(_ a: CGFloat) -> CATransform3D { CATransform3DMakeRotation(a, 0, 0, 1) }

    var perspective: CATransform3D {
        var p = CATransform3DIdentity
        p.m34 = -1 / cameraDistance
        return p
    }

    /// Transformation complète d'une vue de taille `size` dont le centre est placé
    /// par `model` (repère centré, y vers le bas, z vers l'observateur).
    func projection(size: CGSize, model: CATransform3D) -> ProjectionTransform {
        let toCenter = Self.translate(-size.width / 2, -size.height / 2, 0)
        let back = Self.translate(size.width / 2, size.height / 2, 0)
        let m = toCenter.concatenating(model).concatenating(perspective).concatenating(back)
        return ProjectionTransform(m)
    }

    /// Profondeur (z) du centre de la vue après `model`.
    static func depth(of model: CATransform3D) -> CGFloat { model.m43 }
}

extension CATransform3D {
    func concatenating(_ other: CATransform3D) -> CATransform3D { CATransform3DConcat(self, other) }
}

// MARK: - Fondus haut / bas

struct EdgeFade: ViewModifier {
    var top: CGFloat = 0.14
    var bottom: CGFloat = 0.14
    func body(content: Content) -> some View {
        content.mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: top),
                .init(color: .black, location: 1 - bottom),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        )
    }
}

extension View {
    func edgeFade(top: CGFloat = 0.14, bottom: CGFloat = 0.14) -> some View {
        modifier(EdgeFade(top: top, bottom: bottom))
    }
}

/// Glisser vertical → déplacement dans le texte (avec élan au lâcher).
struct ScrubGesture: ViewModifier {
    let engine: PrompterEngine
    /// Nombre d'unités de temps par point glissé.
    let beatsPerPoint: Double
    /// Remis à zéro automatiquement, même si le système annule le geste.
    @GestureState private var last: CGFloat?

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 6)
                    .updating($last) { v, last, _ in
                        if last == nil { engine.beginScrub(); last = 0 }
                        let dy = v.translation.height - (last ?? 0)
                        last = v.translation.height
                        engine.scrub(by: -Double(dy) * beatsPerPoint)
                    }
                    .onEnded { v in
                        let vy = v.predictedEndTranslation.height - v.translation.height
                        engine.endScrub(velocity: -Double(vy) * beatsPerPoint * 2.2)
                    }
            )
            .onChange(of: last == nil) { _, ended in
                if ended { DispatchQueue.main.async { engine.cancelScrubIfNeeded() } }
            }
    }
}
