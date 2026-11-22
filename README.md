# bobprompt 2.0 (iOS, SwiftUI)

Un prompteur pour lire, présenter et filmer — et pour apprendre à lire en
s'amusant. iPhone et iPad, iOS 17 minimum.

## Ce que fait l'app

- **Bibliothèque** : mes textes (cartes colorées, durée estimée, reprise de
  lecture), six exemples fournis (dont deux fables de La Fontaine), création
  avec l'IA. Enregistrement automatique : pas de bouton « Enregistrer ».
- **Lecteur plein écran**, six styles :
  - *Classique* — fonds Nuit, Papier (règle de lecture surligneur), Contraste ;
  - *Vieille école* — écran cathodique vert ou ambre (balayage, lueur,
    démarrage façon ordinateur 8 bits), machine à écrire (frappe lettre à
    lettre, ruban noir/rouge, ding et retour chariot synthétisés) ;
  - *3D* — Tambour (texte enroulé sur un cylindre en perspective : glisser
    pour tourner, glisser latéralement pour pivoter, pincer pour zoomer,
    inclinaison de l'appareil) et Cartes (une phrase par carte, pages qui
    tournent au doigt).
- **Aide à la lecture** : syllabes colorées selon le découpage scolaire
  (a-mi, ta-bleau, pa-pi-llon), mot en cours surligné, un mot par ligne,
  « Écouter la phrase », voix qui lit tout le texte et le fait défiler.
- **Pour filmer** : miroir, compte à rebours, écran maintenu allumé,
  clavier / télécommande Bluetooth (espace, flèches, page suivante).
- **Premium** (achat unique `com.bobprompt.premium`) : 50 textes au lieu de 2.

## Construire

```zsh
brew install xcodegen      # une fois
xcodegen generate          # régénère Prompteur.xcodeproj depuis project.yml
open Prompteur.xcodeproj
```

`project.yml` est la source de vérité (bundle `com.bobprompt.app`, équipe,
version, cible de tests). Ne modifiez pas le `.xcodeproj` à la main.

Tests :

```zsh
xcodebuild -project Prompteur.xcodeproj -scheme Prompteur \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Organisation du code

| Dossier | Rôle |
|---|---|
| `App/` | entrée de l'app, navigation (`AppRouter`), mode démo (Debug) |
| `Model/` | textes (`Script`, `ScriptStore` au Trousseau), réglages persistés, exemples |
| `Text/` | découpage syllabique, mots/phrases/ligne de temps, mise en lignes, coloration |
| `Engine/` | moteur de lecture (horloge, phases, voix), synthèse vocale, sons, inclinaison |
| `Design/` | couleurs, typographie, boutons |
| `Features/` | bibliothèque, éditeur, lecteur et ses six scènes, IA, Premium, aide |

Principe : un seul moteur (`PrompterEngine`) avance dans une **ligne de temps**
exprimée en mots. Chaque style d'affichage fournit la sienne (défilement
régulier, frappe lettre à lettre, phrase par phrase) ; changer de style garde
le mot en cours. Quand la voix est activée, c'est elle qui fait avancer la
position, mot par mot.

## Données

- Textes : Trousseau, clé `prompteur.savedTexts.v2` (celle de la v1 : les
  textes existants sont repris tels quels). Ils survivent à une réinstallation.
- Réglages : `UserDefaults`, clé `bobprompt.readerSettings.v2`.
- Clé OpenAI facultative : Trousseau, `OPENAI_API_KEY`.

## IA

« Avec l'IA » utilise Apple Intelligence sur l'appareil (iOS 26+, gratuit,
privé) quand il est disponible, sinon une clé OpenAI fournie par
l'utilisateur. `FoundationModels` est lié en mode faible pour rester
compatible iOS 17.

## Captures (simulateur)

En compilation Debug, des arguments de lancement ouvrent directement un écran :

```zsh
./Scripts/capture_simulator_screenshot.zsh tambour -demoScreen reader -demoStyle drum -demoWord 30
```

`-demoScreen` : `reader`, `styles`, `settings`, `editor`, `create`, `premium`,
`help` · `-demoStyle` : `classic`, `crtGreen`, `crtAmber`, `typewriter`,
`drum`, `cards` · `-demoTheme` : `night`, `paper`, `contrast` ·
`-demoSample n` · `-demoWord n` · `-demoPlay YES` · `-demoVoice YES` ·
`-demoSeed YES` (textes fictifs en mémoire) · `-demoPremium YES|NO`.

## Icône

`./Scripts/generate_app_icons.zsh image_1024.png` remplit `AppIcon.appiconset`.
