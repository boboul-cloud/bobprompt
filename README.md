# Prompteur Magique (iOS, SwiftUI)

Un prompteur simple et ludique pour enfants : saisie de texte, lecture avec défilement automatique, pause/arrêt, coloration des syllabes en alternant les couleurs, réglage de la vitesse et de la taille du texte. Ajouts récents : mode miroir, compte à rebours 3‑2‑1, et gestion de textes enregistrés.

## Prérequis
- macOS + Xcode installé (iOS 15+ recommandé)
- Homebrew (facultatif) pour installer XcodeGen

## Générer le projet Xcode

```zsh
# Installer XcodeGen si besoin
brew install xcodegen

# À la racine du repo
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "Users/robertoulhen/Documents/CODES/Prompteur" 2>/dev/null || true

# Générer le .xcodeproj
xcodegen generate
```

Ouvrez ensuite `Prompteur.xcodeproj` dans Xcode et lancez l'app sur un simulateur ou un iPhone.

## Déployer sur iPhone (ex. iPhone 14 Pro)

1) Configurer la signature dans Xcode
- Cible `Prompteur` → onglet "Signing & Capabilities".
- Cochez "Automatically manage signing".
- Choisissez votre "Team" (Apple ID connecté).
- Assurez-vous que le `Bundle Identifier` est unique (ex: `com.votreNom.prompteur`).

2) Activer le "Developer Mode" (iOS 16+ requis sur iPhone 14 Pro)
- Réglages → Confidentialité et sécurité → Developer Mode → Activer → Redémarrer.

3) Faire confiance au certificat développeur (si demandé)
- Réglages → Général → VPN et gestion de l’appareil → votre certificat → Faire confiance.

4) Lancer sur l’appareil
- Branchez l’iPhone 14 Pro et sélectionnez-le comme destination de build.
- `Cmd + R` pour construire et installer.

5) Si Xcode signale que "xcodebuild requires Xcode" (outil CLT actif)

```zsh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Conseils
- Cible minimale iOS 15.0 (OK pour iPhone 14 Pro). Si votre appareil est plus ancien, baissez la cible et ajustez les API conditionnellement.
- En cas de conflit d’identifiant, changez le `Bundle Identifier` dans l’onglet Signing & Capabilities.
- Si le build reste bloqué, essayez Product → Clean Build Folder (Shift+Cmd+K).

## Icône de l’application
Un jeu d’icônes placeholder a été ajouté dans `Prompteur/Assets.xcassets/AppIcon.appiconset` (fichiers référencés mais non fournis). Remplacez chaque PNG par vos images exportées:

Tailles à préparer (format PNG sans alpha obligatoire pour App Store, alpha accepté en debug):
- iPhone: 60×60 @2x → 120×120 (`AppIcon-120.png`), 60×60 @3x → 180×180 (`AppIcon-180.png`)
- iPad: 76×76 → 76×76 (`AppIcon-76.png`), 76×76 @2x → 152×152 (`AppIcon-152.png`), 83.5×83.5 @2x → 167×167 (`AppIcon-167.png`)
- Marketing: 1024×1024 (`AppIcon-1024.png`)

Procédure:
1. Déposez vos fichiers nommés exactement comme dans `Contents.json`.
2. Ouvrez le projet Xcode → Asset Catalog pour vérifier l’aperçu.
3. Lancez sur l’appareil/simulateur pour voir l’icône.

Générer les tailles depuis une seule image
Si vous avez un PNG carré (idéalement 1024×1024), utilisez le script fourni pour générer toutes les tailles automatiquement:

```zsh
chmod +x Scripts/generate_app_icons.zsh
./Scripts/generate_app_icons.zsh /chemin/vers/votre_icone_1024.png
open Prompteur.xcodeproj
```

Le script remplit `AppIcon.appiconset` avec les fichiers aux bons noms. Ouvrez Xcode pour voir l’aperçu mis à jour.

Astuce design:
- Forme simple et lisible (pas de trop petits détails).
- Conservez une marge (~12%) pour éviter la découpe optique.
- Evitez le texte; privilégiez symbole (ex: lettre "P" stylisée + baguette magique).

## Fonctionnalités
- Saisie du texte (onglet **Éditer**) et aperçu coloré.
- Lecture (onglet **Lire**) avec défilement automatique.
- Boutons Lecture/Pause, Arrêter.
- Coloration syllabique alternée (activable/désactivable).
- Réglage de la vitesse (pt/s) et de la taille du texte.
 - Mode miroir (pour utilisation avec réflecteur).
 - Compte à rebours (3…2…1) avant démarrage, optionnel.
 - Sauvegarde et chargement de textes (UserDefaults).

## Notes techniques
- SwiftUI + `UITextView` intégré via `UIViewRepresentable` pour un défilement fluide.
- Syllabification basée sur l'API de césure CoreFoundation (`CFStringGetHyphenationLocationBeforeIndex`) avec locale `fr_FR`.
- Thème visuel doux avec couleurs vives et police *rounded*.
 - Sélecteur de thème simple (Océan/Bonbons).

## Génération de texte IA (OpenAI)

Une génération de texte en ligne (qualité supérieure) est disponible dans l'onglet « Créer ».

### Configuration de la clé API
1. Créez un compte sur https://platform.openai.com/ et générez une clé secrète.
2. Ouvrez l'application, onglet « Créer ».
3. Activez le toggle « Utiliser IA en ligne ».
4. Collez la clé dans le champ « Clé API OpenAI ». Elle est stockée localement via le Trousseau (Keychain) et n'est pas envoyée hors des requêtes d'inférence.

Si la clé est absente ou invalide, un message d'erreur apparaît dans la section « Erreur ». La génération locale hors‑ligne reste disponible en désactivant le toggle.

### Paramètres
- Température : contrôle la créativité (0.1 = très factuel, 1.2 = créatif). Valeur par défaut 0.9.
- Nombre de mots : plage 30–600 (la requête ajuste les tokens automatiquement).

### Fallback hors‑ligne
Si le service distant est indisponible ou si aucune clé n'est fournie, vous pouvez basculer sur le générateur intégré (non connecté) pour obtenir un texte d'exemple respectant vos critères de base.

### Confidentialité
Seuls le prompt (critères + consignes) et les paramètres (température, longueur) sont envoyés à OpenAI. Aucune autre donnée locale n'est transmise.

### Améliorations possibles
- Streaming token‑par‑token pour un affichage progressif.
- Sélection du modèle (gpt‑4o, gpt‑4o-mini, etc.) dans l'interface.
- Historique des prompts et régénération rapide.


## Capturer une capture d'écran (simulateur)

Exécutez le script suivant pour construire l'app, démarrer un simulateur iPhone et enregistrer une capture d'écran dans `Screenshots/`.

```zsh
chmod +x Scripts/capture_simulator_screenshot.zsh
./Scripts/capture_simulator_screenshot.zsh
```

Si besoin, modifiez dans le script le nom du device (`DEVICE_NAME`) ou l'emplacement de sortie.

Astuce: vous pouvez aussi exporter une image depuis la Canvas des Previews (clic droit → Export) quand `ContentView.swift` est ouvert.
