# Manchon de réparation pour câble Lightning

Coque en deux moitiés **identiques**, imprimée en PLA, qu'on remplit de colle chaude
pour réparer un câble Lightning dont la jonction connecteur/câble ou la gaine de
protection (le « boot ») se brise.

- Le manchon s'arrête **au ras** de la face avant de la tête : toute la languette
  métallique reste dégagée et la fiche entre à fond dans le téléphone.
- Il entoure la tête puis se prolonge en cône le long du câble (anti-pliage).
- Parois minces (0,8 mm) pour passer dans la plupart des étuis d'iPhone.

Fichier : [`lightning_sleeve.scad`](lightning_sleeve.scad) (OpenSCAD 2021.01 ou plus récent).

## 1. Mesurer son câble (pied à coulisse)

Les valeurs par défaut viennent d'un câble Apple d'origine. Les têtes de câbles
non Apple varient beaucoup : mesurez et ajustez dans le Customizer d'OpenSCAD :

| Paramètre | Quoi mesurer | Défaut |
|---|---|---|
| `head_w` × `head_t` | largeur × épaisseur de la tête plastique | 8,0 × 5,4 |
| `head_len` | longueur de la tête rigide (face avant → début du boot) | 10 |
| `boot_d0`, `boot_d1`, `boot_len` | boot en caoutchouc (mettre `boot_len = 0` si on l'a coupé) | 4,2 / 3,3 / 8 |
| `cable_d` | diamètre du câble | 3,2 |
| `glue` | jeu pour la colle, par côté | 0,35 |
| `wall` | épaisseur de paroi | 0,8 |

### Compatibilité avec l'étui

L'ouverture de l'étui autour du port Lightning est arrondie : **13,65 mm de large ×
6,85 mm de haut** (`keepout_w`, `keepout_t`). Le manchon complet fait ≈ 10,3 × 7,7 mm :
trop épais. Les `keepout_len` premiers millimètres (6 mm par défaut, à régler selon la
profondeur à laquelle la tête entre dans l'étui) sont donc rognés à ce contour, moins
`keepout_margin` (0,15 mm) de jeu par côté, soit ≈ 10,3 × 6,55 mm.

Le manchon entoure quand même la tête **sur les 4 côtés** dans cette zone. Autour d'une
tête Apple (5,4 mm d'épaisseur), il ne reste que ≈ 0,57 mm par côté sur les faces
minces : le jeu de colle dessus/dessous y passe donc à `glue_ko` (0,1 mm) et la paroi
dessus/dessous fait ≈ 0,48 mm (4 couches à 0,12 mm). Les côtés gardent le jeu de colle
et la paroi normaux. La console affiche l'épaisseur obtenue et avertit si elle descend
sous `min_skin` (0,4 mm).

## 2. Exporter

Paramètre `part` :

- `"both_print"` : les deux moitiés côte à côte, prêtes à trancher (le plus simple) ;
- `"bottom"` / `"top"` : une seule moitié (elles sont identiques, en imprimer 2) ;
- `"assembled"` : aperçu fermé avec un connecteur « fantôme » (ne pas imprimer).

Puis F6 → *Export STL*.

## 3. Imprimer (PLA, Kobra X)

- **Orientation** : telle qu'exportée, **face de jonction plate sur le plateau**,
  extérieur vers le haut. Pas de supports : le seul surplomb est le plafond de la
  cavité de la tête, un petit pont de 6–7 mm.
- Hauteur de couche **0,12 mm** : la paroi dessus/dessous à l'avant ne fait que ≈ 0,48 mm.
- 100 % de remplissage (de toute façon presque tout est paroi), 2 périmètres.
- Buse 0,4 mm, vitesse réduite (les pièces sont minuscules) ; activer le
  refroidissement minimum par couche pour éviter qu'elles ramollissent.
- Bordure (brim) seulement si les pièces décollent.

## 4. Assembler à la colle chaude

1. **Protéger la languette métallique** avec un ruban de masquage : aucune colle ne
   doit toucher les contacts.
2. Couper/éliminer les morceaux de gaine qui pendent ; si des fils sont à nu,
   les isoler d'abord (gaine thermo ou ruban).
3. Couper **2 tiges de filament 1,75 mm** de la longueur affichée dans la console
   (≈ 4,4 mm) et les enfoncer dans les trous d'une moitié.
4. Faire un essai à blanc : la tête doit se loger sans forcer, face avant au ras du
   bord du manchon.
5. Remplir la première moitié de colle chaude (sans excès), poser le câble, bien
   aligner la face avant de la tête avec le bord du manchon.
   Sur les 6 premiers mm, mettre très peu de colle sur le dessus et le dessous de la
   tête (le jeu n'est que de 0,1 mm) : la colle va surtout sur les côtés et vers
   l'arrière. Trop de colle à cet endroit empêcherait la coque de bien fermer.
6. Ajouter un filet de colle par-dessus, fermer avec la deuxième moitié et serrer
   entre les doigts (ou une pince à linge) ~1 min. L'excès sort par les petits
   évents et par l'arrière autour du câble.
7. Une fois refroidi, couper les bavures au cutter, retirer le ruban et vérifier
   qu'il ne reste pas de colle sur la fiche.

> Astuce : le PLA ramollit vers 60 °C et la colle chaude sort à 120–190 °C. Les
> parois minces peuvent se déformer : travailler vite, ne pas noyer la pièce, ou
> utiliser un pistolet basse température.

## Sources des cotes

Détails et liens dans l'en-tête du fichier `.scad` ([O] = officiel, [M] = mesuré) :
Wikipédia « Lightning (connector) » pour la fiche 6,7 × 1,5 mm ; les *Accessory
Design Guidelines for Apple Devices* d'Apple pour l'encombrement compatible étuis ;
les mesures de la tête, du boot et du câble sont approximatives.
