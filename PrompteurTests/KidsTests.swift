import XCTest
@testable import Prompteur

@MainActor
final class KidsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testÉtoilesEtBonusDuJour() {
        let r = RewardStore(defaults: freshDefaults())
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let first = r.sentenceRead(today: day)
        XCTAssertEqual(first.stars, 4, "1 étoile + 3 de bonus pour la première lecture du jour")
        XCTAssertEqual(r.sentenceRead(today: day).stars, 1)
        XCTAssertEqual(r.stars, 5)
        XCTAssertEqual(r.streak, 1)
    }

    func testSérieDeJours() {
        let r = RewardStore(defaults: freshDefaults())
        let d1 = Date(timeIntervalSince1970: 1_800_000_000)
        r.sentenceRead(today: d1)
        r.sentenceRead(today: d1.addingTimeInterval(86_400))
        let g = r.sentenceRead(today: d1.addingTimeInterval(2 * 86_400))
        XCTAssertEqual(r.streak, 3)
        XCTAssertTrue(g.badges.contains { $0.id == "trois-jours" })
        // Un jour sauté remet la série à 1.
        r.sentenceRead(today: d1.addingTimeInterval(5 * 86_400))
        XCTAssertEqual(r.streak, 1)
    }

    func testBadgesEtHistoires() {
        let r = RewardStore(defaults: freshDefaults())
        var won: [String] = []
        for _ in 0..<10 { won += r.sentenceRead().badges.map(\.id) }
        XCTAssertTrue(won.contains("premiers-pas"))
        let id = UUID()
        r.textProgress(id, fraction: 0.5)
        XCTAssertEqual(r.starsFor(id), 1)
        let g = r.textFinished(id, wordsPerMinute: 20)
        XCTAssertEqual(g.stars, 5)
        XCTAssertTrue(g.badges.contains { $0.id == "premier-livre" })
        XCTAssertFalse(g.badges.contains { $0.id == "fusee" }, "20 mots/min, ce n'est pas la fusée")
        XCTAssertEqual(r.starsFor(id), 3)
        r.textProgress(id, fraction: 0.1)
        XCTAssertEqual(r.starsFor(id), 3, "Une lecture partielle n'efface pas un meilleur score")
    }

    func testNiveaux() {
        let r = RewardStore(defaults: freshDefaults())
        XCTAssertEqual(r.level.name, "Graine de lecteur")
        var newLevel: RewardStore.Level?
        for _ in 0..<20 { if let l = r.sentenceRead().newLevel { newLevel = l } }
        XCTAssertEqual(newLevel?.name, "Petite pousse")
        XCTAssertGreaterThan(r.levelProgress, 0)
    }

    func testPasDeVitesseFins() {
        XCTAssertEqual(ReaderSettings.stepped(20, up: true), 22)
        XCTAssertEqual(ReaderSettings.stepped(30, up: true), 35)
        XCTAssertEqual(ReaderSettings.stepped(30, up: false), 28)
        XCTAssertEqual(ReaderSettings.stepped(100, up: true), 110)
        XCTAssertEqual(ReaderSettings.stepped(11, up: false), 10)
        XCTAssertEqual(ReaderSettings.speedRange.lowerBound, 10)
    }

    func testVoixLenteDécoupée() {
        let doc = PrompterDocument(text: "Le chat dort. Le chien joue dehors.")
        let last = doc.words.count - 1
        XCTAssertEqual(SpeechEngine.chunks(doc, from: 0, through: last, wordsPerMinute: 120).count, 1)
        let sentences = SpeechEngine.chunks(doc, from: 0, through: last, wordsPerMinute: 25)
        XCTAssertEqual(sentences.map(\.words), [0..<3, 3..<7])
        XCTAssertTrue(sentences.allSatisfy { $0.pause > 0 })
        XCTAssertEqual(SpeechEngine.chunks(doc, from: 0, through: last, wordsPerMinute: 12).count, doc.words.count)
        XCTAssertLessThan(SpeechEngine.rate(forWordsPerMinute: 12), SpeechEngine.rate(forWordsPerMinute: 40))
    }

    func testRéglagesSéparésParProfil() {
        let d = freshDefaults()
        let store = SettingsStore(defaults: d)
        XCTAssertEqual(store.kids.style, .sky)
        XCTAssertEqual(store.kids.wordsPerMinute, 20)
        store[.kids].wordsPerMinute = 14
        store[.studio].wordsPerMinute = 150
        let reloaded = SettingsStore(defaults: d)
        XCTAssertEqual(reloaded.kids.wordsPerMinute, 14)
        XCTAssertEqual(reloaded.reader.wordsPerMinute, 150)
    }

    func testMotSuivant() {
        let doc = PrompterDocument(text: "Un deux trois quatre.")
        let engine = PrompterEngine(document: doc)
        engine.jumpWord(1)
        engine.jumpWord(1)
        XCTAssertEqual(engine.currentWord, 2)
        engine.jumpWord(10)
        XCTAssertEqual(engine.currentWord, doc.words.count - 1)
        engine.shutdown()
    }
}
