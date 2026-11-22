import SwiftUI

/// Écriture d'un texte. Tout est enregistré au fil de la frappe : plus de bouton
/// « Enregistrer », donc plus de doublons.
struct EditorView: View {
    @Environment(ScriptStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let scriptID: UUID
    var presentedFromReader = false

    @State private var title = ""
    @State private var content = ""
    @State private var loaded = false
    @State private var preview = false
    @State private var confirmClear = false
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    enum Field { case title, body }

    var body: some View {
        let accent = Palette.cardColor(store.script(scriptID)?.colorIndex ?? 0)
        VStack(spacing: 0) {
            TextField("Titre", text: $title, axis: .vertical)
                .font(Typo.title(28))
                .foregroundStyle(Palette.ink)
                .lineLimit(1...3)
                .focused($focus, equals: .title)
                .submitLabel(.next)
                .onSubmit { focus = .body }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 8)

            ZStack(alignment: .topLeading) {
                if preview {
                    ScrollView {
                        SyllableDocumentView(text: content, settings: settings.reader)
                            .padding(18)
                    }
                } else {
                    TextEditor(text: $content)
                        .font(Typo.body(19))
                        .foregroundStyle(Palette.ink)
                        .scrollContentBackground(.hidden)
                        .focused($focus, equals: .body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    if content.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Écris ou colle ton texte ici…")
                                .font(Typo.body(19))
                                .foregroundStyle(Palette.inkSoft.opacity(0.7))
                            PasteButton(payloadType: String.self) { strings in
                                guard let s = strings.first else { return }
                                Task { @MainActor in content = s }
                            }
                            .buttonBorderShape(.capsule)
                            .tint(accent)
                        }
                        .padding(.horizontal, 17)
                        .padding(.vertical, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.hairline))
            .padding(.horizontal, 14)

            statsBar(accent: accent)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar(accent: accent) }
        .onAppear(perform: load)
        .onDisappear {
            // Depuis le lecteur, un texte vidé reste en place : le lecteur s'en charge.
            if !presentedFromReader { store.discardIfBlank(scriptID) }
            store.flush()
        }
        .onChange(of: title) { save() }
        .onChange(of: content) { save() }
        .confirmationDialog("Effacer tout le texte ?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Effacer le texte", role: .destructive) { content = "" }
        }
        .confirmationDialog("Supprimer ce texte ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                store.delete(scriptID)
                dismiss()
            }
        } message: {
            Text("Il sera effacé définitivement.")
        }
    }

    @ToolbarContentBuilder
    private func toolbar(accent: Color) -> some ToolbarContent {
        if presentedFromReader {
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") { save(); dismiss() }.fontWeight(.bold)
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                withAnimation(.snappy) { preview.toggle() }
                focus = nil
            } label: {
                Image(systemName: preview ? "pencil" : "textformat.abc.dottedunderline")
            }
            .accessibilityLabel(preview ? "Revenir à l'écriture" : "Aperçu des syllabes")

            Menu {
                if let script = store.script(scriptID) {
                    ShareLink(item: shareText(script)) { Label("Partager", systemImage: "square.and.arrow.up") }
                }
                Button { confirmClear = true } label: { Label("Effacer le texte", systemImage: "eraser") }
                    .disabled(content.isEmpty)
                Button(role: .destructive) { confirmDelete = true } label: { Label("Supprimer", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Plus d'actions")

            if !presentedFromReader {
                Button {
                    save()
                    focus = nil
                    if let s = store.script(scriptID) { router.read(s) }
                } label: {
                    Label("Lire", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                        .font(Typo.headline(15))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(accent)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Terminé") { focus = nil }.fontWeight(.semibold)
        }
    }

    private func statsBar(accent: Color) -> some View {
        let doc = Script(title: title, content: content)
        let words = doc.wordCount
        let wpm = settings.reader.wordsPerMinute
        return HStack(spacing: 8) {
            Tag(text: Format.words(words), tint: accent)
            Tag(text: "≈ " + Format.duration(Double(words) / max(1, wpm) * 60) + " à \(Int(wpm)) mots/min",
                symbol: "clock", tint: Palette.inkSoft)
            Spacer()
            Label("Enregistré", systemImage: "checkmark.circle.fill")
                .font(Typo.caption(12))
                .foregroundStyle(Palette.inkSoft)
                .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    /// Recharge toujours la dernière version : le texte a pu être modifié
    /// ailleurs (depuis le lecteur) pendant que cet écran était caché.
    private func load() {
        guard let s = store.script(scriptID) else {
            loaded = false
            dismiss()
            return
        }
        let first = !loaded
        if title != s.title { title = s.title }
        if content != s.content { content = s.content }
        loaded = true
        if first, s.content.isEmpty, s.title.isEmpty { focus = .title }
    }

    private func save() {
        guard loaded, var s = store.script(scriptID) else { return }
        s.title = title
        s.content = content
        store.update(s)
    }

    private func shareText(_ s: Script) -> String {
        let t = s.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? s.content : "\(t)\n\n\(s.content)"
    }
}

/// Texte complet avec syllabes colorées (aperçu dans l'éditeur).
struct SyllableDocumentView: View {
    let text: String
    let settings: ReaderSettings

    var body: some View {
        let doc = PrompterDocument(text: text)
        var paint = LinePaint(base: Palette.ink)
        let (a, b) = settings.syllableColors(onDark: false)
        paint.syllableA = a
        paint.syllableB = b
        var out = AttributedString()
        var start = 0
        for (i, w) in doc.words.enumerated() where i > 0 && w.breakBefore > 0 {
            out.append(TextStyler.line(doc, words: start..<i, paint: paint))
            out.append(AttributedString(w.breakBefore > 1 ? "\n\n" : "\n"))
            start = i
        }
        if start < doc.words.count { out.append(TextStyler.line(doc, words: start..<doc.words.count, paint: paint)) }
        return Text(out)
            .font(Font(ui: settings.font.uiFont(size: 24)))
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}
