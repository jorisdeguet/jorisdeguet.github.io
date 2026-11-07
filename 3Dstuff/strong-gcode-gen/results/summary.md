# Résultats — crochet de plafond

Généré le 2026-11-07 10:52 par `python -m sgg optimize`.

## Cahier des charges

- charge de service 2.0 kg, coefficient de sécurité 3.0 → charge de calcul 58.9 N
- C : rayon intérieur 12.0 mm, ouverture 220.0°, tige 15.0 mm, vis Ø4 (tête Ø8.0), congés R2.0
- traction de vis ≤ 300.0 N, flèche ≤ 3.0 mm
- PLA : E=3000.0 MPa, X_t=40.0, Z_t=18.0, S_z=18.0, X_c=60.0 MPa
- FEA voxels 0.75 mm pendant l'optimisation, surplomb max 50.0° de la verticale, densité supports 0.25

## Optimiseurs

| méthode | évaluations | temps (s) | meilleure masse (g) | faisable |
|---|---|---|---|---|
| ga | 90 | 576 | 4.06 | True |
| random | 90 | 864 | 5.04 | True |

## Meilleur design

Optimisation (voxels 0.75 mm) : orientation **d=(+0.71,+0.71,+0.00)**, FI 0.98, total 4.06 g.
Vérification (voxels fins), même orientation : FI 1.02, total 4.06 g, faisable=False.

Aucune réparation nécessaire.

**Design final**

| paramètre | valeur (mm) |
|---|---|
| b | 4.21 |
| h_s | 6.01 |
| h_c | 6.96 |
| t_p | 3.61 |
| r_p | 6.41 |
| pad_back | 2.04 |

Orientation d'impression : **à plat (plan du crochet sur le plateau)** (d = (0.0, 1.0, 0.0)).

| grandeur | design final (voxels fins) |
|---|---|
| masse pièce (g) | 3.67 |
| masse supports estimée (g) | 0.55 |
| indice de rupture FI (charge de calcul) | 0.88 |
| capacité prédite (kg, sans SF) | 6.8 |
| flèche en service (mm) | 0.72 |
| traction de vis (N, charge de calcul) | 222 |
| σ tige poutre / FEA (MPa) | 38.3 / 41.4 |

### Comparaison des orientations (design final)

| orientation | FI | supports (g) | total (g) | hauteur (mm) | OK |
|---|---|---|---|---|---|
| à plat (plan du crochet sur le plateau) | 0.88 | 0.55 | 4.22 | 13 | ✓ |
| d=(+0.71,+0.71,+0.00) | 1.02 | 0.39 | 4.06 | 39 | ✗ |
| d=(-0.71,+0.71,+0.00) | 1.02 | 0.50 | 4.18 | 39 | ✗ |
| d=(+0.92,+0.00,+0.38) | 1.11 | 0.50 | 4.17 | 43 | ✗ |
| d=(-0.92,+0.00,-0.38) | 1.11 | 0.84 | 4.51 | 43 | ✗ |
| d=(-0.92,+0.00,+0.38) | 1.29 | 0.61 | 4.28 | 55 | ✗ |
| d=(+0.92,+0.00,-0.38) | 1.29 | 0.94 | 4.61 | 55 | ✗ |
| sur la tranche, pointe du C en haut | 1.30 | 0.68 | 4.35 | 51 | ✗ |
| sur la tranche, arrière de la semelle en haut | 1.30 | 0.78 | 4.45 | 51 | ✗ |
| d=(+0.58,+0.58,+0.58) | 1.30 | 0.23 | 3.90 | 32 | ✗ |
| d=(-0.58,+0.58,-0.58) | 1.30 | 0.44 | 4.12 | 33 | ✗ |
| d=(-0.58,+0.58,+0.58) | 1.34 | 0.41 | 4.08 | 47 | ✗ |
| d=(+0.58,+0.58,-0.58) | 1.34 | 0.68 | 4.35 | 47 | ✗ |
| d=(+0.71,+0.00,+0.71) | 1.42 | 0.23 | 3.90 | 38 | ✗ |
| d=(-0.71,+0.00,-0.71) | 1.42 | 0.47 | 4.14 | 38 | ✗ |
| d=(-0.71,+0.00,+0.71) | 1.53 | 0.18 | 3.85 | 55 | ✗ |
| d=(+0.71,+0.00,-0.71) | 1.53 | 0.78 | 4.46 | 55 | ✗ |
| d=(+0.00,+0.71,-0.71) | 1.53 | 0.19 | 3.87 | 32 | ✗ |
| d=(+0.00,+0.71,+0.71) | 1.53 | 0.24 | 3.91 | 32 | ✗ |
| d=(-0.38,+0.00,-0.92) | 1.78 | 0.92 | 4.59 | 36 | ✗ |
| d=(+0.38,+0.00,+0.92) | 1.78 | 1.37 | 5.04 | 36 | ✗ |
| d=(+0.38,+0.00,-0.92) | 1.85 | 1.03 | 4.70 | 48 | ✗ |
| d=(-0.38,+0.00,+0.92) | 1.85 | 2.20 | 5.87 | 48 | ✗ |
| semelle sur le plateau (debout) | 1.96 | 0.47 | 4.14 | 38 | ✗ |
| semelle en haut (crochet tête en bas) | 1.96 | 2.15 | 5.82 | 38 | ✗ |

## Gcode (OrcaSlicer CLI, profil Kobra X)

- fichier : `best_hook_kobra_x.gcode` — temps estimé 17m 59s
- filament Orca : total 5.00 g, pièce seule 3.50 g, supports 1.50 g
- estimation interne : pièce 3.67 g, supports 0.55 g
- réglages : 6 périmètres, remplissage 100%, couches 0.2 mm, saveur klipper
