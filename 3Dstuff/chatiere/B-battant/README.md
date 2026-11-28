# B. Battant pivotant

Module imprimé de chatière à **battant pivotant sur un axe vertical**. Il se glisse dans la même encoche que le module de porte relevable du [concept A](../A-sas/) (côté gauche du caisson du sas, contreplaqué de 12 mm), à la place du volet 2. Pas de vis : le couvercle est serré par des molettes imprimées sur des tiges filetées imprimées avec le cadre.

![Fermé, vu de la pièce](apercu_ferme_piece.png) ![Ouvert, vu de la pièce](apercu_ouvert_piece.png) ![Ouvert, vu du sas](apercu_ouvert_sas.png)

Un battant de 226 × 166 × 6 mm aux coins bien arrondis (R 38) tourne autour d'un axe vertical, au milieu. L'ouverture fait 210 × 150 mm (`ouv_h_r`, 125 au minimum pour un chat adulte). Le module fait 243 × 202 × 23,6 mm (253 × 207 avec les collerettes). Avec `socle_r` (45 pour la fenêtre du concept C), le cadre et le couvercle s'allongent vers le bas : 253 × 252.

**Arrondis.** L'ouverture (R 30), le battant (R 38) et la cavité où il tourne suivent le même arrondi (`r_coin_r` règle le tout). Le cadre et les collerettes restent des rectangles. Là où passe le chat, les bords sont arrondis en quart de rond. Les faces d'appui des butées restent plates pour le feutre.

**Pourquoi le chat passe toujours à droite.** Depuis le sas, le chat pousse la moitié droite (vue du sas) vers la pièce. Depuis la pièce, sa droite est l'autre moitié, qu'il pousse vers le sas. Dans les deux cas le battant tourne **dans le même sens**. On peut donc lui mettre des butées à recouvrement, comme une vraie porte :

- la moitié droite s'appuie sur la **peau du cadre, côté sas** (8 mm de recouvrement) ;
- la moitié gauche s'appuie sur une **butée en U du couvercle, côté pièce**.

Dans l'autre sens, le battant est bloqué. Du feutre de 1 mm sur les butées fait le joint.

**Axe centré.** Les deux passages font 98 mm de large. Le vent du dehors pousse autant sur les deux moitiés : il ne l'ouvre pas et ne le referme pas. On peut encore décaler l'axe (`part_gauche` > 0,5) pour que le vent le referme, au prix d'un passage plus étroit en sortant du sas.

## Fermeture : élastique sur came, puis aimants

![Came et élastique, vu de dessus, battant à 45°](apercu_came.png)

**Rappel doux.** Un élastique tire le battant vers la position fermée. Il s'enroule sur une **came en spirale** posée en haut de l'axe. Plus la porte s'ouvre, plus l'élastique s'allonge, mais plus le rayon de la came diminue : le couple **baisse** au lieu de monter.

- Le profil est calculé pour que le couple à pleine ouverture soit `ratio_couple` (0,5) fois le couple porte fermée. Le rayon passe de 8,5 mm (fermé) à 5,2 mm (45°) puis à 3 mm (100°). L'élastique ne s'allonge que de 9 mm en plus de sa tension de repos (`pretension_r` = 20 mm).
- Avec un élastique de 0,1 N/mm, la poussée au milieu d'un passage serait d'environ 31 g fermé, 24 g à 45° et 16 g à 100°. Ce sont des ordres de grandeur : la raideur dépend de l'élastique.
- L'élastique est accroché d'un côté dans le trou de la came et de l'autre à l'un des **trois poteaux** de la chambre du haut, à 35, 50 ou 65 mm de l'axe. Plus le poteau est loin, plus l'élastique est tendu.
- **La came est une pièce à part** : la came, le tourillon rond du haut et un tenon en lame qui s'emboîte dans une mortaise du chant du battant. Pour changer la force, il suffit d'en réimprimer une avec un autre `came_r0_r`, `pretension_r` ou `ratio_couple`. La console vérifie qu'elle ne touche ni la peau côté sas (l'axe n'est qu'à 4 mm de l'intérieur de la peau), ni le couvercle, ni les poteaux.

**Verrou par aimants.** Le rappel ramène le battant presque fermé ; les aimants le tiennent fermé contre le vent. Des poches pour aimants disques Ø6 × 2 sont prévues en vis-à-vis dans la bande d'appui, en haut et en bas de chaque moitié, à **15, 30, 45, 60 et 80 mm** de l'axe :

- moitié droite (vue du sas) : dans la face avant du battant et dans la peau côté sas du cadre (il reste 0,8 mm de peau) ;
- moitié gauche : dans la face arrière du battant et dans la butée en U du couvercle.

On ne remplit qu'une paire ou deux, et on choisit la distance. Plus l'aimant est près de l'axe, plus le chat a de levier : pour un aimant qui tient avec 1 N, le chat doit pousser 0,27 N au milieu du passage s'il est à 15 mm, mais 1,4 N s'il est à 80 mm. Commencer près de l'axe et s'en éloigner si le battant ne tient pas. Coller les aimants (attention au sens : ils doivent s'attirer). Le feutre peut passer devant : il fait 1 mm d'entrefer.

**Ouverture maximale.** Vers 100°, la moitié qui s'ouvre vers la pièce bute sur le couvercle, près de l'axe. La came est calculée jusque-là (`angle_max`).

## Battant nervuré côté sas

![Battant tel qu'imprimé : face côté pièce sur le plateau, nervures dessus](apercu_battant.png)

Un grand panneau plat de 6 mm risque de se voiler avec le temps, et l'étanchéité en souffrirait. Le battant garde donc une **bande d'appui plate** de 6 mm tout autour (la face avant de la moitié droite s'appuie sur la peau du cadre, la face arrière de la moitié gauche sur la butée du couvercle).

- **Face côté pièce entièrement plane**, sans arrondi : c'est le dessous à l'impression, et le battant s'imprime **sans aucun support**.
- **Côté sas**, à l'intérieur de l'ouverture (3 mm en retrait de son bord), la plaque est amincie à 2 mm et porte **6 anneaux concentriques** de 1,6 mm de large, tous les 11 mm, qui suivent la forme arrondie du battant.
- **Le long de l'axe**, une bande pleine de 8,8 mm de large sur toute l'épaisseur (6 mm) : le carré de l'axe y passe en monobloc.
- Les nervures font 7 mm de haut et dépassent de 3 mm la face côté sas de la bande d'appui. Porte fermée, elles se logent dans le trou de la peau du cadre (4,3 mm de place). En tournant, elles ne touchent rien (vérifié tous les 5° de 0 à 100°, cadre en deux pièces et monobloc). Le cadre déjà imprimé ne change pas.
- 167 g au lieu de 237 g plein.

Options : `nervures = false` (plaque pleine), `nerv_n` (nombre d'anneaux), `nerv_l_r` (largeur des nervures), `nerv_plaque_r` (épaisseur de la plaque), `nerv_saillie_r` (saillie côté sas, limitée automatiquement à la place dans le trou de la peau).

**Axe.** En bas, un tourillon octogonal du battant ; en haut, le tourillon rond de la came. Ils tournent dans des paliers du cadre ouverts vers l'arrière, que deux taquets du couvercle referment. Le battant repose sur le bout du tourillon du bas.

**Fixation.** Le cadre porte dans ses coins 4 tiges filetées imprimées (Ø 10, pas de 3 mm, filet arrondi imprimable sans support), qui traversent le couvercle et dépassent de 13 mm côté pièce. Quatre molettes imprimées (Ø 16 × 8, moletées et taraudées) se serrent à la main. À l'échelle 0,4 : tiges Ø 6 au pas de 2, molettes Ø 10 × 5.

![Éclaté](apercu_eclate.png)

| Pièce | Qté | Impression |
|---|---|---|
| `cadre` | 1 | Face côté sas sur le plateau ; paliers, chambre de la came, poteaux et tiges filetées vers le haut. |
| `couvercle` | 1 | Face côté pièce sur le plateau ; butée et taquets vers le haut. |
| `battant` | 1 | À plat, face côté pièce dessous, nervures vers le haut : sans support. |
| `molette` | 4 | À plat, chanfrein d'entrée en bas. |
| `came` | 1 | Came sur le plateau, tenon vers le haut. |

Montage :

1. Coller les aimants dans les poches choisies, du battant et des butées, en vérifiant qu'ils s'attirent.
2. Enfoncer le tenon de la came dans la mortaise du haut du battant.
3. Poser le cadre face en dessous. Déposer le battant, tourillons dans les paliers, la came dans la chambre du haut.
4. Passer l'élastique dans le trou de la came et autour d'un poteau.
5. Poser le couvercle sur les tiges filetées et serrer les quatre molettes, puis glisser le module dans l'encoche, côté sas.
6. Le battant doit revenir doucement, puis se coller sur les aimants.

## Maquette (`maquette/`, échelle 0,4)

![Planche](apercu_maquette.png)

- `planche.stl` : toutes les pièces sur un plateau ; une STL par pièce.
- Buse de 0,4 mm, couches de 0,2 mm, PLA. Pas de feutre. Aimants Ø2 × 1 (la bande d'appui ne fait que 3,2 mm) ; les poches de la peau la traversent. Un élastique d'orthodontie. La came (rayon 3,2 mm) est surtout là pour voir le principe.
- Les STL ne sont pas dans git. Régénérer : `openscad -D echelle=0.4 -D 'part="planche"' -o maquette/planche.stl battant.scad`.

## Points à vérifier (non testé)

- **Rappel** : choisir l'élastique et le poteau. Si le battant ne revient pas jusqu'aux aimants, reculer d'un poteau ou réimprimer une came plus grande ou moins dégressive (`ratio_couple` plus près de 1).
- **Aimants** : leur force n'est pas connue ; commencer à 15 mm de l'axe.
- **Molettes** : le filet a 0,35 mm de jeu (`jeu_f`) ; l'augmenter si elles serrent trop.
- **Butées** : le battant doit être bloqué dans le mauvais sens et tourner librement de 0 à 90° dans le bon (vérifié sur le modèle aux deux échelles).

## Fichiers

* `battant.scad` : le module. Options : `echelle`, `angle` (angle d'ouverture du battant dans l'aperçu, de -5 à 90°), `coupe`, `part` (`assembled`, `eclate`, une pièce, `planche`), `part_gauche`, la came (`came_r0_r`, `pretension_r`, `ratio_couple`, `poteau`, `k_elast`), les aimants (`aim_d_r`, `aim_e_r`, `aim_dist_r`), les nervures (`nervures`, `nerv_n`, `nerv_l_r`, `nerv_plaque_r`, `nerv_saillie_r`), et pour la conception `arrondis = false` (sans arrondis des bords) et `rapide = true` (sans arrondis, filets lisses, moins de facettes ; pas pour imprimer). La console affiche les cotes, les passages, le profil de la came, les poussées et les leviers des aimants.
* `apercu_ferme_piece.png`, `apercu_ouvert_piece.png`, `apercu_ouvert_sas.png`, `apercu_eclate.png`, `apercu_came.png`, `apercu_battant.png`, `apercu_maquette.png`.

## Panneau vissé sur un 2×4 (chatière d'hiver, panneau gauche)

`battant.scad -D ouv_l_r=190 -D bordure_s_r=3 -D aile_r=44` : ouverture de 190 × 150 et module de 257 × 207. Les montants du cadre font 3 mm, et il n'y a pas de collerette au bout côté fenêtre. Une **aile pleine** de 44 mm, à l'autre bout, se pose sur la face de 3½ po d'un 2×4. Quatre vis n° 8 × 2 po la traversent en quinconce, têtes fraisées côté couvercle.

- La face du cadre (plate) va contre le 2×4.
- Ajouter `-D aile_gauche=true` si, vue du côté des têtes de vis, la fenêtre est à gauche. Tout le module est alors imprimé en miroir.
- La moitié du battant du côté de l'aile tourne toujours vers le couvercle, donc jamais vers le 2×4.

### Cadre d'une seule pièce (`monobloc = true`)

Le cadre et le couvercle sont fusionnés en une seule pièce : plus de tiges ni de molettes. On monte le battant de face, ouvert à 90°, puis on enfile un axe traversant par le haut. Fichier tout réglé : `panneau_gauche.scad`. STL : `stl_panneau_gauche/` (`cadre`, `battant`, `axe`).

- **Axe** (une pièce, 183 mm) :
  - rond Ø4 en bas, dans le palier du bas ;
  - carré de 4 dans le battant, avec un coin chanfreiné : il n'entre que dans un sens, donc la came est toujours bien orientée ;
  - rond Ø6 dans le palier du haut ;
  - came en tête : sa collerette pose sur le fond de la chambre, et c'est elle qui retient l'axe.
- **Battant** : un trou carré sur toute sa hauteur, le long de l'axe. Il repose sur un petit grain autour du palier du bas.
- **Chambre de la came** : ouverte en haut (on y descend l'axe) et côté couvercle (on y accroche l'élastique aux poteaux).
- **Poteaux d'élastique** : Ø5, avec un pied élargi et une tête qui retient la boucle. Leur section en goutte pointe vers la face côté sas, ce qui évite les supports quand le cadre est imprimé à plat.
- **Impression** :
  - le cadre à plat, face côté sas sur le plateau, avec des supports « depuis le plateau » sous la butée en U ;
  - le battant à plat ;
  - l'axe couché sur son méplat.
- **Montage** :
  1. enfoncer les aimants par l'arrière de leurs poches, qui s'ouvrent du côté opposé à l'appui (0,6 mm de paroi devant l'aimant), puis les coller ; dans la butée en U, la poche fait 11 mm de profondeur, et on pousse l'aimant au fond avec une tige ;
  2. glisser le battant de face, ouvert à 90° ;
  3. descendre l'axe par la chambre : il traverse le palier du haut et le battant, puis entre dans le palier du bas ;
  4. accrocher l'élastique entre la came et un poteau.
- Contrôlé dans le modèle :
  - le battant entre de face sans rien toucher, et l'axe descend sans rien toucher ;
  - le battant et l'axe tournent de 0 à 100° ;
  - seules la collerette de la came et le grain du bas portent.
