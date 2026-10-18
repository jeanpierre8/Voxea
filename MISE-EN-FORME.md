# Voxea — mise en forme et commandes vocales

Version 0.4.0, build 5. Ouvrir les réglages de Voxea, puis l’onglet **Mise en forme**.

## Commandes disponibles

| Dire | Résultat |
| --- | --- |
| « à la ligne » | Retour à la ligne ; nouvelle puce si une liste est en cours |
| « nouveau paragraphe » | Ligne vide et retour au texte hors liste |
| « faire une liste » | Début d’une liste à puces |
| « élément suivant » | Nouvelle puce, uniquement dans une liste en cours |
| « fin de liste » | Fin de la liste et retour à la ligne |

Exemple : « courses à la ligne faire une liste du pain élément suivant du lait fin de liste merci » donne :

```text
Courses
• Du pain
• Du lait
Merci
```

Les commandes sont reconnues dans la transcription finale, sans distinguer les majuscules. La ponctuation immédiatement après une commande est retirée pour éviter qu’elle apparaisse seule sur une ligne. Prononcer les commandes en français, même au milieu d’une dictée anglaise. Une liste ne se poursuit pas entre deux enregistrements. Les puces sont de simples caractères de texte : Voxea ne pilote pas les fonctions de liste de l’éditeur.

Pour dicter une expression telle que « à la ligne » littéralement, désactiver **Reconnaître les commandes vocales**. Le moteur transcrit d’abord les mots ; les commandes ne peuvent fonctionner que si ces mots sont correctement reconnus.

## Autres règles

- **Retirer le point final** : retire un point de fin de texte, conserve `?`, `!`, les points de suspension et certaines abréviations courantes. Ce réglage ne retire pas les points entre les phrases ni à la fin de chaque puce.
- **Commencer les phrases et les lignes par une majuscule** : majuscule au premier caractère alphabétique du texte, après un retour à la ligne et après `.`, `?`, `!`. Il s’agit d’une règle simple : elle ne comprend pas les adresses web, les acronymes ou toutes les abréviations. Désactiver cette règle pour dicter du code ou du texte sensible à la casse.
- **Retirer les hésitations** : enlève uniquement les mots isolés `euh`, `heu`, `uh`, `um` (avec leurs prolongations finales) et leur ponctuation immédiate. Les mots comme « bon » et « alors » sont conservés. Désactiver pour une transcription littérale.
- **Noms et expressions** : utiliser l’onglet **Dictionnaire** pour créer ses remplacements, par exemple `voxéa` → `Voxea`. Aucun nom personnel n’est ajouté automatiquement.

Les quatre options sont activées initialement, conformément aux choix validés. Elles sont indépendantes et enregistrées automatiquement.

## Selon l’application

Le choix **Toutes les applications** définit les réglages généraux. Sélectionner une application ouverte, puis modifier une option pour enregistrer un profil propre à cette application. Son profil reprend les autres options générales au moment de sa création. **Reprendre les réglages généraux** supprime ce profil et rétablit l’héritage.

Exemple : conserver le point final dans un traitement de texte et le retirer dans une messagerie. Un profil de navigateur concerne tous ses onglets. L’application cible est celle active au début de l’enregistrement.

## Essayer

L’aperçu **Essayer sans microphone** applique immédiatement les règles de mise en forme de l’application sélectionnée. Il ne copie rien, n’insère rien et ne compte aucune correction du dictionnaire. Il teste la mise en forme seule.

Pour une vraie dictée : **Ctrl + Maj + W**. Le dictionnaire est appliqué avant la mise en forme ; le texte final formaté est ensuite copié et/ou inséré selon les réglages de l’onglet Dictée. L’acceptation des suggestions utilise les options de mise en forme de la dictée d’origine. La transcription brute reste consultable jusqu’à la prochaine dictée ou à la fermeture de Voxea.

Tout le traitement reste local. Aucune permission supplémentaire n’est nécessaire pour ces règles. Les préférences sont stockées avec celles de Voxea ; le dictionnaire SQLite reste séparé.
