# Cador — storyboard de la fiche Play Store

Statut : **livré** — les 8 visuels sont dans ce dossier (`01_…` à `08_…`, PNG 1080×1920). Sources : `../compose/` (`node render.mjs`, contrôle `node qa.mjs`), captures brutes `../raw/`, démo `../demo/`.

## L'app en une phrase

Cador garde la trace de toutes les parties jouées (jeux de société, cartes, jeux vidéo, sport) et en tire un
classement permanent : l'Elo dit enfin qui est le meilleur du groupe. Entre amis dans un groupe, ou à plus grande
échelle dans un serveur (café jeux, club, association).

- **Pour qui** : les groupes d'amis, familles, collègues, colocs qui jouent régulièrement ensemble ; les cafés jeux,
  clubs et associations qui animent des parties et des tournois.
- **Problème résolu** : les scores notés sur un coin de papier se perdent, personne ne se souvient de qui a gagné, et
  « qui est le meilleur ? » se règle à la mauvaise foi. Côté café jeux : organiser les inscriptions et garder des
  résultats fiables.

## Fonctionnalités différenciantes retenues

1. **Classement permanent avec Elo** : tout le monde part de 100 et grimpe vers son niveau ; podium, cote par jeu,
   paliers Bronze → Argent → Or → Platine → Diamant.
2. **Saisie des scores adaptée à chaque jeu** : points, manches, classement, temps, victoire/défaite, équipes, coop ;
   total et graphique d'évolution automatiques ; la partie en cours est visible « en direct » par le groupe.
3. **Pronostics et équipes équilibrées** calculés d'après l'Elo.
4. **Vie de groupe** : discussion avec sondage « on joue à quoi ce soir ? », faits marquants automatiques, invitation
   par lien ou QR code ; profil avec courbe Elo, records et badges.
5. **Serveurs pour les grosses structures** : salons, rôles propriétaire/admin, évènements planifiés (partie ou
   tournoi) avec inscriptions, places limitées et liste d'attente, résultats en attente jusqu'à confirmation par
   chaque joueur, invités sans compte, invitation par QR code sur place.

## Charte (tirée du code)

| Élément | Valeur |
| --- | --- |
| Marque (icône, site) | nuit `#0B1238`, meeple menthe `#5FDDB6`, couronne or `#FFB938` |
| Interface (thème par défaut) | crème `#F4F2EC`, encre `#18171C`, accent menthe « Cador » `#1DA578`, or `#E8A93B`, vert `#1F9D57` |
| Typo | Space Grotesk (titres, chiffres), Manrope (texte) |

## Le fil conducteur

Une histoire : **Léa** (personnage fictif) et son groupe d'amis « Les Bandits ». Hugo mène le classement ; ce soir,
au Skyjo, Léa part outsider… et gagne. Elle prend la tête. Le samedi, le groupe joue son tournoi Mario Kart. Et Cador
sert aussi les lieux : le café jeux de Léa (« Le Repaire », fictif) a son propre serveur.

- **Fond** : un seul grand panorama nuit de la marque (`#070C27` → `#111A49`), découpé en 8 : le dégradé, les
  petites étoiles (formes vectorielles, pas d'emoji) et le halo coloré se prolongent d'une image à l'autre. Le halo suit
  l'histoire : froid pour le problème, puis bleu → menthe → or au fil de la soirée et du tournoi, bleu + menthe + or
  (couleurs du logo) pour l'appel à l'action.
- **Élément qui traverse les images** : une ligne menthe → or (le meeple et sa couronne), dessinée comme la courbe Elo de l'app, qui sort du
  bord droit de chaque visuel à la hauteur où elle entre dans le suivant ; griffonnée au crayon sur le visuel 2, elle
  grimpe pendant la partie, rejoint la vraie courbe du profil au visuel 7 et finit sur la couronne du logo au 8.

## Système visuel (inspiré des visuels Discord du Play Store)

Ce que fait Discord : fond dégradé continu semé de petites étoiles, gros titre centré + sous-titre, téléphone réduit
à un cadre « verre » translucide coupé par le bas, et surtout des **éléments d'interface découpés dans la capture,
agrandis et posés par-dessus le téléphone**, qui débordent du cadre avec une ombre (une carte, un bouton, un bloc de
liste), parfois un petit personnage qui dépasse.

Adaptation Cador :

- **Titre** : Space Grotesk Bold, majuscules, blanc, centré, 2 lignes maximum, un mot en or `#F5A623` ; sous-titre
  Manrope en dessous. Même position et mêmes marges sur les 8 visuels.
- **Téléphones** : un vrai téléphone (type Pixel : châssis aluminium graphite, bordure noire, caméra poinçon
  centrée, boutons à droite), coupé par le bas, au même gabarit ; à deux écrans, celui du fond est un peu plus petit
  et décalé, celui de devant le chevauche.
- **Superpositions** : 1 à 2 éléments par visuel, découpés dans les vraies captures (aucune interface inventée),
  agrandis d'environ 1,3×, posés à l'endroit d'où ils sortent et débordant du téléphone, avec ombre portée.
- **Décor** : étoiles et formes géométriques aux couleurs du logo, la couronne de l'icône et des marches de podium en
  vectoriel ; jamais d'emoji en décor.

## Les 8 visuels

Google Play accepte 8 captures au maximum. La plupart des visuels montrent **deux écrans** de l'app : une vue
d'ensemble (téléphone du fond, légèrement plus petit) et un écran ciblé (téléphone de devant), toujours au même
gabarit.

| # | Rôle | Titre (4-6 mots) | Écran(s) de l'app | Élément(s) superposé(s) | Ce qu'il apporte à l'histoire |
| --- | --- | --- | --- | --- | --- |
| 1 | Hook | **Qui est le meilleur ? Prouvez-le.** | 1 écran : Classement (Elo), podium avec Léa 1re | Le podium (avatars, marches, Elo) qui jaillit de l'écran, couronne de l'icône au-dessus | La promesse : un classement indiscutable. |
| 2 | Problème | **Fini les scores perdus sur papier** | Feuille de scores griffonnée (illustration) + Accueil du groupe (en tête de la saison, stats, classement, dernières parties) | La carte « En tête cette saison » et la rangée de stats (parties, jeux, joueurs) | Le besoin : le papier se perd ; dans Cador, tout le groupe est au même endroit. |
| 3 | Parcours 1 | **Ce soir, on joue à quoi ?** | 2 écrans : Discussion (sondage de jeux) → « Qui joue ? » | La bulle du sondage (votes) et la carte Pronostic | La soirée commence : le groupe vote, Skyjo l'emporte ; d'après l'Elo, Hugo part favori et Léa outsider. |
| 4 | Parcours 2 | **Comptez les points, manche après manche** | 2 écrans : la saisie par manche sur le téléphone de Léa + la « Partie en direct » sur celui d'Hugo | Le graphique d'évolution des scores et l'en-tête « Partie en direct » | Pendant la partie, Cador fait les totaux ; les amis suivent les scores en direct. |
| 5 | Parcours 3 | **Chaque victoire fait grimper l'Elo** | 2 écrans : Historique des parties (vue d'ensemble) + détail de la partie de Skyjo | La ligne de Léa « 1er · +xx Elo » et, en rappel, sa ligne du pronostic | Le dénouement, gardé pour toujours : l'outsider gagne, l'Elo s'envole. |
| 6 | Parcours 4 | **Organisez de vrais tournois** | 2 écrans : « Format du tournoi » (élimination simple, double, poules) + le bracket du tournoi Mario Kart | La bannière « Champion » et la carte de la finale | Le samedi, le groupe passe au tournoi : chaque match enregistré fait avancer le bracket. |
| 7 | Bénéfice | **Grimpez de Bronze à Diamant** | 2 écrans : profil de Léa (palier, courbe Elo, records) + sa collection de badges | La carte palier + courbe Elo, et quelques médailles de badges qui flottent | La progression dans la durée : la courbe grimpe, les badges se débloquent. |
| 8 | Communauté + appel à l'action | **Créez votre groupe ou votre serveur** | 2 écrans : « Mes groupes & serveurs » avec le choix « Quoi créer ? » + focus sur le serveur « Le Repaire » (salons, membres, rôles) | La tuile « Un serveur — pour un café jeu ou une structure », la carte du tournoi planifié du café (inscrits, liste d'attente), le logo Cador | Entre amis comme pour un café jeux : on passe à l'action. |

Sous-titres retenus :

1. Un classement Elo permanent pour votre groupe.
2. Chaque partie gardée, chaque stat calculée.
3. On vote, et l'Elo fait le pronostic.
4. Cador compte, vos amis suivent en direct.
5. Battre plus fort que soi rapporte davantage.
6. Élimination simple, double ou en poules.
7. Courbe Elo, records et badges à débloquer.
8. Pour vos amis, ou pour tout un café jeux.

## Données de démo prévues

- Groupe « Les Bandits » : 8 joueurs fictifs avec avatars illustrés de l'app (Léa, Hugo, Inès, Malik, Chloé, Théo,
  Nora, Sami), environ trois mois de parties sur des jeux réels de la bibliothèque (Skyjo, Catan, Mario Kart 8
  Deluxe, Codenames, Uno, Pétanque, Dixit…) avec leurs vraies règles, et un tournoi Mario Kart à 8.
- Serveur « Le Repaire » (café jeux fictif) : quelques salons, des membres et des invités, un tournoi planifié avec
  inscriptions et liste d'attente, une partie en attente de confirmation.
- Un point d'entrée de démo dédié, branché sur les dépôts en mémoire de l'app : aucun accès à Firebase ni à la prod.

## Image de présentation (1024 × 500)

`presentation_1024x500.png` (PNG 24 bits sans transparence) : le même fond nuit, la ligne Elo qui monte sous
l'accroche et derrière les téléphones, l'icône et le nom Cador, la promesse du visuel 1 (« Qui est le meilleur ?
Prouvez-le. ») avec « Scores, classement Elo et tournois entre amis. », puis deux vrais téléphones : devant, une
partie terminée ouverte depuis l'historique (le 7 Wonders du 27 sept. gagné par Léa, 52 pts), d'où sort sa feuille
de score (Rhodes, +46 Elo, les 7 catégories) ; derrière, la courbe Elo de Léa ; et la médaille « Numéro 1 ». Source :
`../compose/presentation_1024x500.html` (`node render.mjs presentation`).
