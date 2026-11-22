import SwiftUI

/// Mode d'emploi, court et visuel.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Wordmark(size: 28)
                        Text("Un prompteur pour lire, présenter et filmer — et pour apprendre à lire en s'amusant.")
                            .font(Typo.body(16))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .padding(.bottom, 6)

                    card("1", "Écrire ou choisir un texte", Palette.onAir) {
                        bullet("square.and.pencil", "« Nouveau texte » : écris ou colle ton texte. Tout s'enregistre tout seul.")
                        bullet("sparkles", "« Avec l'IA » : donne un sujet, choisis pour qui, et l'IA l'écrit pour toi.")
                        bullet("book.fill", "Les exemples se lisent tout de suite. Pour les modifier, crée une copie.")
                    }

                    card("2", "Lire", Palette.indigo) {
                        bullet("hand.tap.fill", "Touche le texte pour lancer ou mettre en pause.")
                        bullet("hand.draw.fill", "Glisse vers le haut ou le bas pour avancer ou revenir.")
                        bullet("gobackward", "Les flèches rondes passent à la phrase précédente ou suivante.")
                        bullet("waveform", "« Écouter la phrase » lit la phrase en cours, mot à mot.")
                        bullet("speaker.wave.2.fill", "Active la voix : elle lit tout le texte et le fait défiler.")
                    }

                    card("3", "Choisir un style", Palette.teal) {
                        bullet("text.alignleft", "Classique : fond Nuit, Papier (avec règle de lecture) ou Contraste.")
                        bullet("tv", "Vieille école : écran cathodique vert ou ambre, ou machine à écrire qui tape le texte, ding !")
                        bullet("cylinder.split.1x2", "3D Tambour : fais tourner le texte du doigt, glisse sur le côté pour tourner autour, pince pour zoomer, penche l'appareil.")
                        bullet("rectangle.on.rectangle.angled", "3D Cartes : une phrase par carte, balaie pour tourner la page.")
                    }

                    card("4", "Aide à la lecture", Palette.sun) {
                        bullet("textformat.abc", "Syllabes en couleurs, découpées comme à l'école : a-mi, ta-bleau.")
                        bullet("highlighter", "Le mot en cours est surligné pour suivre sans se perdre.")
                        bullet("text.word.spacing", "« Un mot par ligne » pour lire tout doucement.")
                    }

                    card("5", "Pour filmer", Palette.pink) {
                        bullet("arrow.left.and.right.righttriangle.left.righttriangle.right", "Miroir : pour un prompteur à vitre.")
                        bullet("keyboard", "Clavier ou télécommande Bluetooth : espace = lecture/pause, ↑↓ = phrase, ←→ = vitesse.")
                        bullet("timer", "Compte à rebours 3-2-1 avant de démarrer.")
                    }

                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                        .font(Typo.caption(12))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Mode d'emploi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() }.fontWeight(.bold) } }
        }
    }

    private func card<Content: View>(_ number: String, _ title: String, _ color: Color,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(number)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(color))
                Text(title).font(Typo.headline(18)).foregroundStyle(Palette.ink)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.hairline))
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 22)
            Text(text).font(Typo.body(15)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
