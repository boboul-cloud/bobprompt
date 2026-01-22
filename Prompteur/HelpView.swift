import SwiftUI

// MARK: - Mode d'emploi de l'application
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSection: String? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // En-tête
                    headerSection
                    
                    // Sections d'aide
                    HelpSection(
                        title: "Éditer votre texte",
                        icon: "pencil",
                        color: .blue,
                        isExpanded: expandedSection == "edit",
                        onTap: { toggleSection("edit") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HelpStep(number: 1, text: "Allez dans l'onglet **Éditer** en bas de l'écran.")
                            HelpStep(number: 2, text: "Saisissez un **titre** pour votre texte (optionnel).")
                            HelpStep(number: 3, text: "Écrivez ou collez votre texte dans la zone principale.")
                            HelpStep(number: 4, text: "Utilisez le bouton **Exemple** pour charger un texte de démonstration.")
                            
                            HelpTip(text: "Appuyez sur \"Terminer\" dans la barre clavier pour masquer le clavier.")
                        }
                    }
                    
                    HelpSection(
                        title: "Lire avec le prompteur",
                        icon: "play.fill",
                        color: .green,
                        isExpanded: expandedSection == "read",
                        onTap: { toggleSection("read") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HelpStep(number: 1, text: "Passez à l'onglet **Lire** pour voir le prompteur.")
                            HelpStep(number: 2, text: "Appuyez sur le **bouton Play** ▶️ pour démarrer le défilement.")
                            HelpStep(number: 3, text: "Le texte défile automatiquement. Appuyez à nouveau pour mettre en **pause**.")
                            HelpStep(number: 4, text: "Appuyez sur **Stop** ⏹ pour arrêter et revenir au début.")
                            
                            Divider().padding(.vertical, 8)
                            
                            Text("Options de lecture :")
                                .font(Theme.roundedFont(size: 15, weight: .semibold))
                            
                            HelpOption(icon: "textformat.abc", title: "Syllabes", description: "Colorie les syllabes en alternance pour faciliter la lecture.")
                            HelpOption(icon: "speaker.wave.2.fill", title: "Voix", description: "Active la synthèse vocale pour lire le texte à voix haute.")
                            HelpOption(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", title: "Miroir", description: "Inverse le texte horizontalement (pour réflecteur).")
                            HelpOption(icon: "text.aligncenter", title: "Centrer", description: "Centre le texte au milieu de l'écran.")
                            HelpOption(icon: "arrow.up.left.and.arrow.down.right", title: "Plein écran", description: "Touchez l'icône en haut à droite du prompteur.")
                        }
                    }
                    
                    HelpSection(
                        title: "Paramètres avancés",
                        icon: "gearshape.fill",
                        color: .gray,
                        isExpanded: expandedSection == "settings",
                        onTap: { toggleSection("settings") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Appuyez sur l'icône **⚙️ Réglages** dans la barre de lecture pour accéder aux options :")
                                .font(Theme.roundedFont(size: 14))
                                .foregroundColor(.secondary)
                            
                            HelpOption(icon: "hare.fill", title: "Vitesse", description: "Ajustez la vitesse de défilement (20 à 200 pts/s).")
                            HelpOption(icon: "textformat.size", title: "Taille du texte", description: "Modifiez la taille de la police (18 à 72 pts).")
                            HelpOption(icon: "paintpalette.fill", title: "Couleurs", description: "Choisissez les couleurs pour l'alternance syllabique.")
                            HelpOption(icon: "timer", title: "Compte à rebours", description: "Active un décompte 3-2-1 avant le démarrage.")
                            HelpOption(icon: "speaker.wave.3.fill", title: "Voix de synthèse", description: "Sélectionnez la voix et la vitesse de lecture vocale.")
                            
                            HelpTip(text: "Ajustez la hauteur de la zone de lecture avec le curseur en bas des réglages.")
                        }
                    }
                    
                    HelpSection(
                        title: "Créer avec l'IA",
                        icon: "sparkles",
                        color: .purple,
                        isExpanded: expandedSection == "ai",
                        onTap: { toggleSection("ai") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HelpStep(number: 1, text: "Allez dans l'onglet **Créer** ✨.")
                            HelpStep(number: 2, text: "Renseignez votre **clé API OpenAI** (requise pour l'IA en ligne).")
                            HelpStep(number: 3, text: "Décrivez le **sujet** de votre texte.")
                            HelpStep(number: 4, text: "Choisissez l'objectif, le ton, le public cible et le style.")
                            HelpStep(number: 5, text: "Ajustez le **nombre de mots** souhaité.")
                            HelpStep(number: 6, text: "Appuyez sur **Générer** et patientez.")
                            HelpStep(number: 7, text: "Validez le texte généré pour l'insérer dans l'éditeur.")
                            
                            HelpTip(text: "La température contrôle la créativité : plus elle est haute, plus le texte sera original.")
                        }
                    }
                    
                    HelpSection(
                        title: "Bibliothèque de textes",
                        icon: "books.vertical",
                        color: .orange,
                        isExpanded: expandedSection == "library",
                        onTap: { toggleSection("library") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sauvegardez vos textes pour les réutiliser plus tard :")
                                .font(Theme.roundedFont(size: 14))
                                .foregroundColor(.secondary)
                            
                            HelpStep(number: 1, text: "Dans l'onglet **Éditer**, utilisez le bouton **Enregistrer** 📥 de la barre clavier.")
                            HelpStep(number: 2, text: "Ou allez dans **Bibliothèque** et ajoutez le texte courant.")
                            HelpStep(number: 3, text: "Donnez un titre à votre texte pour le retrouver facilement.")
                            HelpStep(number: 4, text: "Touchez un texte sauvegardé pour le charger dans l'éditeur.")
                            
                            HelpTip(text: "Glissez vers la gauche sur une entrée pour la supprimer.")
                        }
                    }
                    
                    HelpSection(
                        title: "Thèmes visuels",
                        icon: "paintpalette.fill",
                        color: .pink,
                        isExpanded: expandedSection == "themes",
                        onTap: { toggleSection("themes") }
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Personnalisez l'apparence de l'application :")
                                .font(Theme.roundedFont(size: 14))
                                .foregroundColor(.secondary)
                            
                            HelpStep(number: 1, text: "Appuyez sur le **sélecteur de thème** en haut à droite.")
                            HelpStep(number: 2, text: "Choisissez parmi les thèmes disponibles : Océan, Bonbons, Forêt, Nuit, etc.")
                            
                            HelpTip(text: "Le thème Nuit est idéal pour les environnements sombres.")
                        }
                    }
                    
                    // Conseils généraux
                    tipsSection
                    
                    // Footer
                    footerSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Mode d'emploi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .font(Theme.roundedFont(size: 16, weight: .semibold))
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Prompteur Magique")
                .font(Theme.roundedFont(size: 28, weight: .bold))
            
            Text("Votre assistant de lecture pour enfants et adultes")
                .font(Theme.roundedFont(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Astuces")
                    .font(Theme.roundedFont(size: 20, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                TipRow(icon: "iphone.gen3", text: "Placez votre appareil à hauteur des yeux pour un confort optimal.")
                TipRow(icon: "sun.max.fill", text: "Ajustez la luminosité de l'écran selon votre environnement.")
                TipRow(icon: "arrow.clockwise", text: "Faites des essais avec différentes vitesses pour trouver votre rythme.")
                TipRow(icon: "person.2.fill", text: "La coloration syllabique aide particulièrement les enfants à lire.")
                TipRow(icon: "rectangle.portrait.rotate", text: "L'application fonctionne aussi en mode paysage !")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.yellow.opacity(0.1))
        )
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Version 1.0")
                .font(Theme.roundedFont(size: 12))
                .foregroundColor(.secondary)
            
            Text("Conçu avec ❤️ pour faciliter la lecture")
                .font(Theme.roundedFont(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }
    
    // MARK: - Helpers
    
    private func toggleSection(_ section: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if expandedSection == section {
                expandedSection = nil
            } else {
                expandedSection = section
            }
        }
    }
}

// MARK: - Composants réutilisables

private struct HelpSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let isExpanded: Bool
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(color)
                        )
                    
                    Text(title)
                        .font(Theme.roundedFont(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct HelpStep: View {
    let number: Int
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(Theme.roundedFont(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(Theme.roundedFont(size: 14))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HelpOption: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.roundedFont(size: 14, weight: .semibold))
                Text(description)
                    .font(Theme.roundedFont(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct HelpTip: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(.yellow)
            
            Text(text)
                .font(Theme.roundedFont(size: 13))
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.yellow.opacity(0.1))
        )
    }
}

private struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.orange)
                .frame(width: 24)
            
            Text(text)
                .font(Theme.roundedFont(size: 14))
        }
    }
}

// MARK: - Preview
#if DEBUG
struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
#endif
