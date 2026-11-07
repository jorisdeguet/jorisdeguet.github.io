# strong-gcode-gen

Générateur de pièces imprimées en PLA sur **Anycubic Kobra X** qui minimise la
matière (pièce + supports) sous une contrainte de résistance, en tenant compte
de l'**orientation d'impression** (anisotropie des couches) et des **supports**.
Sortie : un gcode prêt à imprimer.

Premier cas d'étude (v0.1) : **crochet de plafond** vissé par une seule vis
dans un plafond plat, avec un C qui doit tenir **2 kg** avec un
**coefficient de sécurité** paramétrable (3 par défaut, car le PLA flue sous
charge permanente).

```
plafond ──────────────────────────────── z = 0
        [====== semelle ======]   vis Ø4 en x = 0
           ^vis          ║ tige (x = e, tête de vis accessible)
                         ║
                         ╲        ╱  ← pointe du C (220°)
                          ╲______╱
                             ↓ 2 kg × SF
```

## Utilisation

```bash
cd 3Dstuff/strong-gcode-gen
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m pytest -q                      # tests (~40 s)
.venv/bin/python -m sgg validate                   # FEA vs théorie des poutres
.venv/bin/python -m sgg evaluate --set b=8 h_s=6   # un design, toutes les orientations
.venv/bin/python -m sgg optimize --pop 12 --gens 8 --out results   # GA + aléatoire + gcode
.venv/bin/python -m sgg --mass 5 --sf 2.5 optimize ...             # autre charge
.venv/bin/python -m sgg slice results/best_params.json --out out/x # retrancher un design
```

Le gcode est produit par la CLI d'OrcaSlicer (≥ 2.3 ; testé avec 2.4.2,
`/Applications/OrcaSlicer.app`, ou variable `ORCA_SLICER`). Résultats du
dernier essai : [`results/summary.md`](results/summary.md).

## Architecture

```
 HookParams ──► Hook.sdf (géométrie paramétrique, distance signée)
                 │
                 ├─► voxels ──► FEA élastique linéaire (scikit-fem, Hex1, pyamg)
                 │               └─► tenseur des contraintes par élément
                 │
                 ├─► pour chaque orientation candidate d (25 directions) :
                 │     • critère de rupture anisotrope avec normale aux couches = d
                 │     • volume de supports (colonnes de voxels dans le repère machine)
                 │     → masse totale = pièce + supports ; faisable si FI ≤ 1, vis, flèche
                 │     → on garde la meilleure orientation
                 │
 optimiseur (GA / aléatoire) ◄── masse totale + violation des contraintes
                 │
 meilleur design ─► FEA fine de vérification ─► STL orienté ─► OrcaSlicer CLI ─► gcode Kobra X
```

| module | rôle |
|---|---|
| `sgg/hook.py` | géométrie paramétrique (SDF unique ; maillage STL par marching cubes), cahier des charges, conditions aux limites, calculs analytiques (traction de vis, poutre) |
| `sgg/material.py` | PLA : rigidité isotrope, résistance isotrope transverse, critère de rupture |
| `sgg/fea.py` | voxelisation → maillage hexaédrique, élasticité linéaire, contraintes aux coins des éléments |
| `sgg/orientation.py` | directions candidates, estimation des supports |
| `sgg/evaluate.py` | évaluation complète d'un design (une FEA, toutes les orientations) |
| `sgg/optimize.py` | GA réel (SBX + mutation polynomiale, tournoi, élitisme, règles de Deb), recherche aléatoire, évaluation parallèle avec cache |
| `sgg/slicer.py` | résolution des profils Orca Kobra X, réglages « résistance », appel CLI, lecture des stats du gcode |
| `sgg/cli.py` | commandes `evaluate`, `validate`, `optimize`, `slice` ; résumé `summary.md` + `convergence.svg` |

### Choix techniques

- **Une seule géométrie : la SDF.** Le voxelisage FEA, l'estimation des
  supports et le STL (marching cubes, pas 0,2 mm) viennent de la même
  fonction ; pas de dérive entre « ce qui est calculé » et « ce qui est
  imprimé ». Les booléens et congés (union lisse) sont triviaux en SDF.
- **FEA voxel Hex1 + multigrille algébrique.** Pas de mailleur tétraédrique
  à installer ; robuste pour n'importe quelle géométrie de la population.
  Le solveur pyamg (CG + agrégation lissée avec modes rigides) est ~25×
  plus rapide que SuperLU (≈ 1 s pour 20 k DDL, 6 s pour 150 k).
- **Congés et arêtes arrondies obligatoires.** Sans congé, l'angle rentrant
  tige/semelle est une singularité : l'indice de rupture passait de 1,45 à
  2,12 entre des voxels de 1 et 0,5 mm. Congé circulaire R2 (union
  arrondie, pas le smin polynomial dont le rayon effectif est bien plus
  petit) + arêtes de la tige et du C arrondies R1 (sinon le congé fait un
  pli rentrant au droit des arêtes vives).
- **Contrainte de calcul moyennée (théorie des distances critiques).** Même
  avec congés, le pic de contrainte sur la surface « en escalier » des
  voxels ne converge pas (FI pic 0,86 → 1,14 entre 1 et 0,4 mm). On prend
  donc, comme la méthode volumique de Taylor (*The Theory of Critical
  Distances*, Elsevier 2007), la moyenne du tenseur des contraintes sur une
  boule de rayon 1 mm. Pour le PLA, L = (K_IC/σ₀)²/π ≈ (3/50)²/π m ≈ 1 mm
  et la méthode volumique moyenne sur ~1,8 L : 1 mm est prudent. Résultat
  convergé à ±10 % entre 1 et 0,4 mm. En flexion pure, cette moyenne vaut
  ~80 % de la contrainte de peau (c'est aussi l'« effet d'échelle » observé :
  la résistance en flexion du PLA dépasse sa résistance en traction).
  `--tcd 0` revient au pic aux coins des éléments (très conservatif).
- **Vérification + réparation.** L'optimisation tourne à 0,75 mm ; le
  meilleur design est revérifié à 0,5 mm et, s'il n'y est pas faisable,
  épaissi (b, h_s, h_c, t_p × FI^(1/3)) jusqu'à ce qu'il le soit.
- **Orientation optimisée « à l'intérieur ».** La rigidité étant supposée
  isotrope, le champ de contrainte ne dépend pas de l'orientation : une
  seule FEA par géométrie, puis évaluation exhaustive de 25 orientations
  (plan XZ tous les 22,5°, à plat, diagonales). Le GA ne cherche donc que
  sur les 6 paramètres géométriques.

### Validation (théorie des poutres)

| cas | FEA / théorie |
|---|---|
| console 40×8×6 mm, flèche, voxels 1 mm / 0,5 mm | 0,98 / 0,99 |
| console, contrainte de flexion (coins des éléments) à mi-portée, 1 mm / 0,5 mm | 1,07 / 1,04 |
| console, même contrainte moyennée sur 1 mm (critère de calcul), 1 mm / 0,5 mm | 0,78 / 0,84 |
| tige du crochet : σ = F/(bh) + 6Fρ/(bh²) (coins des éléments) | 1,04 |

## Hypothèses matériau : PLA FDM anisotrope

Une pièce FDM est un empilement de couches : dans le plan des couches les
cordons sont continus (résistance proche du PLA massif), alors qu'entre
couches la cohésion ne vient que de la soudure partielle des cordons. La
littérature trouve systématiquement que les éprouvettes imprimées
« debout » (traction normale aux couches) sont les plus faibles :

- Ahn et al. (2002), *Anisotropic material properties of fused deposition
  modeling ABS*, Rapid Prototyping J. 8(4):248-257 — première
  caractérisation systématique de l'anisotropie FDM.
- Chacón et al. (2017), *Additive manufacturing of PLA structures using
  fused deposition modelling: effect of process parameters on mechanical
  properties and their optimal selection*, Materials & Design 124:143-157 —
  PLA : orientations « à plat » et « sur chant » nettement plus résistantes
  que « debout », où la rupture est inter-couches.
- Song et al. (2017), *Measurements of the mechanical response of
  unidirectional 3D-printed PLA*, Materials & Design 123:154-164 — PLA
  unidirectionnel : rigidité peu anisotrope, résistance nettement plus faible
  perpendiculairement aux couches.
- Gordelier et al. (2019), *Optimising the FDM additive manufacturing process
  to achieve maximum tensile strength: a state-of-the-art review*, Rapid
  Prototyping J. 25(6):953-971 — synthèse de l'effet des paramètres
  (orientation, périmètres, remplissage, température).

Valeurs de calcul retenues (prudentes, pièce **pleine** : 6 périmètres +
remplissage 100 %) — à recaler par des essais sur la Kobra X (voir feuille
de route) :

| grandeur | valeur | commentaire |
|---|---|---|
| E, ν | 3000 MPa, 0,35 | rigidité supposée isotrope |
| densité | 1,24 g/cm³ | |
| X_t traction dans le plan | 40 MPa | PLA massif 50-60 MPa |
| Z_t traction normale aux couches | 18 MPa | ~40-50 % de X_t |
| S_z cisaillement inter-couches | 18 MPa | |
| X_c compression | 60 MPa | |

Critère (type Tsai-Hill sans termes croisés), avec `n` = normale aux couches :

```
FI = sqrt( (vm_plan/X_t)² + (⟨σ_n⟩₊/Z_t)² + (⟨σ_n⟩₋/X_c)² + (τ_n/S_z)² ) ≤ 1   à F = m·g·SF
```

## Modèle mécanique du crochet

- **Encastrement** : face d'appui au plafond bloquée côté vis/arrière
  (x ≤ rayon de tête). La partie avant n'est pas bloquée car le moment
  F·x_c tend à la décoller. Les éléments à < 1,5 mm de la frontière
  bloqué/libre (singularité numérique artificielle) sont exclus du critère.
- **Charge** : F = m·g·SF verticale, répartie sur la face intérieure du C
  (±12° autour du point bas), là où porte une sangle.
- **Vis** : traction calculée par équilibre de la semelle rigide pivotant sur
  son bord arrière : T = F·(x_c + l_arr)/l_arr ≤ 300 N. C'est ce qui pousse
  la semelle à s'allonger vers l'arrière (`pad_back`).
- **Flèche** en service ≤ 3 mm.
- **Fonctionnel (fixe)** : rayon intérieur du C 12 mm, ouverture 220°, tige
  15 mm, vis Ø4 (trou 4,5, tête Ø8 accessible au tournevis), congés R2,
  arêtes R1.
- **Variables** (bornes en mm) : largeur `b` [3-20], épaisseur de tige `h_s`
  [3-14], épaisseur du C `h_c` [3-14], épaisseur de semelle `t_p` [2-10],
  demi-largeur de semelle `r_p` [5,5-16], prolongement arrière `pad_back`
  [0-30].

## Supports

Méthode par colonnes de voxels (pas 1 mm) dans le repère machine : toute face
inférieure en surplomb (> 50° de la verticale, soit `support_threshold_angle`
= 40° dans Orca) hors plateau demande une colonne de support jusqu'au plein
inférieur ou au plateau ; volume × densité équivalente 0,25 (supports
arborescents + interfaces). Le pipeline tranche aussi le meilleur design
**avec et sans supports** dans Orca pour comparer l'estimation à la matière
réellement consommée (voir `results/summary.md`).

## Anycubic Kobra X et gcode

D'après le profil système livré avec OrcaSlicer 2.4.2
(`Resources/profiles/Anycubic/machine/Anycubic Kobra X 0.4 nozzle.json`) et
la fiche produit Anycubic :

- volume d'impression **260 × 260 × 260 mm**, buse **0,4 mm acier trempé**
  (0,25 / 0,6 / 0,8 en option), entraînement direct, plateau PEI sur acier
  ressort (100 °C max), multicolore via ACE 2 Pro ;
- firmware **Kobra OS** (base Klipper) → `gcode_flavor = klipper`,
  extrusion relative (`M83`), `SET_PRESSURE_ADVANCE`, `EXCLUDE_OBJECT_DEFINE` ;
- gcode de début : macro propriétaire
  `G9111 bedTemp=[first_layer_bed_temperature] extruderTemp=[first_layer_temperature]`
  (chauffe, nettoyage, palpage gérés par le firmware) ;
- gcode de fin : `M400 / M140 S0 / M104 S0 / M107 / M84` ;
- limites : 450 mm/s, 10 000 mm/s².

`sgg/slicer.py` résout la chaîne `inherits` des profils système (machine
Kobra X 0.4, process « 0.20mm Standard », filament « Anycubic PLA »), puis
applique des réglages orientés résistance : **6 périmètres, 6 couches
dessus/dessous, remplissage 100 %**, supports arborescents partout, pas de
tour de purge, plaque PEI texturée (le profil pointe sinon sur la plaque
froide à 35 °C). Deux pièges de la CLI Orca contournés :

1. le profil système Kobra X contient `retraction_distances_when_cut = 0`,
   hors de la plage [10, 18] : la CLI refuse de trancher (code 238,
   message seulement sur stderr) ; on force 18 (inutilisé car
   `enable_long_retraction_when_cut = 0`) ;
2. la compatibilité process/imprimante est vérifiée via le nom du profil
   parent : les profils aplatis déclarent donc `inherits` vers les profils
   système.

La pièce est tournée (direction `d` vers +Z) et centrée sur le plateau
avant le tranchage (`--arrange 0`).

## Limites connues (v0.1)

- élasticité linéaire, pas de contact unilatéral au plafond ni de vis
  modélisée en FEA (traction de vis analytique) ;
- pièce supposée pleine (remplissage 100 %) : le remplissage n'est pas
  encore une variable ;
- rigidité isotrope ; valeurs de résistance issues de la littérature, non
  recalées ; pas de fluage (couvert par le SF) ;
- rayon de moyenne TCD (1 mm) estimé, non mesuré : c'est le réglage qui
  pèse le plus sur la masse finale (pic → moyenne divise FI par ~2) ;
- orientation discrète (25 directions), rotation dans le plan du plateau
  ignorée (plan des couches supposé isotrope : faux en réalité à cause de
  la direction des cordons et de la couture) ;
- supports estimés grossièrement (densité équivalente constante) : sur le
  premier essai, Orca consomme 1,5 g de supports contre 0,55 g estimés
  (pièce : 3,50 g Orca contre 3,67 g estimés) → `support_density` est à
  recaler (~0,7 plutôt que 0,25 pour ces petits surplombs, où brim et
  interfaces dominent).

## Feuille de route

1. **Recalage expérimental** : imprimer sur la Kobra X des éprouvettes
   (ISO 527 / ASTM D638) à plat, sur chant et debout ; mesurer X_t, Z_t, E ;
   tester le crochet à rupture (seau d'eau) pour valider FI.
2. **Remplissage et périmètres comme variables** : propriétés homogénéisées
   du remplissage (gyroïde, % variable), coque = n périmètres ; masse
   calculée par Orca.
3. **Supports** : calibrer `support_density` sur les volumes Orca
   (avec/sans supports), puis option « supports réels » en boucle.
4. **Mécanique** : contact unilatéral au plafond, vis en FEA, éléments Hex2
   ou raffinement local, théorie des distances critiques pour les entailles,
   flambement, fluage (charge permanente).
5. **Orientation continue** et rotation dans le plan (direction des cordons,
   position de la couture).
6. **Optimiseurs** : CMA-ES, NSGA-II multi-objectif (masse / temps
   d'impression / capacité), métamodèle (krigeage) pour réduire le nombre de
   FEA ; optimisation topologique (SIMP) sur la grille voxel existante.
7. **Autres pièces** : équerres, supports d'étagère, pinces — même pipeline
   avec un nouveau module géométrie + cas de charge.
8. **Gcode maison** : trancheur minimal pour contrôler les trajectoires
   (cordons alignés sur les contraintes principales).
