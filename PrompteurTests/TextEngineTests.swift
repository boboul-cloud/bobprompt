import XCTest
import UIKit
@testable import Prompteur

final class SyllabifierTests: XCTestCase {
    private func split(_ w: String) -> String { FrenchSyllabifier.syllables(of: w).joined(separator: "-") }

    func testRèglesDeBase() {
        XCTAssertEqual(split("ami"), "a-mi")
        XCTAssertEqual(split("chocolat"), "cho-co-lat")
        XCTAssertEqual(split("tableau"), "ta-bleau")
        XCTAssertEqual(split("partir"), "par-tir")
        XCTAssertEqual(split("pomme"), "pom-me")
        XCTAssertEqual(split("livre"), "li-vre")
        XCTAssertEqual(split("bonjour"), "bon-jour")
        XCTAssertEqual(split("renard"), "re-nard")
        XCTAssertEqual(split("amusant"), "a-mu-sant")
        XCTAssertEqual(split("prononcer"), "pro-non-cer")
    }

    func testGraphèmesInsécables() {
        XCTAssertEqual(split("montagne"), "mon-ta-gne")
        XCTAssertEqual(split("guitare"), "gui-ta-re")
        XCTAssertEqual(split("quatre"), "qua-tre")
        XCTAssertEqual(split("magique"), "ma-gi-que")
        XCTAssertEqual(split("papillon"), "pa-pi-llon")
        XCTAssertEqual(split("éléphant"), "é-lé-phant")
    }

    func testGroupesDeConsonnes() {
        XCTAssertEqual(split("instruction"), "ins-truc-tion")
        XCTAssertEqual(split("obscur"), "obs-cur")
        XCTAssertEqual(split("monstre"), "mons-tre")
        XCTAssertEqual(split("syllabes"), "syl-la-bes")
    }

    func testVoyelles() {
        XCTAssertEqual(split("oiseau"), "oi-seau")
        XCTAssertEqual(split("poème"), "po-è-me")
        XCTAssertEqual(split("théâtre"), "thé-â-tre")
        XCTAssertEqual(split("Léo"), "Lé-o")
        XCTAssertEqual(split("aéroport"), "a-é-ro-port")
    }

    func testMotsParticuliers() {
        XCTAssertEqual(split("l'école"), "l'é-co-le")
        XCTAssertEqual(FrenchSyllabifier.syllables(of: "arc-en-ciel"), ["arc-", "en-", "ciel"])
        XCTAssertEqual(split("Bonjour\u{00A0}!"), "Bon-jour\u{00A0}!")
        XCTAssertEqual(split("à"), "à")
        XCTAssertEqual(split("2026"), "2026")
        XCTAssertEqual(split("ÉCOLE"), "É-CO-LE")
    }

    func testLesSyllabesRecomposentLeMot() {
        for w in ["anticonstitutionnellement", "Qu'est-ce", "«Oh", "aujourd'hui", "hérisson", "x"] {
            XCTAssertEqual(FrenchSyllabifier.syllables(of: w).joined(), w)
        }
    }
}

final class DocumentTests: XCTestCase {
    func testPonctuationIsoléeRattachée() {
        let doc = PrompterDocument(text: "Hé ! bonjour , Monsieur « du » Corbeau .")
        XCTAssertEqual(doc.words.map(\.text), ["Hé\u{00A0}!", "bonjour\u{00A0},", "Monsieur", "«\u{00A0}du\u{00A0}»", "Corbeau\u{00A0}."])
    }

    func testPhrasesEtParagraphes() {
        let doc = PrompterDocument(text: "Il était une fois. Un dragon !\n\nIl avait peur du noir\nMais pas toujours.")
        XCTAssertEqual(doc.sentences.count, 4)
        XCTAssertEqual(doc.sentenceText(0), "Il était une fois.")
        XCTAssertEqual(doc.sentenceText(1), "Un dragon !".replacingOccurrences(of: " !", with: "\u{00A0}!"))
        XCTAssertEqual(doc.words[6].breakBefore, 2)
        XCTAssertEqual(doc.words.first { $0.text == "Mais" }?.breakBefore, 1)
        XCTAssertEqual(doc.words.last?.sentence, 3)
    }

    func testAbréviationsNeCoupentPasLaPhrase() {
        let doc = PrompterDocument(text: "Bonjour M. Dupont, comment allez-vous ?")
        XCTAssertEqual(doc.sentences.count, 1)
    }

    func testPlagesUTF16PourLaVoix() {
        let text = "Le café 🍵 est très chaud !"
        let doc = PrompterDocument(text: text)
        let ns = text as NSString
        for w in doc.words {
            XCTAssertEqual(ns.substring(with: w.range).replacingOccurrences(of: " ", with: "\u{00A0}"), w.text)
        }
        let chaud = doc.words.last!.range.location
        XCTAssertEqual(doc.wordIndex(atUTF16: chaud), doc.words.count - 1)
    }

    func testTexteVide() {
        let doc = PrompterDocument(text: "  \n\n ")
        XCTAssertTrue(doc.isEmpty)
        XCTAssertEqual(doc.timeline.total, 0)
        XCTAssertEqual(doc.timeline.wordIndex(atBeat: 3), 0)
    }
}

final class TimelineTests: XCTestCase {
    func testAllerRetourMotsTemps() {
        let t = Timeline(weights: [1, 2, 1, 0.5])
        XCTAssertEqual(t.total, 4.5, accuracy: 1e-9)
        XCTAssertEqual(t.wordPosition(atBeat: 0), 0)
        XCTAssertEqual(t.wordPosition(atBeat: 2), 1.5, accuracy: 1e-9)
        XCTAssertEqual(t.wordIndex(atBeat: 3.2), 2)
        for p in stride(from: 0.0, through: 4.0, by: 0.25) {
            XCTAssertEqual(t.wordPosition(atBeat: t.beat(atWordPosition: p)), p, accuracy: 1e-9)
        }
    }

    func testMiseEnLignes() {
        let doc = PrompterDocument(text: "Un deux trois quatre cinq six sept huit neuf dix.\nOnze douze.")
        let font = UIFont.systemFont(ofSize: 30)
        let layout = LineLayout.make(document: doc, font: font, maxWidth: 200)
        XCTAssertGreaterThan(layout.lines.count, 2)
        // Chaque mot appartient à exactement une ligne, dans l'ordre.
        XCTAssertEqual(layout.lines.flatMap { Array($0.words) }, Array(0..<doc.words.count))
        // Le retour à la ligne du texte force une nouvelle ligne.
        let onze = doc.words.firstIndex { $0.text == "Onze" }!
        XCTAssertEqual(layout.lines[layout.lineOfWord[onze]].words.first, onze)
        // Aucune ligne de plusieurs mots ne dépasse la largeur.
        for l in layout.lines where l.words.count > 1 { XCTAssertLessThanOrEqual(l.width, 200.5) }
        // Même durée totale que la lecture naturelle, défilement régulier.
        XCTAssertEqual(layout.timeline.total, doc.timeline.total, accuracy: 1e-6)
        let mid = layout.lines[1]
        XCTAssertEqual(layout.y(atBeat: layout.timeline.start(ofWord: mid.words.lowerBound)), mid.top, accuracy: 0.5)
    }

    func testUnMotParLigne() {
        let doc = PrompterDocument(text: "Un deux trois")
        let layout = LineLayout.make(document: doc, font: .systemFont(ofSize: 20), maxWidth: 1000, oneWordPerLine: true)
        XCTAssertEqual(layout.lines.count, 3)
    }
}

final class ScriptStoreTests: XCTestCase {
    @MainActor
    func testLectureDesTextesDeLaVersion1() throws {
        let legacy = """
        [{"id":"0E1A6F5C-0000-4000-8000-000000000001","title":"Vieux","content":"Bonjour","date":700000000}]
        """
        let scripts = try JSONDecoder().decode([Script].self, from: Data(legacy.utf8))
        XCTAssertEqual(scripts.first?.title, "Vieux")
        XCTAssertEqual(scripts.first?.content, "Bonjour")
        XCTAssertEqual(scripts.first?.lastWord, 0)
        XCTAssertEqual(scripts.first?.updatedAt, scripts.first?.date)
    }

    @MainActor
    func testLimiteGratuiteEtPremium() {
        let mem = MemoryScriptPersistence()
        let store = ScriptStore(persistence: mem)
        var premium = false
        store.isPremium = { premium }
        XCTAssertNotNil(store.create(title: "A"))
        XCTAssertNotNil(store.create(title: "B"))
        XCTAssertNil(store.create(title: "C"), "2 textes maximum en gratuit")
        premium = true
        XCTAssertNotNil(store.create(title: "C"))
        store.flush()
        XCTAssertEqual(mem.stored?.count, 3)
    }

    @MainActor
    func testModifierNeCréePasDeDoublon() {
        let mem = MemoryScriptPersistence()
        let store = ScriptStore(persistence: mem)
        var s = store.create(title: "Titre", content: "Un")!
        s.content = "Un deux"
        store.update(s)
        s.title = "Nouveau titre"
        store.update(s)
        XCTAssertEqual(store.scripts.count, 1)
        XCTAssertEqual(store.scripts.first?.content, "Un deux")
        XCTAssertEqual(store.scripts.first?.title, "Nouveau titre")
    }

    @MainActor
    func testTexteVideAbandonnéSupprimé() {
        let store = ScriptStore(persistence: MemoryScriptPersistence())
        let s = store.create()!
        store.discardIfBlank(s.id)
        XCTAssertTrue(store.scripts.isEmpty)
    }

    @MainActor
    func testTrousseauIllisibleNÉcrasePasLesTextes() {
        let existing = [Script(title: "Gardé", content: "Un texte précieux")]
        let mem = MemoryScriptPersistence(existing)
        mem.failNextLoad = true
        let store = ScriptStore(persistence: mem)
        XCTAssertTrue(store.loadFailed)
        XCTAssertNotNil(store.create(title: "Nouveau", content: "Écrit entre-temps"))
        store.flush()   // relit, fusionne, puis enregistre
        XCTAssertEqual(Set(mem.stored?.map(\.title) ?? []), ["Gardé", "Nouveau"])
    }

    func testRéglagesTolérants() throws {
        let json = #"{"style":"inconnu","fontSize":500,"voiceOn":true}"#
        let s = try JSONDecoder().decode(ReaderSettings.self, from: Data(json.utf8))
        XCTAssertEqual(s.style, .classic)
        XCTAssertEqual(s.fontSize, ReaderSettings.fontRange.upperBound)
        XCTAssertTrue(s.voiceOn)
    }
}
