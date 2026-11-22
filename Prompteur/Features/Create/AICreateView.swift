import SwiftUI

/// Créer un texte avec l'IA : sujet, public, type, ton, longueur.
struct AICreateView: View {
    @Environment(ScriptStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var request = AIRequest()
    @State private var engine: AIEngine = AIService.appleStatus.available ? .apple : .openAI
    @State private var apiKey = AIService.storedKey
    @State private var result = ""
    @State private var working = false
    @State private var error: String?
    @State private var showEngine = false
    @FocusState private var subjectFocused: Bool

    private let ideas = ["un chat astronaute", "le cycle de l'eau", "mon anniversaire", "les dinosaures",
                         "présenter ma chaîne", "la rentrée", "un robot gentil", "les volcans"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    subjectField
                    choice("Pour qui ?", AIRequest.Audience.allCases, selection: $request.audience) { Text($0.rawValue) }
                    choice("Quel texte ?", AIRequest.Kind.allCases, selection: $request.kind) {
                        Label($0.rawValue, systemImage: $0.symbol)
                    }
                    choice("Quel ton ?", AIRequest.Tone.allCases, selection: $request.tone) { Text($0.rawValue) }
                    choice("Longueur", AIRequest.Length.allCases, selection: $request.length) {
                        Text("\($0.rawValue) · ~\($0.words) mots")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle("Mots à placer (facultatif)")
                        TextField("ex. Pistache, une lanterne, l'océan", text: $request.mustInclude)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.hairline))
                    }
                    engineSection
                    if let error { errorCard(error) }
                    if !result.isEmpty { resultCard }
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle("Créer avec l'IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
        .tint(Palette.indigo)
    }

    // MARK: Éléments

    private var subjectField: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("De quoi parle le texte ?")
            TextField("Un sujet, une idée…", text: $request.subject, axis: .vertical)
                .font(Typo.headline(20))
                .lineLimit(1...3)
                .focused($subjectFocused)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(subjectFocused ? Palette.indigo : Palette.hairline,
                                                                         lineWidth: subjectFocused ? 2 : 1))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ideas, id: \.self) { idea in
                        Button(idea) { request.subject = idea; Haptics.tick() }
                            .font(Typo.caption(13))
                            .foregroundStyle(Palette.indigo)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Palette.indigo.opacity(0.1)))
                    }
                }
            }
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(Typo.headline(15)).foregroundStyle(Palette.ink)
    }

    private func choice<T: Hashable & Identifiable, L: View>(_ title: String, _ options: [T], selection: Binding<T>,
                                                         @ViewBuilder label: @escaping (T) -> L) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            FlowLayout(spacing: 8) {
                ForEach(options) { o in
                    let on = selection.wrappedValue == o
                    Button {
                        selection.wrappedValue = o
                        Haptics.tick()
                    } label: {
                        label(o)
                            .font(Typo.headline(14))
                            .foregroundStyle(on ? .white : Palette.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(on ? Palette.indigo : Palette.surface))
                            .overlay(Capsule().strokeBorder(on ? .clear : Palette.hairline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var engineSection: some View {
        let apple = AIService.appleStatus
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { showEngine.toggle() }
            } label: {
                HStack {
                    Image(systemName: engine == .apple ? "wand.and.sparkles" : "key.fill")
                    Text("Moteur : \(engine.title)")
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(showEngine ? 180 : 0))
                }
                .font(Typo.headline(14))
                .foregroundStyle(Palette.inkSoft)
            }
            .buttonStyle(.plain)

            if showEngine {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Moteur", selection: $engine) {
                        ForEach(AIEngine.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if engine == .apple {
                        Label(apple.reason, systemImage: apple.available ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(Typo.body(13))
                            .foregroundStyle(apple.available ? Palette.leaf : Palette.inkSoft)
                    } else {
                        SecureField("Clé API OpenAI (sk-…)", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.hairline))
                            .onChange(of: apiKey) { _, v in AIService.storedKey = v }
                        Text("La clé reste dans le Trousseau de cet appareil. Seule ta demande est envoyée à OpenAI.")
                            .font(Typo.body(12))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.bubble.fill")
            .font(Typo.body(14))
            .foregroundStyle(Palette.onAirDeep)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.onAir.opacity(0.1)))
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Ton texte")
                Spacer()
                Tag(text: Format.words(Script(title: "", content: result).wordCount), tint: Palette.indigo)
            }
            TextEditor(text: $result)
                .font(Typo.body(17))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 240)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 18).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.hairline))
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button(action: generate) {
                HStack {
                    if working { ProgressView().tint(.white) } else { Image(systemName: "sparkles") }
                    Text(result.isEmpty ? "Écrire le texte" : "Recommencer")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(color: Palette.indigo))
            .disabled(working || request.subject.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(request.subject.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

            if !result.isEmpty && !working {
                Button(action: keep) {
                    Label("Garder", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: Actions

    private func generate() {
        subjectFocused = false
        error = nil
        working = true
        Task {
            do {
                let text = try await AIService.generate(request, engine: engine)
                withAnimation(.snappy) { result = text }
                Haptics.success()
            } catch {
                withAnimation { self.error = error.localizedDescription }
                Haptics.warning()
            }
            working = false
        }
    }

    private func keep() {
        let title = request.subject.prefix(1).uppercased() + request.subject.dropFirst()
        if let s = store.create(title: String(title), content: result) {
            dismiss()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                router.edit(s.id)
                router.show("Texte ajouté à ta bibliothèque")
            }
        } else {
            dismiss()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                router.sheet = .premium
            }
        }
    }
}

/// Disposition en lignes qui retournent à la ligne (puces de choix).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let h = rows.last.map { $0.y + $0.height } ?? 0
        let w = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            for (i, x) in zip(row.indices, row.xs) {
                subviews[i].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + row.y), proposal: .unspecified)
            }
        }
    }

    private struct Row { var indices: [Int] = []; var xs: [CGFloat] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        var x: CGFloat = 0, y: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let size = v.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += (rows[rows.count - 1].height) + spacing
                rows.append(Row(y: y))
                x = 0
            }
            rows[rows.count - 1].indices.append(i)
            rows[rows.count - 1].xs.append(x)
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            x += size.width + spacing
            rows[rows.count - 1].width = x - spacing
        }
        return rows
    }
}
