# Diagnostic : grattement sur les premières couches (Kobra X)

But : savoir si le bruit vient **de la buse qui frotte la pièce** (Z offset,
sur-extrusion, bords relevés) ou **de la mécanique** (axes, roues/rails,
courroies, ventilateur), puis quoi faire.

Faire les étapes dans l'ordre et noter ce qu'on entend à chaque fois.

## Étape 1 : mouvements sans impression, `test_mouvements.gcode`

Buse froide, sans filament. Lancer le fichier depuis la carte ou l'interface
(vérifier d'abord que la zone X/Y 20 → 200 mm est dans le plateau). Il fait,
avec une pause de 5 s entre chaque section :

1. monter Z à 10 mm ;
2. aller-retours en **X seul**, lents puis rapides ;
3. aller-retours en **Y seul**, lents puis rapides ;
4. **Z seul** qui monte et descend ;
5. diagonales X+Y ;
6. un carré à **1 mm** au-dessus du plateau.

| Ce qu'on entend | Cause probable | Action |
|---|---|---|
| Grattement en X seul | Tête : roues/patins ou rail X sec ou sale, courroie X qui frotte un flasque | Nettoyer le rail ou les roues, ajuster l'excentrique, vérifier la tension et l'alignement de la courroie |
| Grattement en Y seul | Plateau : roues ou rail Y, courroie Y, câble du plateau qui frotte | Pareil côté Y, et vérifier le passage du câble chauffant |
| Grattement en Z seul | Vis trapézoïdale sèche ou sale, coupleur, écrou anti-jeu | Nettoyer la vis, mettre une goutte de graisse PTFE ou lithium, vérifier le parallélisme |
| Bruit seulement en rapide | Résonance, courroie trop lâche ou trop tendue, ventilateur | Tension des courroies, vis du ventilateur de buse |
| **Silence partout** | La mécanique va bien : le bruit vient de l'impression | Étape 2 |

## Étape 2 : première couche, pièce `premiere_couche`

Cinq carrés d'une seule couche de 0,2 mm (4 coins et le centre). Exporter en
STL avec `part = "premiere_couche"` (déjà fait : `premiere_couche.stl`) et
trancher avec le profil habituel.

Regarder chaque carré :

- **Lignes rondes et séparées, on voit des trous** : buse trop haute. Descendre le Z offset de 0,02 à 0,05.
- **Lignes bien écrasées et soudées, surface lisse et mate** : c'est bon.
- **Surface transparente, crêtes, plastique repoussé sur les bords, bruit de grattement** : buse trop basse. Remonter le Z offset de 0,02 à 0,05.
- **Bon à un coin et mauvais à l'autre** : plateau pas plan ou maillage de nivellement à refaire. Relancer le nivellement automatique à chaud (plateau à 60 °C) et nettoyer la buse avant de palper.

## Étape 3 : épaisseur, pièce `escalier`

Six marches de 1, 2, 3, 5, 8 et 12 couches. Écouter pendant l'impression :

- **Le bruit commence dès la marche 2 ou 3 et augmente sur les couches pleines** : la buse frotte le dessus. Les causes probables sont, dans l'ordre :
  1. Z offset trop bas ;
  2. sur-extrusion : calibrer les e-steps, la rotation distance ou le débit (flow) ;
  3. lissage (*ironing*) activé ;
  4. « Z hop » désactivé alors que la buse passe sur des remplissages pleins.
- **Les marches sont bonnes et le dessus est lisse** : passer à l'étape 4.

## Étape 4 : trajets, pièce `bosses`

16 petits cylindres et de longs déplacements entre eux. Si on entend un
« tic » ou un grattement **pendant les trajets** et que les cylindres ont des
marques :

- Activer le **Z hop** (0,2 à 0,4 mm) ou l'option du trancheur qui évite les parties déjà imprimées pendant les trajets.
- Les bords qui se relèvent (*curling*) se voient sur les cylindres. Augmenter un peu le ventilateur à partir de la couche 3, sinon vérifier l'adhérence et la température du plateau.

## Ordre des actions conseillé

1. **Nettoyer** : buse (brosse laiton à chaud), plateau (alcool isopropylique, ou eau et savon pour un PEI texturé), rails et vis.
2. **Nivellement automatique à chaud**, puis **Z offset** avec `premiere_couche`.
3. **Débit** (flow) si `escalier` montre encore des crêtes sur le dessus.
4. **Z hop** si `bosses` montre des frottements pendant les trajets.
5. Si l'étape 1 a fait du bruit : entretien mécanique de l'axe concerné **avant** de toucher aux réglages d'impression.

> Les commandes du G-code sont standard (G28, G1, M117, M84). Elles sont
> acceptées par les firmwares Marlin et Klipper. Les messages `M117`
> s'affichent seulement si l'écran le permet.
