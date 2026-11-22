import XCTest
import UIKit
@testable import Prompteur

@MainActor
final class EngineTests: XCTestCase {
    private let text = "Il était une fois un dragon. Il avait peur du noir !\nUn soir, la lune s'éteignit. Fin."

    func testLecturePauseRedémarrage() {
        let engine = PrompterEngine(document: PrompterDocument(text: text))
        XCTAssertEqual(engine.phase, .idle)
        engine.toggle(countdown: false)
        XCTAssertEqual(engine.phase, .playing)
        engine.toggle(countdown: false)
        XCTAssertEqual(engine.phase, .paused)
        engine.seek(toWord: 5)
        XCTAssertEqual(engine.currentWord, 5)
        engine.restart()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.beat, 0)
        engine.shutdown()
    }

    func testCompteÀRebours() {
        let engine = PrompterEngine(document: PrompterDocument(text: text))
        engine.toggle(countdown: true)
        XCTAssertEqual(engine.phase, .countdown(3))
        engine.toggle(countdown: true)   // un appui pendant le décompte l'annule
        XCTAssertEqual(engine.phase, .idle)
        engine.shutdown()
    }

    func testChangerDeModeGardeLeMot() {
        let doc = PrompterDocument(text: text)
        let engine = PrompterEngine(document: doc)
        engine.seek(toWord: 9)
        let layout = LineLayout.make(document: doc, font: .systemFont(ofSize: 30), maxWidth: 220)
        engine.setTimeline(layout.timeline)
        XCTAssertEqual(engine.currentWord, 9)
        engine.setTimeline(doc.timeline)
        XCTAssertEqual(engine.currentWord, 9)
        engine.shutdown()
    }

    func testNavigationParPhrase() {
        let doc = PrompterDocument(text: text)
        let engine = PrompterEngine(document: doc)
        engine.jumpSentence(1)
        XCTAssertEqual(engine.currentWord, doc.sentences[1].words.lowerBound)
        engine.jumpSentence(1)
        XCTAssertEqual(engine.currentWord, doc.sentences[2].words.lowerBound)
        // Au milieu d'une phrase, « précédent » revient à son début.
        engine.seek(toWord: doc.sentences[2].words.lowerBound + 3)
        engine.jumpSentence(-1)
        XCTAssertEqual(engine.currentWord, doc.sentences[2].words.lowerBound)
        engine.jumpSentence(-1)
        XCTAssertEqual(engine.currentWord, doc.sentences[1].words.lowerBound)
        // On ne sort pas du texte.
        for _ in 0..<10 { engine.jumpSentence(1) }
        XCTAssertEqual(engine.currentWord, doc.sentences.last!.words.lowerBound)
        engine.shutdown()
    }

    func testPremièreEtDernièreLigneCentrées() {
        let doc = PrompterDocument(text: text)
        let layout = LineLayout.make(document: doc, font: .systemFont(ofSize: 30), maxWidth: 220)
        XCTAssertEqual(layout.readingY(atBeat: 0), layout.lines.first!.center, accuracy: 0.5)
        XCTAssertEqual(layout.readingY(atBeat: layout.timeline.total), layout.lines.last!.center, accuracy: 0.5)
        // La position avance toujours (pas de recul pendant la lecture).
        var previous = -CGFloat.infinity
        for k in 0...200 {
            let y = layout.readingY(atBeat: layout.timeline.total * Double(k) / 200)
            XCTAssertGreaterThanOrEqual(y, previous - 0.001)
            previous = y
        }
    }

    func testVitesseVoix() {
        XCTAssertLessThan(SpeechEngine.rate(forWordsPerMinute: 60), SpeechEngine.rate(forWordsPerMinute: 200))
        XCTAssertEqual(SpeechEngine.rate(forWordsPerMinute: 175), 0.5, accuracy: 0.001)
    }
}
