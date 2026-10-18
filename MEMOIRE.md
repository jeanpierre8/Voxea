# Mémoire des corrections — Voxea 0.3

La dictée reste assurée par Parakeet V3. Le dictionnaire ajoute ensuite les remplacements que vous avez explicitement enregistrés. Aucun réentraînement, Qwen ou Hermes n’intervient dans cette phase.

## Ajouter une correction

1. Ouvrir Voxea, puis l’onglet **Dictionnaire**.
2. Saisir le **texte entendu**, par exemple `Air Mess`.
3. Saisir le **texte à écrire**, par exemple `Hermes`.
4. Choisir **Toutes les applications**, ou une application précise.
5. Choisir **Automatique** ou **Suggestion seulement**, puis **Ajouter la règle**.

Aucune règle n’est ajoutée d’office. Les corrections que vous faites dans vos autres applications ne sont pas surveillées. Une règle enregistrée reste disponible après fermeture et redémarrage de Voxea.

## Automatique ou suggestion

Une règle **automatique** est appliquée après la transcription finale et avant le collage et la copie. La version corrigée est donc celle qui est insérée et placée dans le presse-papiers.

Une règle **suggestion seulement** ne change pas la dictée. La suggestion apparaît dans l’onglet Dictée après la transcription. **Copier en appliquant les suggestions** prépare la version proposée dans le presse-papiers ; vous pouvez ensuite sélectionner le texte à remplacer et le coller. Ce bouton ne réinsère pas le texte et n’envoie aucun message.

Le bouton global **Activer la mémoire des corrections** met toutes les règles en pause sans les supprimer.

## Vérifier et gérer

- Le champ **Phrase à tester** montre le résultat des règles actives, pour l’application choisie dans le formulaire. Il ne lance ni microphone ni collage et n’incrémente pas les compteurs.
- **Modifier** permet de changer le texte, la portée ou le mode d’une règle.
- L’interrupteur d’une ligne désactive uniquement cette règle.
- **Supprimer** retire la règle. **Annuler la dernière suppression** la restaure tant que Voxea reste ouvert ; cette annulation ne survit pas à la fermeture.
- La recherche porte sur le texte entendu et sur son remplacement.
- Le compteur représente les occurrences corrigées dans des dictées, ainsi que les suggestions explicitement acceptées. Il ne constitue pas un score de précision ou une preuve d’apprentissage acoustique.

Dans l’onglet **Dictée**, la **Transcription brute de la dernière dictée** reste consultable et copiable, même si des corrections ont été appliquées. Elle reste uniquement en mémoire jusqu’à la fermeture de l’application.

## Règles de remplacement

Les expressions sont littérales, appliquées sur des mots entiers, sans distinction majuscule/minuscule à la reconnaissance. L’orthographe du remplacement est conservée exactement. Les accents restent significatifs : `dicte` et `dicté` sont différents.

Les espaces ordinaires, insécables et tabulations entre les mots d’une expression sont acceptés. Une règle ne traverse pas un saut de ligne. Les règles sont limitées à une ligne, à 200 caractères entendus et à 500 caractères de remplacement.

Pour une même expression, la règle d’une application précise prime sur la règle générale, même s’il s’agit d’une suggestion. Sinon, le texte est parcouru de gauche à droite en privilégiant la phrase la plus longue au même emplacement. Le résultat d’un remplacement n’est jamais recorrigé par une autre règle pendant cette dictée.

La portée est l’application entière. Elle ne distingue pas les sites ou les onglets d’un même navigateur. Des mots ambigus doivent rester en suggestion ou être limités à une application.

## Données locales

La base est conservée ici :

`~/Library/Application Support/Voxea/corrections.sqlite3`

Elle contient les règles, leur portée, leur mode, leur état, leurs dates et leurs compteurs. Elle ne contient ni audio ni historique complet de vos dictées. Les journaux techniques SQLite éventuels restent dans le même dossier. Le fichier de base est réservé au compte utilisateur du Mac (permissions 600).

Pour une sauvegarde manuelle, quitter Voxea puis copier le dossier `~/Library/Application Support/Voxea`. L’archive de l’application dans Documents ne contient pas cette base personnelle.

Si la base ne peut pas être ouverte, Voxea signale l’erreur et conserve la dictée brute ; il ne remplace pas le fichier par une base vide. Une règle modifiée s’applique aux prochaines dictées : le texte déjà envoyé à une autre application n’est pas modifié rétroactivement.
