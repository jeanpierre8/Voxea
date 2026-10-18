# Rapport de validation — 18 octobre 2026

Prototype exécuté sur le Mac Studio M5 Max (64 Go), macOS 27.0.1, Swift 6.4. Application compilée et signée localement. Aucune installation ou modification des projets Qwen, Ollama ou Hermes existants.

## Résultats mesurés

| Audio synthétique local | Durée | Passe finale | Erreurs de mots normalisées |
|---|---:|---:|---:|
| Français court | 7,30 s | 47 ms | 1 / 17 (5,9 %) |
| Anglais court | 6,81 s | 44 ms | 0 / 19 (0 %) |
| Français long | 21,00 s | 103 ms | 1 / 55 (1,8 %) |

Mesures d’une exécution, moteur chaud. Elles ne représentent ni un benchmark statistique ni une garantie de latence avec un microphone. La première préparation, téléchargement inclus, a pris 28,63 s ; le chargement suivant du moteur local a pris 0,10 s dans le test en ligne de commande. L’ouverture complète de l’interface peut prendre davantage de temps.

Le taux d’erreur supprime la ponctuation et les différences de casse mais conserve les accents. Le français court donne « dicté » au lieu de « dictée ». Le français long donne « A » au lieu de « À ». Les références et résultats sont dans `mesures.json`.

Les préfixes sont retranscrits tous les 2 s dans le banc de mesure ; l’application les demande environ toutes les 1,5 s. Les aperçus peuvent être erronés en fin de fragment puis se corriger. Exemple anglais : « testing a load » devient « testing a local voice dictation application » avec davantage d’audio. Le texte provisoire doit rester distinct du résultat final.

## Vérifications réalisées

- Compilation de l’application native avec les Command Line Tools, sans Xcode complet ; signature locale vérifiée.
- 12 assertions sur les transitions du raccourci : maintien, relâchement, bascule, répétition ignorée, annulation puis redémarrage. Résultats dans `key-tests.txt`.
- Transcription V3 multilingue sans paramètre de langue : français et anglais reconnus.
- Extrait de 21 s traité, couvrant le passage au-delà de la fenêtre de 15 s du moteur.
- Chargement strictement local et transcriptions FR/EN réussis avec les accès réseau interdits au processus par un profil temporaire `sandbox-exec`. Aucun réglage réseau du Mac n’a été modifié. Sorties dans `benchmark-network-denied.jsonl`.
- Fenêtre de réglages vérifiée visuellement ; modèle prêt, raccourci configurable, deux modes, sons, récupération du texte.
- Mode fichier local chargé avec `fr.aiff` ; déclenchement depuis le clavier physique.
- Insertion dans CotEditor confirmée après autorisation Accessibilité accordée par l’utilisateur : le préfixe existant « Début : » est conservé et le texte français est ajouté dans le document. Le focus observé reste dans le champ CotEditor après cet essai. L’interface rapporte 0,07 s pour cette passe finale.
- Casque Plantronics et entrée « Micro externe » détectés après branchement.

## Essai réel validé

L’utilisateur a confirmé l’overlay et l’insertion avec le raccourci physique en mode maintien sur le fichier français. Il a ensuite confirmé qu’une phrase prononcée au microphone a été insérée en mode appui-bascule. L’interface a été relue après cet essai : statut « Texte inséré », dernière passe finale de **0,18 s**, résultat français présent. Le contenu personnel de la phrase n’est pas recopié dans ce rapport.

La capture matérielle et le rééchantillonnage depuis l’entrée audio par défaut, la transcription locale et l’insertion ont donc fonctionné ensemble sur une courte phrase. Le texte final reste dans la mémoire de l’application ; aucun enregistrement audio n’est conservé. L’application est laissée ouverte en mode microphone, appui-bascule, raccourci Commande + Majuscule + Espace.

## Limites de validation

Le corpus ne contient que trois phrases synthétiques créées localement avec les voix macOS Thomas et Samantha. Il ne permet pas de conclure sur un accent, un bruit ambiant, le mélange FR/EN, les termes spécialisés ou des sessions prolongées. Le traitement sans réseau a été testé sur fichiers, pas en désactivant la connexion de tout le Mac.

L’insertion a été vérifiée dans CotEditor uniquement. Les champs de navigateur, IDE, champs sécurisés, changement de cible pendant la dictée, refus de permissions et déconnexion du micro restent à tester. Les contrôles de cible et d’exclusion des champs sécurisés sont présents dans le code, sans garantie de compatibilité universelle.

Fn/Globe, touche modificatrice seule, raccourci librement capturé, mémoire SQLite, Qwen, Hermes, correction personnalisée et annulation de la dernière insertion sont hors de ce prototype. Échap annule une capture en cours. Le résultat final peut être annulé dans l’éditeur si celui-ci l’intègre à son historique d’annulation ; ce comportement n’a pas été validé ici.

## Renommage et déplacement

Le projet a été renommé **Voxea** et déplacé dans `/Users/jean-pierre/Documents/Voxea`. Les mesures ci-dessus ont été réalisées avant le changement de nom ; le moteur et le comportement de dictée n’ont pas été modifiés. Les tests clavier ont été relancés après renommage : 12 assertions réussies. L’identifiant macOS interne est conservé pour la continuité des préférences.

La reconstruction depuis Documents a réussi et la signature locale a été vérifiée. L’application a été relancée : fenêtre « Voxea », modèle local prêt, mode appui-bascule et raccourci conservés.

## Mise à jour 0.2.0 — sortie vers les chats et presse-papiers

Deux préférences indépendantes ont été ajoutées : insertion automatique et copie automatique du texte final, toutes deux activées par défaut. Elles sont mémorisées immédiatement. Le résultat est copié même quand la cible n’est plus disponible ou que l’autorisation d’insertion manque. Les champs web utilisent Commande + V afin de déclencher les événements de l’éditeur ; les champs natifs conservent l’insertion AX avec secours par collage. Aucun événement Entrée n’est envoyé.

Le collage vérifie le processus et l’élément éditable focalisé avant et après une attente de 100 ms. Les champs protégés identifiés et leurs descendants sont exclus. Si la copie automatique est désactivée, le contenu antérieur du presse-papiers est restauré après le collage, uniquement si aucune autre copie n’est intervenue. L’attente d’effacement de l’overlay ne bloque plus le démarrage d’une nouvelle dictée. La fenêtre de réglages défile si nécessaire et affiche l’état de l’autorisation.

La version a été compilée et relancée. Le test du service de copie seul a réussi : résultat « clipboard », contenu du presse-papiers conforme à la phrase synthétique attendue. Ce test ne nécessite pas l’autorisation d’insertion. L’autorisation macOS de l’application ouverte a été rétablie après retrait puis ajout de l’entrée Voxea ; l’interface affiche désormais « Accessibilité : autorisée ». Sur ce Mac, cette permission se trouve dans Confidentialité et sécurité > Contrôle de l’appareil et accès aux données.

L’outil de contrôle refuse l’accès à l’application hébergeant ce chat. Aucun contournement n’a été employé. La confirmation dans cette conversation est demandée à l’utilisateur. Les essais de collage lancés directement depuis le terminal ont été arrêtés avant toute insertion, car cette exécution ne possédait pas l’autorisation d’accessibilité ; ils ne sont pas comptés comme des validations d’insertion.

Après l’essai au microphone, l’état de Voxea a été relu : « Texte inséré et copié », passe finale de 0,05 s. Le contenu de la phrase personnelle n’est pas consigné. Cette observation confirme le chemin d’insertion directe réussi et l’appel de copie du résultat ; l’acceptation visuelle dans le chat et le recollage restent à confirmer par l’utilisateur.

### Correction du conflit Hermes et du faux succès d’insertion

L’utilisateur a confirmé que la copie fonctionnait mais pas l’insertion et a fourni une capture de la fenêtre rapide de Hermes ouverte par l’ancien raccourci. Le raccourci de Voxea a été migré une fois vers **Ctrl + Option + Espace** ; il est affiché et accepté par le gestionnaire natif. Aucun réglage de Hermes n’a été modifié. Le changement physique de focus par Hermes reste à vérifier avec ce nouveau raccourci.

Le chemin d’insertion directe AX qui annonçait un succès sans effet visible a été abandonné. Tous les champs utilisent maintenant le collage normal Commande + V via la session active, après vérification de l’identité du champ. Un bouton d’essai retardé, disponible uniquement en mode fichier de test, permet de vérifier le circuit complet dans une application locale sans dépendre de la simulation du raccourci global.

Le test retardé sur fichier a transcrit l’extrait français, mais a refusé d’insérer : aucun champ éditable correspondant n’était reconnu au premier plan de la session. Le champ du banc web n’a pas changé et aucun événement de saisie n’a été observé. Cet essai confirme le refus d’une cible indisponible et la conservation de la copie ; il ne valide pas le collage. Le test décisif du nouveau raccourci et du collage dans le chat est confié à l’utilisateur sur son clavier physique. Voxea est laissée en mode microphone, maintien pour parler, Ctrl + Alt + Espace, copie automatique active.

### Raccourci personnalisé après signalement du conflit Mini

L’utilisateur a signalé que Ctrl + Alt + Espace était déjà utilisé par Mini. Le raccourci de Voxea a été réglé sur **Ctrl + Alt + D** dans son interface, puis enregistré avec « Appliquer le raccourci ». La touche D et les modificateurs Contrôle + Option sont visibles, sans erreur d’enregistrement. Aucun binaire n’a été reconstruit pour ce changement de préférences ; les autorisations existantes restent applicables. L’absence de conflit avec tous les raccourcis d’autres applications n’est pas garantie par cet enregistrement.

### Choix utilisateur : Ctrl + Maj + W

Les menus ont été élargis aux 15 combinaisons non vides des quatre modificateurs macOS et aux lettres A–Z, chiffres, Espace et F1–F20. Les lettres sont résolues vers les codes physiques à partir de la disposition active. Sur ce Mac, la disposition constatée est `com.apple.keylayout.French` ; W a été résolu en code 6, distinct du code ANSI W (13). Le masque Contrôle + Majuscule vaut 4608. Les préférences ont été réglées sur ce code et ce masque à la demande de l’utilisateur.

La reconstruction a réussi. L’interface affiche Contrôle + Majuscule, touche W ; « Appliquer le raccourci » n’a signalé aucune erreur. La copie automatique et le mode maintien sont conservés. La mise à jour ayant modifié la signature ad hoc, macOS demande de renouveler l’autorisation d’insertion avant de reprendre l’usage complet.

Après réactivation par l’utilisateur et relance, Voxea affiche « Accessibilité : autorisée », mode maintien, Ctrl + Majuscule + W, insertion et copie automatique actives. Les préférences relues sont code 6 et masque 4608.

## Voxea 0.3 — mémoire SQLite des corrections

### Fonctionnement livré

Un onglet Dictionnaire permet de créer, chercher, modifier, désactiver, supprimer et restaurer la dernière règle supprimée. Les règles sont littérales, sur des mots entiers, insensibles à la casse mais sensibles aux accents, générales ou limitées à une application. Une règle spécifique prime sur la règle générale pour la même expression. Les correspondances se traitent de gauche à droite avec priorité à la plus longue au même emplacement, sans remplacement en cascade.

Les règles automatiques sont appliquées entre la transcription finale et la livraison vers l’application et le presse-papiers. Le mode suggestion conserve le texte initial et permet une acceptation explicite par copie, sans réinsertion. Les propositions sont invalidées après modification du dictionnaire pour ne pas accepter une ancienne proposition avec de nouvelles règles. La dernière transcription brute reste accessible séparément en mémoire.

La base locale `~/Library/Application Support/Voxea/corrections.sqlite3` contient uniquement règles, portées, modes, états, dates et compteurs. Aucun audio ni historique complet des dictées n’y est stocké. Le schéma est versionné et les écritures utilisent des paramètres et des transactions. Les données d’un schéma inconnu ou d’un fichier corrompu ne sont pas remplacées. La dictée peut rester utilisable sans corrections si la base est indisponible. La bibliothèque SQLite système est utilisée, sans nouvelle dépendance réseau.

### Tests automatisés

Le script `./test.sh` passe **53 vérifications** : 12 sur les états du raccourci et **41 sur la mémoire**. Ces dernières couvrent notamment persistance, édition, activation, suppression et restauration avec compteurs, doublons, portée par application, accents et Unicode, espaces insécables, mots entiers, expressions littérales, non-cascade, suggestions explicites, règles invalides, contenu avec quotes, contention d’écriture, schéma futur ou incompatible et fichier corrompu. Les bases de test sont temporaires, séparées de la base personnelle. Les sorties sont jointes dans `tests-memoire.txt`.

Une application de 500 règles précompilées à une courte phrase a pris environ **1,3 ms** sur cet essai. Ce résultat ne comprend ni l’inférence audio ni le collage et ne garantit pas la latence dans toutes les conditions.

### Essais interactifs

- Dictionnaire initial vide, formulaire et aperçu vérifiés visuellement.
- Règle temporaire `dicté vocale` → `dictée vocale` ajoutée depuis l’interface. L’aperçu corrige l’expression accentuée et laisse `dicte vocale` inchangé.
- Extrait français local de 7,3 s transcrit avec cette règle automatique : sortie corrigée, statut « 1 correction », transcription brute restée consultable avec l’erreur d’origine. Insertion désactivée pour cet essai isolé ; copie automatique active.
- Après redémarrage, règle et compteur de 1 utilisation conservés.
- Même règle passée en suggestion depuis l’interface : une seconde transcription du même extrait conserve `dicté vocale` et affiche la suggestion. Son acceptation copie `dictée vocale`, sans insertion.
- Collage de cette version dans le champ de test de Voxea : contenu réel du presse-papiers vérifié. Le compteur passe à 2 après cette acceptation, sans compter les aperçus.
- Désactivation vérifiée après relance : règle persistante, compteur 2, aucun remplacement ni suggestion dans l’aperçu.
- Suppression et annulation depuis l’interface : restauration de la règle désactivée et de son compteur 2. La règle de test a ensuite été supprimée.
- Réglages de livraison rétablis : microphone, maintien, Ctrl + Maj + W, insertion et copie automatiques.

Le dictionnaire livré est vide de règles ; il est destiné aux corrections choisies par l’utilisateur. Les menus standard d’édition macOS ont été ajoutés pour copier et coller dans les formulaires. Une opération de sélection automatisée a envoyé le raccourci Quitter à cause du mappage AZERTY de l’outil de test ; elle a entraîné une relance normale, et non un plantage. L’état désactivé et les compteurs ont été retrouvés après cette relance.

### Limites

Le dictionnaire n’analyse pas les corrections faites dans les autres applications, ne calcule pas de confiance acoustique et ne réentraîne pas Parakeet. Une portée navigateur couvre tous ses onglets. La qualité linguistique des règles relève de leur validation par l’utilisateur ; les cas ambigus peuvent être laissés en suggestion. Les modifications affectent les prochaines dictées et ne modifient pas rétroactivement le texte déjà inséré. Qwen, Hermes, import/export et conservation audio restent hors de cette phase.

L’application reste signée localement ad hoc (aucune identité de signature de développement valide trouvée sur le Mac). La reconstruction modifie sa signature et nécessite le renouvellement de l’autorisation macOS d’insertion. Aucune permission supplémentaire n’est demandée pour SQLite. L’ancienne application validée et ses sources ont été sauvegardées dans l’espace de travail avant la mise à jour.

## Affichage de version — 0.3.1, build 4

Ajout de la version et du numéro de build dans l’en-tête des réglages, à partir des métadonnées du bundle. Aucune modification du moteur de dictée ni du dictionnaire. La reconstruction nécessite à nouveau une vérification de l’autorisation d’insertion.

Compilation 0.3.1 réussie. Vérification dans la fenêtre relancée : « Version 0.3.1 · build 4 » visible ; raccourci Ctrl + Maj + W, maintien, insertion et copie automatiques conservés. L’interface signale que l’autorisation d’insertion reste à renouveler pour ce nouveau binaire.

## Mise en forme — 0.4.0, build 5

- 80 vérifications automatisées réussies : 12 raccourci, 41 dictionnaire, 27 mise en forme.
- Les nouveaux contrôles vérifient lignes, paragraphes, listes simples/ponctuées, sortie de liste, commande hors contexte, retour terminal, hésitations isolées et ponctuées, mots à ne pas altérer, casse FR/EN, Unicode, ponctuation finale, options désactivées sans altération, profils et sérialisation.
- Compilation release réussie, version visible 0.4.0 · build 5.
- Interface : nouvel onglet Mise en forme ; aperçu de liste à deux éléments et texte après la liste conforme ; désactivation du retrait du point final immédiatement visible. Préférence retrouvée après fermeture/relance, puis rétablie activée.
- Options initiales conformes à la validation : commandes, majuscules, retrait du point final et hésitations activés. Aucun profil particulier n’est ajouté automatiquement.
- La mise en forme s’applique après les corrections, à la livraison finale comme à l’acceptation des suggestions ; pour les suggestions, conservation des options de la dictée d’origine.
- Pas de nouvelle permission ni de service externe. Signature ad hoc renouvelée : autorisation d’insertion à renouveler pour ce binaire.

Limites : commandes françaises reconnues littéralement, dépendantes de la transcription de Parakeet ; elles ne sont pas distinguées d’une citation. La liste ne se poursuit pas entre deux dictées. Les règles de casse et d’hésitations sont volontairement simples et désactivables ; elles ne remplacent pas une analyse linguistique. L’aperçu ne teste pas le dictionnaire. Voir MISE-EN-FORME.md.

Essai audio de bout en bout : voix locale Thomas, fichier de 5 s contenant « Bonjour à la ligne faire une liste du pain élément suivant du lait fin de liste merci ». Parakeet V3 → mise en forme → copie : résultat observé « Bonjour », puis deux puces « Du pain » / « Du lait », puis « Merci », avec de vrais sauts de ligne. Dernière passe ASR affichée 0,05 s. Collage dans l’aperçu de Voxea : contenu réel du presse-papiers conforme. L’insertion a été désactivée uniquement pendant cet essai, puis rétablie ; retour au microphone effectué. La nouvelle insertion dans une application externe reste à vérifier après renouvellement de l’autorisation macOS. Présentation visuelle du nouvel onglet contrôlée.


## 18 octobre 2026 — réparation de l’insertion, version 0.4.1 (build 6)

### Résultat établi et limite de causalité

Une dictée réelle a été effectuée par l’utilisateur dans ChatGPT avec Ctrl+Maj+W, en mode microphone (pas `--test-output`, pas fichier audio). Le résultat visuel rapporté est « Texte dans Voxea seulement ».

Les traces du 18 octobre, à 14:07:03–14:07:09 heure de Paris, montrent :

- application active `com.openai.codex`, PID 27480 ;
- `begin insert=true copy=true file=false` ;
- `capture denied trust/front`, `captured target=nil trusted=false` ;
- démarrage du microphone et overlay `key=false` ;
- relâchement du raccourci, 95 918 échantillons à 16 kHz (~6 secondes), signal audible ;
- transcription finale de 33 caractères ;
- livraison `method=unavailable`, destination absente.

Le blocage de **cette reproduction** est donc le refus de l’autorisation Accessibilité, et non une transcription manquante ou un overlay devenu fenêtre active. Attention : cette reproduction a eu lieu après recompilation pour ajouter les traces. Elle ne démontre pas à elle seule que le binaire antérieur échouait pour la même raison. Aucune trace de dictée réelle de ce binaire n’était disponible. Les anciens journaux sous `/private/tmp/voxea-*` concernent d’autres PID et ne prouvent pas le fonctionnement courant.

La signature est ad hoc ; aucune identité de signature de développement n’est disponible. Une recompilation peut invalider l’autorisation macOS. Le build 6 a été relancé et affiche « Accessibilité : à autoriser ». Il faut réautoriser **ce binaire exact**, sans modifier les protections macOS. Ne pas recompiler entre réautorisation et essai.

### Modifications livrées

- Traces locales dans `~/Library/Logs/Voxea/insertion.log`, bornées à environ 1 Mo, fichier créé en mode 600. Elles décrivent raccourci, application, capture, transitions d’application, modificateurs, étapes audio/transcription et livraison. Aucun texte de champ, contenu dicté, contenu du presse-papiers ou audio n’est journalisé.
- Actualisation de l’état Accessibilité au début de chaque dictée et message explicite en cas de refus.
- Suppression du choix arbitraire `deepestEditor` dans toutes les fenêtres. La récupération exige un unique éditeur explicitement focalisé dans la fenêtre active et une recherche bornée.
- Validation du même élément AX et de la même fenêtre ; abandon de l’empreinte PID/rôle/position comme preuve de focus. Cette vérification conservatrice peut refuser un éditeur Chromium qui recrée ses éléments ; la compatibilité doit être vérifiée en conditions réelles.
- `AXEnhancedUserInterface` demandé au début de la capture, sans réactiver cet attribut à chaque contrôle du focus.
- Invalidation de la destination si l’application change pendant l’enregistrement/la transcription. Abandon si texte ou sélection a changé avant collage.
- Attente du relâchement réel de Ctrl/Maj/Option/Cmd, avec délai maximal de 3 secondes ; aucune libération artificielle des touches de l’utilisateur.
- Confirmation par changement effectif d’AXValue et remplacement attendu lorsque la sélection est lisible. Si elle ne l’est pas, lecture modifiée contenant la totalité de la dictée ; ce contrôle de secours reste moins probant qu’une comparaison exacte. Aucun suffixe de 40 caractères préexistant ne suffit plus.
- Presse-papiers sauvegardé avant collage et restauré si son compteur n’a pas changé. Abandon si la sauvegarde est incomplète. La copie automatique permanente est désormais désactivée par défaut ; une préférence explicitement activée conserve sa fonction.
- Les exclusions des champs protégés sont conservées ; aucun Enter ni envoi de message n’est ajouté.
- Version 0.4.1, build 6 ; rappel de vérifier l’autorisation après compilation dans le script de construction.

### Vérifications réalisées

- Compilation release réussie et application redéployée à `~/Documents/Voxea/Voxea.app` ; signature vérifiée.
- Interface de l’application relancée : build 6, Parakeet prêt, Ctrl+Maj+W, insertion activée, copie automatique désactivée.
- 88 vérifications réussies : 12 raccourci/état, 41 mémoire, 27 formatage, 8 confirmation du texte (dont sélection UTF-16 et refus du faux succès par suffixe inchangé).
- Aucun ancien succès `--test-output method=confirmed` n’a été utilisé comme validation.

### Validation après réautorisation du build 6

L’utilisateur a retiré/réajouté Voxea dans les autorisations macOS, puis confirmé « ça remarche ». La version qui fonctionne n’a pas été recompilée ni resignée après cette réautorisation.

**ChatGPT, 14:19:21–14:19:27 (heure de Paris)** :

- Ctrl+Maj+W, application active `com.openai.codex`, mode microphone `file=false`, insertion activée, copie automatique désactivée ;
- `trusted=true`, capture directe de `AXTextArea`, champ encore focalisé au démarrage du microphone ;
- overlay non actif (`key=false`), 43 142 échantillons (~2,7 s), signal audible ;
- Parakeet a produit 19 caractères ; collage envoyé avec modificateurs du raccourci relâchés ;
- presse-papiers restauré, un élément sauvegardé ;
- lecture AX avant/après : 24 puis 19 caractères ; `sent=true confirmed=false`, résultat `method=paste`.

L’insertion visible est confirmée par l’utilisateur. **La confirmation automatique exacte n’a pas réussi sur cet essai ChatGPT**, et ne doit pas être présentée comme `method=confirmed`. La différence entre la sélection AX annoncée et le résultat observé n’a pas été expliquée ; aucune nouvelle compilation n’a été faite pour modifier cette vérification conservatrice.

Un premier déclenchement à 14:19:14, juste après réautorisation, ne trouvait aucun champ focalisé puis a été interrompu pendant l’armement par une notification macOS. Le second essai a capturé directement le champ. `AXEnhancedUserInterface` renvoie `-25208` sur cette application, mais le champ est ensuite exposé sans recourir à une recherche arbitraire.

**Éditeur natif identifié par les traces : CotEditor, 14:20:20–14:20:25** :

- application `com.coteditor.CotEditor`, capture `AXTextArea`, `trusted=true`, `file=false` ;
- microphone réel, 41 478 échantillons (~2,6 s), transcription de 16 caractères ;
- collage envoyé, lecture AX de 25 à 41 caractères, remplacement attendu vérifié ;
- `sent=true confirmed=true`, `method=confirmed`, presse-papiers restauré (un élément).

L’utilisateur a ensuite indiqué « sur testedit, ça marche bien ». Ce retour est conservé comme confirmation utilisateur pour TextEdit ; **aucune séquence `com.apple.TextEdit` n’apparaît dans les traces recueillies**, qui attestent directement de CotEditor. Ne pas confondre les deux noms d’application dans les résultats techniques.

La restauration du presse-papiers est attestée par les traces ; le contenu n’a pas été journalisé ni comparé indépendamment octet par octet. Les scénarios champ protégé, changement de champ et modificateurs maintenus au-delà du délai restent à vérifier en intégration. Les protections correspondantes restent dans le code. Les 88 tests automatisés ne remplacent pas ces essais.

Le contrôle de l’interface ChatGPT via l’outil d’automatisation est explicitement refusé sur cette machine (`Computer Use is not allowed to use the app 'com.openai.codex' for safety reasons`). Il n’a pas été contourné. La vérification visuelle ChatGPT dépend donc du retour utilisateur, complété par l’instrumentation de Voxea.

Le correctif et le rapport sont enregistrés dans un commit séparé de `ce28a04`, après les retours utilisateur et l’examen des traces du parcours réel. Le dépôt ne déclare aucun distant Git ; aucun push n’a été effectué. `.rollback/` est conservé, non suivi comme au début. Les sauvegardes `.app.bak` et `.swift.bak` ne sont pas modifiées.


## 18 octobre 2026 — optimisation de latence, Voxea 0.4.2 (build 8)

### Changements

- Arrêt et démarrage du moteur audio sur une file série dédiée : la transcription ne dépend plus de l’arrêt matériel complet. Le tampon est figé au relâchement ; une conversion déjà en cours se termine sous le même verrou pour conserver sa fin. Les opérations matérielles restent sérialisées.
- Protection par génération de session : un démarrage annulé qui se termine tard ne peut ni réactiver l’ancienne capture ni arrêter une nouvelle dictée.
- Annulation coopérative de l’aperçu obsolète, puis attente de sa terminaison avant la transcription finale. La phrase complète est toujours retranscrite, sans réutiliser un aperçu tronqué.
- Le délai de lecture du presse-papiers est compté depuis l’envoi du collage, au lieu d’ajouter 900 ms après la fenêtre de vérification. Si la modification attendue est confirmée, le champ a déjà consommé le texte et la restauration peut se faire immédiatement. La protection contre une nouvelle copie utilisateur est conservée.
- La bulle se ferme dès l’envoi du collage. L’ancienne attente de 2,5 s après la livraison n’est maintenue que pour laisser lire un échec d’insertion. Le texte reste disponible dans la fenêtre principale, avec le résultat de la vérification.
- Traces horodatées à la milliseconde, durées monotones jusqu’à la transcription, à l’envoi et à la fin de livraison, sans contenu dicté ni audio.

### Vérifications et mesures

102 tests automatisés réussis : 12 raccourci, 41 mémoire, 27 formatage, 12 livraison/confirmation et 10 génération de session audio.

Le test `--benchmark-cancellation TestAudio/fr-long.aiff` a réellement interrompu cinq aperçus en cours dans FluidAudio : les cinq transcriptions finales sont identiques à la référence sans annulation. Les sorties finales des trois fichiers audio de référence FR, EN et FR long sont également identiques entre 0.4.1 et le code optimisé. Ces essais sur fichiers ne sont pas présentés comme des dictées au microphone.

Avant changement, les passes finales sur ces fichiers prenaient respectivement 54,8 ms, 43,2 ms et 105,6 ms sur ce Mac. Elles montrent que Parakeet n’était pas la principale attente sur ces extraits. Les anciens journaux de dictée, arrondis à la seconde, ne permettent pas de calculer un pourcentage fiable de gain avant/après.

Deux essais microphone dans ChatGPT (`com.openai.codex`) après réautorisation ont été examinés :

| Mesure depuis la fin de dictée | Build 7, 14:38:45 | Build 8, 14:42:11 |
|---|---:|---:|
| Prêt pour transcription finale | 170,6 ms | 85,6 ms |
| Transcription achevée | 219,3 ms | 140,9 ms |
| Calcul Parakeet final seul | 48,6 ms | 55,2 ms |
| Callback d’envoi (incluant fermeture de bulle en build 8) | 314,2 ms | 237,4 ms |
| Fin de livraison / disponibilité suivante | 1 645,9 ms | 1 591,9 ms |

Pour le build 8, l’événement de collage a été posté à 14:42:11,400, et la bulle masquée à 14:42:11,407, après le relâchement à 14:42:11,169. Ces chiffres mesurent l’envoi et la fermeture de bulle ; ils ne mesurent pas indépendamment le rendu visuel de ChatGPT. Le dernier essai contient 89 440 échantillons (~5,6 s) et une transcription de 51 caractères. L’arrêt matériel, exécuté à part, prend 27,3 ms sur cet essai.

L’utilisateur a confirmé « Plus rapide, texte complet » sur le premier essai, puis « Oui, la bulle disparaît au collage » sur le build 8. Les traces attestent `file=false`, `trusted=true`, le même champ AXTextArea, un overlay non actif, le collage et la restauration du presse-papiers (un élément).

### Limites conservées

La vérification exacte AX du remplacement reste non confirmée dans ces deux essais ChatGPT : résultat `method=paste`, succès visuel confirmé par l’utilisateur, sans prétendre `method=confirmed`. Le traitement de vérification/restauration peut donc rester occupé environ 1,3 s après l’envoi ; la bulle ne le masque plus à l’utilisateur et le texte est déjà envoyé. Le prochain raccourci n’est accepté qu’après la fin de livraison. Les gains sur des dictées longues ou dans d’autres applications ne sont pas extrapolés à partir de ces deux essais. Le mode appui-bascule n’a pas fait l’objet d’un nouvel essai microphone distinct.

Au premier déclenchement de chaque nouveau binaire, une notification macOS a interrompu l’armement ; ces essais sont exclus des mesures de succès. Le second déclenchement a enregistré la dictée. Les autorisations ont été renouvelées manuellement par l’utilisateur ; aucun contournement TCC n’a été ajouté.

Le binaire final est 0.4.2, build 8, signé localement. SHA-256 de `Contents/MacOS/Voxea` : `14745857beaeb4f7e30970f6e0d66b0a944c50b2498d0b89113f8108d3e2eb5f`. Il ne sera pas recompilé pour l’archive de publication. La version 0.4.1 reste disponible dans la Release précédente et dans une sauvegarde locale de travail. Les sauvegardes `.rollback/` et `.app.bak` ne sont pas modifiées.
