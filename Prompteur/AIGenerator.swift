// filepath: /Volumes/Seagate Backup Plus Drive/Prompteur/Prompteur/AIGenerator.swift
import Foundation
import SwiftUI

struct AIGeneratorCriteria: Equatable {
    var sujet: String = ""
    var objectif: Objectif = .informer
    var ton: Ton = .amical
    var publicCible: PublicCible = .grandPublic
    var style: Style = .storytelling
    var contraintes: String = ""

    enum Objectif: String, CaseIterable, Identifiable { 
        case informer = "Informer", convaincre = "Convaincre", divertir = "Divertir", inspirer = "Inspirer"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .informer: return "info.circle.fill"
            case .convaincre: return "hand.raised.fill"
            case .divertir: return "face.smiling.fill"
            case .inspirer: return "sparkles"
            }
        }
        var color: Color {
            switch self {
            case .informer: return Theme.neonBlue
            case .convaincre: return Theme.warmOrange
            case .divertir: return Theme.neonPink
            case .inspirer: return Theme.lavender
            }
        }
    }
    enum Ton: String, CaseIterable, Identifiable { 
        case amical = "Amical", professionnel = "Professionnel", inspirant = "Inspirant", humoristique = "Humoristique", neutre = "Neutre"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .amical: return "heart.fill"
            case .professionnel: return "briefcase.fill"
            case .inspirant: return "star.fill"
            case .humoristique: return "theatermasks.fill"
            case .neutre: return "circle.fill"
            }
        }
    }
    enum PublicCible: String, CaseIterable, Identifiable { 
        case enfants = "Enfants", ados = "Adolescents", adultes = "Adultes", pros = "Professionnels", grandPublic = "Grand public"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .enfants: return "figure.child"
            case .ados: return "figure.wave"
            case .adultes: return "person.fill"
            case .pros: return "person.crop.rectangle.stack.fill"
            case .grandPublic: return "person.3.fill"
            }
        }
    }
    enum Style: String, CaseIterable, Identifiable { 
        case storytelling = "Storytelling", tutoriel = "Tutoriel", liste = "Liste", discours = "Discours", annonce = "Annonce"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .storytelling: return "book.fill"
            case .tutoriel: return "graduationcap.fill"
            case .liste: return "list.bullet"
            case .discours: return "mic.fill"
            case .annonce: return "megaphone.fill"
            }
        }
    }
}

enum AIGenerator {
    static func generate(criteria: AIGeneratorCriteria, wordCount: Int) -> String {
        let wc = max(10, min(1200, wordCount))
        var sentences: [String] = []

        let sujet = criteria.sujet.isEmpty ? "votre sujet" : criteria.sujet
        let motsContraintes = criteria.contraintes
            .split{ $0 == "," || $0 == ";" || $0 == "\n" }
            .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter{ !$0.isEmpty }

        let accroches = accrochesPour(criteria: criteria, sujet: sujet)
        let corps = paragraphesPour(criteria: criteria, sujet: sujet, contraintes: motsContraintes)
        let conclusions = conclusionsPour(criteria: criteria, sujet: sujet)

        sentences.append(contentsOf: accroches)
        sentences.append(contentsOf: corps)
        sentences.append(contentsOf: conclusions)

        // Aplatir en texte et ajuster au nombre de mots demandé
        let text = sentences.joined(separator: " ")
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter{ !$0.isEmpty }
        if words.count <= wc { return text }
        // Tronquer proprement à la fin d'une phrase ou au plus proche
        var count = 0
        var builder: [String] = []
        for w in words {
            builder.append(w)
            count += 1
            if count >= wc {
                break
            }
        }
        var truncated = builder.joined(separator: " ")
        if let lastDot = truncated.lastIndex(of: ".") ?? truncated.lastIndex(of: "!") ?? truncated.lastIndex(of: "?") {
            truncated = String(truncated[...lastDot])
        } else {
            truncated.append("…")
        }
        return truncated
    }

    private static func accrochesPour(criteria: AIGeneratorCriteria, sujet: String) -> [String] {
        let prefix: String
        switch criteria.ton {
        case .amical: prefix = "Salut !"
        case .professionnel: prefix = "Bonjour," 
        case .inspirant: prefix = "Imaginez ceci :"
        case .humoristique: prefix = "Plot twist :"
        case .neutre: prefix = "Note d'introduction :"
        }
        let cible: String
        switch criteria.publicCible {
        case .enfants: cible = "les enfants"
        case .ados: cible = "les ados"
        case .adultes: cible = "les adultes"
        case .pros: cible = "les pros"
        case .grandPublic: cible = "tout le monde"
        }
        let obj: String
        switch criteria.objectif {
        case .informer: obj = "Voici l'essentiel à connaître sur"
        case .convaincre: obj = "Laissez-moi vous montrer pourquoi"
        case .divertir: obj = "Et si on s'amusait avec"
        case .inspirer: obj = "Prenons une grande inspiration autour de"
        }
        switch criteria.style {
        case .storytelling:
            return ["\(prefix) Il était une fois \(cible), une histoire autour de \(sujet).", "\(obj) \(sujet), sans jargon ni détour."]
        case .tutoriel:
            return ["\(prefix) Aujourd'hui, on apprend ensemble \(sujet).", "\(obj) \(sujet) en étapes simples."]
        case .liste:
            return ["\(prefix) Top départ : 3 points rapides sur \(sujet)."]
        case .discours:
            return ["\(prefix) Chers toutes et tous, parlons de \(sujet)."]
        case .annonce:
            return ["\(prefix) Grande nouvelle concernant \(sujet) !"]
        }
    }

    private static func paragraphesPour(criteria: AIGeneratorCriteria, sujet: String, contraintes: [String]) -> [String] {
        var lines: [String] = []
        let extras = contraintes.isEmpty ? "" : " Mots-clés : " + contraintes.joined(separator: ", ") + "."

        switch criteria.style {
        case .storytelling:
            lines.append("Au départ, \(sujet) semblait lointain. Puis tout a changé : une petite action a entraîné une grande différence.")
            lines.append("Pas à pas, l'idée a pris forme, portée par la curiosité et l'envie d'apprendre.")
        case .tutoriel:
            lines.append("Étape 1 — Comprendre l'objectif : clarifier ce que \(sujet) doit accomplir.")
            lines.append("Étape 2 — Mettre en pratique : appliquer une méthode simple, mesurable et reproductible.")
            lines.append("Étape 3 — Vérifier et améliorer : ajuster, simplifier et partager.")
        case .liste:
            lines.append("• Pourquoi c'est important : parce que \(sujet) touche notre quotidien.")
            lines.append("• Le point clé : une règle claire vaut mieux qu'un long discours.")
            lines.append("• À retenir : commencer petit, progresser vite.")
        case .discours:
            lines.append("Nous avons une opportunité : faire de \(sujet) un vecteur d'impact positif.")
            lines.append("En unissant nos forces, nous pouvons avancer plus vite et mieux.")
        case .annonce:
            lines.append("Voici l'essentiel : \(sujet) arrive avec des bénéfices concrets et mesurables.")
            lines.append("Restez à l'écoute : d'autres détails et démonstrations suivent bientôt.")
        }

        switch criteria.ton {
        case .amical: lines.append("En bref, rien de sorcier : on y va ensemble, simplement.")
        case .professionnel: lines.append("Conclusion provisoire : indicateurs, risques et prochaines étapes sont identifiés.")
        case .inspirant: lines.append("Souvenez-vous : chaque pas compte, surtout le premier.")
        case .humoristique: lines.append("Morale de l'histoire : le café aide, mais pas autant qu'une bonne idée.")
        case .neutre: lines.append("Synthèse : points clés recensés et pistes d'action définies.")
        }

        if !extras.isEmpty { lines.append(extras) }
        return lines
    }

    private static func conclusionsPour(criteria: AIGeneratorCriteria, sujet: String) -> [String] {
        let callToAction: String
        switch criteria.objectif {
        case .informer: callToAction = "Envie d'en savoir plus ? Passons à la suite."
        case .convaincre: callToAction = "Prêt à tenter l'expérience ? Faisons le premier pas."
        case .divertir: callToAction = "Si ça vous a plu, on remet ça très vite !"
        case .inspirer: callToAction = "Commencez aujourd'hui : un geste simple, un vrai élan."
        }
        return [callToAction]
    }
}
