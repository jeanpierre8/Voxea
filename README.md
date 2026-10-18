# Voxea — phase prototype v0.2

Application native macOS, interface française, Parakeet TDT 0.6B V3 avec FluidAudio/CoreML. Les sources, l’application et le modèle restent sur le Mac. Le dictionnaire personnel est désormais conservé dans SQLite. Qwen et Hermes ne sont pas intégrés à cette phase.

Le projet est installé dans **`/Users/jean-pierre/Documents/Voxea`**, à côté de Qwen3-TTS MLX Studio. Ce dossier contient l’application, les sources, les documents, les mesures et les extraits de test.

## Mémoire des corrections — version 0.3

Ouvrir l’onglet **Dictionnaire** pour ajouter, modifier, désactiver ou supprimer des règles « entendu → à écrire ». Elles peuvent être générales ou propres à une application, automatiques ou proposées comme suggestions. La transcription brute reste accessible dans l’onglet Dictée. Aucun apprentissage par surveillance des autres applications et aucune règle préremplie.

Le guide détaillé est dans **MEMOIRE.md**. La base personnelle reste locale dans `~/Library/Application Support/Voxea/corrections.sqlite3`, séparée des sources et des archives de l’application.

## Lancer

Ouvrir **Voxea.app** dans ce dossier. Une icône de forme d’onde apparaît dans la barre des menus. Fermer la fenêtre conserve l’application ; quitter via son menu.

Le modèle est préparé durant les essais de développement et occupe environ 469 Mio dans `~/Library/Application Support/FluidAudio/Models/`. Si absent, « Installer le modèle » télécharge les poids publics depuis Hugging Face. « Recharger hors ligne » utilise uniquement les fichiers locaux et échoue localement si incomplets ; aucun téléchargement de secours silencieux.

1. Choisir le mode maintien (par défaut) ou appui-bascule et appliquer le raccourci.
2. Pour l’insertion, cliquer « Autoriser l’insertion… », puis activer **Voxea** dans Réglages système > Confidentialité et sécurité > **Contrôle de l’appareil et accès aux données** sur ce Mac (nommé Accessibilité sur les anciennes versions de macOS). Si la ligne reste cochée mais Voxea affiche « à autoriser », retirer cette seule ligne puis rajouter `Documents/Voxea/Voxea.app` : la signature locale a pu changer après compilation.
3. Placer le curseur dans un champ éditable d’une autre application.
4. Utiliser **Contrôle + Majuscule + W** : maintenir pour parler, relâcher pour terminer. Au premier essai, accepter la permission microphone puis recommencer la dictée si la touche a été relâchée pendant le dialogue.
5. Les barres réagissent au volume réel. Le texte de l’overlay est provisoire. Seul le résultat final est inséré ; aucune touche Entrée n’est envoyée.
6. Échap annule pendant l’enregistrement. Si le champ a changé ou refuse l’accessibilité, ouvrir la fenêtre par la barre des menus et récupérer le dernier texte final. La copie automatique du texte final est activée par défaut ; le bouton Copier permet aussi de recopier le dernier texte.

Le raccourci peut entrer en conflit avec macOS ou une autre application : choisir une autre combinaison en cas d’erreur ou d’absence de réponse. Le prototype propose toutes les combinaisons de Ctrl, Option, Majuscule et Commande, ainsi que les lettres A–Z, les chiffres, Espace et F1–F20 ; Fn/Globe et les modificateurs seuls sont différés pour éviter une permission de surveillance du clavier.

## Raccourci distinct de Hermes et Mini

Le raccourci actuel est **Contrôle + Majuscule + W**, soit **Ctrl + Maj + W** sur un clavier Windows. Les lettres proposées suivent la disposition clavier active au lancement : la touche W française est reconnue à sa position correcte. L’ancien Commande + Majuscule + Espace ouvre aussi la capture rapide de Hermes et peut lui transférer le focus. La combinaison Ctrl + Alt + Espace est également utilisée par Mini sur ce Mac. Les préférences de Hermes et de Mini n’ont pas été modifiées. Le choix Ctrl + Maj + W est enregistré dans les préférences de Voxea sur ce Mac ; il est personnalisable depuis la fenêtre de réglages. Voxea migre une fois les anciennes préférences utilisant cette combinaison ; un raccourci choisi ensuite reste personnalisable.

## Après la dictée : insertion et presse-papiers

Dans la fenêtre de Voxea, les deux options de **Après la dictée** sont indépendantes et mémorisées immédiatement :

- **Insérer automatiquement dans le champ actif** : écrire au curseur, ou remplacer la sélection active, si le champ ciblé est toujours le même.
- **Copier automatiquement le texte final** : conserver le résultat dans le presse-papiers après chaque transcription réussie. Vous pouvez ensuite cliquer dans une autre sélection et utiliser **Commande + V**. Activée par défaut, même si l’insertion échoue.

Pour dicter uniquement vers le presse-papiers, désactiver l’insertion et garder la copie. Si les deux options sont désactivées, le texte reste dans la fenêtre de Voxea. Les aperçus, les captures annulées, trop courtes ou silencieuses ne remplacent pas le presse-papiers.

Pour les champs web, Voxea utilise le collage afin que l’éditeur traite correctement la modification. Si la copie automatique est désactivée, ce collage utilise temporairement le presse-papiers puis restaure son contenu après 0,7 s, à condition qu’aucune autre copie n’ait eu lieu entre-temps. Un éditeur qui lit le presse-papiers très tard peut nécessiter de laisser la copie automatique activée. Aucun message n’est envoyé automatiquement.

Cliquez réellement dans la zone de rédaction avant de dicter : survoler le champ avec la souris ne lui donne pas le focus.

## Essayer sans microphone

« Tester un fichier audio… » charge un extrait local de moins de 60 s. Choisir `TestAudio/fr.aiff` ou `TestAudio/en.aiff`, placer le curseur dans un éditeur puis utiliser le raccourci. Le fichier avance à vitesse réelle, anime les barres et passe par le même circuit de transcription et d’insertion. Il s’arrête automatiquement à sa fin. Le bouton « Essai dans 3 s » permet aussi de lancer ce test sans raccourci : cliquez dessus, puis cliquez dans le champ à remplir pendant le compte à rebours. « Revenir au micro » quitte ce mode. Ce mode valide le circuit applicatif, pas la capture matérielle. Les fichiers de test choisis restent en mémoire jusqu’au changement de mode ou à la fermeture.

## Choix d’implémentation

- SwiftUI/AppKit et paquet Swift : compilable avec les Command Line Tools, sans installer Xcode.
- Dépendance FluidAudio épinglée au commit `2d6c42ca5f3accc0faf9fee9e0fff5b9b2cf6042`, traits TTS/diarisation/normalisation désactivés. Voir Package.resolved.
- Modèle V3 demandé explicitement ; aucune langue forcée. Le modèle transcrit automatiquement FR/EN et peut aussi produire d’autres langues prises en charge. Aucun identificateur de langue séparé, aucune promesse de mélange FR/EN parfait.
- Une retranscription du préfixe complet toutes les 1,5 s environ, dès 1,5 s d’audio, sans passes concurrentes. Les passes peuvent réviser les mots précédents. La transcription finale attend la passe en cours puis repart avec un état de décodage neuf sur tout l’audio.
- Limite volontaire de 60 s : arrêt et finalisation automatiques, mémoire bornée. Cette méthode sert à mesurer le confort du progressif ; elle augmente le coût à mesure que la dictée s’allonge. Un fenêtrage avec stabilisation de segments sera à évaluer ensuite.
- AVAudioEngine : conversion continue en mono Float32 16 kHz avec AVAudioConverter et mesure RMS. Enregistrement en mémoire, effacé à l’arrêt/annulation, jamais conservé comme fichier par l’application.
- NSPanel flottant et non activant, transparent, en bas de l’écran contenant le pointeur. Son contenu n’intercepte pas les clics et ne prend pas le focus.
- Raccourcis Carbon press/release : modes maintien et bascule, répétitions ignorées. Pas d’écoute globale de toutes les touches. Échap enregistré uniquement pendant la capture.
- Insertion par collage standard pour tous les champs : Voxea copie le texte puis envoie uniquement Commande + V dans la session active. Le même processus et le même élément éditable doivent encore être focalisés ; les champs sécurisés identifiés sont exclus. Aucun changement forcé d’application ni touche Entrée. L’ancienne insertion `AXSelectedText` n’est plus utilisée, car certains éditeurs annoncent un succès sans prendre en compte la modification. L’envoi du collage n’est pas une preuve universelle d’acceptation ; le texte reste récupérable.
- Deux sons système à faible volume ; préférences locales UserDefaults. Les règles de correction et leurs compteurs sont conservés dans SQLite. Aucun historique complet de dictée persistant ; derniers textes brut et corrigé uniquement en mémoire jusqu’à la fermeture du processus.
- Signature locale ad hoc, application non notariée. Une recompilation peut demander de réactiver l’autorisation Accessibilité. Pas de lancement à la connexion, pas de service, pas de port réseau.

## Environnement constaté

Mac Studio M5 Max, 64 Go, macOS 27.0.1, Swift 6.4 et Command Line Tools. Xcode complet absent ; le script de tests utilise le compilateur et la bibliothèque standard, sans XCTest. Le studio Qwen existant dans Documents n’a pas été modifié. Un casque USB Plantronics Blackwire 5220 a été détecté après branchement ; l’entrée par défaut constatée est « Micro externe ». Le prototype suit l’entrée macOS par défaut (Réglages système > Son > Entrée).

## Recompiler et tester

Depuis ce dossier :

```sh
./build-app.sh
./test.sh
.build/release/Voxea --prepare
.build/release/Voxea --benchmark /chemin/fr.aiff /chemin/en.aiff
```

`--prepare` est la seule commande qui autorise le téléchargement initial. `--benchmark` charge strictement les poids locaux, convertit les fichiers audio avec FluidAudio.AudioConverter, affiche les préfixes à 2 s d’intervalle puis le final, et mesure chaque passe. Ne l’utiliser qu’avec des fichiers dont vous souhaitez afficher le contenu dans le terminal.

Le test hors réseau a également été exécuté sous `sandbox-exec` avec les accès réseau interdits au processus ; le rapport et les sorties de mesures sont joints.

Les tests automatisés ciblent les transitions clavier (maintien, bascule, répétition et annulation), le remplacement déterministe et la persistance SQLite sur des bases temporaires (41 vérifications de mémoire). Les essais du moteur utilisent des phrases synthétiques produites localement avec les voix macOS ; ils ne mesurent pas la précision sur votre voix, votre accent ou votre microphone.

## État à la livraison

Le test de maintien avec le fichier français et l’essai au microphone en mode appui-bascule ont réussi, avec insertion dans CotEditor. La dernière passe au microphone a pris 0,18 s. L’application est actuellement réglée sur **maintenir pour parler**, avec **Contrôle + Majuscule + W**. Le modèle et les permissions sont déjà préparés sur ce Mac. L’archive contient le projet et l’application, sans les poids du modèle ni le dossier de compilation ; les poids restent dans le cache FluidAudio indiqué plus haut.

## Validation manuelle à poursuivre

- Répéter une phrase française et une anglaise avec le microphone ; relever les erreurs et la latence ressentie.
- Tester maintien, bascule, sons, silence, Échap et 60 s.
- Vérifier que l’overlay ne change pas le champ focalisé.
- Dans CotEditor puis un champ de navigateur : dicter au milieu d’un texte et sur une sélection. Contrôler accents et ponctuation.
- Changer de champ ou d’application pendant la dictée : aucune insertion, texte récupérable.
- Tester les permissions refusées puis accordées ; les champs de mot de passe doivent rester exclus.
- Couper la connexion puis recharger et dicter : le chargement local ne doit pas dépendre du réseau.

Aucune qualité universelle d’insertion ni précision FR/EN n’est considérée acquise avant ces essais. Le rapport de test joint distingue les mesures du moteur des vérifications interactives.

## Références

- Cahier des charges récupéré depuis « Synthèse Grapho et modèle vocal ». Le message v0.2 contient une référence de contenu embarqué non résolue ; les décisions ont été recoupées avec les messages et la roadmap accessibles. Aucun document joint complet n’était disponible.
- FluidAudio : https://github.com/FluidInference/FluidAudio
- API ASR : https://github.com/FluidInference/FluidAudio/blob/2d6c42ca5f3accc0faf9fee9e0fff5b9b2cf6042/Documentation/ASR/GettingStarted.md
- FluidAudio est sous Apache-2.0 ; conserver les notices de la dépendance et vérifier celles des poids lors d’une distribution ultérieure.

## Renommage en Voxea

Le nom du projet Swift, son exécutable, le dossier de sources, la fenêtre et l’application sont désormais **Voxea**. L’identifiant macOS interne `local.jp.DictationPrototype` reste stable pour conserver les préférences et faciliter la continuité des autorisations. Il n’est pas le nom affiché. Une nouvelle signature locale ou le déplacement de l’application peut néanmoins nécessiter de réactiver Accessibilité dans macOS. Les poids FluidAudio restent dans leur cache partagé ; ils n’ont pas été déplacés ni retéléchargés.

SQLite est utilisé via la bibliothèque système : https://www.sqlite.org/c3ref/open.html

## Version affichée

Les réglages affichent la version et le numéro de build sous le nom Voxea, lus directement dans les informations de l’application. Version courante : **0.3.1 · build 4**.

## Mise en forme — 0.4.0 · build 5

L’onglet **Mise en forme** ajoute les commandes vocales de lignes, paragraphes et listes, les majuscules, le retrait du point final et des hésitations. Options indépendantes, aperçu et profils par application. Voir [MISE-EN-FORME.md](MISE-EN-FORME.md). Le numéro visible dans les réglages est lu dans l’application installée ; la version courante est 0.4.0, build 5.
