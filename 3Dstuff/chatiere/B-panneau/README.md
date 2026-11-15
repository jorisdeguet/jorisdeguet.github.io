# Chatière d'hiver — Concept B : panneau isolé dans la coulisse

**Le principe :** on garde la fenêtre coulissante telle quelle. On remplace seulement le panneau gris à trou hexagonal (bouché par la serviette verte) par un **panneau sandwich isolé** qui glisse dans la même coulisse. Ce panneau porte une **vraie chatière à double volet**, soit achetée, soit imprimée en 3D.

---

## 1. Ce que montrent les photos

- **Vue intérieure (IMG_4179)** : le châssis mobile est à gauche et coulisse dans le rail intérieur. Le panneau gris occupe la partie droite, dans le rail extérieur. La poignée blanche du châssis vient fermer contre le chant du panneau. L'appui intérieur est profond (≈ 305 mm), avec une hauteur d'ouverture d'environ 368 mm.
- **Vue extérieure (IMG_4180)** : le cadre blanc du dormant recouvre les bords du panneau gris. La partie visible du panneau (le « clair de jour ») est **nettement plus petite que 368 mm**. D'après les proportions de la photo, j'estime le clair de jour à 230–260 mm de haut. **C'est la cote la plus critique : il faut la mesurer.**
- L'ouverture donne sur une margelle (window well). Un bloc de béton sert de marche. Le chat entre donc presque à l'horizontale.

> Conséquence de conception : on ne peut **pas** épaissir le panneau partout. Ses bords doivent rester minces pour entrer dans la coulisse et laisser passer le recouvrement du châssis mobile. On fait donc un panneau **à deux niveaux** :
> 1. une **peau extérieure mince** (3–6 mm), découpée exactement aux dimensions du panneau gris, qui glisse dans la coulisse ;
> 2. un **caisson isolé** (cadre bois + 2ᵉ peau) collé sur sa face intérieure, de la taille du clair intérieur. Il est en retrait des rails et de la zone où le châssis mobile vient recouvrir le panneau.

## 2. Croquis

Coupe horizontale (vue de dessus) :

```
   EXTÉRIEUR (margelle)
 ───────────────┐                                    ┌───────────── dormant
   lèvre dormant│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  ← peau ext. 3-6 mm (dans la coulisse)
                │   ┌──[auvent]───────────────┐  ║║ │  ║ = montant à brosse imprimé
                │   ║▒ cadre bois 1x2 (38) ▒▒▒║  ║║ │     (pince sur le chant)
                │   ║▒   ┌─tunnel imprimé─┐ ▒▒║  ║║ │
                │   ║▒   │ volet 1 ⟋      │ ▒▒║  ║║ │
                │   ║▒   │ volet 2 ⟋      │ ▒▒║  ┌─┴──────── châssis coulissant
                │   ║▒   └────────────────┘ ▒▒║  │  (recouvre ~25-45 mm)
                │   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  └──────────
                │    ↑ peau intérieure         ↑ retrait "inset_sash"
   INTÉRIEUR (appui profond 305 mm)
```

Coupe verticale dans le tunnel :

```
          collerette ext.    peau ext.  cadre/air  peau int.   collerette int.
              │  auvent        │                    │              │
          ◄───┤▀▀▀▀            │                    │              │
              ├─────────────────────────────────────────────────────┤ plafond + brosse
              │  ○ axe 3 mm                                 ○ axe   │
              │  ┃ volet ext.          lame d'air            ┃ volet int.
              │  ┃  (PETG 3 mm)        ~36 mm                ┃
              │  ┃                                           ┃
              │  ■ aimant 8x3                                ■
              ├──■──────────────────────────────────────────■───────┤ plancher + brosse
           boulons M4 + entretoises traversent le sandwich sur les côtés
```

## 3. Mesures à prendre (checklist)

Mesurez au mm, de préférence avec un pied à coulisse pour les épaisseurs. Prenez une photo de chaque mesure avec le ruban.

**Le panneau gris (une fois sorti)**
- [ ] A. Largeur totale du panneau, au point le plus large.
- [ ] B. Hauteur totale du panneau, à gauche **et** à droite (parfois en biais).
- [ ] C. Épaisseur du panneau, et présence éventuelle d'un profilé en U ou d'un joint sur le pourtour.
- [ ] D. Matériau et mode de retenue : vis, clips, butée, ou simplement serré par le châssis ?
- [ ] E. Dimensions et position du trou hexagonal (centre par rapport aux bords).

**La coulisse (panneau retiré)**
- [ ] F. Largeur intérieure de la rainure du rail où glisse le panneau, en haut et en bas.
- [ ] G. Profondeur de la rainure en haut et en bas. Le haut est souvent plus profond pour permettre l'insertion « monter puis descendre ».
- [ ] H. Distance entre la face intérieure du panneau gris et la face extérieure du châssis mobile fermé (l'écart à combler par la brosse : `rib_h` + hauteur de velours).
- [ ] I. **Recouvrement** : sur quelle largeur le montant du châssis mobile passe-t-il devant le panneau une fois fermé ? (→ `inset_sash`, plus 10 mm de marge)
- [ ] J. Hauteur des rails intérieurs au-dessus et au-dessous du panneau (→ `inset_tb`).

**Les clairs**
- [ ] K. **Clair de jour extérieur** : hauteur et largeur visibles du panneau entre les lèvres du dormant. La collerette extérieure doit y entrer : collerette par défaut 207 × 200 mm.
- [ ] L. **Clair intérieur** entre les rails et le montant du dormant. Le caisson et la collerette intérieure doivent y entrer.
- [ ] M. Profondeur libre devant la fenêtre, à l'intérieur (≈ 305 mm d'après vous). Il faut ~60 mm pour le caisson et ~170 mm pour le volet intérieur qui s'ouvre.

**Verrouillage**
- [ ] N. Où s'accroche le loquet du châssis mobile ? Sur une gâche du dormant (OK), ou sur l'ancien panneau fixe, auquel cas il faut une solution de remplacement (§ 6) ?

**Le chat**
- [ ] O. Largeur des épaules et hauteur au garrot. Le passage par défaut fait 150 × 165 mm, ce qui convient à un chat jusqu'à environ 6–7 kg. Un Maine Coon demande plus.

**Le verre**
- [ ] P. Vos vitres 411 × 309 mm : épaisseur ? Y a-t-il un **poinçon « TEMPERED / TREMPÉ »** dans un coin ? (voir § 5)

## 4. Option (a) chatière du commerce vs (b) tunnel imprimé

| | **PetSafe Extreme Weather (Small)** | **Cat Mate 4-way vitre (210)** | **SureFlap Microchip + adaptateur vitre** | **Endura Flap (cat / small)** | **Tunnel imprimé (ce dossier)** |
|---|---|---|---|---|---|
| Volets | **3 volets** + aimants | 1 volet, aimant + brosse | 1 volet, joint brosse | 1 volet souple épais (option double) | **2 volets** + 4 brosses + aimants |
| Découpe | rectangle 162 × 257 mm (6⅜" × 10⅛") | rond **Ø 223 mm** | rond **Ø 212 mm** (adaptateur Ø 285, trous 210–260) | rectangle, selon la taille | rectangle 158 × 173 mm (paramétrique) |
| Encombrement | cadre ≈ 191 × 279 mm | Ø ≈ 245 mm | Ø ≈ 285 mm avec adaptateur | ≈ 250–300 mm | collerette **207 × 200 mm** |
| Épaisseur acceptée | porte de 41–57 mm (1⅝"–2¼") : **colle avec un sandwich de 44 mm** | vitrage jusqu'à ~30 mm (à vérifier) | vitrage simple ou double (à vérifier) | panneau / porte, kits d'épaisseur | `panel_t` paramétrique, 30–80 mm |
| Prix CAD ≈ (à vérifier) | 120–170 $ | 45–70 $ | 200–260 $ + 25–35 $ | 250–350 $ (import US) | ≈ 30 $ (filament, aimants, velours) |
| Entre dans un clair de ~240 mm ? | **Non** (279 mm) | **Limite** | **Non** | Probablement non | **Oui** |
| Anti-raton / anti-voisin | verrou manuel | verrou 4 positions | **lecteur de puce** | verrou | aimants seulement (verrou à ajouter) |

Liens (prix et spécifications à revérifier avant d'acheter) :
- PetSafe Extreme Weather (Canada) : https://www.petsafe.com/en-ca/p/extreme-weather-pet-door/HPA11-10988/ · Pet Valu : https://www.petvalu.ca/product/petsafe-extreme-weather-pet-door/SCM03747CA · fiche détaillée : https://www.petsmart.com/5127356.html
- Cat Mate 4-way glass fitting (210) : https://www.zooplus.com/shop/cats/cat_flaps_nets/catmate/127606
- SureFlap, adaptateur de montage : https://www.ypc.co.uk/product/sureflap-pet-door-mounting-adaptor-white/
- Endura Flap : site du fabricant (recherche « Endura Flap cat door ») ; tailles et prix variables, expédié des É.-U.
- « Transcat » et autres chatières isolées québécoises ou canadiennes : je n'ai pas pu confirmer de modèle ni de cotes. Demandez en animalerie locale ou chez une quincaillerie de portes et fenêtres.

**Verdict :**
- Si votre clair de jour (mesure K) est **≥ 290 mm** de haut, la **PetSafe Extreme Weather Small** est la meilleure option achetée : trois volets, épaisseur 41–57 mm compatible avec le sandwich de 44 mm, découpe rectangulaire facile dans du polycarbonate.
- S'il est plus petit, ce qui est probable vu les photos, aucune chatière isolée du commerce n'entre. Le **tunnel imprimé** est alors la solution. Il est dimensionné pour entrer dans environ 205 mm.
- Si des chats du voisinage ou des ratons laveurs posent problème, seule la **SureFlap** règle vraiment la question, mais elle exige un clair de ~290 mm.

## 5. Le verre : l'utiliser, le couper, ou le remplacer

- **On ne perce pas de trou dans du verre soi-même.** Un trou de chatière dans le verre demande un vitrier : 50–100 $, et le verre ne doit pas être trempé. Le trou ne se fait donc pas dans vos vitres.
- **Verre trempé** (poinçon dans un coin) : **il ne se coupe pas du tout**. Il éclate en morceaux. Vous pouvez seulement l'utiliser entier.
- **Verre recuit (normal)** : une coupe droite est faisable.
  1. Achetez un coupe-verre à molette à réservoir d'huile (Red Devil, Fletcher, Toyo ; ~15–30 $) et de l'huile de coupe, ou de l'huile 3-en-1.
  2. Nettoyez la vitre. Posez-la à plat sur un tapis ou un carton. Tracez la ligne au marqueur, avec une règle métallique fixée par des serre-joints.
  3. Faites **un seul passage** avec une pression ferme et constante, d'un bord à l'autre, sans revenir. Le trait doit « grésiller ».
  4. Placez le trait au-dessus d'un bord de table ou d'un goujon. Appuyez d'un coup sec des deux côtés, ou utilisez une pince à rompre.
  5. Adoucissez les arêtes à la pierre ou au papier carbure n° 220 sous l'eau. Portez des gants, des lunettes et des manches longues. Entraînez-vous d'abord sur une chute.
  - Une bande de moins de ~25 mm se casse mal. Prévoyez la coupe pour enlever au moins 30 mm.
- **Recommandation :** pour les peaux qui reçoivent le trou du tunnel, utilisez du **polycarbonate**. Il se coupe à la scie (scie sauteuse lame fine, ou scie circulaire lame à dents fines, en reculant le film protecteur). Il se perce sans risque, il est incassable et il isole mieux que le verre.
  - Peau extérieure : polycarbonate plein de **3 à 6 mm**. Le polycarbonate résiste aux UV et aux chocs. Évitez l'acrylique à l'extérieur, car il fissure au perçage par grand froid.
  - Peau intérieure : polycarbonate 3 mm, ou **polycarbonate alvéolaire 6–8 mm** (twinwall), qui isole mieux et coûte moins cher.
  - **Vos vitres 411 × 309 mm** peuvent servir sans coupe en **contre-fenêtre intérieure** posée dans l'embrasure, sur la partie vitrée du châssis mobile. Ça améliore toute la fenêtre. Elles peuvent aussi servir de peau intérieure du caisson **si** le clair intérieur les accepte entières (mesure L) et que le tunnel passe *à côté* du verre. C'est rarement le cas ici.

## 6. Étanchéité contre le châssis coulissant et verrouillage

1. **Peau extérieure dans la coulisse** : même dimension que le panneau gris (A × B) moins 1 mm. Sur le chant haut et bas, posez du **ruban mousse EPDM à cellules fermées** (3–5 mm) ou un **V-strip** (bande en V vinyle ou bronze). La peau doit glisser serrée. Quand la peau est plus mince que la rainure F, on comble avec le ruban : posez-en sur les deux faces du bord.
2. **Chant côté dormant** : mousse EPDM comprimée ou cordon de silicone. Ce côté ne bouge pas.
3. **Côté châssis mobile** : le **montant imprimé** (`part="montant"`) se clipse sur le chant de la peau, en 2 tronçons de 130 mm ou moins si la hauteur est plus grande. Il porte une nervure rainurée qui reçoit du **coupe-froid à velours (pile weatherstrip) 3/16" × 1/4"**. Le velours frotte sur la face extérieure du montant du châssis mobile quand celui-ci est fermé, comme le joint d'origine d'une coulissante. Réglez `rib_h` avec la mesure H : `rib_h ≈ H − hauteur de velours + 1 mm`.
4. **Caisson intérieur** : son pourtour (cadre bois) est collé et scellé au silicone sur la peau extérieure. C'est le caisson qui fait l'isolation : une lame d'air de ~38 mm entre deux peaux, comme un double vitrage maison. Vous pouvez remplir le cadre autour du tunnel de **mousse XPS rose ou bleue** (opaque mais R-5/po) si la lumière n'est pas importante.
5. **Verrouillage** : si le loquet s'accrochait à l'ancien panneau (mesure N), deux solutions :
   - un **bloque-fenêtre coulissante** vissé dans le rail (~8–15 $, Rona / Home Depot) ;
   - un simple **goujon de bois** coupé à longueur et posé dans le rail derrière le châssis.

   De toute façon, une chatière dans une fenêtre de sous-sol mérite ce blocage.
6. Vérifiez que le châssis mobile **ferme complètement** sans toucher le caisson : `inset_sash` doit dépasser le recouvrement I d'au moins 10 mm.

## 7. Condensation, givre, neige

- **Condensation** : la lame d'air entre les deux peaux doit être **étanche côté intérieur** (silicone continu sur le cadre et autour du tunnel) et **légèrement ventilée côté extérieur**. Faites un ou deux trous de Ø 3 mm en bas du cadre bois, vers l'extérieur. C'est la règle des contre-fenêtres : l'air humide de la maison ne doit pas atteindre la paroi froide.
- **Givre sur le volet extérieur** : c'est le principal problème des chatières à aimant par -20 °C. Le volet extérieur colle par la glace.
  - Le volet est en **PETG**, pas en PLA : le PLA devient cassant au froid et se déforme au soleil.
  - Les aimants sont **noyés** sous une peau de 0,8 mm, et non face à face à nu.
  - Le jeu au plancher est de 2 mm, pour ne pas souder le volet au seuil.
  - Le **volet intérieur** reste au chaud. C'est lui qui assure l'étanchéité quand l'extérieur givre.
  - Si le volet extérieur colle quand même, réduisez l'aimant extérieur à 6 × 2 mm, ou supprimez-le. Le velours suffit à limiter le vent. Ne mettez pas de graisse : elle ramasse la poussière.
- **Pente** : posez le panneau pour que le plancher du tunnel penche de 1–2° vers l'extérieur. Une cale sous le caisson suffit. L'eau de fonte sort ainsi au lieu de geler dans le tunnel.
- **Margelle** : déneigez la margelle et gardez un dégagement d'au moins 25 cm sous l'ouverture. L'**auvent** imprimé empêche l'eau qui ruisselle sur la peau de couler dans le tunnel.

## 8. Liste de matériel (prix CAD approximatifs, nov. 2026)

| Article | Qté | Prix ≈ | Où |
|---|---|---|---|
| Polycarbonate plein 3 mm (ou 4,5–6 mm pour l'extérieur), feuille 18" × 24" ou 24" × 36" | 1–2 | 30–60 $ | Rona, Home Depot, Canac, Plastique Polyalto |
| *ou* polycarbonate alvéolaire 6–8 mm (peau intérieure) | 1 | 25–40 $ | Rona, Canac |
| Bois 1x2 (19 × 38) pin, 8' | 1 | 5 $ | quincaillerie |
| Filament **PETG**, ≈ 450 g (2 demi-coques, 2 volets, auvent, montant, entretoises) | — | 15 $ | |
| Aimants néodyme 8 × 3 mm (lot de 20) | 1 | 10–15 $ | Amazon.ca, Lee Valley |
| Tige acier ou inox Ø 3 mm (axes), 2 × ~160 mm | 1 | 5 $ | quincaillerie (ou clous longs) |
| Coupe-froid à velours 3/16" × 1/4" (pile weatherstrip), 5 m | 1 | 10–15 $ | Rona / Home Depot (M-D, Frost King) |
| Ruban mousse EPDM cellules fermées 3–6 mm | 1 | 10 $ | idem |
| Cordon mousse Ø 4 mm (backer rod) ou cordon EPDM, rainure de collerette | 1 | 5 $ | idem |
| Boulons M4 × 60 mm tête fraisée + écrous M4 (lot) | 6 + 2 | 8 $ | idem |
| Silicone transparent extérieur | 1 | 10 $ | idem |
| (opt.) Mousse XPS 1½" 2' × 2' | 1 | 12 $ | idem |
| (opt.) Bloque-fenêtre coulissante | 1 | 10 $ | idem |
| (opt.) Coupe-verre à molette + huile | 1 | 20 $ | idem |
| **Total version imprimée** | | **≈ 120–170 $** | |
| (alt.) PetSafe Extreme Weather Small, *à la place* des pièces imprimées du tunnel | 1 | +120–170 $ | Pet Valu, PetSmart, Amazon.ca |

## 9. Étapes de construction

1. **Mesurer** (§ 3). Reportez les mesures dans le bloc de paramètres du `.scad` : `skin_W`, `skin_H`, `inset_*`, `panel_t`, `hole_w`, `hole_h`, `montant_len`, `rib_h`. Vérifiez dans l'aperçu `assembled` que tout tient, et lisez les `ECHO` et `assert`.
2. **Imprimer un test** : `demi_int` réduit, ou une tranche, pour valider les jeux de l'axe, de l'aimant et du velours.
3. **Peau extérieure** : tracez le panneau gris sur le polycarbonate et coupez-le. Imprimez le `gabarit`, collez-le au ruban, découpez le rectangle du tunnel (perçages aux coins, puis scie sauteuse) et percez les 6 trous M4.
4. **Cadre bois** : coupez 4 morceaux de 1x2 posés à plat (38 mm d'épaisseur) aux dimensions du caisson. Ajoutez des traverses de chaque côté du tunnel pour les boulons, ou utilisez les **entretoises imprimées**. Collez-le à la peau extérieure au silicone ou à la colle PU. Percez les trous de ventilation de § 7.
5. **Peau intérieure** : coupez-la, percez-la avec le même gabarit et scellez-la au silicone sur le cadre.
6. **Tunnel** :
   - Imprimez en PETG, collerette à plat, sans support : 3 parois, 25 % de remplissage, 0,2 mm.
   - Collez les aimants (polarité **attirante** entre volet et plancher, marquez-les au feutre avant) à la cyano ou à l'époxy.
   - Posez le velours dans les rainures.
   - Enfilez les axes dans les volets et les demi-coques.
7. **Assemblage** :
   - Posez un cordon mousse dans les rainures de collerette.
   - Insérez la demi-coque extérieure par l'extérieur et la demi-coque intérieure par l'intérieur. La languette s'emboîte dans la rainure : ajoutez un filet de silicone.
   - Boulonnez au travers, en serrant modérément.
   - Vissez l'auvent sur les 2 boulons du haut. Prenez des boulons plus longs, et la fraisure passe sur l'auvent.
8. **Montant** : clipsez-le sur le chant côté châssis mobile (une goutte de colle) et posez le velours.
9. **Pose** :
   - Retirez le panneau gris et nettoyez les rails.
   - Posez le ruban EPDM sur les chants haut et bas.
   - Insérez le panneau en le montant d'abord dans la rainure du haut, puis en le laissant descendre.
   - Fermez le châssis et vérifiez le contact du velours, par exemple avec un bâton d'encens les jours de vent.
   - Posez le bloque-fenêtre.
10. **Habituer le chat** : attachez les volets ouverts à l'aide de ruban pendant quelques jours, puis libérez d'abord le volet intérieur.

## 10. Le fichier OpenSCAD `chatiere_panneau.scad`

Variable `part` (menu déroulant du Customizer) :

| part | pièce | qté | taille (défaut) |
|---|---|---|---|
| `assembled` | aperçu : peaux, cadre, tunnel, volets, auvent, montant (`explode`, `flap_angle`) | — | — |
| `demi_ext` | demi-coque extérieure (languette, fraisures) | 1 | 207 × 200 × 28 mm |
| `demi_int` | demi-coque intérieure (rainure, pièges à écrou) | 1 | 207 × 200 × 26 mm |
| `volet` | volet battant à imprimer à plat | 2 | 142 × 159 mm |
| `auvent` | auvent anti-ruissellement | 1 | 207 × 35 mm |
| `entretoise` | entretoise de boulon (empêche d'écraser le sandwich) | 6 | Ø 9 × 38 mm |
| `montant` | tronçon de montant à velours, pince sur le chant | `nseg` | ≤ 250 mm |
| `gabarit` | gabarit de découpe et perçage (1,2 mm) | 1 | 207 × 200 mm |

Le fichier contient aussi :
- Les **contrôles automatiques**, qui bloquent la génération en cas de problème :
  - collerette de plus de 260 mm (plateau Kobra X) ;
  - panneau trop mince pour les volets (minimum ~30 mm) ;
  - tunnel plus grand que le caisson.
- Le **découpage du montant** : il est découpé automatiquement en tronçons d'au plus `seg_max`.

Les autres pièces font moins de 260 mm avec un passage jusqu'à environ 200 × 210 mm. Au-delà, il faudrait couper les collerettes : ce n'est pas implémenté.

Rendu en ligne de commande :

```sh
openscad -o demi_ext.stl -D 'part="demi_ext"' chatiere_panneau.scad
openscad -o apercu.png --imgsize=1200,900 -D 'explode=60' -D 'flap_angle=-35' chatiere_panneau.scad
```

## 11. Pour / contre du concept B

**Pour**
- Il réutilise l'emplacement existant : aucune coupe dans le cadre ni dans le mur. C'est réversible, et on remet le panneau gris au printemps si on veut.
- La double peau avec lame d'air et la double porte à brosses donnent un gain énorme par rapport à la serviette. Infiltration d'air quasi nulle quand le châssis est fermé et bloqué.
- La version imprimée coûte peu (~30 $ de pièces) et s'adapte au mm près au petit clair de jour.
- Le panneau reste en partie translucide : lumière et vue sur la margelle.

**Contre**
- Le clair de jour (peut-être moins de 250 mm) **limite la taille** du passage et exclut probablement les chatières isolées du commerce.
- L'étanchéité dépend du contact velours contre châssis mobile. Si le châssis est mal fermé, ça fuit. Il faut un blocage.
- Le volet extérieur peut givrer par grand froid. Le volet intérieur compense, mais le chat doit pousser deux volets.
- Une chatière dans une fenêtre de sous-sol reste un point faible de sécurité (bloquer le coulissant).
- Il faut un peu de rigueur : bien mesurer, silicone propre pour éviter la condensation entre les peaux.

**Recommandation :**
1. Faites d'abord les mesures K, L, H et I.
2. Si K est d'au moins 290 mm, achetez une **PetSafe Extreme Weather Small** et montez-la dans un sandwich polycarbonate + cadre 1x2 de 44 mm.
3. Sinon, imprimez le **tunnel à double volet** de ce dossier, en PETG, avec une peau extérieure en polycarbonate de 4,5–6 mm.
4. Dans les deux cas, ne coupez pas vos vitres pour ça. Gardez-les pour une contre-fenêtre intérieure sur la partie vitrée.
