# Crochet de tableau blanc sous tablette

Petite pièce imprimée pour suspendre un tableau blanc **sous une tablette appuyée contre un mur**, sans percer.

- Un **bloc** court et épais (10 × 6 mm) se pose sur le dessus de la tablette et accroche le bois.
- Une **bande mince** (0,8 mm) se glisse entre le mur et l'arrière de la tablette.
- Sous la tablette, la bande s'épaissit (rampe à 45°) et **descend** jusqu'à un **crochet en U** qui reçoit le bord du haut du tableau.

Le profil est entièrement orthogonal, avec de petits goussets à 45° dans les angles intérieurs pour renforcer les plis.

Fichier : `whiteboard_hanger.scad` (OpenSCAD). `whiteboard_hanger.stl` contient 2 exemplaires avec les valeurs par défaut.

## Paramètres

| Paramètre | Défaut | Rôle |
|---|---|---|
| `part` | `"print"` | `"print"` : à plat, prêt à trancher. `"preview"` : en place avec mur, tablette et tableau fantômes |
| `count` | 2 | nombre d'exemplaires sur le plateau |
| `width` | 20 | largeur du crochet (= hauteur d'impression) |
| `strip_t` | 0.8 | épaisseur de la bande coincée entre mur et tablette |
| `shelf_t` | 21.4 | épaisseur de la tablette = longueur de la bande mince |
| `shelf_clear` | 0.5 | jeu : la partie épaisse commence ce jeu sous la tablette |
| `tab_len` | 10 | longueur du bloc sur la tablette (depuis le mur) |
| `tab_t` | 6.0 | hauteur du bloc (court et épais pour ne pas plier sous la charge) |
| `tab_lip_h` | 0 | rebord descendant au bout de la languette (0 = aucun) |
| `drop_len` | 60 | du dessous de la tablette au fond intérieur du crochet |
| `below_t` | 3.5 | épaisseur de la bande sous la tablette |
| `board_t` | 15 | épaisseur du tableau (ou de son cadre) |
| `board_clear` | 1.0 | jeu entre le tableau et la lèvre |
| `hook_t` | 4.0 | épaisseur du fond et de la lèvre du crochet |
| `lip_h` | 12 | hauteur de la lèvre au-dessus du fond |
| `fillet` | 2.5 | goussets dans les angles du crochet (0 = angles vifs) |
| `top_fillet` | 0.6 | gousset entre la bande mince et le bloc ; loge dans l'arête arrière-haut de la tablette, qui doit être adoucie d'au moins cette valeur (sinon 0) |
| `tab_round` | 1.5 | rayon des deux arêtes avant du bloc du haut (dessus visible, dessous contre le bois) |

Pour **enserrer l'avant de la tablette** (pièce impossible à faire glisser) : `tab_len = strip_t + profondeur de la tablette + jeu + tab_t` et `tab_lip_h` = 5 à 10 mm.

`shelf_depth`, `board_h` et `ghost_len` ne servent qu'à l'aperçu.

## Mesures à prendre

1. Épaisseur de la tablette → `shelf_t`.
2. Hauteur voulue du haut du tableau sous la tablette → `drop_len`.
3. Épaisseur du tableau **au bord du haut** (cadre compris) → `board_t`.

Note : les goussets du crochet (`fillet`) mangent un peu les coins du tableau. Avec un cadre aux coins arrondis, ça ne gêne pas ; sinon mettre `fillet = 0` ou ajouter un peu à `board_clear`.

## Impression (Kobra X, PLA)

- **Coucher la pièce sur le côté** : le profil à plat sur le plateau (c'est l'orientation exportée par `part = "print"`). Les couches suivent alors le profil, donc les plis ne peuvent pas se fendre entre deux couches. Debout, la languette et le crochet casseraient au premier effort.
- Aucun support nécessaire.
- Buse 0,4 : la bande de 0,8 mm = 2 périmètres. Régler le trancheur pour qu'il **n'oublie pas les parois minces** (dans Cura « Imprimer les parois fines » / PrusaSlicer-Orca « détection des parois minces »). Vérifier l'aperçu du trancheur.
- 100 % de remplissage (de toute façon la pièce est presque entièrement en périmètres).
- Hauteur de couche 0,2 mm ; première couche soignée — la pièce est étroite au sol, un peu de bordure (brim) aide.
- Utiliser au moins 2 crochets, vers les extrémités du tableau.

## Utilisation

1. Décoller légèrement la tablette du mur, glisser la bande mince derrière, languette sur le dessus.
2. Repousser la tablette contre le mur.
3. Poser le bord du haut du tableau dans les crochets.
