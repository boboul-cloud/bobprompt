import Foundation

/// Textes fournis avec l'app : lisibles tout de suite, non comptés dans la limite.
enum SampleScripts {
    static let all: [Script] = [dragon, corbeau, herisson, cigale, video, toast]

    static let dragon = Script(
        id: UUID(uuidString: "6B1D8E40-0001-4C3A-9C41-0B0B0B0B0001")!,
        title: "Le dragon qui avait peur du noir",
        content: """
        Il était une fois un petit dragon vert qui s'appelait Pistache.

        Pistache savait voler. Il savait cracher des bulles de feu. Mais il avait peur du noir !

        Chaque soir, il allumait une petite lune dans sa grotte. La lune faisait des ombres sur le mur : un lapin, un bateau, un chapeau.

        Un soir, la lune s'éteignit. Pistache trembla. Puis il souffla très doucement, et une flamme bleue dansa devant lui.

        « Oh ! dit-il. Je suis ma propre lumière. »

        Depuis ce jour, Pistache n'a plus peur du noir. Et toi, quelle est ta lumière ?
        """,
        colorIndex: 5, isSample: true, symbol: "flame.fill")

    static let corbeau = Script(
        id: UUID(uuidString: "6B1D8E40-0002-4C3A-9C41-0B0B0B0B0002")!,
        title: "Le Corbeau et le Renard",
        content: """
        Maître Corbeau, sur un arbre perché,
        Tenait en son bec un fromage.
        Maître Renard, par l'odeur alléché,
        Lui tint à peu près ce langage :
        « Hé ! bonjour, Monsieur du Corbeau.
        Que vous êtes joli ! que vous me semblez beau !
        Sans mentir, si votre ramage
        Se rapporte à votre plumage,
        Vous êtes le Phénix des hôtes de ces bois. »
        À ces mots le Corbeau ne se sent pas de joie ;
        Et pour montrer sa belle voix,
        Il ouvre un large bec, laisse tomber sa proie.
        Le Renard s'en saisit, et dit : « Mon bon Monsieur,
        Apprenez que tout flatteur
        Vit aux dépens de celui qui l'écoute :
        Cette leçon vaut bien un fromage, sans doute. »
        Le Corbeau, honteux et confus,
        Jura, mais un peu tard, qu'on ne l'y prendrait plus.

        Jean de La Fontaine
        """,
        colorIndex: 1, isSample: true, symbol: "bird.fill")

    static let herisson = Script(
        id: UUID(uuidString: "6B1D8E40-0003-4C3A-9C41-0B0B0B0B0003")!,
        title: "Mon exposé : le hérisson",
        content: """
        Bonjour à tous ! Aujourd'hui, je vais vous présenter le hérisson.

        Le hérisson est un petit mammifère. Il vit dans les jardins, les haies et les forêts.

        Sur son dos, il a des milliers de piquants. Quand il a peur, il se roule en boule pour se protéger.

        Le hérisson sort surtout la nuit. Il mange des insectes, des vers de terre et des limaces. C'est un ami du jardinier !

        En hiver, il fait une longue sieste : il hiberne dans un nid de feuilles.

        Pour l'aider, on peut laisser un coin sauvage dans le jardin.

        Merci de m'avoir écouté. Avez-vous des questions ?
        """,
        colorIndex: 2, isSample: true, symbol: "leaf.fill")

    static let cigale = Script(
        id: UUID(uuidString: "6B1D8E40-0004-4C3A-9C41-0B0B0B0B0004")!,
        title: "La Cigale et la Fourmi",
        content: """
        La Cigale, ayant chanté
        Tout l'été,
        Se trouva fort dépourvue
        Quand la bise fut venue :
        Pas un seul petit morceau
        De mouche ou de vermisseau.
        Elle alla crier famine
        Chez la Fourmi sa voisine,
        La priant de lui prêter
        Quelque grain pour subsister
        Jusqu'à la saison nouvelle.
        « Je vous paierai, lui dit-elle,
        Avant l'Oût, foi d'animal,
        Intérêt et principal. »
        La Fourmi n'est pas prêteuse :
        C'est là son moindre défaut.
        « Que faisiez-vous au temps chaud ?
        Dit-elle à cette emprunteuse.
        — Nuit et jour à tout venant
        Je chantais, ne vous déplaise.
        — Vous chantiez ? j'en suis fort aise.
        Eh bien ! dansez maintenant. »

        Jean de La Fontaine
        """,
        colorIndex: 3, isSample: true, symbol: "music.note")

    static let video = Script(
        id: UUID(uuidString: "6B1D8E40-0005-4C3A-9C41-0B0B0B0B0005")!,
        title: "Intro de vidéo",
        content: """
        Salut à tous, et bienvenue sur la chaîne !

        Aujourd'hui, je vous montre comment préparer une vidéo en trois étapes simples, sans matériel compliqué.

        Première étape : écrire son texte. Des phrases courtes, une idée par phrase.

        Deuxième étape : le lire avec un prompteur, en regardant l'objectif. On garde le contact avec vous, sans réciter.

        Troisième étape : tourner en plusieurs prises, puis garder la meilleure.

        Si cette vidéo vous aide, abonnez-vous et dites-moi en commentaire ce que vous voulez voir ensuite.

        C'est parti !
        """,
        colorIndex: 0, isSample: true, symbol: "video.fill")

    static let toast = Script(
        id: UUID(uuidString: "6B1D8E40-0006-4C3A-9C41-0B0B0B0B0006")!,
        title: "Toast d'anniversaire",
        content: """
        Chers amis, merci d'être là ce soir.

        Je ne vais pas faire un long discours… enfin, je vais essayer.

        Nous sommes réunis pour fêter quelqu'un de rare : quelqu'un qui écoute, qui fait rire, et qui arrive toujours avec un gâteau, même quand ce n'est pas son anniversaire.

        Ce soir, c'est ton tour. Alors levons nos verres : à ta santé, à tes projets, et à toutes les années qui viennent.

        Joyeux anniversaire !
        """,
        colorIndex: 4, isSample: true, symbol: "party.popper.fill")
}
