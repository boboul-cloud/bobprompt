// filepath: /Volumes/Seagate Backup Plus Drive/Prompteur/Prompteur/AICreationView.swift
import SwiftUI

// MARK: - Suggestions de sujets
struct AIPromptSuggestion: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let prompt: String
}

let promptSuggestions: [AIPromptSuggestion] = [
    AIPromptSuggestion(emoji: "🎬", title: "Intro YouTube", prompt: "Introduction accrocheuse pour une vidéo YouTube"),
    AIPromptSuggestion(emoji: "📢", title: "Annonce produit", prompt: "Présentation d'un nouveau produit ou service"),
    AIPromptSuggestion(emoji: "💡", title: "Pitch idée", prompt: "Présenter une idée innovante de façon convaincante"),
    AIPromptSuggestion(emoji: "🎤", title: "Discours événement", prompt: "Discours pour une occasion spéciale"),
    AIPromptSuggestion(emoji: "📚", title: "Conte enfant", prompt: "Histoire courte et amusante pour enfants"),
    AIPromptSuggestion(emoji: "🏋️", title: "Motivation sport", prompt: "Message de motivation pour le sport et le dépassement de soi"),
    AIPromptSuggestion(emoji: "🍳", title: "Recette cuisine", prompt: "Présentation d'une recette de cuisine étape par étape"),
    AIPromptSuggestion(emoji: "🌍", title: "Voyage découverte", prompt: "Présentation d'une destination de voyage"),
]

// MARK: - FlowLayout pour les chips (iOS 16+)
@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

// MARK: - Fallback pour iOS 15 (ScrollView horizontal)
struct WrappingHStack<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                content
            }
            .padding(.horizontal, 4)
        }
    }
}

struct AICreationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var criteria = AIGeneratorCriteria()
    @State private var wordCount: Double = 120
    @State private var generated: String = ""
    @State private var useOnlineAI: Bool = true
    @State private var apiKey: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var temperature: Double = 0.9
    @State private var showAdvancedSettings: Bool = false
    @State private var selectedSuggestion: AIPromptSuggestion? = nil
    @State private var keywords: [String] = []
    @State private var newKeyword: String = ""
    private let apiKeyStorageKey = "OPENAI_API_KEY"
    var onInsert: (String) -> Void

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: - Hero Section avec suggestions
                    heroSection
                    
                    // MARK: - Carte principale du sujet
                    subjectCard
                    
                    // MARK: - Sélecteurs visuels
                    objectiveSelector
                    toneSelector
                    
                    // MARK: - Sélecteurs secondaires
                    secondarySelectors
                    
                    // MARK: - Mots-clés avec chips
                    keywordsSection
                    
                    // MARK: - Nombre de mots
                    wordCountSlider
                    
                    // MARK: - Paramètres avancés
                    advancedSettings
                    
                    // MARK: - Résultat généré
                    if !generated.isEmpty {
                        generatedResultCard
                    }
                    
                    // MARK: - Erreur
                    if let err = errorMessage {
                        errorCard(err)
                    }
                    
                    // MARK: - Boutons d'action
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Créer avec l'IA ✨")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear { 
                loadStoredKeyIfAny() 
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            Text("💡 Idées rapides")
                .font(Theme.roundedFont(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(promptSuggestions) { suggestion in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                criteria.sujet = suggestion.prompt
                                selectedSuggestion = suggestion
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            VStack(spacing: 8) {
                                Text(suggestion.emoji)
                                    .font(.system(size: 28))
                                Text(suggestion.title)
                                    .font(Theme.roundedFont(size: 12, weight: .medium))
                                    .foregroundColor(selectedSuggestion?.id == suggestion.id ? .white : .primary)
                                    .lineLimit(1)
                            }
                            .frame(width: 90, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(selectedSuggestion?.id == suggestion.id 
                                          ? AnyShapeStyle(Theme.auroraGradient)
                                          : AnyShapeStyle(Color.white))
                            )
                            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Carte du sujet
    private var subjectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("De quoi voulez-vous parler ?", systemImage: "text.bubble.fill")
                .font(Theme.roundedFont(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            
            if #available(iOS 16.0, *) {
                TextField("Décrivez votre sujet...", text: $criteria.sujet, axis: .vertical)
                    .font(Theme.roundedFont(size: 17))
                    .lineLimit(3...6)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            } else {
                TextEditor(text: $criteria.sujet)
                    .font(Theme.roundedFont(size: 17))
                    .frame(minHeight: 80)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                    .overlay(
                        Group {
                            if criteria.sujet.isEmpty {
                                Text("Décrivez votre sujet...")
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 16)
                                    .padding(.top, 20)
                            }
                        },
                        alignment: .topLeading
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
    }
    
    // MARK: - Sélecteur d'objectif
    private var objectiveSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Objectif", systemImage: "target")
                .font(Theme.roundedFont(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                ForEach(AIGeneratorCriteria.Objectif.allCases) { obj in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            criteria.objectif = obj
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: obj.icon)
                                .font(.system(size: 20))
                            Text(obj.rawValue)
                                .font(Theme.roundedFont(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(criteria.objectif == obj ? .white : obj.color)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(criteria.objectif == obj ? obj.color : obj.color.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Sélecteur de ton
    private var toneSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ton", systemImage: "waveform")
                .font(Theme.roundedFont(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AIGeneratorCriteria.Ton.allCases) { ton in
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                criteria.ton = ton
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: ton.icon)
                                    .font(.system(size: 14))
                                Text(ton.rawValue)
                                    .font(Theme.roundedFont(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundColor(criteria.ton == ton ? .white : Theme.primary)
                            .background(
                                Capsule()
                                    .fill(criteria.ton == ton 
                                          ? AnyShapeStyle(LinearGradient(colors: [Theme.primary, Theme.softIndigo], startPoint: .leading, endPoint: .trailing))
                                          : AnyShapeStyle(Theme.primary.opacity(0.1)))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Sélecteurs secondaires
    private var secondarySelectors: some View {
        HStack(spacing: 16) {
            // Public cible
            VStack(alignment: .leading, spacing: 8) {
                Label("Public", systemImage: "person.2.fill")
                    .font(Theme.roundedFont(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(AIGeneratorCriteria.PublicCible.allCases) { pub in
                        Button(action: { criteria.publicCible = pub }) {
                            Label(pub.rawValue, systemImage: pub.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: criteria.publicCible.icon)
                        Text(criteria.publicCible.rawValue)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(Theme.roundedFont(size: 14, weight: .medium))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
                .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            
            // Style
            VStack(alignment: .leading, spacing: 8) {
                Label("Style", systemImage: "paintbrush.fill")
                    .font(Theme.roundedFont(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(AIGeneratorCriteria.Style.allCases) { style in
                        Button(action: { criteria.style = style }) {
                            Label(style.rawValue, systemImage: style.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: criteria.style.icon)
                        Text(criteria.style.rawValue)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(Theme.roundedFont(size: 14, weight: .medium))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
                .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Section mots-clés
    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mots-clés à intégrer", systemImage: "tag.fill")
                .font(Theme.roundedFont(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            
            // Chips des mots-clés existants
            if !keywords.isEmpty {
                keywordsChipsView
            }
            
            // Champ d'ajout
            HStack(spacing: 12) {
                TextField("Ajouter un mot-clé...", text: $newKeyword)
                    .font(Theme.roundedFont(size: 15))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onSubmit { addKeyword() }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                    )
                
                Button(action: { 
                    addKeyword()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(newKeyword.isEmpty ? .gray : Theme.friendlyGreen)
                }
                .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
    
    // MARK: - Keywords chips view (compatible iOS 15+)
    @ViewBuilder
    private var keywordsChipsView: some View {
        let chipContent = ForEach(keywords, id: \.self) { kw in
            HStack(spacing: 6) {
                Text(kw)
                    .font(Theme.roundedFont(size: 14, weight: .medium))
                Button(action: { 
                    withAnimation(.spring(response: 0.3)) {
                        removeKeyword(kw) 
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(Theme.primary)
            .background(
                Capsule()
                    .fill(Theme.primary.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(Theme.primary.opacity(0.2), lineWidth: 1)
            )
        }
        
        if #available(iOS 16.0, *) {
            FlowLayout(spacing: 8) {
                chipContent
            }
        } else {
            WrappingHStack(spacing: 8) {
                chipContent
            }
        }
    }
    
    // MARK: - Slider nombre de mots
    private var wordCountSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Nombre de mots", systemImage: "textformat.123")
                    .font(Theme.roundedFont(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(wordCount))")
                    .font(Theme.roundedFont(size: 24, weight: .bold))
                    .foregroundColor(Theme.primary)
            }
            
            Slider(value: $wordCount, in: 30...600, step: 10)
                .tint(Theme.primary)
            
            HStack {
                Text("Court")
                    .font(Theme.roundedFont(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Text("~\(max(1, Int(wordCount / 130))) min de lecture")
                    .font(Theme.roundedFont(size: 12, weight: .medium))
                    .foregroundColor(Theme.friendlyGreen)
                Spacer()
                Text("Long")
                    .font(Theme.roundedFont(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
    
    // MARK: - Paramètres avancés
    private var advancedSettings: some View {
        VStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showAdvancedSettings.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Paramètres avancés")
                    Spacer()
                    Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                }
                .font(Theme.roundedFont(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if showAdvancedSettings {
                VStack(spacing: 20) {
                    // Toggle IA en ligne
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("IA en ligne (OpenAI)")
                                .font(Theme.roundedFont(size: 15, weight: .semibold))
                            Text(useOnlineAI ? "Résultats de haute qualité" : "Mode hors-ligne basique")
                                .font(Theme.roundedFont(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $useOnlineAI)
                            .labelsHidden()
                            .tint(Theme.friendlyGreen)
                    }
                    
                    if useOnlineAI {
                        // Clé API
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Clé API OpenAI")
                                .font(Theme.roundedFont(size: 14, weight: .medium))
                            SecureField("sk-...", text: $apiKey)
                                .font(.system(size: 14, design: .monospaced))
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                        
                        // Température
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Créativité")
                                    .font(Theme.roundedFont(size: 14, weight: .medium))
                                Spacer()
                                Text(String(format: "%.1f", temperature))
                                    .font(Theme.roundedFont(size: 14, weight: .bold))
                                    .foregroundColor(Theme.primary)
                            }
                            Slider(value: $temperature, in: 0.1...1.2, step: 0.1)
                                .tint(Theme.lavender)
                            HStack {
                                Text("🎯 Précis")
                                    .font(.caption2)
                                Spacer()
                                Text("🎨 Créatif")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
    }
    
    // MARK: - Résultat généré
    private var generatedResultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Texte généré", systemImage: "doc.text.fill")
                    .font(Theme.roundedFont(size: 16, weight: .semibold))
                Spacer()
                Text("\(generated.split(separator: " ").count) mots")
                    .font(Theme.roundedFont(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(generated)
                .font(Theme.roundedFont(size: 16))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.mintGreen.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.friendlyGreen.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Theme.friendlyGreen.opacity(0.2), radius: 15, y: 6)
    }
    
    // MARK: - Carte d'erreur
    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(Theme.roundedFont(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.accent)
        )
    }
    
    // MARK: - Boutons d'action
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Bouton Générer
            Button(action: { generate() }) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(isLoading ? "Génération en cours..." : "Générer le texte")
                        .font(Theme.roundedFont(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.friendlyPurple, Theme.softIndigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Theme.friendlyPurple.opacity(0.4), radius: 15, y: 8)
            }
            .disabled(isLoading || criteria.sujet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(criteria.sujet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
            
            // Bouton Insérer (si texte généré)
            if !generated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: { 
                    onInsert(generated)
                    dismiss()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.doc.on.clipboard")
                        Text("Utiliser ce texte")
                            .font(Theme.roundedFont(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.friendlyGreen, Theme.friendlyGreen.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Theme.friendlyGreen.opacity(0.4), radius: 15, y: 8)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 30)
    }
    
    // MARK: - Keywords management
    private func addKeyword() {
        let clean = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if !keywords.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
            keywords.append(clean)
            syncConstraintsFromKeywords()
        }
        newKeyword = ""
    }
    
    private func removeKeyword(_ kw: String) {
        keywords.removeAll { $0.caseInsensitiveCompare(kw) == .orderedSame }
        syncConstraintsFromKeywords()
    }
    
    private func syncConstraintsFromKeywords() {
        criteria.contraintes = keywords.joined(separator: ", ")
    }

    private func generate() {
        errorMessage = nil
        generated = ""
        syncConstraintsFromKeywords()
        let targetWords = Int(wordCount)
        if useOnlineAI {
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Veuillez saisir une clé API OpenAI."
                return
            }
            isLoading = true
            Task {
                do {
                    let gen = OpenAITextGenerator(apiKey: apiKey, model: "gpt-4o-mini", temperature: temperature)
                    let text = try await gen.generate(criteria: criteria, wordCount: targetWords)
                    await MainActor.run {
                        generated = text
                        isLoading = false
                        // Sauvegarde clé si nouvelle
                        if SecureStore.load(key: apiKeyStorageKey) == nil {
                            try? SecureStore.save(key: apiKeyStorageKey, data: Data(apiKey.utf8))
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isLoading = false
                    }
                }
            }
        } else {
            let text = AIGenerator.generate(criteria: criteria, wordCount: targetWords)
            generated = text
        }
    }

    private func loadStoredKeyIfAny() {
        if let data = SecureStore.load(key: apiKeyStorageKey), let stored = String(data: data, encoding: .utf8) {
            apiKey = stored
        }
    }

    init(onInsert: @escaping (String) -> Void) {
        self.onInsert = onInsert
    }
}

#if DEBUG
struct AICreationView_Previews: PreviewProvider {
    static var previews: some View {
        AICreationView { _ in }
    }
}
#endif
